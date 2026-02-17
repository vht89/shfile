#!/usr/bin/env bash
# nexus.sh — Script tự động build & chạy Nexus node
# Cập nhật: 16-Feb-2026
set -euo pipefail

# ================================
#  CÀI ĐẶT BIẾN CỘNG ĐỒNG
# ================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Kiểm tra Cargo.toml
[[ -f "Cargo.toml" ]] || {
    echo -e "\e[31m❌ LỖI:\e[0m Không tìm thấy file Cargo.toml trong $(pwd)"
    exit 1
}

# ================================
#  CÀI RUST NẾU CHƯA CÓ
# ================================
if ! command -v cargo &>/dev/null; then
    echo -e "\e[33m⚙️  Rust chưa được cài đặt. Đang cài tự động...\e[0m"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    echo -e "\e[32m✅ Rust đã được cài đặt!\e[0m"
fi

# ================================
#  XÁC ĐỊNH TÊN BINARY TỪ Cargo.toml
# ================================
BINARY_NAME=$(grep '^name =' Cargo.toml | cut -d '"' -f 2)

[[ -n "$BINARY_NAME" ]] || {
    echo -e "\e[31m❌ LỖI:\e[0m Không thể đọc tên binary từ Cargo.toml!"
    exit 1
}

# ================================
#  BUILD DỰ ÁN
# ================================
echo -e "\e[34m🔨 Đang build $BINARY_NAME (release mode)...\e[0m"
cargo clean
cargo build --release > /dev/null 2>&1

# Kiểm tra file binary đã build
if [[ ! -f "target/release/$BINARY_NAME" ]]; then
    echo -e "\e[31m❌ LỖI:\e[0m Build thất bại! Không tìm thấy: target/release/$BINARY_NAME"
    exit 1
fi

echo -e "\e[32m✅ Build thành công!\e[0m"

# ================================
#  CHẠY NODE
# ================================
echo -e "\e[35m🚀 Khởi động $BINARY_NAME với tham số: $*\e[0m"
exec "./target/release/$BINARY_NAME" "$@"
