#!/bin/bash

# generate-secrets.sh
# Script to generate and manage Kubernetes secrets for Task API
# Usage: ./scripts/generate-secrets.sh [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENV_FILE=".env"
NAMESPACE="default"
SECRET_NAME="task-api-secrets"
DRY_RUN=false
GENERATE_ONLY=false

# Help message
show_help() {
    cat << EOF
Usage: ${0##*/} [OPTIONS]

Generate and manage Kubernetes secrets for Task API application.

OPTIONS:
    -h, --help              Show this help message
    -f, --file FILE         Path to .env file (default: .env)
    -n, --namespace NS      Kubernetes namespace (default: default)
    -s, --secret-name NAME  Secret name (default: task-api-secrets)
    -d, --dry-run           Print kubectl commands without executing
    -g, --generate-only     Only generate secrets, don't create in Kubernetes
    --github                Show GitHub secrets setup commands

EXAMPLES:
    # Generate and apply secrets from .env file
    ./scripts/generate-secrets.sh

    # Use custom .env file
    ./scripts/generate-secrets.sh -f .env.production

    # Dry run to see what would be created
    ./scripts/generate-secrets.sh --dry-run

    # Generate secrets but don't apply to Kubernetes
    ./scripts/generate-secrets.sh --generate-only

    # Show GitHub secrets commands
    ./scripts/generate-secrets.sh --github

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--file)
            ENV_FILE="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -s|--secret-name)
            SECRET_NAME="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -g|--generate-only)
            GENERATE_ONLY=true
            shift
            ;;
        --github)
            show_github_instructions
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Function to show GitHub secrets setup instructions
show_github_instructions() {
    echo -e "${BLUE}=== GitHub Secrets Setup ===${NC}\n"

    echo -e "${GREEN}1. KUBECONFIG${NC}"
    echo "   Encode your kubeconfig file:"
    echo -e "   ${YELLOW}cat ~/.kube/config | base64 | pbcopy${NC}"
    echo "   Then add to GitHub: Settings → Secrets → Actions → New secret"
    echo "   Name: KUBECONFIG"
    echo "   Value: <paste from clipboard>"
    echo ""

    echo -e "${GREEN}2. GITHUB_TOKEN${NC}"
    echo "   No action needed - automatically provided by GitHub Actions"
    echo ""

    echo -e "${BLUE}To add secrets to GitHub:${NC}"
    echo "1. Go to https://github.com/<your-org>/<your-repo>/settings/secrets/actions"
    echo "2. Click 'New repository secret'"
    echo "3. Add each secret name and value"
    echo "4. Click 'Add secret'"
}

# Function to generate a strong JWT secret
generate_jwt_secret() {
    openssl rand -base64 32
}

# Function to load and validate .env file
load_env_file() {
    if [[ ! -f "$ENV_FILE" ]]; then
        echo -e "${RED}Error: $ENV_FILE not found${NC}"
        echo -e "${YELLOW}Creating template .env file...${NC}"
        create_env_template
        echo -e "${GREEN}Please edit $ENV_FILE with your values and run this script again${NC}"
        exit 1
    fi

    # Source the .env file
    set -a
    source "$ENV_FILE"
    set +a

    echo -e "${GREEN}✓ Loaded environment file: $ENV_FILE${NC}"
}

# Function to create .env template
create_env_template() {
    cat > "$ENV_FILE" << 'EOF'
# PostgreSQL Database Configuration
POSTGRES_HOST=postgres-service
POSTGRES_DB=taskapi_db
POSTGRES_USER=taskapi_user
POSTGRES_PASSWORD=changeme

# JWT Configuration (will be auto-generated if not set)
JWT_SECRET=

# Optional: JWT token expiration in milliseconds (default: 86400000 = 24 hours)
# JWT_EXPIRATION=86400000
EOF
    chmod 600 "$ENV_FILE"
}

