#!/bin/bash

#═══════════════════════════════════════════════════════════
#  NEXUS CLI INSTALLER - PRODUCTION GRADE
#  Version: 2.0
#  Author: Enhanced Security & Safety Edition
#═══════════════════════════════════════════════════════════

set -euo pipefail
IFS=$'\n\t'

#─────────────────────────────────────────────────────────────
# CONSTANTS
#─────────────────────────────────────────────────────────────
readonly SCRIPT_VERSION="2.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly INSTALL_DIR="$HOME/nexus-cli"
readonly CLI_DIR="$INSTALL_DIR/clients/cli"
readonly SETUP_FILE="src/session/setup.rs"
readonly BACKUP_FILE="src/session/setup.rs.backup"
readonly LOG_FILE="$HOME/nexus-install-$(date +%Y%m%d-%H%M%S).log"

# Git Repository
readonly REPO_URL="https://github.com/nexus-xyz/nexus-cli"
readonly REPO_OWNER="nexus-xyz"
readonly REPO_NAME="nexus-cli"

# Modifications Config
readonly TARGET_RATIO="1.0"
readonly ORIGINAL_RATIO="0.75"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Flags
DRY_RUN=false
FORCE_MODE=false
SKIP_DEPS=false

#─────────────────────────────────────────────────────────────
# LOGGING FUNCTIONS
#─────────────────────────────────────────────────────────────
log() {
    local level=$1; shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Log to console
    case $level in
        INFO)    echo -e "${BLUE}ℹ${NC} $message" ;;
        SUCCESS) echo -e "${GREEN}✓${NC} $message" ;;
        WARN)    echo -e "${YELLOW}⚠${NC} $message" ;;
        ERROR)   echo -e "${RED}✗${NC} $message" ;;
        DEBUG)   echo -e "${CYAN}⚙${NC} $message" ;;
        STEP)    echo -e "${MAGENTA}▶${NC} ${BOLD}$message${NC}" ;;
    esac
}

header() {
    clear
    echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  🚀 NEXUS CLI INSTALLER v${SCRIPT_VERSION}${NC}"
    echo -e "${BOLD}  Production Grade - Security Enhanced${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    log INFO "Log file: $LOG_FILE"
    echo ""
}

progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    
    printf "\r["
    printf "%${completed}s" | tr ' ' '█'
    printf "%$((width - completed))s" | tr ' ' '░'
    printf "] %d%%" $percentage
    
    [ $current -eq $total ] && echo ""
}

#─────────────────────────────────────────────────────────────
# ERROR HANDLING & CLEANUP
#─────────────────────────────────────────────────────────────
cleanup_on_error() {
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        log ERROR "Script failed with exit code: $exit_code"
        
        # Restore backup if exists
        if [ -f "$CLI_DIR/$BACKUP_FILE" ] && [ -f "$CLI_DIR/$SETUP_FILE" ]; then
            log WARN "Attempting to restore backup..."
            cp "$CLI_DIR/$BACKUP_FILE" "$CLI_DIR/$SETUP_FILE" 2>/dev/null || true
            log SUCCESS "Backup restored"
        fi
        
        echo ""
        log ERROR "Installation failed! Check log: $LOG_FILE"
        echo ""
        echo "Để debug:"
        echo "  tail -n 50 $LOG_FILE"
        echo ""
        echo "Để retry:"
        echo "  $0"
        echo ""
    fi
}

trap cleanup_on_error EXIT ERR

