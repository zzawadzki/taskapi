#!/bin/bash

# Task API Testing Script
# This script tests all major endpoints of the Task Management API
# Requirements: curl, jq

set -e  # Exit on error

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="http://localhost:8080"
TIMESTAMP=$(date +%s)
USERNAME="testuser_${TIMESTAMP}"
EMAIL="testuser_${TIMESTAMP}@example.com"
PASSWORD="password123"

# Check dependencies
if ! command -v curl &> /dev/null; then
    echo -e "${RED}❌ curl is not installed${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ jq is not installed${NC}"
    exit 1
fi

# Args and usage
usage() {
    cat <<USAGE
Usage: ./test-api.sh [BASE_URL]

Runs integration tests against the Task API.

Arguments:
  BASE_URL   Base URL of the API to test (default: http://localhost:8080)

Examples:
  ./test-api.sh                          # Uses http://localhost:8080
  ./test-api.sh http://taskapi.local     # Uses custom URL
  ./test-api.sh http://localhost:8888    # Uses different port
USAGE
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

# Allow overriding BASE_URL by first argument
if [[ -n "$1" ]]; then
    BASE_URL="$1"
fi

# Function to print section headers
print_section() {
    echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
}

# Function to check HTTP status
check_status() {
    local status=$1
    local expected=$2
    local message=$3

    if [ "$status" -eq "$expected" ]; then
        echo -e "${GREEN}✅ $message (HTTP $status)${NC}"
        return 0
    else
        echo -e "${RED}❌ $message - Expected HTTP $expected, got $status${NC}"
        exit 1
    fi
}

# Start testing
echo -e "${YELLOW}"
echo "╔════════════════════════════════════════════╗"
echo "║   Task API Integration Test Suite         ║"
echo "╔════════════════════════════════════════════╗"
echo -e "${NC}"

# Inform which URL will be tested
echo -e "${YELLOW}Testing API at: ${BASE_URL}${NC}"

# Connection test (quick reachability check)
echo -n "Checking connection... "
if curl -sS -o /dev/null -m 10 "$BASE_URL"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
    echo -e "${RED}❌ Unable to connect to ${BASE_URL}. Ensure the server is running and reachable.${NC}"
    echo -e "${YELLOW}Tip:${NC} You can specify a different base URL, e.g.: ./test-api.sh http://localhost:8888"
    exit 1
fi

print_section "1. REGISTER NEW USER"
echo "Username: $USERNAME"
echo "Email: $EMAIL"

REGISTER_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\",\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")

HTTP_STATUS=$(echo "$REGISTER_RESPONSE" | tail -n1)
REGISTER_BODY=$(echo "$REGISTER_RESPONSE" | sed '$d')

check_status "$HTTP_STATUS" 201 "User registered successfully"

JWT_TOKEN=$(echo "$REGISTER_BODY" | jq -r '.token')
TOKEN_PREVIEW="${JWT_TOKEN:0:20}..."

echo "JWT Token: $TOKEN_PREVIEW"

print_section "2. LOGIN WITH USER"

LOGIN_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}")

HTTP_STATUS=$(echo "$LOGIN_RESPONSE" | tail -n1)
LOGIN_BODY=$(echo "$LOGIN_RESPONSE" | sed '$d')

check_status "$HTTP_STATUS" 200 "Login successful"

print_section "3. CREATE TASKS"

# Task 1
echo -e "\nCreating Task 1: Learn Spring Boot..."
TASK1_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/tasks" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -d '{"title":"Learn Spring Boot","description":"Complete Spring Boot tutorial","completed":false}')

HTTP_STATUS=$(echo "$TASK1_RESPONSE" | tail -n1)
TASK1_BODY=$(echo "$TASK1_RESPONSE" | sed '$d')

check_status "$HTTP_STATUS" 201 "Task 1 created"
TASK1_ID=$(echo "$TASK1_BODY" | jq -r '.id')
echo "Task 1 ID: $TASK1_ID"

# Task 2
echo -e "\nCreating Task 2: Write Tests..."
TASK2_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/tasks" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -d '{"title":"Write Tests","description":"Add unit and integration tests","completed":false}')

HTTP_STATUS=$(echo "$TASK2_RESPONSE" | tail -n1)
TASK2_BODY=$(echo "$TASK2_RESPONSE" | sed '$d')

check_status "$HTTP_STATUS" 201 "Task 2 created"
TASK2_ID=$(echo "$TASK2_BODY" | jq -r '.id')
echo "Task 2 ID: $TASK2_ID"

