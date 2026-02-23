#!/usr/bin/env bash
#
# IronClaw Local-First Setup Script
# ==================================
# This script helps you set up IronClaw to run entirely locally
# without any cloud accounts or external dependencies.
#
# Usage:
#   ./local-first-setup.sh [OPTIONS]
#
# Options:
#   --backend=BACKEND   Choose backend: ollama, lmstudio, vllm, litellm (default: auto-detect)
#   --skip-model-pull   Skip pulling Ollama models
#   --skip-db-setup     Skip PostgreSQL setup
#   --help              Show this help message
#
# Repository: https://github.com/nearai/ironclaw
# License: MIT

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Default values
BACKEND="auto"
SKIP_MODEL_PULL=false
SKIP_DB_SETUP=false
IRONCLAW_CONFIG_DIR="${HOME}/.ironclaw"
ENV_FILE="${IRONCLAW_CONFIG_DIR}/.env"

# Recommended models
OLLAMA_CHAT_MODEL="llama3.2"
OLLAMA_EMBED_MODEL="nomic-embed-text"

#------------------------------------------------------------------------------
# Utility Functions
#------------------------------------------------------------------------------

print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║   ██╗██████╗  ██████╗ ███╗   ██╗ ██████╗██╗      █████╗ ██╗    ║"
    echo "║   ██║██╔══██╗██╔═══██╗████╗  ██║██╔════╝██║     ██╔══██╗██║    ║"
    echo "║   ██║██████╔╝██║   ██║██╔██╗ ██║██║     ██║     ███████║██║ ██║   ║"
    echo "║   ██║██╔══██╗██║   ██║██║╚██╗██║██║     ██║     ██╔══██║╚██╗██╔╝   ║"
    echo "║   ██║██║  ██║╚██████╔╝██║ ╚████║╚██████╗███████╗██║  ██║ ╚███╔╝    ║"
    echo "║   ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚══════╝╚═╝  ╚═╝  ╚══╝     ║"
    echo "║                                                                  ║"
    echo "║               LOCAL-FIRST SETUP SCRIPT                          ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_info() {
    echo -e "${BLUE}ℹ${NC}  $1"
}

print_success() {
    echo -e "${GREEN}✓${NC}  $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

print_error() {
    echo -e "${RED}✗${NC}  $1"
}

print_step() {
    echo -e "${CYAN}➤${NC}  $1"
}

#------------------------------------------------------------------------------
# OS Detection
#------------------------------------------------------------------------------

detect_os() {
    print_section "Detecting Operating System"
    
    OS="unknown"
    ARCH=$(uname -m)
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if grep -q Microsoft /proc/version 2>/dev/null; then
            OS="wsl"
            print_info "Detected: Windows Subsystem for Linux (WSL)"
        else
            OS="linux"
            print_info "Detected: Linux"
        fi
        
        # Detect distro
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            DISTRO=$ID
            print_info "Distribution: $NAME"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        print_info "Detected: macOS"
    else
        print_warning "Unknown OS: $OSTYPE"
        print_warning "This script supports Linux, macOS, and Windows WSL"
    fi
    
    print_info "Architecture: $ARCH"
    echo ""
}

#------------------------------------------------------------------------------
# Dependency Checks
#------------------------------------------------------------------------------

check_rust() {
    print_step "Checking for Rust..."
    if command -v cargo &> /dev/null; then
        RUST_VERSION=$(rustc --version | cut -d' ' -f2)
        print_success "Rust found: $RUST_VERSION"
        return 0
    else
        print_warning "Rust not found"
        return 1
    fi
}

check_postgres() {
    print_step "Checking for PostgreSQL..."
    if command -v psql &> /dev/null; then
        PG_VERSION=$(psql --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
        print_success "PostgreSQL found: $PG_VERSION"
        return 0
    else
        print_warning "PostgreSQL not found"
        return 1
    fi
}

check_ollama() {
    print_step "Checking for Ollama..."
    if command -v ollama &> /dev/null; then
        print_success "Ollama found"
        # Check if running
        if curl -s http://localhost:11434/api/tags &> /dev/null; then
            print_success "Ollama server is running"
            return 0
        else
            print_warning "Ollama installed but server not running"
            return 2
        fi
    else
        print_warning "Ollama not found"
        return 1
    fi
}

check_pgvector() {
    print_step "Checking for pgvector extension..."
    if psql -d postgres -c "SELECT 1 FROM pg_available_extensions WHERE name = 'vector';" 2>/dev/null | grep -q "1"; then
        print_success "pgvector extension available"
        return 0
    else
        print_warning "pgvector extension not found"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Installation Functions
#------------------------------------------------------------------------------

install_ollama() {
    print_section "Installing Ollama"
    
    if command -v ollama &> /dev/null; then
        print_info "Ollama is already installed"
        return 0
    fi
    
    print_step "Installing Ollama..."
    
    case "$OS" in
        linux|wsl)
            curl -fsSL https://ollama.com/install.sh | sh
            ;;
        macos)
            if command -v brew &> /dev/null; then
                brew install ollama
            else
                print_info "Installing via curl (Homebrew not found)..."
                curl -fsSL https://ollama.com/install.sh | sh
            fi
            ;;
        *)
            print_error "Please install Ollama manually from: https://ollama.com/download"
            return 1
            ;;
    esac
    
    print_success "Ollama installed successfully"
}

