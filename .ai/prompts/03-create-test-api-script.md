Create a bash script named test-api.sh that:

1. Sets BASE_URL to http://localhost:8080
2. Registers a test user with a random username (using timestamp)
3. Extracts and saves the JWT token from the response
4. Creates three different tasks using the token
5. Lists all tasks
6. Updates the first task
7. Marks the second task as complete using PATCH
8. Deletes the third task
9. Lists all tasks again to verify changes

Requirements:
- Use curl with -s (silent) and -w for HTTP status codes
- Use jq to parse JSON responses
- Print clear output for each step with ✅ or ❌
- Print the JWT token (first 20 chars only for security)
- Exit with error code if any step fails
- Add colors to the output (green for success, red for error)

Make the script executable and well-documented.