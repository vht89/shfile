#!/bin/bash

# Dừng script nếu có lỗi nghiêm trọng (tùy chọn)
# set -e 

echo "=== BẮT ĐẦU CÀI ĐẶT NEXUS CLI (GIỮ NGUYÊN 4GB) ==="

# --- BƯỚC 3: Cài đặt các gói phụ thuộc và Rust ---
echo ">>> Đang cập nhật hệ thống và cài đặt dependencies..."
sudo apt update && sudo apt install build-essential pkg-config libssl-dev git -y

echo ">>> Đang kiểm tra và cài đặt Rust..."
if ! command -v rustc &> /dev/null; then
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source "$HOME/.cargo/env"
else
    echo "Rust đã được cài đặt."
    source "$HOME/.cargo/env"
fi

# --- BƯỚC 4: Clone repo và build dự án ---
echo ">>> Đang clone repository Nexus CLI..."
cd ~
rm -rf nexus-cli
git clone https://github.com/nexus-xyz/nexus-cli

# Di chuyển vào thư mục cli
cd ~/nexus-cli/clients/cli

# Chỉnh sửa tỷ lệ cores từ 0.75 lên 1.0
echo ">>> Đang sửa cấu hình cơ bản (0.75 -> 1.0)..."
sed -i 's/0\.75/1.0/g' src/session/setup.rs

# --- BƯỚC 5: Tự động chỉnh sửa file setup.rs (Code Logic) ---
echo ">>> Đang chèn code logic cho num_workers..."

TARGET_FILE="src/session/setup.rs"

# 1. Cập nhật dòng khai báo num_workers (ép kiểu đúng logic)
# Tìm dòng 'let mut num_workers' cũ và thay thế bằng dòng mới
sed -i 's/let mut num_workers.*/let mut num_workers: usize = max_threads.unwrap_or(1).clamp(1, max_workers as u32) as usize;/g' "$TARGET_FILE"

# 2. Chèn đoạn code override (max_threads)
# Logic: Chèn đoạn check if let Some(mt)... vào TRƯỚC dòng comment "// Additional memory warning"
# Điều này đảm bảo code nằm đúng vị trí như trong ảnh bạn gửi
OVERRIDE_CODE='if let Some(mt) = max_threads { num_workers = mt as usize; }'

sed -i "/\/\/ Additional memory warning/i $OVERRIDE_CODE" "$TARGET_FILE"

# LƯU Ý: Đã bỏ qua bước sửa 4GB -> 2GB theo yêu cầu mới.

echo ">>> Đã chỉnh sửa xong setup.rs"

# --- BƯỚC 6: Build dự án ---
echo ">>> Đang build dự án (Release mode)..."
cargo build --release

echo "=== CÀI ĐẶT HOÀN TẤT ==="
echo "Bạn có thể chạy node ngay bây giờ."
