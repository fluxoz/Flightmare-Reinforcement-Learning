#!/usr/bin/env bash
# Flightmare Nix Build Helper Script
# This script helps users build and run Flightmare using Nix

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║      Flightmare Nix Build Helper                      ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

check_nix() {
    if ! command -v nix &> /dev/null; then
        print_error "Nix is not installed!"
        echo ""
        echo "To install Nix, run:"
        echo "  curl -L https://nixos.org/nix/install | sh -s -- --daemon"
        echo ""
        echo "Or on NixOS, it's already available."
        exit 1
    fi
    print_success "Nix is installed"
}

check_flakes() {
    if ! nix flake metadata &> /dev/null; then
        print_error "Nix flakes are not enabled!"
        echo ""
        echo "To enable flakes, add this to your /etc/nix/nix.conf or ~/.config/nix/nix.conf:"
        echo "  experimental-features = nix-command flakes"
        echo ""
        echo "Then restart the nix-daemon:"
        echo "  sudo systemctl restart nix-daemon  # On NixOS"
        exit 1
    fi
    print_success "Nix flakes are enabled"
}

show_help() {
    print_header
    echo "Usage: ./nix-build.sh [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  check      - Check if Nix and flakes are properly configured"
    echo "  build      - Build the Flightmare packages"
    echo "  shell      - Enter a development shell"
    echo "  run        - Run Python with Flightmare installed"
    echo "  train      - Run a quick training example"
    echo "  test       - Validate installation (runs validate_install.py)"
    echo "  update     - Update flake.lock"
    echo "  clean      - Remove build artifacts (result symlinks)"
    echo "  help       - Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./nix-build.sh check         # Verify Nix setup"
    echo "  ./nix-build.sh build         # Build everything"
    echo "  ./nix-build.sh shell         # Enter dev environment"
    echo "  ./nix-build.sh test          # Test imports"
    echo ""
}

cmd_check() {
    print_header
    echo "Checking Nix configuration..."
    echo ""
    check_nix
    check_flakes
    echo ""
    print_success "All checks passed! Ready to build."
}

cmd_build() {
    print_header
    check_nix
    check_flakes
    echo ""
    print_info "Building Flightmare..."
    nix build --print-build-logs
    print_success "Build complete!"
    echo ""
    echo "Result is available at: ./result"
}

cmd_shell() {
    print_header
    check_nix
    check_flakes
    echo ""
    print_info "Entering development shell..."
    echo ""
    nix develop
}

cmd_run() {
    print_header
    check_nix
    check_flakes
    echo ""
    print_info "Running Python with Flightmare..."
    nix run
}

cmd_train() {
    print_header
    check_nix
    check_flakes
    echo ""
    print_info "Running training example..."
    nix run .#train -- --timesteps 1000
}

cmd_test() {
    print_header
    check_nix
    check_flakes
    echo ""
    print_info "Testing package imports..."
    echo ""
    
    nix develop --command python ./validate_install.py
    
    if [ $? -eq 0 ]; then
        echo ""
        print_success "All validation tests passed!"
    else
        echo ""
        print_error "Some validation tests failed."
        exit 1
    fi
}

cmd_update() {
    print_header
    check_nix
    check_flakes
    echo ""
    print_info "Updating flake.lock..."
    nix flake update
    print_success "Flake updated!"
}

cmd_clean() {
    print_header
    echo "Cleaning build artifacts..."
    rm -f result result-*
    print_success "Cleaned!"
}

# Main command dispatcher
case "${1:-help}" in
    check)
        cmd_check
        ;;
    build)
        cmd_build
        ;;
    shell)
        cmd_shell
        ;;
    run)
        cmd_run
        ;;
    train)
        cmd_train
        ;;
    test)
        cmd_test
        ;;
    update)
        cmd_update
        ;;
    clean)
        cmd_clean
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