start_ollama() {
    print_step "Starting Ollama server..."
    
    # Check if already running
    if curl -s http://localhost:11434/api/tags &> /dev/null; then
        print_success "Ollama server already running"
        return 0
    fi
    
    # Start in background
    case "$OS" in
        linux|wsl)
            nohup ollama serve > /dev/null 2>&1 &
            ;;
        macos)
            if command -v brew &> /dev/null && brew services list | grep -q ollama; then
                brew services start ollama
            else
                nohup ollama serve > /dev/null 2>&1 &
            fi
            ;;
    esac
    
    # Wait for server to start
    print_info "Waiting for Ollama server to start..."
    for i in {1..30}; do
        if curl -s http://localhost:11434/api/tags &> /dev/null; then
            print_success "Ollama server started"
            return 0
        fi
        sleep 1
    done
    
    print_error "Ollama server failed to start"
    return 1
}

pull_ollama_models() {
    print_section "Pulling Ollama Models"
    
    if [ "$SKIP_MODEL_PULL" = true ]; then
        print_info "Skipping model pull (--skip-model-pull)"
        return 0
    fi
    
    print_step "Pulling chat model: $OLLAMA_CHAT_MODEL"
    ollama pull "$OLLAMA_CHAT_MODEL"
    print_success "Pulled $OLLAMA_CHAT_MODEL"
    
    print_step "Pulling embedding model: $OLLAMA_EMBED_MODEL"
    ollama pull "$OLLAMA_EMBED_MODEL"
    print_success "Pulled $OLLAMA_EMBED_MODEL"
    
    echo ""
    print_info "Available models:"
    ollama list
}

#------------------------------------------------------------------------------
# Database Setup
#------------------------------------------------------------------------------

setup_postgres() {
    print_section "PostgreSQL Setup"
    
    if [ "$SKIP_DB_SETUP" = true ]; then
        print_info "Skipping database setup (--skip-db-setup)"
        return 0
    fi
    
    # Check if ironclaw database exists
    if psql -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw ironclaw; then
        print_info "Database 'ironclaw' already exists"
    else
        print_step "Creating database 'ironclaw'..."
        createdb ironclaw 2>/dev/null || {
            print_warning "Could not create database. You may need to create it manually:"
            print_info "  sudo -u postgres createdb ironclaw"
            print_info "  OR: createdb ironclaw"
        }
    fi
    
    # Enable pgvector extension
    print_step "Enabling pgvector extension..."
    psql -d ironclaw -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null || {
        print_warning "Could not enable pgvector. You may need to install it first:"
        case "$OS" in
            linux)
                print_info "  Ubuntu/Debian: sudo apt install postgresql-15-pgvector"
                print_info "  OR build from source: https://github.com/pgvector/pgvector"
                ;;
            macos)
                print_info "  brew install pgvector"
                ;;
        esac
    }
    
    # Verify
    if psql -d ironclaw -c "SELECT extname FROM pg_extension WHERE extname = 'vector';" 2>/dev/null | grep -q vector; then
        print_success "pgvector extension enabled"
    else
        print_warning "pgvector verification failed - semantic search may not work"
    fi
}

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------

select_backend() {
    print_section "Select LLM Backend"
    
    if [ "$BACKEND" != "auto" ]; then
        print_info "Using specified backend: $BACKEND"
        return 0
    fi
    
    echo "Choose your preferred LLM backend:"
    echo ""
    echo "  ${GREEN}1)${NC} Ollama       - Easy local inference (recommended)"
    echo "  ${BLUE}2)${NC} LM Studio    - Local GUI with server mode"
    echo "  ${CYAN}3)${NC} vLLM         - High-performance inference server"
    echo "  ${YELLOW}4)${NC} LiteLLM      - Unified proxy for multiple backends"
    echo ""
    
    read -p "Select option [1-4, default=1]: " choice
    
    case "$choice" in
        1|"") BACKEND="ollama" ;;
        2) BACKEND="lmstudio" ;;
        3) BACKEND="vllm" ;;
        4) BACKEND="litellm" ;;
        *) BACKEND="ollama" ;;
    esac
    
    print_info "Selected backend: $BACKEND"
}

