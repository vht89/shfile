#!/bin/bash
# PHIÊN BẢN SCRIPT TỐI GIẢN - CHỈ CÀI ĐẶT, KHÔNG CHẠY NODE

# Dừng script ngay lập tức nếu có lệnh nào thất bại
set -e

echo "======================================================"
echo "  Bat dau Script Cai Dat Nexus CLI (Phien ban Toi gian) "
echo "======================================================"
echo ""

# BUOC 1: CAI DAT CAC GOI PHU THUOC
echo "--> Buoc 1: Cai dat cac goi he thong..."
sudo apt-get update
sudo apt-get install -y openssh-server screen build-essential pkg-config libssl-dev git
sudo systemctl enable --now ssh
echo "Hoan tat Buoc 1."
echo ""

# BUOC 2: CAI DAT RUST
echo "--> Buoc 2: Cai dat Rust..."
# Kiem tra xem Rust da co chua
if ! command -v rustc &> /dev/null; then
    # Neu chua co, tien hanh cai dat
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    # Them bien moi truong cua Cargo vao session hien tai
    source "$HOME/.cargo/env"
else
    echo "Rust da duoc cai dat, bo qua buoc nay."
fi
echo "Hoan tat Buoc 2."
echo ""

# BUOC 3: CLONE REPOSITORY
echo "--> Buoc 3: Clone repository Nexus CLI..."
cd ~
# Xoa thu muc cu neu ton tai de dam bao clone moi
if [ -d "nexus-cli" ]; then
    echo "Tim thay thu muc 'nexus-cli' cu, se xoa va clone lai."
    rm -rf nexus-cli
fi
git clone https://github.com/nexus-xyz/nexus-cli.git
echo "Hoan tat Buoc 3."
echo ""

# BUOC 4: CHINH SUA FILE SOURCE (KHONG BACKUP)
echo "--> Buoc 4: Chinh sua file setup.rs..."
SETUP_FILE="$HOME/nexus-cli/clients/cli/src/session/setup.rs"

# Thay doi ti le su dung CPU tu 0.75 thanh 1.0
sed -i '/let max_workers = (num_cpus::get() as f64 \* 0.75)/s/0\.75/1.0/' "$SETUP_FILE"

# Thay doi cach khai bao num_workers
sed -i "/let mut num_workers =/c\\    let mut num_workers: usize = max_threads.unwrap_or(1).clamp(1, max_workers as u32) as usize;" "$SETUP_FILE"

# Them dong logic de ghi de max_threads
sed -i "/\/\/ Additional memory warning/i\\    if let Some(mt) = max_threads { num_workers = mt as usize; }" "$SETUP_FILE"

echo "Da chinh sua file. Khong co backup duoc tao."
echo "Hoan tat Buoc 4."
echo ""

# BUOC 5: BUILD DU AN
echo "--> Buoc 5: Build du an (co the mat vai phut)..."
cd ~/nexus-cli/clients/cli
cargo build --release
echo "Hoan tat Buoc 5."
echo ""

# THONG BAO HOAN TAT
echo "======================================================"
echo "      🎉 CAI DAT VA BUILD HOAN TAT! 🎉"
echo "======================================================"
echo "File thuc thi cua ban da duoc build thanh cong va nam o:"
echo "~/nexus-cli/clients/cli/target/release/nexus-network"
echo ""
echo "Ban co the chay node thu cong khi can."
echo "======================================================"
