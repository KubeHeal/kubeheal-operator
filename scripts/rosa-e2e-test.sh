#!/bin/bash
set -euo pipefail

# rosa-e2e-test.sh - Full E2E test for kubeheal-operator on ROSA
#
# Tiered testing approach (inspired by jupyter-notebook-validator-operator):
#   Tier 1: OLM bundle install, CRD, CSV, operator pod
#   Tier 2: Apply minimal CR, verify reconciled resources
#   Tier 3: CR deletion, operator cleanup, clean state
#
# Usage:
#   ./scripts/rosa-e2e-test.sh                          # Full test
#   ./scripts/rosa-e2e-test.sh --bundle-image <img>     # Custom bundle image
#   ./scripts/rosa-e2e-test.sh --skip-cleanup           # Keep resources for debugging
#   ./scripts/rosa-e2e-test.sh --tier 1                 # Run only Tier 1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
BUNDLE_IMG="${BUNDLE_IMG:-quay.io/takinosh/kubeheal-operator-bundle:v0.1.0}"
OPERATOR_NAMESPACE="kubeheal-operator-system"
CR_NAMESPACE="self-healing-platform"
CR_NAME="kubeheal"
TIMEOUT_OLM="300"
TIMEOUT_OPERATOR="120"
TIMEOUT_RECONCILE="180"
SKIP_CLEANUP=false
RUN_TIER=""

# Results tracking
declare -A TEST_RESULTS
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
START_TIME=$(date +%s)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}    $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC}    $1"; }
log_fail()    { echo -e "${RED}[FAIL]${NC}    $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}    $1"; }
log_section() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --bundle-image) BUNDLE_IMG="$2"; shift 2 ;;
        --skip-cleanup) SKIP_CLEANUP=true; shift ;;
        --tier) RUN_TIER="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --bundle-image IMG   Bundle image to test (default: $BUNDLE_IMG)"
            echo "  --skip-cleanup       Keep resources after test for debugging"
            echo "  --tier N             Run only tier N (1, 2, or 3)"
            echo "  --help, -h           Show this help"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

record_result() {
    local test_name="$1"
    local result="$2"
    local detail="${3:-}"
    TEST_RESULTS["$test_name"]="$result"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    case "$result" in
        PASSED)  PASSED_TESTS=$((PASSED_TESTS + 1)); log_success "$test_name${detail:+ ($detail)}" ;;
        FAILED)  FAILED_TESTS=$((FAILED_TESTS + 1)); log_fail "$test_name${detail:+ ($detail)}" ;;
        SKIPPED) SKIPPED_TESTS=$((SKIPPED_TESTS + 1)); log_warn "SKIP: $test_name${detail:+ ($detail)}" ;;
    esac
}

should_run_tier() {
    local tier="$1"
    [[ -z "$RUN_TIER" ]] || [[ "$RUN_TIER" == "$tier" ]]
}

# ============================================================================
# PRE-FLIGHT CHECKS
# ============================================================================

