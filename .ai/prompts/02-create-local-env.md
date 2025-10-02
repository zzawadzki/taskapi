Create a docker-compose.yml file in the project root with:

SERVICES:
1. PostgreSQL 15 database service named "postgres"
    - Image: postgres:15-alpine
    - Container name: taskapi-postgres
    - Environment variables:
        - POSTGRES_DB=taskapi_db
        - POSTGRES_USER=taskapi_user
        - POSTGRES_PASSWORD=local_dev_password
    - Port mapping: 5432:5432
    - Volume: postgres_data:/var/lib/postgresql/data (for persistence)
    - Health check:
        - test: pg_isready -U taskapi_user -d taskapi_db
        - interval: 10s
        - timeout: 5s
        - retries: 5
    - Restart policy: unless-stopped

2. pgAdmin (optional but helpful - web UI for database)
    - Image: dpage/pgadmin4:latest
    - Container name: taskapi-pgadmin
    - Environment variables:
        - PGADMIN_DEFAULT_EMAIL=admin@taskapi.local
        - PGADMIN_DEFAULT_PASSWORD=admin
    - Port mapping: 5050:80
    - Depends on postgres service
    - Restart policy: unless-stopped

NETWORKING:
- Create a custom bridge network named "taskapi-network"

VOLUMES:
- Named volume for PostgreSQL data persistence

Also, create a .env.docker file with all the database credentials that docker-compose will use.