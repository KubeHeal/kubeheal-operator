# Contributing to KubeHeal Operator

Thank you for your interest in contributing! This document provides guidelines
for contributing to the KubeHeal Operator project.

## Getting Started

1. **Fork** the repository on GitHub.
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/<your-username>/kubeheal-operator.git
   cd kubeheal-operator
   ```
3. Create a **feature branch**:
   ```bash
   git checkout -b feat/my-feature
   ```

## Development Workflow

### Prerequisites

- Go 1.21+ (for local `make run`)
- `operator-sdk` v1.42+
- `helm` v3.16+
- Access to an OpenShift 4.20+ cluster (or `kind`/`minikube` for basic tests)
- `podman` or `docker`

### Building

```bash
# Build the operator image
make docker-build CONTAINER_TOOL=podman

# Run chart linting and template tests
make test
```

### Running Locally

```bash
# Install CRDs and run the operator outside the cluster
make install run
```

### Generating the OLM Bundle

```bash
make bundle
```

## Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>
```

| Type       | Purpose                           |
|------------|-----------------------------------|
| `feat`     | New feature                       |
| `fix`      | Bug fix                           |
| `docs`     | Documentation only                |
| `chore`    | Maintenance / tooling             |
| `refactor` | Code restructuring (no behaviour change) |
| `test`     | Tests                             |

Examples:
- `feat(chart): add GPU scheduling support`
- `fix(rbac): correct ClusterRoleBinding namespace`
- `docs(runbook): add troubleshooting section`

## Pull Requests

1. Ensure `make test` passes.
2. Update documentation if behaviour changes.
3. Keep PRs focused — one logical change per PR.
4. Reference related issues (e.g., `Fixes #42`).

## Reporting Issues

Use [GitHub Issues](https://github.com/KubeHeal/kubeheal-operator/issues).
Include:
- OpenShift version and cluster topology (HA / SNO / ROSA)
- Operator version (`oc get csv -n kubeheal-system`)
- Steps to reproduce
- Relevant logs (`oc logs`, `oc describe`)

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).

## License

By contributing you agree that your contributions will be licensed under the
[Apache License 2.0](LICENSE).
