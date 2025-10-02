Create a file docs/SETUP.md that documents all required secrets:

GITHUB SECRETS NEEDED:

For CI/CD:
- GITHUB_TOKEN (automatically provided)
- KUBECONFIG (base64 encoded kubeconfig file)

For Application (in Kubernetes):
- POSTGRES_HOST (from managed database)
- POSTGRES_DB
- POSTGRES_USER
- POSTGRES_PASSWORD
- JWT_SECRET (generate strong random string)

Instructions:
1. How to get each secret
2. How to add to GitHub (Settings → Secrets → Actions)
3. How to add to Kubernetes (kubectl create secret)
4. Security best practices

Also create scripts/generate-secrets.sh that:
- Generates strong JWT_SECRET
- Creates Kubernetes secrets from .env file
- Outputs commands to set GitHub secrets