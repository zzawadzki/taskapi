Create a Spring Boot 3.2+ Maven project with the following specifications:

PROJECT SETUP:
- Group: com.learning
- Artifact: task-api
- Package: com.learning.tasks
- Java 21+
- Spring Boot 3.5.x (latest stable)

DEPENDENCIES (in pom.xml):
- spring-boot-starter-web
- spring-boot-starter-data-jpa
- spring-boot-starter-security
- spring-boot-starter-validation
- postgresql (runtime)
- lombok
- io.jsonwebtoken:jjwt-api:0.12.3
- io.jsonwebtoken:jjwt-impl:0.12.3 (runtime)
- io.jsonwebtoken:jjwt-jackson:0.12.3 (runtime)
- spring-boot-starter-test (test scope)

PROJECT STRUCTURE:
src/main/java/com/learning/task/
├── TaskApiApplication.java (main class)
├── config/
│   ├── SecurityConfig.java (Spring Security configuration)
│   └── JwtConfig.java (JWT properties)
├── controller/
│   ├── AuthController.java (register, login endpoints)
│   └── TaskController.java (CRUD operations)
├── dto/
│   ├── LoginRequest.java
│   ├── RegisterRequest.java
│   ├── AuthResponse.java (contains JWT token)
│   ├── TaskRequest.java
│   └── TaskResponse.java
├── entity/
│   ├── User.java (id, username, email, password, createdAt)
│   └── Task.java (id, title, description, completed, user relationship, createdAt, updatedAt)
├── repository/
│   ├── UserRepository.java
│   └── TaskRepository.java
├── security/
│   ├── JwtTokenProvider.java (generate and validate JWT)
│   ├── JwtAuthenticationFilter.java (filter for JWT validation)
│   └── CustomUserDetailsService.java
├── service/
│   ├── AuthService.java
│   └── TaskService.java
└── exception/
├── GlobalExceptionHandler.java
├── ResourceNotFoundException.java
└── UnauthorizedException.java

REST API ENDPOINTS:
Auth endpoints (public):
- POST /api/auth/register - Register new user
- POST /api/auth/login - Login and return JWT token

Task endpoints (secured - require JWT):
- GET /api/tasks - Get all tasks for authenticated user
- POST /api/tasks - Create new task
- GET /api/tasks/{id} - Get specific task
- PUT /api/tasks/{id} - Update task
- DELETE /api/tasks/{id} - Delete task
- PATCH /api/tasks/{id}/complete - Toggle task completion

SECURITY REQUIREMENTS:
- JWT-based authentication
- Password encryption with BCryptPasswordEncoder
- All /api/tasks/** endpoints require authentication
- /api/auth/** endpoints are public
- JWT token expires in 24 hours
- Custom authentication entry point for 401 errors

VALIDATION:
- Email must be valid format
- Username min 3 chars, max 50 chars
- Password min 6 chars
- Task title required, max 200 chars
- Proper error messages for validation failures

DATABASE:
- Use JPA/Hibernate
- Proper entity relationships (User has many Tasks)
- Use @CreatedDate and @LastModifiedDate for timestamps
- Add indexes on frequently queried fields

Create application.yml with:
- Server port: 8080
- Database configuration using environment variables:
    - SPRING_DATASOURCE_URL (default: jdbc:postgresql://localhost:5432/taskapi_db)
    - SPRING_DATASOURCE_USERNAME (default: taskapi_user)
    - SPRING_DATASOURCE_PASSWORD (default: changeme)
    - JWT_SECRET (no default - must be provided)
    - JWT_EXPIRATION (default: 86400000 - 24 hours in ms)
- JPA settings: show-sql: true, ddl-auto: update
- Logging level: INFO

ERROR HANDLING:
- Return proper HTTP status codes
- Return consistent error response format: {timestamp, status, error, message, path}
- Handle validation errors
- Handle ResourceNotFoundException (404)
- Handle authentication errors (401)
- Handle authorization errors (403)

Also create:
- .gitignore (Maven, IntelliJ, macOS)
- README.md with setup instructions

Make the code production-ready with:
- Proper exception handling
- Input validation
- Security best practices
- Clean code structure
- Javadoc for public methods
