# KubeHeal Operator -- Quick Start Install
# Records: namespace creation, CatalogSource, OLM Subscription, CSV watch, CR apply
# Duration: ~3 minutes
# Requires: oc CLI logged into an OpenShift 4.20+ cluster

Output demos/01-install.gif

Set Shell "bash"
Set FontSize 14
Set Width 1200
Set Height 600
Set Theme "Dracula"
Set TypingSpeed 40ms
Set Padding 20

# --- Title ---
Type "# KubeHeal Operator -- Quick Start Install on ROSA"
Enter
Sleep 1s

# --- Step 1: Verify cluster ---
Type "oc version | head -2"
Enter
Sleep 2s

Type "oc get nodes -l node-role.kubernetes.io/worker="
Enter
Sleep 3s

# --- Step 2: Create namespace ---
Type "oc create namespace kubeheal-system"
Enter
Sleep 2s

# --- Step 3: Create CatalogSource ---
Type "cat <<'EOF' | oc apply -f -"
Enter
Type "apiVersion: operators.coreos.com/v1alpha1"
Enter
Type "kind: CatalogSource"
Enter
Type "metadata:"
Enter
Type "  name: kubeheal-operator-catalog"
Enter
Type "  namespace: openshift-marketplace"
Enter
Type "spec:"
Enter
Type "  sourceType: grpc"
Enter
Type "  image: quay.io/takinosh/kubeheal-operator-catalog:v0.1.10"
Enter
Type "  displayName: KubeHeal Operator"
Enter
Type "  publisher: KubeHeal Community"
Enter
Type "EOF"
Enter
Sleep 3s

# --- Step 4: Wait for catalog ---
Type "echo 'Waiting for CatalogSource...' && sleep 15"
Enter
Sleep 16s

Type "oc get catalogsource kubeheal-operator-catalog -n openshift-marketplace -o jsonpath='{.status.connectionState.lastObservedState}'"
Enter
Sleep 2s

# --- Step 5: Create OperatorGroup + Subscription ---
Type "cat <<'EOF' | oc apply -f -"
Enter
Type "apiVersion: operators.coreos.com/v1"
Enter
Type "kind: OperatorGroup"
Enter
Type "metadata:"
Enter
Type "  name: kubeheal-operator-group"
Enter
Type "  namespace: kubeheal-system"
Enter
Type "spec:"
Enter
Type "  targetNamespaces:"
Enter
Type "  - kubeheal-system"
Enter
Type "---"
Enter
Type "apiVersion: operators.coreos.com/v1alpha1"
Enter
Type "kind: Subscription"
Enter
Type "metadata:"
Enter
Type "  name: kubeheal-operator"
Enter
Type "  namespace: kubeheal-system"
Enter
Type "spec:"
Enter
Type "  channel: alpha"
Enter
Type "  name: kubeheal-operator"
Enter
Type "  source: kubeheal-operator-catalog"
Enter
Type "  sourceNamespace: openshift-marketplace"
Enter
Type "  installPlanApproval: Automatic"
Enter
Type "EOF"
Enter
Sleep 3s

# --- Step 6: Wait for CSV ---
Type "echo 'Waiting for operator install...' && sleep 30"
Enter
Sleep 31s

Type "oc get csv -n kubeheal-system"
Enter
Sleep 3s

# --- Step 7: Apply the SelfHealingPlatform CR ---
Type "oc apply -f config/samples/aiops_v1alpha1_selfhealingplatform.yaml"
Enter
Sleep 3s

# --- Step 8: Check status ---
Type "sleep 15 && oc get selfhealingplatform -n kubeheal-system"
Enter
Sleep 16s

Type "oc get pods -n kubeheal-system"
Enter
Sleep 3s

Type "echo '✅ KubeHeal Operator installed and platform CR applied!'"
Enter
Sleep 3s
