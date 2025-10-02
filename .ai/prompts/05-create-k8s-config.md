Create Kubernetes manifests for deploying the Task API application. Create a directory named 'k8s/' with the following files:

FILE 1: k8s/namespace.yaml
- Create namespace: taskapi

FILE 2: k8s/postgres-secret.yaml
- Kind: Secret
- Name: postgres-secret
- Namespace: taskapi
- Type: Opaque
- Data (base64 encoded):
    - POSTGRES_DB: taskapi_db
    - POSTGRES_USER: taskapi_user
    - POSTGRES_PASSWORD: local_dev_password

FILE 3: k8s/app-secret.yaml
- Kind: Secret
- Name: app-secret
- Namespace: taskapi
- Type: Opaque
- Data (base64 encoded):
    - JWT_SECRET: mySuperSecretKeyForJWTTokenGenerationChangeThisInProduction123456

FILE 4: k8s/postgres-pvc.yaml
- Kind: PersistentVolumeClaim
- Name: postgres-pvc
- Namespace: taskapi
- Storage: 1Gi
- AccessMode: ReadWriteOnce
- StorageClass: local-path (k3d default)

FILE 5: k8s/postgres-deployment.yaml
- Kind: Deployment
- Name: postgres
- Namespace: taskapi
- Replicas: 1
- Selector: app=postgres
- Container:
    - Image: postgres:15-alpine
    - Ports: 5432
    - Environment variables from postgres-secret
    - Volume mount: postgres-pvc to /var/lib/postgresql/data
    - Resources: requests (cpu: 100m, memory: 128Mi), limits (cpu: 500m, memory: 512Mi)
    - Liveness probe: pg_isready
    - Readiness probe: pg_isready

FILE 6: k8s/postgres-service.yaml
- Kind: Service
- Name: postgres
- Namespace: taskapi
- Type: ClusterIP
- Port: 5432
- Selector: app=postgres

FILE 7: k8s/app-deployment.yaml
- Kind: Deployment
- Name: taskapi-app
- Namespace: taskapi
- Replicas: 2 (for learning about scaling)
- Selector: app=taskapi
- Container:
    - Image: taskapi:v1.0
    - ImagePullPolicy: Never (local image)
    - Ports: 8080
    - Environment variables:
        - SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/taskapi_db
        - SPRING_DATASOURCE_USERNAME: from postgres-secret
        - SPRING_DATASOURCE_PASSWORD: from postgres-secret
        - JWT_SECRET: from app-secret
        - JWT_EXPIRATION: 86400000
    - Resources: requests (cpu: 200m, memory: 256Mi), limits (cpu: 1000m, memory: 512Mi)
    - Liveness probe: HTTP GET /actuator/health on port 8080
    - Readiness probe: HTTP GET /actuator/health on port 8080
    - Startup probe: HTTP GET /actuator/health with longer initialDelaySeconds

FILE 8: k8s/app-service.yaml
- Kind: Service
- Name: taskapi-service
- Namespace: taskapi
- Type: ClusterIP
- Port: 80 -> TargetPort: 8080
- Selector: app=taskapi

FILE 9: k8s/ingress.yaml
- Kind: Ingress
- Name: taskapi-ingress
- Namespace: taskapi
- Annotations:
    - ingress.kubernetes.io/ssl-redirect: "false"
- IngressClassName: traefik (k3d default)
- Rules:
    - Host: taskapi.local
    - Path: / -> taskapi-service:80

FILE 10: k8s/kustomization.yaml
- Create kustomization file that includes all resources in order:
    1. namespace
    2. secrets
    3. pvc
    4. postgres deployment and service
    5. app deployment and service
    6. ingress

Add helpful comments in each YAML file explaining what each resource does.