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

# Danh sach node IDs
NODE_IDS=(7959383 8284963 37715791 37684726 37655296 37564991 7085509 37566608 37597014 37567111 37567112 37717276 37746469 37566953 37686914 37597357 37687065 37567082 37717255 37717274 37567109 37657605 37597533 37687100 37717277 37717278 37657611 37717279 37657612 37567113 37657614 37717342 37687169 37746571 37687190 37747407 37717373 37657707 37657709 37717376)

TOTAL_NODES=${#NODE_IDS[@]}

# === NHẬP TỪ NGƯỜI DÙNG ===
echo -e "${YELLOW}Nhap thong so:${NC}"
echo ""
echo -e "Tong so node co san: ${GREEN}$TOTAL_NODES${NC} (1 - $TOTAL_NODES)"
echo ""
read -p "Chay tu node so (vi du: 1): " START_NODE
read -p "Den node so (vi du: 10): " END_NODE
echo ""
read -p "Max threads: " MAX_THREADS
read -p "Max difficulty (LARGE/... - bo qua neu khong co): " MAX_DIFF
echo ""

# Validate input
if [ "$START_NODE" -lt 1 ] || [ "$START_NODE" -gt "$TOTAL_NODES" ]; then
    echo -e "${RED}Loi: START_NODE phai tu 1 den $TOTAL_NODES${NC}"
    exit 1
fi

if [ "$END_NODE" -lt "$START_NODE" ] || [ "$END_NODE" -gt "$TOTAL_NODES" ]; then
    echo -e "${RED}Loi: END_NODE phai tu $START_NODE den $TOTAL_NODES${NC}"
    exit 1
fi

NUM_NODES=$((END_NODE - START_NODE + 1))

echo -e "${YELLOW}Cau hinh:${NC}"
echo "  - Path: $NEXUS_PATH"
echo "  - Chay node: $START_NODE -> $END_NODE ($NUM_NODES nodes)"
echo "  - Max threads: $MAX_THREADS"
if [ -z "$MAX_DIFF" ]; then
    echo "  - Max difficulty: (khong dat)"
else
    echo "  - Max difficulty: $MAX_DIFF"
fi
echo ""

read -p "Nhan Enter de bat dau hoac Ctrl+C de huy: " CONFIRM

echo ""
echo -e "${GREEN}Dang khoi dong $NUM_NODES nodes (tu $START_NODE den $END_NODE)...${NC}"
echo ""

# Loop to create screens
count=0
for i in $(seq $START_NODE $END_NODE); do
    count=$((count + 1))
    screen_name="nexus$i"
    node_index=$((i - 1))
    node_id=${NODE_IDS[$node_index]}
    
    echo -e "${GREEN}[$count/$NUM_NODES]${NC} Khoi screen: $screen_name | Node ID: $node_id"
    
    # Build command with optional max-difficulty
    COMMAND="cd $NEXUS_PATH/clients/cli && ./target/release/nexus-network start --max-threads $MAX_THREADS --node-id $node_id"
    
    if [ -n "$MAX_DIFF" ]; then
        COMMAND="$COMMAND --max-difficulty $MAX_DIFF"
    fi
    
    screen -dmS "$screen_name" bash -c "$COMMAND; exec bash"
done

echo ""
echo -e "${YELLOW}Dang kiem tra trang thai...${NC}"
sleep 2
screen -ls

echo ""
echo -e "${GREEN}Da hoan thanh!${NC}"