create_env_file() {
    print_section "Creating Configuration"
    
    # Create config directory
    mkdir -p "$IRONCLAW_CONFIG_DIR"
    
    # Backup existing .env if present
    if [ -f "$ENV_FILE" ]; then
        cp "$ENV_FILE" "${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        print_info "Backed up existing .env file"
    fi
    
    print_step "Creating $ENV_FILE"
    
    case "$BACKEND" in
        ollama)
            cat > "$ENV_FILE" << EOF
# IronClaw Local-First Configuration
# Generated by local-first-setup.sh on $(date)
# Backend: Ollama

# ─────────────────────────────────────────────────────────────────
# LLM Backend Configuration
# ─────────────────────────────────────────────────────────────────
LLM_BACKEND=ollama
OLLAMA_MODEL=$OLLAMA_CHAT_MODEL
OLLAMA_BASE_URL=http://localhost:11434

# ─────────────────────────────────────────────────────────────────
# Embeddings Configuration (for semantic search)
# ─────────────────────────────────────────────────────────────────
EMBEDDINGS_PROVIDER=ollama
EMBEDDINGS_MODEL=$OLLAMA_EMBED_MODEL

# ─────────────────────────────────────────────────────────────────
# Database Configuration
# ─────────────────────────────────────────────────────────────────
DATABASE_URL=postgres://localhost/ironclaw
DATABASE_POOL_SIZE=10

# ─────────────────────────────────────────────────────────────────
# Optional: Logging (uncomment for debugging)
# ─────────────────────────────────────────────────────────────────
# RUST_LOG=ironclaw=debug
EOF
            ;;
            
        lmstudio)
            cat > "$ENV_FILE" << EOF
# IronClaw Local-First Configuration
# Generated by local-first-setup.sh on $(date)
# Backend: LM Studio

# ─────────────────────────────────────────────────────────────────
# LLM Backend Configuration
# ─────────────────────────────────────────────────────────────────
LLM_BACKEND=openai_compatible
LLM_BASE_URL=http://localhost:1234/v1
LLM_MODEL=your-loaded-model
# LLM_API_KEY not needed for LM Studio

# ─────────────────────────────────────────────────────────────────
# Database Configuration
# ─────────────────────────────────────────────────────────────────
DATABASE_URL=postgres://localhost/ironclaw
DATABASE_POOL_SIZE=10

# ─────────────────────────────────────────────────────────────────
# NOTE: Start LM Studio and load a model before running IronClaw
# Go to "Local Server" tab and click "Start Server"
# ─────────────────────────────────────────────────────────────────
EOF
            ;;
            
        vllm)
            cat > "$ENV_FILE" << EOF
# IronClaw Local-First Configuration
# Generated by local-first-setup.sh on $(date)
# Backend: vLLM

# ─────────────────────────────────────────────────────────────────
# LLM Backend Configuration
# ─────────────────────────────────────────────────────────────────
LLM_BACKEND=openai_compatible
LLM_BASE_URL=http://localhost:8000/v1
LLM_MODEL=meta-llama/Llama-3.1-8B-Instruct
LLM_API_KEY=not-needed

# ─────────────────────────────────────────────────────────────────
# Database Configuration
# ─────────────────────────────────────────────────────────────────
DATABASE_URL=postgres://localhost/ironclaw
DATABASE_POOL_SIZE=10

# ─────────────────────────────────────────────────────────────────
# Start vLLM server with:
# python -m vllm.entrypoints.openai.api_server \\
#     --model meta-llama/Llama-3.1-8B-Instruct --port 8000
# ─────────────────────────────────────────────────────────────────
EOF
            ;;
            
        litellm)
            cat > "$ENV_FILE" << EOF
# IronClaw Local-First Configuration
# Generated by local-first-setup.sh on $(date)
# Backend: LiteLLM

# ─────────────────────────────────────────────────────────────────
# LLM Backend Configuration
# ─────────────────────────────────────────────────────────────────
LLM_BACKEND=openai_compatible
LLM_BASE_URL=http://localhost:4000/v1
LLM_MODEL=gpt-3.5-turbo
LLM_API_KEY=not-needed

# ─────────────────────────────────────────────────────────────────
# Database Configuration
# ─────────────────────────────────────────────────────────────────
DATABASE_URL=postgres://localhost/ironclaw
DATABASE_POOL_SIZE=10

# ─────────────────────────────────────────────────────────────────
# Start LiteLLM proxy with:
# litellm --config litellm_config.yaml --port 4000
# ─────────────────────────────────────────────────────────────────
EOF
            ;;
    esac
    
    print_success "Configuration saved to $ENV_FILE"
}

