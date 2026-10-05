---
name: Bug Report
about: Report a problem with the KubeHeal Operator
title: "[BUG] "
labels: bug
assignees: ''
---

## Environment

- **Operator version**: (e.g. v0.1.10)
- **OpenShift version**: (e.g. 4.22.15)
- **Cluster topology**: HA / SNO / ROSA
- **Platform**: AWS / Baremetal / other

## Describe the Bug

A clear and concise description of what the bug is.

## Steps to Reproduce

1. Deploy operator with `...`
2. Apply CR `...`
3. Observe `...`

## Expected Behaviour

What you expected to happen.

## Actual Behaviour

What actually happened.

## Logs / Evidence

```
oc get csv -n kubeheal-system
oc logs -n kubeheal-system deployment/kubeheal-operator-controller-manager --tail=50
```

## Additional Context

Add any other context about the problem here.
