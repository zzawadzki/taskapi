Prepare the project for cloud deployment:

1. Create a new directory 'k8s/base/' and move all k8s yaml files there

2. Create 'k8s/overlays/local/' with kustomization.yaml:
    - References ../base
    - Patches for local development (ImagePullPolicy: Never)

3. Create 'k8s/overlays/production/' with:
    - kustomization.yaml referencing ../base
    - Remove postgres deployment (we'll use managed database)
    - Patches for production:
        - ImagePullPolicy: Always
        - Replicas: 3
        - Resource limits increased
        - Add labels: environment=production
    - Production secrets template (values to be replaced)

4. Update base kustomization.yaml to be environment-agnostic

This follows Kustomize best practices for multi-environment deployments.