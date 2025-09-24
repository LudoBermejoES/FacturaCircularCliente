#!/bin/bash

# E2E Test Runner Script for FacturaCircular
# This script provides various options for running Playwright tests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
BROWSER="chromium"
HEADED="false"
DEBUG="false"
TEST_PATH=""
COMMAND="test"

# Function to display usage
usage() {
    echo -e "${BLUE}FacturaCircular E2E Test Runner${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -b, --browser BROWSER    Browser to use (chromium, firefox, webkit, mobile, all) [default: chromium]"
    echo "  -h, --headed             Run tests in headed mode (visible browser)"
    echo "  -d, --debug              Run tests in debug mode"
    echo "  -u, --ui                 Open Playwright UI mode"
    echo "  -t, --test PATH          Run specific test file or directory"
    echo "  -r, --report             Show HTML report from last test run"
    echo "  -i, --install            Install Playwright and dependencies"
    echo "  -c, --codegen            Open Playwright codegen tool"
    echo "  -s, --smoke              Run smoke tests only"
    echo "  --build                  Build Docker image before running"
    echo "  --local                  Run tests locally (not in Docker)"
    echo "  --help                   Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Run all tests in Docker"
    echo "  $0 -b firefox                         # Run tests in Firefox"
    echo "  $0 -h -d                              # Run in headed debug mode"
    echo "  $0 -t tests/invoices                  # Run invoice tests only"
    echo "  $0 --local -u                         # Open UI mode locally"
    echo "  $0 --build                            # Rebuild and run tests"
    echo ""
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--browser)
            BROWSER="$2"
            shift 2
            ;;
        -h|--headed)
            HEADED="true"
            shift
            ;;
        -d|--debug)
            DEBUG="true"
            shift
            ;;
        -u|--ui)
            COMMAND="ui"
            shift
            ;;
        -t|--test)
            TEST_PATH="$2"
            shift 2
            ;;
        -r|--report)
            COMMAND="report"
            shift
            ;;
        -i|--install)
            COMMAND="install"
            shift
            ;;
        -c|--codegen)
            COMMAND="codegen"
            shift
            ;;
        -s|--smoke)
            TEST_PATH="tests/smoke"
            shift
            ;;
        --build)
            BUILD="true"
            shift
            ;;
        --local)
            LOCAL="true"
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Function to run tests locally
run_local() {
    echo -e "${BLUE}Running tests locally...${NC}"
    cd e2e

    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        echo -e "${YELLOW}Installing dependencies...${NC}"
        npm ci
    fi

    case $COMMAND in
        install)
            echo -e "${GREEN}Installing Playwright browsers...${NC}"
            npx playwright install --with-deps
            ;;
        ui)
            echo -e "${GREEN}Opening Playwright UI...${NC}"
            npx playwright test --ui
            ;;
        report)
            echo -e "${GREEN}Opening test report...${NC}"
            npx playwright show-report
            ;;
        codegen)
            echo -e "${GREEN}Opening Playwright codegen...${NC}"
            npx playwright codegen http://localhost:3002
            ;;
        test)
            # Build test command
            TEST_CMD="npx playwright test"

            if [ "$BROWSER" != "all" ]; then
                TEST_CMD="$TEST_CMD --project=$BROWSER"
            fi

            if [ "$HEADED" == "true" ]; then
                TEST_CMD="$TEST_CMD --headed"
            fi

            if [ "$DEBUG" == "true" ]; then
                TEST_CMD="$TEST_CMD --debug"
            fi

            if [ -n "$TEST_PATH" ]; then
                TEST_CMD="$TEST_CMD $TEST_PATH"
            fi

            echo -e "${GREEN}Running: $TEST_CMD${NC}"
            $TEST_CMD
            ;;
    esac
}

# Function to run tests in Docker
run_docker() {
    echo -e "${BLUE}Running tests in Docker...${NC}"

    # Build if requested
    if [ "$BUILD" == "true" ]; then
        echo -e "${YELLOW}Building Playwright Docker image...${NC}"
        docker-compose build playwright
    fi

    # Prepare Docker command
    DOCKER_CMD="docker-compose run --rm"

    # Add environment variables
    if [ "$HEADED" == "true" ]; then
        DOCKER_CMD="$DOCKER_CMD -e HEADED=1"
    fi

    if [ "$DEBUG" == "true" ]; then
        DOCKER_CMD="$DOCKER_CMD -e DEBUG=1"
    fi

    DOCKER_CMD="$DOCKER_CMD playwright"

    case $COMMAND in
        install)
            echo -e "${GREEN}Installing dependencies in Docker...${NC}"
            $DOCKER_CMD npm ci
            ;;
        report)
            echo -e "${GREEN}Opening test report...${NC}"
            $DOCKER_CMD npx playwright show-report
            ;;
        test)
            # Build test command
            TEST_CMD="npx playwright test"

            if [ "$BROWSER" != "all" ]; then
                TEST_CMD="$TEST_CMD --project=$BROWSER"
            fi

            if [ "$HEADED" == "true" ]; then
                TEST_CMD="$TEST_CMD --headed"
            fi

            if [ "$DEBUG" == "true" ]; then
                TEST_CMD="$TEST_CMD --debug"
            fi

            if [ -n "$TEST_PATH" ]; then
                TEST_CMD="$TEST_CMD $TEST_PATH"
            fi

            echo -e "${GREEN}Running: $DOCKER_CMD $TEST_CMD${NC}"
            $DOCKER_CMD $TEST_CMD

            # Check exit code
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Tests passed successfully!${NC}"
            else
                echo -e "${RED}✗ Tests failed. Check the output above for details.${NC}"
                echo -e "${YELLOW}Tip: Run with -r flag to see the HTML report${NC}"
                exit 1
            fi
            ;;
        *)
            echo -e "${RED}Command '$COMMAND' is not supported in Docker mode${NC}"
            echo -e "${YELLOW}Use --local flag for UI mode, codegen, etc.${NC}"
            exit 1
            ;;
    esac
}

# Main execution
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}     FacturaCircular E2E Test Runner${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

# Check if running locally or in Docker
if [ "$LOCAL" == "true" ]; then
    run_local
else
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}Docker is not running!${NC}"
        echo -e "${YELLOW}Please start Docker or use --local flag to run tests locally${NC}"
        exit 1
    fi

    # Check if containers are running
    if ! docker-compose ps | grep -q "factura-circular-client.*Up"; then
        echo -e "${YELLOW}Starting application containers...${NC}"
        docker-compose up -d web
        echo -e "${GREEN}Waiting for application to be ready...${NC}"
        sleep 10
    fi

    run_docker
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Test execution completed!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"