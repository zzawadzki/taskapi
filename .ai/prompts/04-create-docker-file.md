Create a multi-stage Dockerfile for the Spring Boot application with these requirements:

STAGE 1 - BUILD:
- Name: builder
- Base image: maven:3.9-eclipse-temurin-21-alpine
- Working directory: /app
- Copy pom.xml first (for layer caching)
- Download dependencies (mvn dependency:go-offline)
- Copy source code
- Build the application: mvn clean package -DskipTests
- The JAR should be in /app/target/*.jar

STAGE 2 - RUNTIME:
- Base image: eclipse-temurin:21-jre-alpine
- Install dumb-init (for proper signal handling)
- Create non-root user 'appuser' with UID 1000
- Create /app directory owned by appuser
- Working directory: /app
- Copy the JAR from builder stage (rename to app.jar)
- Change ownership to appuser
- Expose port 8080
- Switch to appuser
- Add healthcheck (curl localhost:8080/actuator/health every 30s)
- Use ENTRYPOINT with dumb-init and exec form
- Java options for container: -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0

Security best practices:
- Non-root user
- Minimal base image (alpine)
- No unnecessary packages
- Proper signal handling with dumb-init

Also create .dockerignore file to exclude:
- target/
- .git/
- .idea/
- .mvn/
- *.md
- .env
- .env.*
- docker-compose.yml
- *.log
- .DS_Store