# Setup Guide

This guide covers all required secrets and configuration for running the Task API in production with Kubernetes.

## GitHub Secrets (for CI/CD)

The following secrets need to be configured in GitHub for the CI/CD workflows to function properly.

### Required Secrets

#### 1. GITHUB_TOKEN
- **Description**: Automatically provided by GitHub Actions
- **Setup**: No action needed - GitHub provides this automatically
- **Used by**: Both `deploy.yml` and `pr-check.yml` workflows

#### 2. KUBECONFIG
- **Description**: Base64-encoded Kubernetes configuration file for cluster access
- **How to obtain**:
  ```bash
  # If you have kubectl configured with your cluster
  cat ~/.kube/config | base64

  # Or for cloud providers:
  # AWS EKS: aws eks update-kubeconfig --name <cluster-name> --kubeconfig ./config && cat ./config | base64
  # GKE: gcloud container clusters get-credentials <cluster-name> && cat ~/.kube/config | base64
  # Azure AKS: az aks get-credentials --name <cluster-name> --resource-group <rg> && cat ~/.kube/config | base64
  ```
- **How to add to GitHub**:
  1. Navigate to your repository on GitHub
  2. Go to **Settings** → **Secrets and variables** → **Actions**
  3. Click **New repository secret**
  4. Name: `KUBECONFIG`
  5. Value: Paste the base64-encoded kubeconfig
  6. Click **Add secret**
- **Used by**: `deploy.yml` workflow

### Adding Secrets to GitHub

1. Go to your GitHub repository
2. Click **Settings** (top navigation)
3. In the left sidebar, click **Secrets and variables** → **Actions**
4. Click **New repository secret**
5. Enter the secret name and value
6. Click **Add secret**

## Kubernetes Secrets (for Application)

The application requires the following secrets to be configured in Kubernetes.

### Required Secrets

#### PostgreSQL Database Configuration
- **POSTGRES_HOST**: Hostname or IP of your PostgreSQL database
  - Example: `postgres-service` (for in-cluster PostgreSQL)
  - Example: `my-db.abc123.us-east-1.rds.amazonaws.com` (for AWS RDS)
- **POSTGRES_DB**: Database name
  - Example: `taskapi_db`
- **POSTGRES_USER**: Database username
  - Example: `taskapi_user`
- **POSTGRES_PASSWORD**: Database password
  - Generate strong password: `openssl rand -base64 32`

#### JWT Authentication
- **JWT_SECRET**: Secret key for signing JWT tokens
  - **MUST be at least 256 bits (32 characters)**
  - Generate with: `openssl rand -base64 32`
  - Example output: `AbCdEfGhIjKlMnOpQrStUvWxYz0123456789AbCdEfGh==`

### How to Add Secrets to Kubernetes

#### Method 1: Using the provided script (Recommended)
```bash
# Create a .env file with your secrets
cp .env.example .env
# Edit .env with your actual values

# Run the script to generate and apply secrets
./scripts/generate-secrets.sh
```

#### Method 2: Manual kubectl commands
```bash
# Create the secret manually
kubectl create secret generic task-api-secrets \
  --from-literal=POSTGRES_HOST=your-db-host \
  --from-literal=POSTGRES_DB=taskapi_db \
  --from-literal=POSTGRES_USER=taskapi_user \
  --from-literal=POSTGRES_PASSWORD=your-secure-password \
  --from-literal=JWT_SECRET=$(openssl rand -base64 32) \
  --namespace=default

# Verify the secret was created
kubectl get secrets task-api-secrets -o yaml
```

#### Method 3: Using a YAML file (Not Recommended for sensitive data)
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: task-api-secrets
type: Opaque
data:
  POSTGRES_HOST: <base64-encoded-value>
  POSTGRES_DB: <base64-encoded-value>
  POSTGRES_USER: <base64-encoded-value>
  POSTGRES_PASSWORD: <base64-encoded-value>
  JWT_SECRET: <base64-encoded-value>
