#!/bin/bash

set -euo pipefail  # Dừng ngay khi có lỗi

#═══════════════════════════════════════════════════════════
#  NEXUS CLI INSTALLER - ENHANCED VERSION
#═══════════════════════════════════════════════════════════

readonly SCRIPT_VERSION="1.1"
readonly SETUP_FILE="src/session/setup.rs"
readonly BACKUP_FILE="src/session/setup.rs.backup"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log() {
  local level=$1; shift
  case $level in
    INFO)  echo -e "${BLUE}ℹ${NC} $*" ;;
    OK)    echo -e "${GREEN}✓${NC} $*" ;;
    WARN)  echo -e "${YELLOW}⚠${NC} $*" ;;
    ERROR) echo -e "${RED}✗${NC} $*" ;;
  esac
}

header() {
  clear
  echo "═══════════════════════════════════════════════════════════"
  echo "  NEXUS CLI INSTALLER v${SCRIPT_VERSION}"
  echo "  Enhanced with Safety Checks"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
}

#─────────────────────────────────────────────────────────────
# STEP 1: Install System Dependencies
#─────────────────────────────────────────────────────────────
install_system_deps() {
  log INFO "Cài đặt system dependencies..."
  
  sudo apt update || { log ERROR "apt update failed"; exit 1; }
  sudo apt install -y openssh-server screen build-essential pkg-config libssl-dev git || {
    log ERROR "Cài đặt packages thất bại"
    exit 1
  }
  
  sudo systemctl enable --now ssh
  
  log OK "System dependencies đã cài đặt"
}

#─────────────────────────────────────────────────────────────
# STEP 2: Install Rust
#─────────────────────────────────────────────────────────────
install_rust() {
  log INFO "Kiểm tra Rust..."
  
  if command -v rustc &> /dev/null; then
    local rust_version=$(rustc --version)
    log OK "Rust đã có: $rust_version"
    source "$HOME/.cargo/env" 2>/dev/null || true
    return 0
  fi
  
  log INFO "Đang cài đặt Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || {
    log ERROR "Cài đặt Rust thất bại"
    exit 1
  }
  
  source "$HOME/.cargo/env"
  log OK "Rust đã cài đặt: $(rustc --version)"
}

#─────────────────────────────────────────────────────────────
# STEP 3: Clone Repository
#─────────────────────────────────────────────────────────────
clone_repository() {
  log INFO "Clone Nexus CLI repository..."
  
  cd ~
  
  if [ -d "nexus-cli" ]; then
    log WARN "Thư mục nexus-cli đã tồn tại"
    read -p "Xóa và clone lại? (y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      rm -rf nexus-cli
    else
      log INFO "Giữ nguyên repo cũ"
      return 0
    fi
  fi
  
  git clone https://github.com/nexus-xyz/nexus-cli || {
    log ERROR "Clone repository thất bại"
    exit 1
  }
  
  log OK "Repository đã clone"
}

