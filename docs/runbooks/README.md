# Runbooks

Step-by-step operational guides for the KubeHeal Operator.

| Runbook | Audience | Description |
|---------|----------|-------------|
| [install-operator.md](install-operator.md) | Cluster admin | Install the operator via OLM and deploy a `SelfHealingPlatform` CR. Covers CatalogSource setup, pre-flight checks, verification, rollback, and troubleshooting. |
| [full-platform-deployment.md](full-platform-deployment.md) | Platform engineer | End-to-end deployment including prerequisite operators (RHOAI, Tekton, ODF), cluster sizing, model training pipelines, and post-deployment validation. |

## Which Runbook Should I Use?

* **First-time install** → Start with [install-operator.md](install-operator.md).
* **Full platform with ML models** → Follow [full-platform-deployment.md](full-platform-deployment.md) (includes the install step).
