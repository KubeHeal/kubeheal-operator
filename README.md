<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/branding/png/kubeheal-logo-horizontal.png">
    <source media="(prefers-color-scheme: light)" srcset="assets/branding/png/kubeheal-logo-light.png">
    <img alt="KubeHeal Logo" src="assets/branding/png/kubeheal-logo-horizontal.png" width="520">
  </picture>
</p>

# KubeHeal Operator

A Kubernetes operator for deploying and managing the [KubeHeal AIOps Self-Healing Platform](https://github.com/KubeHeal/openshift-aiops-platform) on OpenShift clusters.

## Overview

The KubeHeal Operator automates the deployment and lifecycle management of the KubeHeal self-healing platform. It wraps the platform's Helm chart into an OLM-compatible operator, enabling one-click installation from OperatorHub.

**What it deploys:**
- Coordination Engine (Go-based multi-layer remediation orchestrator)
- MCP Server (Model Context Protocol for AI assistant integration)
- ML model serving via KServe (anomaly detection + predictive analytics)
- Tekton pipelines for model training and validation
- Monitoring stack (Prometheus rules, Grafana dashboards, ServiceMonitors)
- Jupyter workbench for ML development
- S3 object storage integration (NooBaa/ODF)

## Quick Start

### From OperatorHub (Coming Soon)

1. Search for "KubeHeal" in OperatorHub
2. Click Install
3. Create a `SelfHealingPlatform` CR

### Manual Installation

```bash
# Build and push the operator image
make docker-build docker-push IMG=quay.io/takinosh/kubeheal-operator:v0.1.0

# Deploy the operator
make deploy IMG=quay.io/takinosh/kubeheal-operator:v0.1.0

# Create a SelfHealingPlatform instance
kubectl apply -f config/samples/aiops_v1alpha1_selfhealingplatform.yaml
```

### Using OLM Bundle

```bash
# Build and push the bundle
make bundle-build bundle-push

# Run the bundle
operator-sdk run bundle quay.io/takinosh/kubeheal-operator-bundle:v0.1.0
```

## Custom Resource

The operator manages a single CRD: `SelfHealingPlatform`

```yaml
apiVersion: aiops.kubeheal.io/v1alpha1
kind: SelfHealingPlatform
metadata:
  name: kubeheal
  namespace: self-healing-platform
spec:
  cluster:
    topology: "ha"    # "ha" or "sno"
    version: "4.22"   # OpenShift version
  coordinationEngine:
    enabled: true
    replicas: 1
  mcpServer:
    enabled: true
  modelServing:
    enabled: true
  monitoring:
    enabled: true
  notebooks:
    enabled: true
  features:
    aiml: true
```

See `config/samples/` for HA and SNO configuration examples.

## Prerequisites

The following operators must be installed on your cluster before deploying:

| Operator | Required | Purpose |
|----------|----------|---------|
| Red Hat OpenShift AI (RHOAI) | Yes | ML platform, KServe |
| OpenShift Data Foundation (ODF) | Yes | S3 object storage |
| OpenShift Pipelines (Tekton) | Yes | CI/CD pipelines |
| External Secrets Operator | Yes | Secrets management |
| NVIDIA GPU Operator | Optional | GPU workloads |

## Supported Platforms

- OpenShift 4.20 - 4.22
- HA (HighlyAvailable) and SNO (Single Node OpenShift) topologies

## Development

```bash
# Build the operator image
make docker-build CONTAINER_TOOL=podman

# Run locally (outside cluster)
make install run

# Run tests
make test

# Generate OLM bundle
make bundle
```

## Architecture

```
kubeheal-operator
  └── watches SelfHealingPlatform CR
       └── reconciles Helm chart (helm-charts/self-healing-platform/)
            ├── Coordination Engine (Deployment)
            ├── MCP Server (Deployment)
            ├── KServe InferenceServices
            ├── Tekton Pipelines + Tasks
            ├── Monitoring (ServiceMonitor, PrometheusRule)
            ├── Jupyter Workbench (Notebook CR)
            └── Storage (PVCs, ObjectBucketClaim)
```

## Related Repositories

| Repository | Purpose |
|------------|---------|
| [openshift-aiops-platform](https://github.com/KubeHeal/openshift-aiops-platform) | Platform Helm charts and deployment |
| [openshift-coordination-engine](https://github.com/KubeHeal/openshift-coordination-engine) | Go coordination engine |
| [openshift-cluster-health-mcp](https://github.com/KubeHeal/openshift-cluster-health-mcp) | MCP server for cluster health |
| [self-healing-workshop](https://github.com/KubeHeal/self-healing-workshop) | Workshop and training materials |

## License

Apache License 2.0 - see [LICENSE](LICENSE)
