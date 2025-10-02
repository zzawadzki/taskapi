Create .github/workflows/pr-check.yml:

NAME: PR Checks

TRIGGERS:
- Pull request to main

JOBS:

JOB 1: lint-and-format
- Run Maven checkstyle
- Check code formatting
- Fail if not formatted correctly

JOB 2: security-scan
- Run dependency vulnerability scan
- Use Maven dependency-check plugin
- Fail on HIGH/CRITICAL vulnerabilities

JOB 3: build-test
- Build Docker image (don't push)
- Run tests in container
- Check image size (warn if > 300MB)

Add status checks and comments to PR.