Create .github/workflows/deploy.yml for CI/CD pipeline:

NAME: Build and Deploy

TRIGGERS:
- Push to main branch
- Pull request to main branch
- Manual workflow dispatch

ENVIRONMENT VARIABLES:
- REGISTRY: ghcr.io
- IMAGE_NAME: ${{ github.repository }}
- K8S_NAMESPACE: taskapi

JOBS:

JOB 1: test
- Runs on: ubuntu-latest
- Steps:
    1. Checkout code
    2. Set up JDK 21
    3. Cache Maven dependencies
    4. Run tests: mvn test
    5. Upload test results

JOB 2: build-and-push
- Runs on: ubuntu-latest
- Needs: test (only runs if tests pass)
- Only runs on: push to main (not PRs)
- Permissions: contents: read, packages: write
- Steps:
    1. Checkout code
    2. Set up Docker Buildx
    3. Log in to GitHub Container Registry
    4. Extract metadata (tags, labels)
    5. Build and push Docker image
        - Tags: latest, git sha, git tag if exists
        - Cache layers for faster builds
    6. Run Trivy security scan on image
        - Fail on HIGH/CRITICAL vulnerabilities
        - Upload results as artifact

JOB 3: deploy
- Runs on: ubuntu-latest
- Needs: build-and-push
- Only runs on: push to main
- Environment: production (with protection rules)
- Steps:
    1. Checkout code
    2. Install kubectl
    3. Configure kubectl with kubeconfig from secret
    4. Update image in deployment
    5. Wait for rollout to complete
    6. Run smoke test
    7. Notify on failure

Add helpful comments explaining each step.