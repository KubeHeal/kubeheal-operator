# KubeHeal Demos

Terminal recordings created with [VHS](https://github.com/charmbracelet/vhs) (Charmbracelet).

## Tapes

| Tape | Description | Duration |
|------|-------------|----------|
| [01-install.tape](01-install.tape) | Operator install via OLM Quick Start | ~3 min |
| [02-training.tape](02-training.tape) | Anomaly detection model training pipeline | ~5 min |
| [03-self-healing.tape](03-self-healing.tape) | Fault injection and automatic recovery | ~5 min |

## Prerequisites

- [VHS](https://github.com/charmbracelet/vhs#installation) installed
- [ttyd](https://github.com/tsl0922/ttyd) installed
- `oc` CLI logged into an OpenShift 4.20+ cluster with the KubeHeal platform deployed

## Recording

```bash
# Record a single tape
vhs demos/01-install.tape

# Record all tapes
for tape in demos/*.tape; do vhs "$tape"; done
```

Output GIF files are written to `demos/` alongside the tape files.

## Embedding in README

```markdown
![KubeHeal Install](demos/01-install.gif)
```
