#!/bin/bash

#═══════════════════════════════════════════════════════════
#  NEXUS CLI INSTALLER - INSTALL ONLY
#═══════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Paths
INSTALL_DIR="$HOME/nexus-cli"
CLI_DIR="$INSTALL_DIR/clients/cli"
SETUP_FILE="$CLI_DIR/src/session/setup.rs"

print_header() {
    clear
    echo -e "${BOLD}═══════════════════════════════════════════${NC}"
    echo -e "${BOLD}  🔧 NEXUS CLI INSTALLER${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}▶${NC} ${BOLD}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

#─────────────────────────────────────────────────────────────
# STEP 1: Install Dependencies
#─────────────────────────────────────────────────────────────
install_deps() {
    print_step "[1/5] Installing dependencies..."
    
    sudo apt update -qq
    sudo apt install -y \
        build-essential \
        pkg-config \
        libssl-dev \
        git \
        curl \
        > /dev/null 2>&1
    
    print_success "Dependencies installed"
}

#─────────────────────────────────────────────────────────────
# STEP 2: Install Rust
#─────────────────────────────────────────────────────────────
install_rust() {
    print_step "[2/5] Installing Rust..."
    
    if command -v cargo &> /dev/null; then
        print_success "Rust already installed"
        source "$HOME/.cargo/env"
        return
    fi
    
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    
    print_success "Rust installed"
}

#─────────────────────────────────────────────────────────────
# STEP 3: Clone Repository
#─────────────────────────────────────────────────────────────
clone_repo() {
    print_step "[3/5] Cloning repository..."
    
    cd "$HOME"
    
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Removing old directory...${NC}"
        rm -rf "$INSTALL_DIR"
    fi
    
    git clone https://github.com/nexus-xyz/nexus-cli "$INSTALL_DIR" > /dev/null 2>&1
    
    print_success "Repository cloned"
}

#─────────────────────────────────────────────────────────────
# STEP 4: Modify Setup File
#─────────────────────────────────────────────────────────────
modify_setup() {
    print_step "[4/5] Modifying setup.rs..."
    
    cd "$CLI_DIR"
    
    # Change 0.75 -> 1.0
    sed -i 's/0\.75/1.0/g' "$SETUP_FILE"
    
    # Update num_workers line
    sed -i '/let mut num_workers/c\    let mut num_workers: usize = max_threads.unwrap_or(1).clamp(1, max_workers as u32) as usize;' "$SETUP_FILE"
    
    # Add override logic
    sed -i '/println!.*Warning/i\    if let Some(mt) = max_threads { num_workers = mt as usize; }\n' "$SETUP_FILE"
    
    print_success "Setup.rs modified"
}

#─────────────────────────────────────────────────────────────
# STEP 5: Build Project
#─────────────────────────────────────────────────────────────
build_project() {
    print_step "[5/5] Building project (10-15 minutes)..."
    
    cd "$CLI_DIR"
    
    cargo build --release
    
    print_success "Build completed"
}

#─────────────────────────────────────────────────────────────
# Show Summary
#─────────────────────────────────────────────────────────────
show_summary() {
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════${NC}"
    echo -e "${BOLD}  ✅ CÀI ĐẶT HOÀN TẤT!${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BOLD}📍 Location:${NC} $CLI_DIR"
    echo ""
    echo -e "${YELLOW}Muốn chạy node sau, dùng lệnh:${NC}"
    echo -e "   ${GREEN}cd $CLI_DIR${NC}"
    echo -e "   ${GREEN}./target/release/nexus-network start --max-threads 25${NC}"
    echo ""
}

#─────────────────────────────────────────────────────────────
# MAIN
#─────────────────────────────────────────────────────────────
main() {
    print_header
    
    echo -e "${YELLOW}Cài đặt Nexus CLI (~15 phút)${NC}"
    read -p "Tiếp tục? (y/n): " confirm
    [[ ! "$confirm" =~ ^[Yy]$ ]] && exit 0
    echo ""
    
    install_deps
    install_rust
    clone_repo
    modify_setup
    build_project
    
    show_summary
}

main