# Task 3
echo -e "\nCreating Task 3: Deploy to Production..."
TASK3_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/tasks" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -d '{"title":"Deploy to Production","description":"Set up CI/CD pipeline","completed":false}')

HTTP_STATUS=$(echo "$TASK3_RESPONSE" | tail -n1)
TASK3_BODY=$(echo "$TASK3_RESPONSE" | sed '$d')

check_status "$HTTP_STATUS" 201 "Task 3 created"
TASK3_ID=$(echo "$TASK3_BODY" | jq -r '.id')
echo "Task 3 ID: $TASK3_ID"

print_section "4. LIST ALL TASKS"

LIST_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/tasks" \
    -H "Authorization: Bearer $JWT_TOKEN")

HTTP_STATUS=$(echo "$LIST_RESPONSE" | tail -n1)
LIST_BODY=$(echo "$LIST_RESPONSE" | sed '$d')

check_status "$HTTP_STATUS" 200 "Tasks listed successfully"

TASK_COUNT=$(echo "$LIST_BODY" | jq '. | length')
echo "Total tasks: $TASK_COUNT"
echo -e "\nTasks:"
echo "$LIST_BODY" | jq -r '.[] | "  • [\(.id)] \(.title) - Completed: \(.completed)"'

print_section "5. UPDATE TASK 1"

UPDATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "$BASE_URL/api/tasks/$TASK1_ID" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -d '{"title":"Learn Spring Boot [UPDATED]","description":"Complete advanced Spring Boot tutorial","completed":false}')

HTTP_STATUS=$(echo "$UPDATE_RESPONSE" | tail -n1)
UPDATE_BODY=$(echo "$UPDATE_RESPONSE" | sed '$d')

check_status "$HTTP_STATUS" 200 "Task 1 updated"
echo "Updated title: $(echo "$UPDATE_BODY" | jq -r '.title')"

print_section "6. MARK TASK 2 AS COMPLETE"

COMPLETE_RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH "$BASE_URL/api/tasks/$TASK2_ID/complete" \
    -H "Authorization: Bearer $JWT_TOKEN")

HTTP_STATUS=$(echo "$COMPLETE_RESPONSE" | tail -n1)
COMPLETE_BODY=$(echo "$COMPLETE_RESPONSE" | sed '$d')

check_status "$HTTP_STATUS" 200 "Task 2 marked as complete"
COMPLETED_STATUS=$(echo "$COMPLETE_BODY" | jq -r '.completed')
echo "Completion status: $COMPLETED_STATUS"

print_section "7. DELETE TASK 3"

DELETE_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE_URL/api/tasks/$TASK3_ID" \
    -H "Authorization: Bearer $JWT_TOKEN")

HTTP_STATUS=$(echo "$DELETE_RESPONSE" | tail -n1)

check_status "$HTTP_STATUS" 204 "Task 3 deleted"

print_section "8. LIST ALL TASKS (AFTER CHANGES)"

LIST_FINAL_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/tasks" \
    -H "Authorization: Bearer $JWT_TOKEN")

HTTP_STATUS=$(echo "$LIST_FINAL_RESPONSE" | tail -n1)
LIST_FINAL_BODY=$(echo "$LIST_FINAL_RESPONSE" | sed '$d')

check_status "$HTTP_STATUS" 200 "Final tasks listed successfully"

FINAL_TASK_COUNT=$(echo "$LIST_FINAL_BODY" | jq '. | length')
echo "Total tasks: $FINAL_TASK_COUNT"
echo -e "\nFinal tasks:"
echo "$LIST_FINAL_BODY" | jq -r '.[] | "  • [\(.id)] \(.title) - Completed: \(.completed)"'

print_section "9. TEST UNAUTHORIZED ACCESS"

UNAUTH_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/tasks")

HTTP_STATUS=$(echo "$UNAUTH_RESPONSE" | tail -n1)

check_status "$HTTP_STATUS" 401 "Unauthorized access blocked correctly"

# Summary
echo -e "\n${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ ALL TESTS PASSED SUCCESSFULLY!        ║${NC}"
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo ""
echo "Test Summary:"
echo "  • User registered: $USERNAME"
echo "  • Tasks created: 3"
echo "  • Tasks updated: 1"
echo "  • Tasks completed: 1"
echo "  • Tasks deleted: 1"
echo "  • Final task count: $FINAL_TASK_COUNT"
echo ""

exit 0
