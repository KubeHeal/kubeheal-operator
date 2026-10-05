# Security Policy

## Supported Versions

| Version  | Supported          |
|----------|--------------------|
| 0.1.x    | :white_check_mark: |

## Reporting a Vulnerability

**Do not open a public issue for security vulnerabilities.**

Instead, please report them privately via
[GitHub Security Advisories](https://github.com/KubeHeal/kubeheal-operator/security/advisories/new).

Include:
1. Description of the vulnerability
2. Steps to reproduce
3. Potential impact
4. Suggested fix (if any)

You will receive an acknowledgement within **48 hours** and a detailed response
within **7 days** indicating next steps.

## Security Best Practices for Users

* Never commit secrets, API keys, or tokens to the repository.
* Use `ExternalSecret` CRs or Kubernetes Secrets for credentials.
* Keep the operator updated to the latest patch release.
* Follow the [pre-commit hooks guide](CONTRIBUTING.md) to scan for secrets before pushing.
