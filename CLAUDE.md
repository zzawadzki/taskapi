# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Task Management API with JWT-based authentication built with Spring Boot 3.5.x and Java 21. The application follows a clean architecture pattern with clear separation between controllers, services, repositories, and security layers.

## Build and Development Commands

### Maven Build
```bash
# Clean and build
mvn clean install

# Build without tests
mvn clean package -DskipTests

# Run tests
mvn test

# Run the application
mvn spring-boot:run
```

### Docker
```bash
# Build and start all services (PostgreSQL + API)
docker-compose up --build

# Start services in background
docker-compose up -d

# Stop services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

### Testing the API
Use the provided shell script for quick API testing:
```bash
./test-api.sh
```

## Configuration

### Required Environment Variables
- `JWT_SECRET` - REQUIRED. Must be at least 256 bits (32 characters). Generate with: `openssl rand -base64 32`
- `JWT_EXPIRATION` - Optional, defaults to 86400000ms (24 hours)
- `SPRING_DATASOURCE_URL` - Database connection URL (defaults to localhost:5432/taskapi_db)
- `SPRING_DATASOURCE_USERNAME` - Database user (defaults to taskapi_user)
- `SPRING_DATASOURCE_PASSWORD` - Database password (defaults to changeme)

## Architecture and Key Patterns

### Security Architecture
- **JWT-based authentication**: Stateless token-based auth using `JwtTokenProvider` (src/main/java/com/learning/task/security/JwtTokenProvider.java)
- **Filter chain**: `JwtAuthenticationFilter` intercepts requests and validates tokens before Spring Security processes them
- **User isolation**: All task operations are scoped to the authenticated user via `getCurrentUser()` in `TaskService`
- **Public endpoints**: `/api/auth/**` and `/actuator/health` are publicly accessible
- **Protected endpoints**: `/api/tasks/**` requires valid JWT authentication

### Layer Responsibilities
- **Controllers** (`controller/`): Handle HTTP routing and request/response mapping only. No business logic.
- **Services** (`service/`): Contain all business logic and transaction boundaries. Use `@Transactional` for state changes.
- **Repositories** (`repository/`): JPA interfaces extending `JpaRepository` with custom query methods like `findByIdAndUserId`
- **DTOs** (`dto/`): Immutable data transfer objects. Use Java `record` types for new DTOs.
- **Entities** (`entity/`): JPA entities with relationships. Never exposed directly in API responses.

### Entity-DTO Mapping Pattern
Always map entities to DTOs before returning from services. Example pattern used in `TaskResponse.fromEntity(Task task)`. Never expose JPA entities directly in controller responses.

### User Context Retrieval
`TaskService.getCurrentUser()` demonstrates the pattern for getting the authenticated user from Spring Security context. All service methods requiring user context should use this pattern.

### Exception Handling
Centralized in `GlobalExceptionHandler` with `@ControllerAdvice`. Returns consistent error format with timestamp, status, error, message, and path fields. Custom exceptions (`ResourceNotFoundException`, `UnauthorizedException`) are mapped to appropriate HTTP status codes.

## Code Guidelines

### Spring Boot
- Use constructor-based dependency injection with Lombok's `@RequiredArgsConstructor`
- Externalize configuration via environment variables (see `application.yml` and `JwtConfig`)
- Use `@Transactional` at service layer for state-changing operations
- Use `@Transactional(readOnly = true)` for read-only operations
- Use SLF4J for logging (`@Slf4j` annotation)
- Use Bean Validation annotations (`@Valid`, `@Size`, `@Email`) instead of manual validation

### JPA/Hibernate
- Define custom repository methods following Spring Data JPA naming conventions (e.g., `findByIdAndUserId`)
- Keep `open-in-view: false` to avoid lazy loading issues
- Use `@EntityGraph` or fetch joins for N+1 prevention when needed
- Always use DTOs in responses, never entities

### Lombok
- Use `@RequiredArgsConstructor` for constructor injection
- Prefer Java `record` for DTOs over Lombok's `@Value`
- Use `@Slf4j` for logging
- Avoid `@Data` in non-DTO classes; use specific annotations like `@Getter`, `@Setter`

### Security
- JWT tokens are validated in `JwtAuthenticationFilter` before reaching controllers
- Token expiration is configurable via `JWT_EXPIRATION` environment variable
- Passwords are encrypted with BCrypt (configured in `SecurityConfig`)
- CORS is configured to allow all origins in development (see `SecurityConfig.corsConfigurationSource()`)

## Database

PostgreSQL 15+ is required. The application uses Hibernate DDL auto-update (`ddl-auto: update`). For production, consider using proper migration tools like Flyway or Liquibase.

HikariCP connection pooling is provided by Spring Boot defaults.

## Testing

No tests currently exist in the repository. When adding tests:
- Use `@SpringBootTest` for integration tests
- Use `@WebMvcTest` for controller tests
- Use `@DataJpaTest` for repository tests
- Include `spring-security-test` for security testing with `@WithMockUser`
