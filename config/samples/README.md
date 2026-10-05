# Sample Custom Resources

Choose the sample CR that matches your cluster:

```
What is your cluster platform?
│
├── ROSA Classic / AWS IPI
│   ├── Multi-node (HA)  →  aiops_v1alpha1_selfhealingplatform.yaml
│   └── Single-worker    →  aiops_v1alpha1_selfhealingplatform_sno.yaml
│
├── Baremetal / Agent-Based Install
│   └── With ODF         →  aiops_v1alpha1_selfhealingplatform_baremetal.yaml
│
└── SNO (non-ROSA)
    └── Any storage       →  aiops_v1alpha1_selfhealingplatform_sno.yaml
```

## Quick Reference

| File | Topology | Object Store | Storage Class |
|------|----------|--------------|---------------|
| [`aiops_v1alpha1_selfhealingplatform.yaml`](aiops_v1alpha1_selfhealingplatform.yaml) | HA | AWS S3 (default) | `gp3-csi` |
| [`aiops_v1alpha1_selfhealingplatform_sno.yaml`](aiops_v1alpha1_selfhealingplatform_sno.yaml) | SNO | AWS S3 | `gp3-csi` |
| [`aiops_v1alpha1_selfhealingplatform_baremetal.yaml`](aiops_v1alpha1_selfhealingplatform_baremetal.yaml) | HA | NooBaa (ODF) | `ocs-storagecluster-cephfs` |

## Usage

```bash
# Apply the sample that matches your cluster
oc apply -f config/samples/aiops_v1alpha1_selfhealingplatform.yaml
```

All CRs are deployed to the `kubeheal-system` namespace (the operator namespace).
The chart creates the `self-healing-platform` namespace for platform workloads.
