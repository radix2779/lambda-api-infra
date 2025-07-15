#!/bin/bash

# Lambda Service Generator Script
# Helps create new Lambda services using the TypeScript template

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_color() {
    printf "${1}${2}${NC}\n"
}

print_header() {
    echo ""
    print_color $BLUE "🚀 Lambda Service Generator"
    print_color $BLUE "=================================="
    echo ""
}

print_success() {
    print_color $GREEN "✅ $1"
}

print_warning() {
    print_color $YELLOW "⚠️  $1"
}

print_error() {
    print_color $RED "❌ $1"
}

# Check prerequisites
check_prerequisites() {
    print_color $BLUE "Checking prerequisites..."
    
    # Check if copier is installed
    if ! command -v copier &> /dev/null; then
        print_error "Copier is not installed. Please install it with: pip install copier"
        exit 1
    fi
    
    # Check if node is installed
    if ! command -v node &> /dev/null; then
        print_warning "Node.js is not installed. You'll need it for development."
    fi
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_warning "Terraform is not installed. You'll need it for deployment."
    fi
    
    print_success "Prerequisites check completed"
}

# Get service name
get_service_name() {
    echo ""
    while true; do
        read -p "Enter service name (e.g., user-service, order-processor): " SERVICE_NAME
        
        if [[ $SERVICE_NAME =~ ^[a-z][a-z0-9-]*[a-z0-9]$ ]]; then
            break
        else
            print_error "Service name must be lowercase, start with a letter, and contain only letters, numbers, and hyphens"
        fi
    done
}

# Generate service
generate_service() {
    print_color $BLUE "Generating Lambda service: $SERVICE_NAME"
    
    # Get the directory of this script
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    TEMPLATE_DIR="$SCRIPT_DIR/templates/lambda-typescript"
    
    # Check if template exists
    if [ ! -d "$TEMPLATE_DIR" ]; then
        print_error "Template directory not found: $TEMPLATE_DIR"
        print_error "Make sure you're running this script from the cloud-infra repository root"
        exit 1
    fi
    
    # Generate the service
    copier copy "$TEMPLATE_DIR" "$SERVICE_NAME"
    
    if [ $? -eq 0 ]; then
        print_success "Service generated successfully!"
    else
        print_error "Failed to generate service"
        exit 1
    fi
}

# Provide next steps
show_next_steps() {
    echo ""
    print_color $GREEN "🎉 Service '$SERVICE_NAME' created successfully!"
    echo ""
    print_color $BLUE "Next steps:"
    echo ""
    echo "1. Navigate to your service:"
    print_color $YELLOW "   cd $SERVICE_NAME"
    echo ""
    echo "2. Install dependencies:"
    print_color $YELLOW "   npm install"
    echo ""
    echo "3. Build the TypeScript code:"
    print_color $YELLOW "   npm run build"
    echo ""
    echo "4. Run tests (if enabled):"
    print_color $YELLOW "   npm test"
    echo ""
    echo "5. Configure Terraform backend in terraform/main.tf"
    echo ""
    echo "6. Create GitHub repository and set up variables:"
    print_color $YELLOW "   AWS_ROLE_ARN=arn:aws:iam::123456789012:role/github-actions-role"
    echo ""
    echo "7. Deploy infrastructure:"
    print_color $YELLOW "   cd terraform && terraform init && terraform apply"
    echo ""
    print_color $BLUE "📚 Documentation:"
    echo "   - Service README: $SERVICE_NAME/README.md"
    echo "   - Template docs: templates/lambda-typescript/README.md"
    echo "   - Integration guide: docs/lambda-integration.md"
    echo ""
}

# Main execution
main() {
    print_header
    check_prerequisites
    get_service_name
    generate_service
    show_next_steps
}

# Show help
show_help() {
    echo "Lambda Service Generator"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -n, --name     Service name (skip interactive prompt)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Interactive mode"
    echo "  $0 -n user-service   # Generate user-service directly"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -n|--name)
            SERVICE_NAME="$2"
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function if service name is provided via CLI
if [ ! -z "$SERVICE_NAME" ]; then
    if [[ $SERVICE_NAME =~ ^[a-z][a-z0-9-]*[a-z0-9]$ ]]; then
        print_header
        check_prerequisites
        generate_service
        show_next_steps
    else
        print_error "Invalid service name format"
        show_help
        exit 1
    fi
else
    main
fi
