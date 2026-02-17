#!/bin/bash

# ===================================
# NEXUS NETWORK - AUTO SETUP & RUN
# ===================================

set -e  # Dừng nếu có lỗi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configs
NODE_ID="7959383"
MAX_THREADS="12"
DIFFICULTY="extra_large_5"
NEXUS_HOME="$HOME/nexus-cli"
CLI_PATH="$NEXUS_HOME/clients/cli"
BINARY_PATH="$CLI_PATH/target/release/nexus-network"
REPO_URL="https://github.com/nexus-xyz/nexus-cli.git"

# ===================================
# FUNCTIONS
# ===================================

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Kiểm tra và cài Git
check_git() {
    if ! command -v git &> /dev/null; then
        log_warning "Git chưa được cài đặt!"
        log_info "Đang cài Git..."
        
        if [ -f /etc/debian_version ]; then
            sudo apt update && sudo apt install -y git
        elif [ -f /etc/redhat-release ]; then
            sudo yum install -y git
        else
            log_error "Không thể tự động cài Git. Vui lòng cài thủ công!"
            exit 1
        fi
        
        log_success "Đã cài Git: $(git --version)"
    else
        log_success "Git đã sẵn sàng: $(git --version)"
    fi
}

# Kiểm tra và clone repo
check_repo() {
    if [ ! -d "$NEXUS_HOME" ]; then
        log_warning "Chưa có repo Nexus!"
        log_info "Đang clone từ GitHub..."
        
        git clone "$REPO_URL" "$NEXUS_HOME"
        
        if [ -d "$NEXUS_HOME" ]; then
            log_success "Clone repo thành công!"
        else
            log_error "Clone repo thất bại!"
            exit 1
        fi
    else
        log_success "Repo đã tồn tại"
        
        # Hỏi có muốn update không
        read -p "$(echo -e ${YELLOW}Bạn có muốn cập nhật repo không? [y/N]: ${NC})" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Đang cập nhật repo..."
            cd "$NEXUS_HOME"
            git pull
            log_success "Cập nhật xong!"
        fi
    fi
}

# Kiểm tra và cài Rust
check_rust() {
    if ! command -v cargo &> /dev/null; then
        log_warning "Cargo chưa được cài đặt!"
        log_info "Đang cài Rust & Cargo..."
        
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
        
        if command -v cargo &> /dev/null; then
            log_success "Đã cài Rust thành công: $(cargo --version)"
        else
            log_error "Cài Rust thất bại!"
            exit 1
        fi
    else
        log_success "Rust đã sẵn sàng: $(cargo --version)"
    fi
}

# Kiểm tra và build binary
check_binary() {
    if [ ! -f "$BINARY_PATH" ]; then
        log_warning "Binary chưa được build!"
        log_info "Đang build Nexus Network... (có thể mất 5-10 phút)"
        
        cd "$CLI_PATH"
        cargo build --release
        
        if [ -f "$BINARY_PATH" ]; then
            log_success "Build thành công!"
        else
            log_error "Build thất bại!"
            exit 1
        fi
    else
        log_success "Binary đã sẵn sàng"
    fi
}

# Chạy node
run_node() {
    log_info "Đang khởi động Nexus Network..."
    log_info "Node ID: $NODE_ID | Threads: $MAX_THREADS | Difficulty: $DIFFICULTY"
    echo ""
    
    "$BINARY_PATH" start \
        --max-threads "$MAX_THREADS" \
        --node-id "$NODE_ID" \
        --max-difficulty "$DIFFICULTY"
}

# ===================================
# MAIN
# ===================================

main() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}   NEXUS NETWORK - AUTO LAUNCHER${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # 1. Kiểm tra Git
    check_git
    
    # 2. Kiểm tra & Clone Repo
    check_repo
    
    # 3. Kiểm tra Rust
    check_rust
    
    # 4. Kiểm tra Binary
    check_binary
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}   BẮT ĐẦU CHẠY NODE${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # 5. Chạy Node
    run_node
}

# Chạy main
main
