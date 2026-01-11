#!/bin/bash

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}   NEXUS NETWORK MULTI-NODE STARTER   ${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# === THÔNG SỐ ===
NEXUS_PATH=~/nexus-cli

# === NHẬP TỪ NGƯỜI DÙNG ===
echo -e "${YELLOW}Nhap thong so:${NC}"
read -p "Max threads: " MAX_THREADS
read -p "Max difficulty (LARGE/...): " MAX_DIFF
echo ""

# Danh sach node IDs
NODE_IDS=(7959383 8284963 37715791 37684726 37655296 37564991 7085509 37566608 37597014 37567111 37567112 37717276 37746469 37566953 37686914 37597357 37687065 37567082 37717255 37717274 37567109 37657605 37597533 37687100 37717277 37717278 37657611 37717279 37657612 37567113 37657614 37717342 37687169 37746571 37687190 37747407 37717373 37657707 37657709 37717376)

NUM_NODES=${#NODE_IDS[@]}

echo -e "${YELLOW}Cau hinh:${NC}"
echo "  - Path: $NEXUS_PATH"
echo "  - So luong node: $NUM_NODES"
echo "  - Max threads: $MAX_THREADS"
echo "  - Max difficulty: $MAX_DIFF"
echo ""

read -p "Nhan Enter de bat dau hoac Ctrl+C de huy: " CONFIRM

echo ""
echo -e "${GREEN}Dang khoi dong $NUM_NODES nodes...${NC}"
echo ""

# Loop to create screens
for i in $(seq 1 $NUM_NODES); do
    screen_name="nexus$i"
    node_index=$((i - 1))
    node_id=${NODE_IDS[$node_index]}
    
    echo -e "${GREEN}[$i/$NUM_NODES]${NC} Khoi screen: $screen_name | Node ID: $node_id"
    
    screen -dmS "$screen_name" bash -c "
        cd $NEXUS_PATH/clients/cli
        ./target/release/nexus-network start --max-threads $MAX_THREADS --node-id $node_id --max-difficulty $MAX_DIFF
        exec bash"
done

echo ""
echo -e "${YELLOW}Dang kiem tra trang thai...${NC}"
sleep 2
screen -ls

echo ""
echo -e "${GREEN}Da hoan thanh!${NC}"