#------------------------------------------------------------------------------
# Final Steps
#------------------------------------------------------------------------------

print_next_steps() {
    print_section "Setup Complete! 🎉"
    
    echo -e "${GREEN}IronClaw is configured for local-first operation.${NC}"
    echo ""
    
    case "$BACKEND" in
        ollama)
            echo -e "${BOLD}Your setup:${NC}"
            echo "  • Backend:    Ollama"
            echo "  • Chat model: $OLLAMA_CHAT_MODEL"
            echo "  • Embeddings: $OLLAMA_EMBED_MODEL"
            echo "  • Database:   PostgreSQL (ironclaw)"
            ;;
        lmstudio)
            echo -e "${BOLD}Your setup:${NC}"
            echo "  • Backend: LM Studio (OpenAI-compatible)"
            echo "  • Database: PostgreSQL (ironclaw)"
            echo ""
            echo -e "${YELLOW}Before running IronClaw:${NC}"
            echo "  1. Open LM Studio"
            echo "  2. Download and load a model"
            echo "  3. Go to 'Local Server' tab"
            echo "  4. Click 'Start Server'"
            ;;
        vllm)
            echo -e "${BOLD}Your setup:${NC}"
            echo "  • Backend: vLLM"
            echo "  • Database: PostgreSQL (ironclaw)"
            echo ""
            echo -e "${YELLOW}Before running IronClaw:${NC}"
            echo "  pip install vllm"
            echo "  python -m vllm.entrypoints.openai.api_server \\"
            echo "      --model meta-llama/Llama-3.1-8B-Instruct --port 8000"
            ;;
        litellm)
            echo -e "${BOLD}Your setup:${NC}"
            echo "  • Backend: LiteLLM proxy"
            echo "  • Database: PostgreSQL (ironclaw)"
            echo ""
            echo -e "${YELLOW}Before running IronClaw:${NC}"
            echo "  pip install litellm[proxy]"
            echo "  litellm --config litellm_config.yaml --port 4000"
            ;;
    esac
    
    echo ""
    echo -e "${BOLD}Run IronClaw:${NC}"
    echo ""
    echo "  cd $(pwd)"
    echo "  cargo run -- --no-onboard"
    echo ""
    echo -e "${BOLD}Or with debug logging:${NC}"
    echo ""
    echo "  RUST_LOG=ironclaw=debug cargo run"
    echo ""
    echo "─────────────────────────────────────────────────────────────────"
    echo -e "${CYAN}Configuration file:${NC} $ENV_FILE"
    echo -e "${CYAN}Documentation:${NC}      LOCAL_FIRST_SETUP.md"
    echo "─────────────────────────────────────────────────────────────────"
    echo ""
    echo -e "${GREEN}No cloud account required. Your data stays local! 🔒${NC}"
    echo ""
}

show_help() {
    echo "IronClaw Local-First Setup Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --backend=BACKEND   Choose backend: ollama, lmstudio, vllm, litellm"
    echo "                      (default: auto-detect/interactive)"
    echo "  --skip-model-pull   Skip pulling Ollama models"
    echo "  --skip-db-setup     Skip PostgreSQL database setup"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                           # Interactive setup"
    echo "  $0 --backend=ollama          # Quick Ollama setup"
    echo "  $0 --backend=lmstudio        # Configure for LM Studio"
    echo "  $0 --skip-model-pull         # Skip downloading models"
    echo ""
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {
    # Parse arguments
    for arg in "$@"; do
        case $arg in
            --backend=*)
                BACKEND="${arg#*=}"
                ;;
            --skip-model-pull)
                SKIP_MODEL_PULL=true
                ;;
            --skip-db-setup)
                SKIP_DB_SETUP=true
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $arg"
                show_help
                exit 1
                ;;
        esac
    done
    
    print_banner
    
    # Step 1: Detect OS
    detect_os
    
    # Step 2: Check dependencies
    print_section "Checking Dependencies"
    check_rust || print_warning "Install Rust from https://rustup.rs"
    check_postgres || print_warning "Install PostgreSQL for database support"
    
    # Step 3: Select backend
    select_backend
    
    # Step 4: Install/setup based on backend
    if [ "$BACKEND" = "ollama" ]; then
        install_ollama
        start_ollama
        pull_ollama_models
    fi
    
    # Step 5: Database setup
    if ! [ "$SKIP_DB_SETUP" = true ]; then
        if check_postgres; then
            setup_postgres
        fi
    fi
    
    # Step 6: Create configuration
    create_env_file
    
    # Step 7: Show next steps
    print_next_steps
}

# Run main
main "$@"