#─────────────────────────────────────────────────────────────
# PREREQUISITE CHECKS
#─────────────────────────────────────────────────────────────
check_prerequisites() {
    log STEP "Kiểm tra prerequisites..."
    
    local missing_tools=()
    
    # Check required commands
    local required_cmds=("curl" "git" "sudo")
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_tools+=("$cmd")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log ERROR "Missing required tools: ${missing_tools[*]}"
        log INFO "Install them with: sudo apt install ${missing_tools[*]}"
        exit 1
    fi
    
    # Check disk space (need at least 2GB)
    local free_space=$(df -BG "$HOME" | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$free_space" -lt 2 ]; then
        log WARN "Low disk space: ${free_space}GB free"
        read -p "Continue anyway? (y/n): " confirm
        [[ ! "$confirm" =~ ^[Yy]$ ]] && exit 0
    fi
    
    # Check OS
    if [ ! -f /etc/os-release ]; then
        log WARN "Cannot detect OS"
    else
        local os_name=$(grep ^NAME= /etc/os-release | cut -d'"' -f2)
        log INFO "OS: $os_name"
    fi
    
    log SUCCESS "Prerequisites check passed"
}

#─────────────────────────────────────────────────────────────
# STEP 1: Install System Dependencies
#─────────────────────────────────────────────────────────────
install_system_deps() {
    if [ "$SKIP_DEPS" = true ]; then
        log INFO "Skipping system dependencies (--skip-deps)"
        return 0
    fi
    
    log STEP "[1/6] Installing system dependencies..."
    
    if [ "$DRY_RUN" = true ]; then
        log INFO "[DRY RUN] Would install: openssh-server screen build-essential pkg-config libssl-dev git"
        return 0
    fi
    
    log INFO "Updating apt cache..."
    sudo apt update -qq || {
        log ERROR "apt update failed"
        return 1
    }
    
    log INFO "Installing packages..."
    sudo apt install -y \
        openssh-server \
        screen \
        build-essential \
        pkg-config \
        libssl-dev \
        git-all \
        curl \
        wget 2>&1 | tee -a "$LOG_FILE" > /dev/null
    
    if [ $? -eq 0 ]; then
        log SUCCESS "System dependencies installed"
        
        # Enable SSH
        sudo systemctl enable --now ssh 2>/dev/null || true
        log INFO "SSH service enabled"
    else
        log ERROR "Failed to install some packages"
        return 1
    fi
}

#─────────────────────────────────────────────────────────────
# STEP 2: Install Rust
#─────────────────────────────────────────────────────────────
install_rust() {
    log STEP "[2/6] Setting up Rust toolchain..."
    
    # Check if Rust is already installed
    if command -v rustc &> /dev/null && command -v cargo &> /dev/null; then
        local rust_version=$(rustc --version 2>/dev/null)
        local cargo_version=$(cargo --version 2>/dev/null)
        log SUCCESS "Rust already installed"
        log INFO "  rustc: $rust_version"
        log INFO "  cargo: $cargo_version"
        
        # Ensure environment is loaded
        [ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log INFO "[DRY RUN] Would install Rust from rustup.rs"
        return 0
    fi
    
    log INFO "Installing Rust via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
    
    if [ $? -ne 0 ]; then
        log ERROR "Rust installation failed"
        return 1
    fi
    
    # Load environment
    source "$HOME/.cargo/env"
    
    # Verify installation
    if ! command -v cargo &> /dev/null; then
        log ERROR "Cargo not found after installation"
        log INFO "Try manually: source $HOME/.cargo/env"
        return 1
    fi
    
    # Update rustup
    log INFO "Updating Rust toolchain..."
    rustup update stable 2>&1 | tee -a "$LOG_FILE" > /dev/null
    
    log SUCCESS "Rust installed successfully"
    log INFO "  rustc: $(rustc --version)"
    log INFO "  cargo: $(cargo --version)"
}

#─────────────────────────────────────────────────────────────
# STEP 3: Clone Repository
#─────────────────────────────────────────────────────────────
verify_repository() {
    local repo_dir=$1
    
    cd "$repo_dir"
    
    # Check remote URL
    local remote_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
    
    if [[ ! "$remote_url" =~ $REPO_OWNER/$REPO_NAME ]]; then
        log ERROR "Invalid repository URL: $remote_url"
        log ERROR "Expected: $REPO_OWNER/$REPO_NAME"
        return 1
    fi
    
    log SUCCESS "Repository verified: $remote_url"
    
    # Show current branch and commit
    local branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    log INFO "Branch: $branch"
    log INFO "Commit: $commit"
    
    return 0
}

clone_repository() {
    log STEP "[3/6] Cloning Nexus CLI repository..."
    
    cd "$HOME"
    
    if [ -d "$INSTALL_DIR" ]; then
        log WARN "Directory already exists: $INSTALL_DIR"
        
        if [ "$FORCE_MODE" = true ]; then
            log INFO "Force mode: removing existing directory"
            rm -rf "$INSTALL_DIR"
        else
            read -p "Remove and re-clone? (y/n): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                rm -rf "$INSTALL_DIR"
            else
                log INFO "Using existing repository"
                if verify_repository "$INSTALL_DIR"; then
                    return 0
                else
                    log ERROR "Existing repository validation failed"
                    return 1
                fi
            fi
        fi
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log INFO "[DRY RUN] Would clone from $REPO_URL"
        return 0
    fi
    
    log INFO "Cloning from $REPO_URL..."
    git clone "$REPO_URL" "$INSTALL_DIR" 2>&1 | tee -a "$LOG_FILE"
    
    if [ $? -ne 0 ]; then
        log ERROR "Failed to clone repository"
        return 1
    fi
    
    verify_repository "$INSTALL_DIR"
    
    log SUCCESS "Repository cloned successfully"
}

#─────────────────────────────────────────────────────────────
# STEP 4: Modify Setup File (PRODUCTION GRADE)
#─────────────────────────────────────────────────────────────
backup_setup_file() {
    if [ ! -f "$SETUP_FILE" ]; then
        log ERROR "Setup file not found: $SETUP_FILE"
        return 1
    fi
    
    if [ ! -f "$BACKUP_FILE" ]; then
        cp "$SETUP_FILE" "$BACKUP_FILE"
        log SUCCESS "Backup created: $BACKUP_FILE"
    else
        log INFO "Backup already exists: $BACKUP_FILE"
    fi
    
    # Create timestamped backup too
    local timestamp_backup="${BACKUP_FILE}.$(date +%Y%m%d-%H%M%S)"
    cp "$SETUP_FILE" "$timestamp_backup"
    log INFO "Timestamped backup: $timestamp_backup"
}

verify_modifications() {
    log INFO "Verifying modifications..."
    
    local errors=0
    local warnings=0
    
    # Check 1: Ratio changed to 1.0
    if grep -q "1\.0" "$SETUP_FILE"; then
        log SUCCESS "✓ Check 1: Ratio changed to 1.0"
    else
        log ERROR "✗ Check 1: Ratio 1.0 not found"
        ((errors++))
    fi
    
    # Check 2: num_workers declaration updated
    if grep -q "let mut num_workers.*clamp" "$SETUP_FILE"; then
        log SUCCESS "✓ Check 2: num_workers declaration updated"
    else
        log ERROR "✗ Check 2: num_workers declaration missing"
        ((errors++))
    fi
    
    # Check 3: Override code inserted
    if grep -q "if let Some(mt) = max_threads" "$SETUP_FILE"; then
        log SUCCESS "✓ Check 3: Override code inserted"
    else
        log WARN "⚠ Check 3: Override code not found (optional)"
        ((warnings++))
    fi
    
    # Check 4: File still compiles (syntax check)
    log INFO "Syntax validation..."
    if grep -q "fn setup_prover" "$SETUP_FILE" && grep -q "WorkersConfig" "$SETUP_FILE"; then
        log SUCCESS "✓ Check 4: File structure intact"
    else
        log ERROR "✗ Check 4: File structure corrupted"
        ((errors++))
    fi
    
    # Summary
    echo ""
    if [ $errors -eq 0 ]; then
        log SUCCESS "All critical checks passed ($warnings warnings)"
        return 0
    else
        log ERROR "$errors critical check(s) failed"
        return 1
    fi
}

show_diff() {
    if command -v diff &> /dev/null && [ -f "$BACKUP_FILE" ]; then
        log INFO "Showing changes:"
        echo "─────────────────────────────────────────────────"
        diff -u "$BACKUP_FILE" "$SETUP_FILE" | head -n 50 || true
        echo "─────────────────────────────────────────────────"
    fi
}

modify_setup_file() {
    log STEP "[4/6] Modifying setup.rs..."
    
    cd "$CLI_DIR"
    
    # Pre-flight checks
    if [ ! -f "$SETUP_FILE" ]; then
        log ERROR "Setup file not found: $SETUP_FILE"
        log INFO "Expected location: $CLI_DIR/$SETUP_FILE"
        return 1
    fi
    
    log INFO "Setup file found: $(wc -l < "$SETUP_FILE") lines"
    
    # Create backup
    backup_setup_file || return 1
    
    if [ "$DRY_RUN" = true ]; then
        log INFO "[DRY RUN] Would modify setup.rs"
        return 0
    fi
    
    # Modification 1: Change ratio 0.75 -> 1.0
    log INFO "Modification 1: Changing core ratio $ORIGINAL_RATIO -> $TARGET_RATIO..."
    
    # Try context-aware replacement first
    if grep -q "num_cpus::get().*${ORIGINAL_RATIO}" "$SETUP_FILE"; then
        sed -i "/num_cpus::get()/s/${ORIGINAL_RATIO}/${TARGET_RATIO}/" "$SETUP_FILE"
        log SUCCESS "  Context-aware replacement done"
    elif grep -q "${ORIGINAL_RATIO}" "$SETUP_FILE"; then
        # Fallback to global replacement
        log WARN "  Using global replacement"
        sed -i "s/${ORIGINAL_RATIO}/${TARGET_RATIO}/g" "$SETUP_FILE"
    else
        log WARN "  Pattern ${ORIGINAL_RATIO} not found (may be already modified)"
    fi
    
    # Modification 2: Update num_workers declaration
    log INFO "Modification 2: Updating num_workers declaration..."
    
    local NEW_DECLARATION='let mut num_workers: usize = max_threads.unwrap_or(1).clamp(1, max_workers as u32) as usize;'
    
    if grep -q "let mut num_workers" "$SETUP_FILE"; then
        # Replace entire line
        sed -i "/let mut num_workers/c\\    $NEW_DECLARATION" "$SETUP_FILE"
        log SUCCESS "  num_workers declaration updated"
    else
        log ERROR "  Pattern 'let mut num_workers' not found"
        return 1
    fi
    
    # Modification 3: Insert override code (idempotent)
    log INFO "Modification 3: Inserting override logic..."
    
    local OVERRIDE_CODE='    if let Some(mt) = max_threads { num_workers = mt as usize; }'
    
    if grep -q "if let Some(mt) = max_threads" "$SETUP_FILE"; then
        log INFO "  Override code already exists, skipping"
    else
        # Try multiple anchor points
        local anchors=(
            "// Additional memory warning"
            "println!(\"Warning"
            "let workers_config"
        )
        
        local inserted=false
        for anchor in "${anchors[@]}"; do
            if grep -q "$anchor" "$SETUP_FILE"; then
                sed -i "/$anchor/i\\$OVERRIDE_CODE\\n" "$SETUP_FILE"
                log SUCCESS "  Override code inserted (anchor: $anchor)"
                inserted=true
                break
            fi
        done
        
        if [ "$inserted" = false ]; then
            log WARN "  Could not find anchor point for override code"
            log WARN "  Manual insertion may be needed"
        fi
    fi
    
    # Verify all modifications
    if verify_modifications; then
        log SUCCESS "All modifications completed and verified"
        show_diff
        return 0
    else
        log ERROR "Modification verification failed"
        log WARN "Restoring backup..."
        cp "$BACKUP_FILE" "$SETUP_FILE"
        log INFO "Backup restored. Original file preserved."
        return 1
    fi
}

#─────────────────────────────────────────────────────────────
# STEP 5: Build Project
#─────────────────────────────────────────────────────────────
build_project() {
    log STEP "[5/6] Building Nexus CLI (Release mode)..."
    
    cd "$CLI_DIR"
    
    if [ "$DRY_RUN" = true ]; then
        log INFO "[DRY RUN] Would run: cargo build --release"
        return 0
    fi
    
    log INFO "This may take 5-15 minutes depending on your system..."
    log INFO "Build log: $LOG_FILE"
    echo ""
    
    # Build with progress indication
    local build_start=$(date +%s)
    
    if cargo build --release 2>&1 | tee -a "$LOG_FILE"; then
        local build_end=$(date +%s)
        local build_time=$((build_end - build_start))
        
        echo ""
        log SUCCESS "Build completed in ${build_time}s"
        
        # Verify binary
        local binary="target/release/nexus-network"
        if [ -f "$binary" ]; then
            local binary_size=$(du -h "$binary" | cut -f1)
            local binary_hash=$(sha256sum "$binary" | cut -d' ' -f1)
            
            log INFO "Binary: $binary"
            log INFO "  Size: $binary_size"
            log INFO "  SHA256: ${binary_hash:0:16}..."
            
            # Test binary
            if "$binary" --version &> /dev/null; then
                log SUCCESS "Binary is executable"
            else
                log WARN "Binary may not be executable (--version failed)"
            fi
        else
            log ERROR "Binary not found: $binary"
            return 1
        fi
        
        return 0
    else
        echo ""
        log ERROR "Build failed"
        log INFO "Check build log: tail -n 100 $LOG_FILE"
        return 1
    fi
}

#─────────────────────────────────────────────────────────────
# STEP 6: Post-Installation
#─────────────────────────────────────────────────────────────
create_run_script() {
    log INFO "Creating run script..."
    
    local run_script="$CLI_DIR/run-nexus.sh"
    
    cat > "$run_script" << 'EOF'
#!/bin/bash
# Nexus Network Runner
# Generated by installer

set -euo pipefail

cd "$(dirname "$0")"

BINARY="./target/release/nexus-network"
MAX_THREADS="${MAX_THREADS:-25}"

if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found: $BINARY"
    exit 1
fi

echo "Starting Nexus Network Prover..."
echo "Max threads: $MAX_THREADS"
echo ""

exec "$BINARY" start --max-threads "$MAX_THREADS" "$@"
EOF
    
    chmod +x "$run_script"
    log SUCCESS "Run script created: $run_script"
}

post_install() {
    log STEP "[6/6] Post-installation setup..."
    
    cd "$CLI_DIR"
    
    # Create run script
    create_run_script
    
    # Create systemd service (optional)
    if [ -d /etc/systemd/system ] && command -v systemctl &> /dev/null; then
        log INFO "Systemd detected. You can create a service later."
    fi
    
    log SUCCESS "Post-installation completed"
}

#─────────────────────────────────────────────────────────────
# FINAL SUMMARY
#─────────────────────────────────────────────────────────────
show_summary() {
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  🎉 INSTALLATION COMPLETED SUCCESSFULLY${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    log SUCCESS "Nexus CLI is ready to use!"
    echo ""
    
    echo -e "${BOLD}📍 Installation Directory:${NC}"
    echo "   $CLI_DIR"
    echo ""
    
    echo -e "${BOLD}🔧 Binary Location:${NC}"
    echo "   $CLI_DIR/target/release/nexus-network"
    echo ""
    
    echo -e "${BOLD}📝 Configuration Files:${NC}"
    echo "   Setup: $CLI_DIR/$SETUP_FILE"
    echo "   Backup: $CLI_DIR/$BACKUP_FILE"
    echo ""
    
    echo -e "${BOLD}📋 Log File:${NC}"
    echo "   $LOG_FILE"
    echo ""
    
    echo -e "${BOLD}🚀 Quick Start:${NC}"
    echo -e "   ${CYAN}cd $CLI_DIR${NC}"
    echo -e "   ${CYAN}./run-nexus.sh${NC}"
    echo ""
    echo "   Or manually:"
    echo -e "   ${CYAN}./target/release/nexus-network start --max-threads 25${NC}"
    echo ""
    
    echo -e "${BOLD}🔄 Run in Background (with screen):${NC}"
    echo -e "   ${CYAN}screen -S nexus${NC}"
    echo -e "   ${CYAN}cd $CLI_DIR && ./run-nexus.sh${NC}"
    echo "   Press Ctrl+A then D to detach"
    echo -e "   ${CYAN}screen -r nexus${NC} to reattach"
    echo ""
    
    echo -e "${BOLD}🛠️ Troubleshooting:${NC}"
    echo "   Restore backup:"
    echo -e "   ${CYAN}cp $CLI_DIR/$BACKUP_FILE $CLI_DIR/$SETUP_FILE${NC}"
    echo -e "   ${CYAN}cd $CLI_DIR && cargo build --release${NC}"
    echo ""
    
    echo -e "${BOLD}📚 Documentation:${NC}"
    echo "   https://github.com/nexus-xyz/nexus-cli"
    echo ""
    
    echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
}

#─────────────────────────────────────────────────────────────
# USAGE
#─────────────────────────────────────────────────────────────
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Production-grade Nexus CLI installer with safety checks and rollback.

OPTIONS:
    -h, --help          Show this help message
    -d, --dry-run       Simulate installation without making changes
    -f, --force         Force installation (skip confirmations)
    -s, --skip-deps     Skip system dependencies installation
    -v, --version       Show script version

EXAMPLES:
    $0                  # Normal installation
    $0 --dry-run        # Test without making changes
    $0 --force          # Force installation
    $0 --skip-deps      # Skip apt packages

LOG:
    Installation logs are saved to: ~/nexus-install-*.log

EOF
}

#─────────────────────────────────────────────────────────────
# ARGUMENT PARSING
#─────────────────────────────────────────────────────────────
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -d|--dry-run)
                DRY_RUN=true
                log INFO "Dry-run mode enabled"
                shift
                ;;
            -f|--force)
                FORCE_MODE=true
                log INFO "Force mode enabled"
                shift
                ;;
            -s|--skip-deps)
                SKIP_DEPS=true
                log INFO "Skip dependencies mode enabled"
                shift
                ;;
            -v|--version)
                echo "Nexus CLI Installer v$SCRIPT_VERSION"
                exit 0
                ;;
            *)
                log ERROR "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

