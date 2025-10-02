# Task Management API

A production-ready RESTful API for task management with JWT-based authentication, built with Spring Boot 3.5.x and Java 21.

## Features

- User registration and authentication with JWT tokens
- Secure password encryption using BCrypt
- Full CRUD operations for tasks
- User-specific task isolation
- Comprehensive error handling and validation
- PostgreSQL database with JPA/Hibernate
- Production-ready security configuration
- Docker and Docker Compose support
- Kubernetes deployment manifests with Kustomize
- Health check endpoints via Spring Boot Actuator

## Tech Stack

- **Backend**: Java 21, Spring Boot 3.5.6
- **Security**: Spring Security with JWT (jjwt 0.13.0)
- **Data**: Spring Data JPA, PostgreSQL 15
- **Build**: Maven 3.6+
- **Utilities**: Lombok
- **Containerization**: Docker, Docker Compose
- **Orchestration**: Kubernetes (k3d/k3s ready)
- **Monitoring**: Spring Boot Actuator

## Prerequisites

- Java 21 or higher
- Maven 3.6+
- PostgreSQL 15+ (or use Docker Compose)
- Docker (optional, for containerized deployment)
- kubectl and k3d (optional, for Kubernetes deployment)

## Database Setup

1. Install PostgreSQL if not already installed
2. Create a database and user:

```sql
CREATE DATABASE taskapi_db;
CREATE USER taskapi_user WITH PASSWORD 'changeme';
GRANT ALL PRIVILEGES ON DATABASE taskapi_db TO taskapi_user;
```

## Configuration

The application uses environment variables for configuration. You can set them in your system or create a `.env` file (not tracked by git).

Required environment variables:

```bash
# Database configuration (defaults shown)
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/taskapi_db
SPRING_DATASOURCE_USERNAME=taskapi_user
SPRING_DATASOURCE_PASSWORD=changeme

# JWT configuration (JWT_SECRET is REQUIRED)
JWT_SECRET=your-secret-key-here-at-least-256-bits-long
JWT_EXPIRATION=86400000  # 24 hours in milliseconds (optional, default: 86400000)
```

**Important**: Generate a secure JWT secret key (at least 256 bits / 32 characters). Example:
```bash
openssl rand -base64 32
```

## Running the Application

### Option 1: Using Maven (Local Development)

```bash
# Build the project
mvn clean install

# Run the application
mvn spring-boot:run
```

### Option 2: Using Java

```bash
# Build the JAR
mvn clean package

# Run the JAR
java -jar target/task-api-0.0.1-SNAPSHOT.jar
```

### Option 3: Using Docker Compose (Recommended)

This starts both PostgreSQL and the API in containers:

```bash
# Ensure JWT_SECRET is set
export JWT_SECRET=$(openssl rand -base64 32)

# Build and start services
docker-compose up --build

# Or run in detached mode
docker-compose up -d

# View logs
docker-compose logs -f app

# Stop services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

**Helper script**: Use `./docker-cleanup.sh` to clean up Docker resources:
```bash
./docker-cleanup.sh       # Remove containers and images
./docker-cleanup.sh -v    # Also remove volumes (with confirmation)
./docker-cleanup.sh -v -y # Remove volumes without prompting
```

### Option 4: Kubernetes Deployment

Deploy to a local k3d cluster using Kustomize:

```bash
# Create a k3d cluster (if needed)
k3d cluster create taskapi --port "8080:80@loadbalancer"

# Generate JWT secret
kubectl create secret generic app-secrets \
  --from-literal=jwt-secret=$(openssl rand -base64 32) \
  -n taskapi --dry-run=client -o yaml > k8s/overlays/local/app-secret.yaml

# Deploy using kubectl with Kustomize
kubectl apply -k k8s/overlays/local

# Check deployment status
kubectl get pods -n taskapi

# Port-forward to access locally
kubectl port-forward -n taskapi svc/taskapi-service 8080:80
```

**Helper script**: Use `./k8s-diagnose.sh` for troubleshooting:
```bash
./k8s-diagnose.sh  # Runs comprehensive diagnostics
```

The application will start on `http://localhost:8080`

## API Endpoints

### Authentication Endpoints (Public)

#### Register a new user
```http
POST /api/auth/register
Content-Type: application/json

{
  "username": "john_doe",
  "email": "john@example.com",
  "password": "password123"
}
```

**Response (201 Created):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "type": "Bearer",
  "username": "john_doe"
}
```

#### Login
```http
POST /api/auth/login
Content-Type: application/json

{
  "username": "john_doe",
  "password": "password123"
}
```

**Response (200 OK):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "type": "Bearer",
  "username": "john_doe"
}
```

### Task Endpoints (Secured - Require JWT)

For all task endpoints, include the JWT token in the Authorization header:
```http
Authorization: Bearer <your-jwt-token>
```

#### Get all tasks
```http
GET /api/tasks
```

#### Get a specific task
```http
GET /api/tasks/{id}
```

