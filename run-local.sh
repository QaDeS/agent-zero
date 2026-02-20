#!/bin/bash
# Script to build and run Agent Zero locally with model overrides

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="agent-zero:model-overrides"
CONTAINER_NAME="agent-zero-local"
DATA_DIR="${SCRIPT_DIR}/agent-zero-data"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if Docker is available
check_docker() {
    if command -v docker &> /dev/null; then
        DOCKER_CMD="docker"
        COMPOSE_CMD="docker-compose"
    elif command -v podman &> /dev/null; then
        DOCKER_CMD="podman"
        if command -v podman-compose &> /dev/null; then
            COMPOSE_CMD="podman-compose"
        else
            log_error "podman-compose not found. Install it with: pip install podman-compose"
            exit 1
        fi
    else
        log_error "Neither Docker nor Podman found. Please install one of them."
        exit 1
    fi
    log_info "Using: $DOCKER_CMD"
}

# Function to build the image
build_image() {
    log_info "Building Docker image: $IMAGE_NAME"
    
    if [ ! -f "$SCRIPT_DIR/Dockerfile.localdev" ]; then
        log_error "Dockerfile.localdev not found in $SCRIPT_DIR"
        exit 1
    fi
    
    $DOCKER_CMD build -f "$SCRIPT_DIR/Dockerfile.localdev" -t "$IMAGE_NAME" "$SCRIPT_DIR"
    
    log_info "Image built successfully!"
}

# Function to create data directory
setup_data_dir() {
    if [ ! -d "$DATA_DIR" ]; then
        log_info "Creating data directory: $DATA_DIR"
        mkdir -p "$DATA_DIR"
    fi
    
    # Set permissions if running as current user
    if [ -z "$RUN_AS_USER" ]; then
        chmod -R u+rwx "$DATA_DIR" 2>/dev/null || true
    fi
}

# Function to run the container
run_container() {
    log_info "Starting container: $CONTAINER_NAME"
    
    # Stop existing container if running
    if $DOCKER_CMD ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_warn "Container $CONTAINER_NAME already exists. Stopping and removing..."
        $DOCKER_CMD stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
        $DOCKER_CMD rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
    fi
    
    # Run new container
    $DOCKER_CMD run -d \
        --name "$CONTAINER_NAME" \
        -v "$DATA_DIR:/a0" \
        -p "${HOST_PORT:-50080}:80" \
        -p "${SSH_PORT:-50022}:22" \
        ${API_KEY_OPENAI:+-e "API_KEY_OPENAI=$API_KEY_OPENAI"} \
        ${API_KEY_ANTHROPIC:+-e "API_KEY_ANTHROPIC=$API_KEY_ANTHROPIC"} \
        ${API_KEY_OPENROUTER:+-e "API_KEY_OPENROUTER=$API_KEY_OPENROUTER"} \
        "$IMAGE_NAME"
    
    log_info "Container started successfully!"
    log_info "UI available at: http://localhost:${HOST_PORT:-50080}"
}

# Function to run with docker-compose
run_compose() {
    log_info "Starting with docker-compose..."
    
    if [ ! -f "$SCRIPT_DIR/docker-compose.local.yml" ]; then
        log_error "docker-compose.local.yml not found in $SCRIPT_DIR"
        exit 1
    fi
    
    $COMPOSE_CMD -f "$SCRIPT_DIR/docker-compose.local.yml" up -d
    
    log_info "Services started!"
    log_info "UI available at: http://localhost:${HOST_PORT:-50080}"
}

# Function to show logs
show_logs() {
    $DOCKER_CMD logs -f "$CONTAINER_NAME"
}

# Function to stop container
stop_container() {
    log_info "Stopping container..."
    $DOCKER_CMD stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
    log_info "Container stopped."
}

# Function to save image for distribution
save_image() {
    local output_file="${1:-agent-zero-model-overrides.tar.gz}"
    log_info "Saving image to: $output_file"
    $DOCKER_CMD save "$IMAGE_NAME" | gzip > "$output_file"
    log_info "Image saved! Size: $(du -h "$output_file" | cut -f1)"
}