#─────────────────────────────────────────────────────────────
# STEP 4: Modify Setup File (SAFE VERSION)
#─────────────────────────────────────────────────────────────
modify_setup_file() {
  log INFO "Đang chỉnh sửa setup.rs..."
  
  cd ~/nexus-cli/clients/cli
  
  if [ ! -f "$SETUP_FILE" ]; then
    log ERROR "Không tìm thấy $SETUP_FILE"
    exit 1
  fi
  
  # Backup file gốc
  if [ ! -f "$BACKUP_FILE" ]; then
    cp "$SETUP_FILE" "$BACKUP_FILE"
    log OK "Đã backup: $BACKUP_FILE"
  else
    log WARN "Backup đã tồn tại, skip"
  fi
  
  # Modification 1: Change 0.75 -> 1.0
  log INFO "Thay đổi core ratio 0.75 -> 1.0..."
  sed -i 's/0\.75/1.0/g' "$SETUP_FILE"
  
  # Modification 2: Update num_workers declaration
  log INFO "Cập nhật num_workers declaration..."
  
  # Kiểm tra xem dòng cũ có tồn tại không
  if grep -q "let mut num_workers" "$SETUP_FILE"; then
    sed -i 's/let mut num_workers.*/let mut num_workers: usize = max_threads.unwrap_or(1).clamp(1, max_workers as u32) as usize;/g' "$SETUP_FILE"
    log OK "Đã cập nhật num_workers"
  else
    log WARN "Không tìm thấy dòng 'let mut num_workers', skip"
  fi
  
  # Modification 3: Insert override code (only if not exists)
  log INFO "Chèn override logic..."
  
  local OVERRIDE_CODE='    if let Some(mt) = max_threads { num_workers = mt as usize; }'
  
  # Kiểm tra xem code đã được chèn chưa
  if grep -q "if let Some(mt) = max_threads" "$SETUP_FILE"; then
    log WARN "Override code đã tồn tại, skip chèn"
  else
    # Tìm vị trí chèn (trước comment "Additional memory warning")
    if grep -q "// Additional memory warning" "$SETUP_FILE"; then
      sed -i "/\/\/ Additional memory warning/i $OVERRIDE_CODE" "$SETUP_FILE"
      log OK "Đã chèn override code"
    else
      log WARN "Không tìm thấy anchor comment, skip chèn"
    fi
  fi
  
  # Verify changes
  log INFO "Verifying changes..."
  echo ""
  echo "--- Changed lines ---"
  grep -n "1.0" "$SETUP_FILE" | head -3
  grep -n "num_workers" "$SETUP_FILE" | head -5
  echo "---"
  echo ""
  
  log OK "Setup file đã được chỉnh sửa"
}

#─────────────────────────────────────────────────────────────
# STEP 5: Build Project
#─────────────────────────────────────────────────────────────
build_project() {
  log INFO "Đang build project (Release mode)..."
  echo ""
  
  cd ~/nexus-cli/clients/cli
  
  cargo build --release || {
    log ERROR "Build thất bại"
    log INFO "Restore backup với: cp $BACKUP_FILE $SETUP_FILE"
    exit 1
  }
  
  echo ""
  log OK "Build thành công!"
  
  # Show binary info
  if [ -f "target/release/nexus-network" ]; then
    local binary_size=$(du -h target/release/nexus-network | cut -f1)
    log INFO "Binary: target/release/nexus-network ($binary_size)"
  fi
}

#─────────────────────────────────────────────────────────────
# STEP 6: Final Summary
#─────────────────────────────────────────────────────────────
show_summary() {
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "  🎉 CÀI ĐẶT HOÀN TẤT"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
  log OK "Nexus CLI đã sẵn sàng!"
  echo ""
  echo "Thư mục: ~/nexus-cli/clients/cli"
  echo "Binary: ./target/release/nexus-network"
  echo "Backup: $BACKUP_FILE"
  echo ""
  echo "--- Cách chạy ---"
  echo "cd ~/nexus-cli/clients/cli"
  echo "./target/release/nexus-network start --max-threads 25"
  echo ""
  echo "--- Restore backup nếu cần ---"
  echo "cp $BACKUP_FILE $SETUP_FILE"
  echo "cargo build --release"
  echo ""
}

#─────────────────────────────────────────────────────────────
# MAIN
#─────────────────────────────────────────────────────────────
main() {
  header
  
  # Confirmation
  read -p "Tiếp tục cài đặt? (y/n): " confirm
  [[ ! "$confirm" =~ ^[Yy]$ ]] && { log INFO "Đã hủy"; exit 0; }
  
  echo ""
  
  install_system_deps
  echo ""
  
  install_rust
  echo ""
  
  clone_repository
  echo ""
  
  modify_setup_file
  echo ""
  
  build_project
  echo ""
  
  show_summary
}

# Run
main "$@"