```

To encode values: `echo -n "your-value" | base64`

## Environment Variables Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `POSTGRES_HOST` | Yes | localhost | PostgreSQL server hostname |
| `POSTGRES_DB` | Yes | taskapi_db | Database name |
| `POSTGRES_USER` | Yes | taskapi_user | Database username |
| `POSTGRES_PASSWORD` | Yes | changeme | Database password |
| `JWT_SECRET` | Yes | (none) | JWT signing key (min 32 chars) |
| `JWT_EXPIRATION` | No | 86400000 | JWT expiration in ms (24h) |
| `SPRING_PROFILES_ACTIVE` | No | default | Spring profile (e.g., prod) |

## Security Best Practices

### Secret Generation
1. **Always use cryptographically secure random generators**
   ```bash
   # Good: OpenSSL random
   openssl rand -base64 32

   # Good: /dev/urandom
   cat /dev/urandom | head -c 32 | base64

   # Bad: Simple passwords like "password123"
   ```

2. **Minimum strength requirements**:
   - JWT_SECRET: At least 256 bits (32 characters)
   - Database passwords: At least 20 characters, mixed case, numbers, symbols

### Secret Storage
1. **Never commit secrets to Git**
   - Add `.env` to `.gitignore` (already configured)
   - Use `.env.example` for templates only
   - Review commits before pushing

2. **Use Kubernetes secrets for container environment**
   - Never hardcode secrets in Dockerfiles
   - Never store secrets in ConfigMaps
   - Use `stringData` or base64-encoded `data` in Secret manifests

3. **Limit secret access**
   ```bash
   # Check who can read secrets in your namespace
   kubectl auth can-i get secrets --as=system:serviceaccount:default:default

   # Use RBAC to restrict access
   kubectl create role secret-reader --verb=get --resource=secrets
   kubectl create rolebinding secret-reader-binding --role=secret-reader --serviceaccount=default:task-api-sa
   ```

### Secret Rotation
1. **Rotate secrets regularly**:
   - JWT_SECRET: Every 90 days (requires application restart)
   - Database passwords: Every 90 days (coordinate with application restart)

2. **Update secrets in Kubernetes**:
   ```bash
   # Update a specific secret value
   kubectl create secret generic task-api-secrets \
     --from-literal=JWT_SECRET=$(openssl rand -base64 32) \
     --dry-run=client -o yaml | kubectl apply -f -

   # Rollout restart to pick up new secrets
   kubectl rollout restart deployment task-api
   ```

### Monitoring and Auditing
1. **Enable audit logging** in Kubernetes for secret access
2. **Monitor failed authentication attempts** in application logs
3. **Set up alerts** for unusual secret access patterns

## Database Setup

### Using Managed Database (Recommended for Production)
- **AWS RDS**: Follow [AWS RDS setup guide](https://docs.aws.amazon.com/rds/latest/userguide/USER_CreateDBInstance.html)
- **Google Cloud SQL**: Follow [Cloud SQL setup guide](https://cloud.google.com/sql/docs/postgres/create-instance)
- **Azure Database**: Follow [Azure PostgreSQL setup guide](https://docs.microsoft.com/en-us/azure/postgresql/)

Set the `POSTGRES_HOST` to your managed database endpoint.

### Using In-Cluster PostgreSQL (Development/Testing)
```bash
# Deploy PostgreSQL to Kubernetes
kubectl apply -f k8s/postgres-deployment.yml

# POSTGRES_HOST will be: postgres-service
```

## Troubleshooting

### Application won't start - "JWT secret must be at least 256 bits"
**Cause**: JWT_SECRET is too short or missing
**Solution**: Generate a proper secret: `openssl rand -base64 32`

### Application can't connect to database
**Cause**: Wrong POSTGRES_HOST or network issues
**Solution**:
```bash
# Test database connectivity from within cluster
kubectl run psql-test --rm -it --image=postgres:15 --env="PGPASSWORD=yourpass" -- \
  psql -h postgres-service -U taskapi_user -d taskapi_db -c "SELECT 1;"
```

### GitHub Actions workflow fails: "error: You must be logged in to the server (Unauthorized)"
**Cause**: Invalid or missing KUBECONFIG secret
**Solution**: Re-generate and update the KUBECONFIG secret in GitHub

### Kubernetes secret not found
**Cause**: Secret not created or wrong namespace
**Solution**:
```bash
# Check if secret exists
kubectl get secrets -A | grep task-api

# Create the secret
./scripts/generate-secrets.sh
```

## Quick Start Checklist

- [ ] Generate JWT_SECRET: `openssl rand -base64 32`
- [ ] Set up PostgreSQL database (managed or in-cluster)
- [ ] Create `.env` file with all required variables
- [ ] Run `./scripts/generate-secrets.sh` to create Kubernetes secrets
- [ ] Encode kubeconfig: `cat ~/.kube/config | base64`
- [ ] Add KUBECONFIG to GitHub Secrets
- [ ] Test deployment: `kubectl get pods`
- [ ] Test API: `curl http://your-api-url/actuator/health`