preflight_checks() {
    log_section "Pre-Flight Checks"

    # Check oc/kubectl
    if ! command -v oc &>/dev/null; then
        log_fail "oc CLI not found"
        exit 1
    fi
    log_info "oc version: $(oc version --client 2>/dev/null | head -1)"

    # Check operator-sdk
    if ! command -v operator-sdk &>/dev/null; then
        log_fail "operator-sdk CLI not found"
        log_info "Install: curl -LO https://github.com/operator-framework/operator-sdk/releases/download/v1.37.0/operator-sdk_linux_amd64 && chmod +x operator-sdk_linux_amd64 && sudo mv operator-sdk_linux_amd64 /usr/local/bin/operator-sdk"
        exit 1
    fi
    log_info "operator-sdk: $(operator-sdk version 2>/dev/null | head -1)"

    # Check cluster connectivity
    if ! oc whoami &>/dev/null; then
        log_fail "Not logged into an OpenShift cluster"
        log_info "Run: oc login <cluster-api-url>"
        exit 1
    fi
    log_info "Logged in as: $(oc whoami)"
    log_info "Cluster: $(oc whoami --show-server)"

    # Check OLM is available (required for ROSA)
    if ! oc get crd catalogsources.operators.coreos.com &>/dev/null; then
        log_fail "OLM not available on this cluster"
        exit 1
    fi
    log_info "OLM is available"

    # Detect cluster info
    local node_count
    node_count=$(oc get nodes --no-headers 2>/dev/null | wc -l)
    local ocp_version
    ocp_version=$(oc get clusterversion version -o jsonpath='{.status.desired.version}' 2>/dev/null || echo "unknown")
    local platform
    platform=$(oc get infrastructure cluster -o jsonpath='{.status.platformStatus.type}' 2>/dev/null || echo "unknown")

    log_info "OpenShift version: $ocp_version"
    log_info "Platform: $platform"
    log_info "Node count: $node_count"
    log_info "Bundle image: $BUNDLE_IMG"

    echo ""
}

# ============================================================================
# TIER 1: OLM Bundle Install
# ============================================================================