# Function to load image
load_image() {
    local input_file="${1:-agent-zero-model-overrides.tar.gz}"
    if [ ! -f "$input_file" ]; then
        log_error "File not found: $input_file"
        exit 1
    fi
    log_info "Loading image from: $input_file"
    gunzip -c "$input_file" | $DOCKER_CMD load
    log_info "Image loaded!"
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    build       Build the Docker image locally
    run         Run the container directly (not via compose)
    compose     Run using docker-compose (recommended)
    stop        Stop the running container
    logs        Show container logs
    save        Save the image to a tar.gz file
    load        Load the image from a tar.gz file
    dev         Run in development mode (mounts files directly)

Options:
    -u, --user USER         Run as specific user (default: current user)
    -p, --port PORT         Host port for web UI (default: 50080)
    -k, --api-key KEY       OpenAI API key
    -a, --anthropic-key KEY Anthropic API key
    -o, --openrouter-key KEY OpenRouter API key
    -h, --help              Show this help message

Examples:
    # Build the image
    $0 build

    # Run with docker-compose
    $0 compose

    # Run directly with custom port
    $0 run -p 8080

    # Run as different user
    sudo -u otheruser $0 compose

    # Save image for sharing
    $0 save /tmp/agent-zero.tar.gz

    # Load image from file
    $0 load /tmp/agent-zero.tar.gz

    # Development mode (no rebuild needed)
    $0 dev

EOF
}

# Parse arguments
COMMAND=""
while [[ $# -gt 0 ]]; do
    case $1 in
        build|run|compose|stop|logs|save|load|dev)
            COMMAND="$1"
            shift
            ;;
        -u|--user)
            RUN_AS_USER="$2"
            shift 2
            ;;
        -p|--port)
            HOST_PORT="$2"
            shift 2
            ;;
        -k|--api-key)
            API_KEY_OPENAI="$2"
            shift 2
            ;;
        -a|--anthropic-key)
            API_KEY_ANTHROPIC="$2"
            shift 2
            ;;
        -o|--openrouter-key)
            API_KEY_OPENROUTER="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            # For save/load commands, remaining arg is the file path
            if [[ "$COMMAND" == "save" || "$COMMAND" == "load" ]]; then
                FILE_ARG="$1"
                shift
            else
                log_error "Unknown option: $1"
                usage
                exit 1
            fi
            ;;
    esac
done

# Check if command is specified
if [ -z "$COMMAND" ]; then
    usage
    exit 1
fi

# Main execution
check_docker

case $COMMAND in
    build)
        build_image
        ;;
    run)
        setup_data_dir
        run_container
        log_info "Use '$0 logs' to view logs"
        ;;
    compose)
        setup_data_dir
        run_compose
        log_info "Use '$COMPOSE_CMD -f $SCRIPT_DIR/docker-compose.local.yml logs -f' to view logs"
        ;;
    stop)
        stop_container
        ;;
    logs)
        show_logs
        ;;
    save)
        save_image "$FILE_ARG"
        ;;
    load)
        load_image "$FILE_ARG"
        ;;
    dev)
        log_info "Starting in development mode..."
        $DOCKER_CMD run -d \
            --name "$CONTAINER_NAME-dev" \
            -v "$SCRIPT_DIR/python/helpers/subagents.py:/a0/python/helpers/subagents.py:ro" \
            -v "$SCRIPT_DIR/python/extensions/agent_init/_15_load_profile_settings.py:/a0/python/extensions/agent_init/_15_load_profile_settings.py:ro" \
            -v "$SCRIPT_DIR/agents:/a0/agents:ro" \
            -v "$SCRIPT_DIR/webui/components/settings/agents:/a0/webui/components/settings/agents:ro" \
            -v "$DATA_DIR:/a0" \
            -p "${HOST_PORT:-50080}:80" \
            agent0ai/agent-zero:latest
        log_info "Development container started!"
        log_info "Changes to local files are reflected immediately (refresh browser)."
        ;;
esac