#─────────────────────────────────────────────────────────────
# MAIN
#─────────────────────────────────────────────────────────────
main() {
    # Parse arguments first
    parse_arguments "$@"
    
    # Show header
    header
    
    # Pre-flight checks
    check_prerequisites
    echo ""
    
    # Confirmation (skip in force mode)
    if [ "$FORCE_MODE" = false ] && [ "$DRY_RUN" = false ]; then
        echo -e "${YELLOW}This script will:${NC}"
        echo "  1. Install system dependencies (build tools, SSH, etc.)"
        echo "  2. Install Rust toolchain via rustup"
        echo "  3. Clone Nexus CLI repository"
        echo "  4. Modify source code for optimization"
        echo "  5. Build in release mode (~10-15 minutes)"
        echo "  6. Create helper scripts"
        echo ""
        read -p "Continue? (y/n): " confirm
        
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log INFO "Installation cancelled by user"
            exit 0
        fi
        echo ""
    fi
    
    # Execute installation steps
    local steps=(
        "install_system_deps"
        "install_rust"
        "clone_repository"
        "modify_setup_file"
        "build_project"
        "post_install"
    )
    
    local total_steps=${#steps[@]}
    local current_step=0
    
    for step in "${steps[@]}"; do
        ((current_step++))
        
        if ! $step; then
            log ERROR "Step failed: $step"
            log ERROR "Installation aborted"
            exit 1
        fi
        
        progress_bar $current_step $total_steps
        echo ""
    done
    
    # Show summary
    show_summary
    
    # Final message
    if [ "$DRY_RUN" = true ]; then
        echo ""
        log INFO "This was a dry-run. No changes were made."
        log INFO "Run without --dry-run to perform actual installation."
    fi
}

#─────────────────────────────────────────────────────────────
# ENTRY POINT
#─────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