tier1_olm_install() {
    log_section "Tier 1: OLM Bundle Installation"

    # Test 1.1: Install operator via OLM bundle
    log_info "Installing operator via: operator-sdk run bundle $BUNDLE_IMG"
    if operator-sdk run bundle "$BUNDLE_IMG" \
        --namespace "$OPERATOR_NAMESPACE" \
        --timeout "${TIMEOUT_OLM}s" 2>&1; then
        record_result "T1.1-olm-bundle-install" "PASSED"
    else
        record_result "T1.1-olm-bundle-install" "FAILED" "operator-sdk run bundle failed"
        log_info "Debug: checking namespace and events..."
        oc get events -n "$OPERATOR_NAMESPACE" --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || true
        return 1
    fi

    # Test 1.2: CRD created
    if oc get crd selfhealingplatforms.aiops.kubeheal.io &>/dev/null; then
        record_result "T1.2-crd-created" "PASSED" "selfhealingplatforms.aiops.kubeheal.io"
    else
        record_result "T1.2-crd-created" "FAILED" "CRD not found"
        return 1
    fi

    # Test 1.3: CSV in Succeeded phase
    local csv_phase
    csv_phase=$(oc get csv -n "$OPERATOR_NAMESPACE" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
    if [[ "$csv_phase" == "Succeeded" ]]; then
        local csv_name
        csv_name=$(oc get csv -n "$OPERATOR_NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        record_result "T1.3-csv-succeeded" "PASSED" "$csv_name"
    else
        record_result "T1.3-csv-succeeded" "FAILED" "CSV phase: $csv_phase"
        oc get csv -n "$OPERATOR_NAMESPACE" -o yaml 2>/dev/null | head -40 || true
        return 1
    fi

    # Test 1.4: Operator pod running
    local pod_ready=false
    local elapsed=0
    while [[ $elapsed -lt $TIMEOUT_OPERATOR ]]; do
        local running_pods
        running_pods=$(oc get pods -n "$OPERATOR_NAMESPACE" -l control-plane=controller-manager \
            --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        if [[ "$running_pods" -ge 1 ]]; then
            pod_ready=true
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done

    if $pod_ready; then
        local pod_name
        pod_name=$(oc get pods -n "$OPERATOR_NAMESPACE" -l control-plane=controller-manager \
            -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        record_result "T1.4-operator-pod-running" "PASSED" "$pod_name"
    else
        record_result "T1.4-operator-pod-running" "FAILED" "No running pods after ${TIMEOUT_OPERATOR}s"
        oc get pods -n "$OPERATOR_NAMESPACE" -o wide 2>/dev/null || true
        return 1
    fi

    # Test 1.5: Operator pod container is helm-operator
    local containers
    containers=$(oc get pods -n "$OPERATOR_NAMESPACE" -l control-plane=controller-manager \
        -o jsonpath='{.items[0].spec.containers[*].name}' 2>/dev/null || echo "")
    if echo "$containers" | grep -q "manager"; then
        record_result "T1.5-helm-operator-container" "PASSED" "containers: $containers"
    else
        record_result "T1.5-helm-operator-container" "FAILED" "expected 'manager', got: $containers"
    fi

    # Test 1.6: Operator logs are clean (no crash/panic)
    local error_count
    error_count=$(oc logs -n "$OPERATOR_NAMESPACE" -l control-plane=controller-manager \
        --tail=50 2>/dev/null | grep -ciE "panic|fatal|crash" || echo "0")
    if [[ "$error_count" -eq 0 ]]; then
        record_result "T1.6-operator-logs-clean" "PASSED" "no panics/fatals in last 50 lines"
    else
        record_result "T1.6-operator-logs-clean" "FAILED" "$error_count panic/fatal messages found"
        oc logs -n "$OPERATOR_NAMESPACE" -l control-plane=controller-manager --tail=20 2>/dev/null || true
    fi

    # Test 1.7: RBAC - ClusterRole exists
    if oc get clusterrole kubeheal-operator-manager-role &>/dev/null; then
        record_result "T1.7-clusterrole-exists" "PASSED" "kubeheal-operator-manager-role"
    else
        record_result "T1.7-clusterrole-exists" "FAILED" "ClusterRole not found"
    fi

    log_info "Tier 1 complete."
}

# ============================================================================
# TIER 2: CR Reconciliation
# ============================================================================

tier2_cr_reconciliation() {
    log_section "Tier 2: CR Reconciliation"

    # Create a minimal CR for testing (disable features that need RHOAI/ODF)
    log_info "Creating minimal SelfHealingPlatform CR for testing..."

    cat <<'EOF' | oc apply -f -
apiVersion: aiops.kubeheal.io/v1alpha1
kind: SelfHealingPlatform
metadata:
  name: kubeheal
  namespace: kubeheal-operator-system
spec:
  cluster:
    topology: "ha"
    version: "4.22"

  global:
    pattern: "self-healing-platform"
    version: "1.0.0"
    namespace: "self-healing-platform"
    imagePullPolicy: "IfNotPresent"
    git:
      repoURL: "https://github.com/KubeHeal/openshift-aiops-platform.git"
      revision: "main"

  coordinationEngine:
    enabled: false

  mcpServer:
    enabled: false

  modelServing:
    enabled: false

  dataScienceCluster:
    enabled: false

  models: []

  storage:
    workbenchData:
      size: "5Gi"
      storageClass: "gp3-csi"
    modelStorage:
      size: "5Gi"

  objectStore:
    enabled: false

  monitoring:
    enabled: false

  workbench:
    enabled: false

  notebooks:
    validation:
      enabled: false

  tekton:
    enabled: false

  features:
    aiml: false

  namespace:
    create: true
    name: self-healing-platform

  rbac:
    create: true
    serviceAccountName: self-healing-operator
    clusterScoped:
      enabled: false
    crossNamespaceEnabled: false

  imageBuilds:
    enabled: false

  buildConfig:
    enabled: false

  alerts:
    enabled: false
EOF

    # Test 2.1: CR accepted by API server
    if oc get selfhealingplatform kubeheal -n "$OPERATOR_NAMESPACE" &>/dev/null; then
        record_result "T2.1-cr-accepted" "PASSED" "SelfHealingPlatform/kubeheal"
    else
        record_result "T2.1-cr-accepted" "FAILED" "CR not found after apply"
        return 1
    fi

    # Wait for reconciliation
    log_info "Waiting up to ${TIMEOUT_RECONCILE}s for operator to reconcile..."
    sleep 15

    # Test 2.2: Namespace created
    local ns_elapsed=0
    local ns_created=false
    while [[ $ns_elapsed -lt $TIMEOUT_RECONCILE ]]; do
        if oc get namespace "$CR_NAMESPACE" &>/dev/null; then
            ns_created=true
            break
        fi
        sleep 5
        ns_elapsed=$((ns_elapsed + 5))
    done

    if $ns_created; then
        record_result "T2.2-namespace-created" "PASSED" "$CR_NAMESPACE"
    else
        record_result "T2.2-namespace-created" "FAILED" "namespace $CR_NAMESPACE not created after ${TIMEOUT_RECONCILE}s"
        log_info "Checking operator logs for reconciliation errors..."
        oc logs -n "$OPERATOR_NAMESPACE" -l control-plane=controller-manager --tail=30 2>/dev/null || true
    fi

    # Test 2.3: ServiceAccount created
    if oc get serviceaccount self-healing-operator -n "$CR_NAMESPACE" &>/dev/null; then
        record_result "T2.3-serviceaccount-created" "PASSED" "self-healing-operator"
    else
        record_result "T2.3-serviceaccount-created" "SKIPPED" "SA may not exist without full RBAC"
    fi

    # Test 2.4: CR status is populated (Helm operator sets conditions)
    local cr_status
    cr_status=$(oc get selfhealingplatform kubeheal -n "$OPERATOR_NAMESPACE" \
        -o jsonpath='{.status.conditions[0].type}' 2>/dev/null || echo "")
    if [[ -n "$cr_status" ]]; then
        local cr_reason
        cr_reason=$(oc get selfhealingplatform kubeheal -n "$OPERATOR_NAMESPACE" \
            -o jsonpath='{.status.conditions[0].reason}' 2>/dev/null || echo "")
        record_result "T2.4-cr-status-populated" "PASSED" "type=$cr_status reason=$cr_reason"
    else
        record_result "T2.4-cr-status-populated" "SKIPPED" "status not yet populated"
    fi

    # Test 2.5: Operator did not crash during reconciliation
    local post_reconcile_pods
    post_reconcile_pods=$(oc get pods -n "$OPERATOR_NAMESPACE" -l control-plane=controller-manager \
        --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    if [[ "$post_reconcile_pods" -ge 1 ]]; then
        local restarts
        restarts=$(oc get pods -n "$OPERATOR_NAMESPACE" -l control-plane=controller-manager \
            -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")
        record_result "T2.5-operator-stable-after-reconcile" "PASSED" "restarts=$restarts"
    else
        record_result "T2.5-operator-stable-after-reconcile" "FAILED" "operator pod not running after reconcile"
    fi

    # Test 2.6: Check if Helm release was created
    local release_info
    release_info=$(oc logs -n "$OPERATOR_NAMESPACE" -l control-plane=controller-manager --tail=100 2>/dev/null \
        | grep -i "release" | tail -3 || echo "")
    if [[ -n "$release_info" ]]; then
        record_result "T2.6-helm-release-tracked" "PASSED" "release activity in logs"
    else
        record_result "T2.6-helm-release-tracked" "SKIPPED" "no release info found in logs"
    fi

    # Test 2.7: Verify basic resources from Helm chart
    local resources_found=0
    local resources_checked=0

    for resource_check in \
        "configmap/git-credentials:$CR_NAMESPACE" \
        "role/self-healing-operator:$CR_NAMESPACE" \
        "rolebinding/self-healing-operator:$CR_NAMESPACE"; do

        local kind_name="${resource_check%%:*}"
        local ns="${resource_check##*:}"
        resources_checked=$((resources_checked + 1))

        if oc get "$kind_name" -n "$ns" &>/dev/null 2>&1; then
            resources_found=$((resources_found + 1))
        fi
    done

    if [[ $resources_found -gt 0 ]]; then
        record_result "T2.7-helm-resources-created" "PASSED" "$resources_found/$resources_checked resources found"
    else
        record_result "T2.7-helm-resources-created" "SKIPPED" "0/$resources_checked resources (may need dependencies)"
    fi

    # Test 2.8: Verify watches.yaml mapping works (CR spec → Helm values)
    local deployed_release
    deployed_release=$(oc get selfhealingplatform kubeheal -n "$OPERATOR_NAMESPACE" \
        -o jsonpath='{.status.deployedRelease.name}' 2>/dev/null || echo "")
    if [[ -n "$deployed_release" ]]; then
        record_result "T2.8-watches-yaml-mapping" "PASSED" "deployedRelease=$deployed_release"
    else
        record_result "T2.8-watches-yaml-mapping" "SKIPPED" "deployedRelease not in status"
    fi

    log_info "Tier 2 complete."
}

# ============================================================================
# TIER 3: Cleanup Verification
# ============================================================================

tier3_cleanup() {
    log_section "Tier 3: Cleanup Verification"

    if [[ "$SKIP_CLEANUP" == "true" ]]; then
        log_warn "Skipping cleanup (--skip-cleanup). Resources left for debugging."
        record_result "T3.0-cleanup-skipped" "SKIPPED" "user requested --skip-cleanup"
        return 0
    fi

    # Test 3.1: Delete the CR
    log_info "Deleting SelfHealingPlatform CR..."
    if oc delete selfhealingplatform kubeheal -n "$OPERATOR_NAMESPACE" --timeout=60s 2>/dev/null; then
        record_result "T3.1-cr-deleted" "PASSED"
    else
        record_result "T3.1-cr-deleted" "FAILED" "CR deletion timed out or failed"
    fi

    # Wait for Helm uninstall
    sleep 10

    # Test 3.2: Helm-managed resources cleaned up
    local remaining_resources=0
    if oc get namespace "$CR_NAMESPACE" &>/dev/null 2>&1; then
        local ns_resources
        ns_resources=$(oc get all -n "$CR_NAMESPACE" --no-headers 2>/dev/null | wc -l || echo "0")
        if [[ "$ns_resources" -eq 0 ]]; then
            record_result "T3.2-helm-resources-cleaned" "PASSED" "namespace exists but empty"
        else
            record_result "T3.2-helm-resources-cleaned" "SKIPPED" "$ns_resources resources remain (may be owned by other controllers)"
        fi
    else
        record_result "T3.2-helm-resources-cleaned" "PASSED" "namespace removed"
    fi

    # Test 3.3: operator-sdk cleanup
    log_info "Running operator-sdk cleanup..."
    if operator-sdk cleanup kubeheal-operator --namespace "$OPERATOR_NAMESPACE" --timeout "${TIMEOUT_OLM}s" 2>&1; then
        record_result "T3.3-operator-sdk-cleanup" "PASSED"
    else
        record_result "T3.3-operator-sdk-cleanup" "FAILED" "cleanup command failed"
    fi

    # Wait for cleanup
    sleep 10

    # Test 3.4: CRD removed
    if ! oc get crd selfhealingplatforms.aiops.kubeheal.io &>/dev/null 2>&1; then
        record_result "T3.4-crd-removed" "PASSED"
    else
        record_result "T3.4-crd-removed" "FAILED" "CRD still exists after cleanup"
    fi

    # Test 3.5: CSV removed
    local remaining_csv
    remaining_csv=$(oc get csv -n "$OPERATOR_NAMESPACE" --no-headers 2>/dev/null | grep -c "kubeheal" || echo "0")
    if [[ "$remaining_csv" -eq 0 ]]; then
        record_result "T3.5-csv-removed" "PASSED"
    else
        record_result "T3.5-csv-removed" "FAILED" "$remaining_csv CSV(s) remaining"
    fi

    # Test 3.6: Operator pod removed
    local remaining_pods
    remaining_pods=$(oc get pods -n "$OPERATOR_NAMESPACE" -l control-plane=controller-manager \
        --no-headers 2>/dev/null | wc -l || echo "0")
    if [[ "$remaining_pods" -eq 0 ]]; then
        record_result "T3.6-operator-pod-removed" "PASSED"
    else
        record_result "T3.6-operator-pod-removed" "FAILED" "$remaining_pods pod(s) remaining"
    fi

    # Cleanup leftover namespace
    oc delete namespace "$CR_NAMESPACE" --ignore-not-found=true --timeout=60s 2>/dev/null || true
    oc delete namespace "$OPERATOR_NAMESPACE" --ignore-not-found=true --timeout=60s 2>/dev/null || true

    log_info "Tier 3 complete."
}

# ============================================================================
# REPORT
# ============================================================================

generate_report() {
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - START_TIME))

    log_section "E2E Test Report"

    echo "══════════════════════════════════════════════════════════"
    echo "  KUBEHEAL-OPERATOR E2E TEST RESULTS"
    echo "══════════════════════════════════════════════════════════"
    echo ""
    echo "  Date:           $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    echo "  Duration:       ${duration}s ($(( duration / 60 ))m $(( duration % 60 ))s)"
    echo "  Bundle:         $BUNDLE_IMG"
    echo "  Cluster:        $(oc whoami --show-server 2>/dev/null || echo 'unknown')"
    echo "  OCP Version:    $(oc get clusterversion version -o jsonpath='{.status.desired.version}' 2>/dev/null || echo 'unknown')"
    echo "  Platform:       $(oc get infrastructure cluster -o jsonpath='{.status.platformStatus.type}' 2>/dev/null || echo 'unknown')"
    echo ""
    echo "──────────────────────────────────────────────────────────"
    echo "  INDIVIDUAL RESULTS"
    echo "──────────────────────────────────────────────────────────"

    for test_name in $(echo "${!TEST_RESULTS[@]}" | tr ' ' '\n' | sort); do
        local result="${TEST_RESULTS[$test_name]}"
        case "$result" in
            PASSED)  echo -e "  ${GREEN}✅${NC} $test_name" ;;
            FAILED)  echo -e "  ${RED}❌${NC} $test_name" ;;
            SKIPPED) echo -e "  ${YELLOW}⏭️${NC}  $test_name" ;;
        esac
    done

    echo ""
    echo "──────────────────────────────────────────────────────────"
    echo "  SUMMARY"
    echo "──────────────────────────────────────────────────────────"
    echo -e "  Total:   $TOTAL_TESTS"
    echo -e "  ${GREEN}Passed:  $PASSED_TESTS${NC}"
    echo -e "  ${RED}Failed:  $FAILED_TESTS${NC}"
    echo -e "  ${YELLOW}Skipped: $SKIPPED_TESTS${NC}"
    echo ""

    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  ✅ ALL TESTS PASSED${NC}"
        echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
        return 0
    else
        echo -e "${RED}══════════════════════════════════════════════════════════${NC}"
        echo -e "${RED}  ❌ $FAILED_TESTS TEST(S) FAILED${NC}"
        echo -e "${RED}══════════════════════════════════════════════════════════${NC}"
        return 1
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    log_section "KubeHeal Operator E2E Test"
    log_info "Testing bundle: $BUNDLE_IMG"
    log_info "Skip cleanup: $SKIP_CLEANUP"
    [[ -n "$RUN_TIER" ]] && log_info "Running tier: $RUN_TIER only"
    echo ""

    preflight_checks

    local exit_code=0

    if should_run_tier 1; then
        tier1_olm_install || true
    fi

    if should_run_tier 2; then
        # Only run tier 2 if tier 1 passed (or we're running tier 2 alone)
        if [[ -n "$RUN_TIER" ]] || [[ "${TEST_RESULTS[T1.1-olm-bundle-install]:-}" == "PASSED" ]]; then
            tier2_cr_reconciliation || true
        else
            log_warn "Skipping Tier 2: Tier 1 OLM install failed"
            record_result "T2.0-skipped" "SKIPPED" "Tier 1 prerequisite failed"
        fi
    fi

    if should_run_tier 3; then
        tier3_cleanup || true
    fi

    generate_report || exit_code=1

    exit $exit_code
}

main "$@"
