#!/bin/bash

# Lambda Service Generator
# Creates a new Lambda service using the Copier template

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TEMPLATE_PATH="./copier-template"
SERVICE_NAME=""
INTERACTIVE=true

# Help function
show_help() {
    echo "Lambda Service Generator"
    echo ""
    echo "Usage: $0 [OPTIONS] SERVICE_NAME"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help              Show this help message"
    echo "  -t, --template PATH     Path to template (default: ./copier-template)"
    echo "  -n, --non-interactive   Use default values (requires config file)"
    echo "  -c, --config FILE       Use configuration file for non-interactive mode"
    echo ""
    echo "Examples:"
    echo "  $0 my-service                    # Interactive mode"
    echo "  $0 -n -c config.yml my-service  # Non-interactive with config"
    echo "  $0 -t /path/to/template my-service"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--template)
            TEMPLATE_PATH="$2"
            shift 2
            ;;
        -n|--non-interactive)
            INTERACTIVE=false
            shift
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -*|--*)
            echo -e "${RED}Error: Unknown option $1${NC}"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$SERVICE_NAME" ]]; then
                SERVICE_NAME="$1"
            else
                echo -e "${RED}Error: Multiple service names provided${NC}"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate inputs
if [[ -z "$SERVICE_NAME" ]]; then
    echo -e "${RED}Error: Service name is required${NC}"
    show_help
    exit 1
fi

# Check if copier is installed
if ! command -v copier &> /dev/null; then
    echo -e "${RED}Error: Copier is not installed${NC}"
    echo "Install it with: pip install copier"
    exit 1
fi

# Check if template exists
if [[ ! -d "$TEMPLATE_PATH" ]]; then
    echo -e "${RED}Error: Template path does not exist: $TEMPLATE_PATH${NC}"
    exit 1
fi

# Check if service directory already exists
if [[ -d "$SERVICE_NAME" ]]; then
    echo -e "${RED}Error: Directory '$SERVICE_NAME' already exists${NC}"
    exit 1
fi

echo -e "${BLUE}🚀 Generating Lambda service: $SERVICE_NAME${NC}"
echo ""

# Generate the service
if [[ "$INTERACTIVE" == true ]]; then
    echo -e "${YELLOW}Starting interactive service generation...${NC}"
    copier copy "$TEMPLATE_PATH" "$SERVICE_NAME"
else
    echo -e "${YELLOW}Starting non-interactive service generation...${NC}"
    if [[ -n "$CONFIG_FILE" ]]; then
        copier copy "$TEMPLATE_PATH" "$SERVICE_NAME" --data-file "$CONFIG_FILE"
    else
        copier copy "$TEMPLATE_PATH" "$SERVICE_NAME" --defaults
    fi
fi

# Check if generation was successful
if [[ $? -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}✅ Service '$SERVICE_NAME' generated successfully!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. cd $SERVICE_NAME"
    echo "2. cp .env.example .env"
    echo "3. Edit .env with your configuration"
    echo "4. npm install  # or pip install -e .[dev] for Python"
    echo "5. cd terraform && terraform init"
    echo "6. terraform plan && terraform apply"
    echo ""
    echo -e "${BLUE}For detailed instructions, see:${NC}"
    echo "  📖 $SERVICE_NAME/README.md"
    echo "  📚 ../copier-template/USAGE.md"
    echo ""
    echo -e "${GREEN}Happy coding! 🎉${NC}"
else
    echo -e "${RED}❌ Failed to generate service${NC}"
    exit 1
fi