# Function to validate required variables
validate_env_vars() {
    local missing_vars=()

    [[ -z "$POSTGRES_HOST" ]] && missing_vars+=("POSTGRES_HOST")
    [[ -z "$POSTGRES_DB" ]] && missing_vars+=("POSTGRES_DB")
    [[ -z "$POSTGRES_USER" ]] && missing_vars+=("POSTGRES_USER")
    [[ -z "$POSTGRES_PASSWORD" ]] && missing_vars+=("POSTGRES_PASSWORD")

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo -e "${RED}Error: Missing required variables in $ENV_FILE:${NC}"
        printf '  %s\n' "${missing_vars[@]}"
        exit 1
    fi

    # Generate JWT_SECRET if not set
    if [[ -z "$JWT_SECRET" ]]; then
        echo -e "${YELLOW}JWT_SECRET not set. Generating new secret...${NC}"
        JWT_SECRET=$(generate_jwt_secret)
        echo -e "${GREEN}✓ Generated JWT_SECRET${NC}"

        # Optionally update .env file
        if [[ "$GENERATE_ONLY" == false ]]; then
            sed -i.bak "s|^JWT_SECRET=.*|JWT_SECRET=$JWT_SECRET|" "$ENV_FILE"
            echo -e "${GREEN}✓ Updated $ENV_FILE with generated JWT_SECRET${NC}"
        fi
    fi

    # Validate JWT_SECRET length (must be at least 32 characters for 256 bits)
    if [[ ${#JWT_SECRET} -lt 32 ]]; then
        echo -e "${RED}Error: JWT_SECRET must be at least 32 characters (256 bits)${NC}"
        echo -e "${YELLOW}Current length: ${#JWT_SECRET}${NC}"
        echo -e "${YELLOW}Generating new secure JWT_SECRET...${NC}"
        JWT_SECRET=$(generate_jwt_secret)
        echo -e "${GREEN}✓ Generated new JWT_SECRET: $JWT_SECRET${NC}"
    fi

    echo -e "${GREEN}✓ All required variables validated${NC}"
}

# Function to display generated secrets (without values)
display_secrets_info() {
    echo -e "\n${BLUE}=== Secrets Configuration ===${NC}"
    echo -e "${GREEN}Secret Name:${NC} $SECRET_NAME"
    echo -e "${GREEN}Namespace:${NC} $NAMESPACE"
    echo -e "\n${GREEN}Variables:${NC}"
    echo "  • POSTGRES_HOST: $POSTGRES_HOST"
    echo "  • POSTGRES_DB: $POSTGRES_DB"
    echo "  • POSTGRES_USER: $POSTGRES_USER"
    echo "  • POSTGRES_PASSWORD: [hidden]"
    echo "  • JWT_SECRET: [hidden - ${#JWT_SECRET} characters]"
    [[ -n "$JWT_EXPIRATION" ]] && echo "  • JWT_EXPIRATION: $JWT_EXPIRATION"
    echo ""
}

# Function to create Kubernetes secret
create_k8s_secret() {
    local cmd="kubectl create secret generic $SECRET_NAME \
  --from-literal=POSTGRES_HOST='$POSTGRES_HOST' \
  --from-literal=POSTGRES_DB='$POSTGRES_DB' \
  --from-literal=POSTGRES_USER='$POSTGRES_USER' \
  --from-literal=POSTGRES_PASSWORD='$POSTGRES_PASSWORD' \
  --from-literal=JWT_SECRET='$JWT_SECRET'"

    # Add optional JWT_EXPIRATION if set
    [[ -n "$JWT_EXPIRATION" ]] && cmd+=" --from-literal=JWT_EXPIRATION='$JWT_EXPIRATION'"

    # Add namespace
    cmd+=" --namespace=$NAMESPACE"

    # Add dry-run or save-config flags
    if [[ "$DRY_RUN" == true ]]; then
        cmd+=" --dry-run=client -o yaml"
        echo -e "${YELLOW}DRY RUN - Command that would be executed:${NC}"
        echo "$cmd"
        echo ""
        eval "$cmd"
        return 0
    fi

    # Check if secret already exists
    if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &> /dev/null; then
        echo -e "${YELLOW}Secret '$SECRET_NAME' already exists in namespace '$NAMESPACE'${NC}"
        read -p "Do you want to replace it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}Aborted. No changes made.${NC}"
            exit 0
        fi

        echo -e "${YELLOW}Deleting existing secret...${NC}"
        kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE"
    fi

    # Create the secret
    echo -e "${GREEN}Creating Kubernetes secret...${NC}"
    eval "$cmd"

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Secret '$SECRET_NAME' created successfully in namespace '$NAMESPACE'${NC}"

        # Verify the secret
        echo -e "\n${BLUE}Verifying secret...${NC}"
        kubectl get secret "$SECRET_NAME" -n "$NAMESPACE"

        echo -e "\n${GREEN}✓ Secret verified${NC}"
        echo -e "\n${YELLOW}Note: You may need to restart your pods to pick up the new secret:${NC}"
        echo -e "  ${BLUE}kubectl rollout restart deployment task-api -n $NAMESPACE${NC}"
    else
        echo -e "${RED}✗ Failed to create secret${NC}"
        exit 1
    fi
}

# Function to output secrets for manual use
output_secrets() {
    echo -e "\n${BLUE}=== Generated Secrets ===${NC}\n"
    echo -e "${GREEN}JWT_SECRET:${NC}"
    echo "$JWT_SECRET"
    echo ""

    echo -e "${GREEN}Base64 encoded values for manual secret creation:${NC}"
    echo "POSTGRES_HOST: $(echo -n "$POSTGRES_HOST" | base64)"
    echo "POSTGRES_DB: $(echo -n "$POSTGRES_DB" | base64)"
    echo "POSTGRES_USER: $(echo -n "$POSTGRES_USER" | base64)"
    echo "POSTGRES_PASSWORD: $(echo -n "$POSTGRES_PASSWORD" | base64)"
    echo "JWT_SECRET: $(echo -n "$JWT_SECRET" | base64)"
    [[ -n "$JWT_EXPIRATION" ]] && echo "JWT_EXPIRATION: $(echo -n "$JWT_EXPIRATION" | base64)"
    echo ""
}

# Main execution
main() {
    echo -e "${BLUE}=== Task API Secret Generator ===${NC}\n"

    # Load and validate environment
    load_env_file
    validate_env_vars

    # Display configuration
    display_secrets_info

    # Generate or create secrets based on flags
    if [[ "$GENERATE_ONLY" == true ]]; then
        output_secrets
    else
        create_k8s_secret
    fi

    echo -e "\n${GREEN}✓ Done!${NC}\n"
}

# Run main function
main