#### Create a new task
```http
POST /api/tasks
Content-Type: application/json

{
  "title": "Complete project documentation",
  "description": "Write comprehensive README and API docs",
  "completed": false
}
```

#### Update a task
```http
PUT /api/tasks/{id}
Content-Type: application/json

{
  "title": "Updated task title",
  "description": "Updated description",
  "completed": true
}
```

#### Delete a task
```http
DELETE /api/tasks/{id}
```

#### Toggle task completion
```http
PATCH /api/tasks/{id}/complete
```

## Validation Rules

### User Registration
- Username: 3-50 characters, required
- Email: Valid email format, required
- Password: Minimum 6 characters, required

### Task
- Title: Required, maximum 200 characters
- Description: Optional
- Completed: Optional, defaults to false

## Error Response Format

All errors return a consistent JSON format:

```json
{
  "timestamp": "2025-01-15T10:30:00",
  "status": 404,
  "error": "Not Found",
  "message": "Task not found with id: 123",
  "path": "/api/tasks/123"
}
```

## HTTP Status Codes

- `200 OK` - Request succeeded
- `201 Created` - Resource created successfully
- `204 No Content` - Request succeeded with no response body
- `400 Bad Request` - Invalid request or validation error
- `401 Unauthorized` - Authentication required or failed
- `403 Forbidden` - Not authorized to access resource
- `404 Not Found` - Resource not found
- `500 Internal Server Error` - Server error

## Security Features

- JWT-based stateless authentication
- Password encryption with BCrypt
- Token expiration (24 hours by default)
- User-specific task isolation
- Protected endpoints requiring authentication
- Custom authentication entry point for unauthorized access

## Development

### Project Structure

```
src/main/java/com/learning/task/
├── TaskApiApplication.java          # Main application class
├── config/                           # Configuration classes
│   ├── SecurityConfig.java
│   └── JwtConfig.java
├── controller/                       # REST controllers
│   ├── AuthController.java
│   └── TaskController.java
├── dto/                              # Data Transfer Objects
│   ├── LoginRequest.java
│   ├── RegisterRequest.java
│   ├── AuthResponse.java
│   ├── TaskRequest.java
│   └── TaskResponse.java
├── entity/                           # JPA entities
│   ├── User.java
│   └── Task.java
├── repository/                       # JPA repositories
│   ├── UserRepository.java
│   └── TaskRepository.java
├── security/                         # Security components
│   ├── JwtTokenProvider.java
│   ├── JwtAuthenticationFilter.java
│   └── CustomUserDetailsService.java
├── service/                          # Business logic
│   ├── AuthService.java
│   └── TaskService.java
└── exception/                        # Exception handling
    ├── GlobalExceptionHandler.java
    ├── ResourceNotFoundException.java
    └── UnauthorizedException.java
```

### Testing the API

#### Automated Testing Script

Use the provided test script for comprehensive API testing:

```bash
./test-api.sh                          # Tests http://localhost:8080
./test-api.sh http://taskapi.local     # Tests custom URL
./test-api.sh http://localhost:8888    # Tests different port
```

The script tests:
- User registration
- User login
- Task creation (3 tasks)
- Task listing
- Task updates
- Task completion toggle
- Task deletion
- Unauthorized access protection

#### Manual Testing with cURL

Register a user:
```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"password123"}'
```

Login:
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"password123"}'
```

Create a task (replace `<TOKEN>` with the JWT from login):
```bash
curl -X POST http://localhost:8080/api/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <TOKEN>" \
  -d '{"title":"My first task","description":"Task description","completed":false}'
```

Get all tasks:
```bash
curl -X GET http://localhost:8080/api/tasks \
  -H "Authorization: Bearer <TOKEN>"
```

## Deployment Options

### Docker Compose (Development/Local)
- Simple setup with `docker-compose up`
- Includes PostgreSQL database
- Automatic dependency management
- Volume persistence for database
- See `docker-compose.yml` for configuration

### Kubernetes (Production-Ready)
- Kustomize-based configuration in `k8s/`
- Overlays for `local` and `production` environments
- Includes:
  - Namespace isolation
  - Secrets management for sensitive data
  - Persistent volume for PostgreSQL
  - Service and Ingress configuration
  - Health checks and resource limits
- Deploy with: `kubectl apply -k k8s/overlays/local`

### Helper Scripts

- **test-api.sh**: Comprehensive API integration testing
- **docker-cleanup.sh**: Docker resource cleanup utility
- **k8s-diagnose.sh**: Kubernetes troubleshooting and diagnostics

## Monitoring and Health Checks

The API exposes health endpoints via Spring Boot Actuator:

```bash
# Health check endpoint
curl http://localhost:8080/actuator/health

# Response when healthy
{
  "status": "UP"
}
```

Health checks are used in:
- Docker healthchecks (Dockerfile and docker-compose.yml)
- Kubernetes liveness/readiness probes
- Test scripts for verification

## License

This project is for learning purposes.

## Contributing

This is a learning project. Feel free to fork and experiment!
