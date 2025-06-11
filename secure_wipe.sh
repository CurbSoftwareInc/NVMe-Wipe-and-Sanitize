#!/bin/bash

# NVMe Secure Wipe Script
# Version: 2.0.9
# 
# WARNING: This script will PERMANENTLY DESTROY all data on the specified drive!
# 
# Performs 6-pass secure wipe:
# 1. NVMe Sanitize
# 2. Overwrite with zeros
# 3. Overwrite with ones (0xFF)
# 4. Overwrite with zeros
# 5. NVMe Sanitize
# 6. Overwrite with zeros (final)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_pass() {
    echo -e "\n${MAGENTA}════════════════════════════════════════"
    echo -e "PASS $1: $2"
    echo -e "════════════════════════════════════════${NC}\n"
}

# Function to monitor sanitize progress
monitor_sanitize() {
    local drive=$1
    print_status "Monitoring sanitize progress..."
    
    while true; do
        sleep 5
        
        # Get sanitize status
        local status_output=$(sudo nvme sanitize-log "$drive" 2>&1)
        
        # Check if sanitize is still in progress
        if [[ $status_output == *"Sanitize In Progress"* ]]; then
            echo -n "."
            continue
        fi
        
        # Extract progress
        local progress=$(echo "$status_output" | grep -oP "Sanitize Progress\s*\(SPROG\)\s*:\s*\K\d+" || echo "0")
        local status=$(echo "$status_output" | grep -oP "Sanitize Status\s*\(SSTAT\)\s*:\s*\K0x[0-9a-fA-F]+" || echo "")
        
        # Check if completed
        if [[ "$progress" == "65535" ]] || [[ "$status" == *"0x101"* ]] || [[ "$status" == *"0x1"* ]]; then
            echo
            print_success "Sanitize completed!"
            echo "$status_output" | grep -E "Progress|Status" || true
            break
        fi
        
        # Calculate percentage
        if [[ "$progress" =~ ^[0-9]+$ ]] && [[ "$progress" -gt 0 ]]; then
            local percent=$(( (progress * 100) / 65535 ))
            printf "\rProgress: %d%% " "$percent"
        fi
    done
}

# Main function
main() {
    echo "NVMe Secure Wipe Script v1.0.0"
    echo "6-pass paranoid drive sanitization tool"
    echo
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
    
    # Check for nvme command
    if ! command -v nvme &> /dev/null; then
        print_error "nvme-cli is not installed"
        exit 1
    fi
    
    # Get drive parameter
    if [[ $# -eq 0 ]]; then
        print_error "Usage: $0 /dev/nvmeXnY"
        echo "Available NVMe drives:"
        nvme list 2>/dev/null || echo "No NVMe drives found"
        exit 1
    fi
    
    DRIVE=$1
    
    # Validate drive
    if [[ ! -b "$DRIVE" ]]; then
        print_error "Drive $DRIVE does not exist"
        exit 1
    fi
    
    # Get drive info
    DRIVE_SIZE=$(lsblk -b -n -o SIZE "$DRIVE" 2>/dev/null | head -1)
    DRIVE_SIZE_GB=$((DRIVE_SIZE / 1073741824))
    DRIVE_SIZE_TB=$(awk "BEGIN {printf \"%.1f\", $DRIVE_SIZE_GB / 1024}")
    
    # Show warning
    echo
    print_warning "═══════════════════════════════════════════════════════"
    print_warning "         CRITICAL WARNING - DATA DESTRUCTION"
    print_warning "═══════════════════════════════════════════════════════"
    print_warning "This will PERMANENTLY DESTROY ALL DATA on:"
    print_warning "  → Drive: $DRIVE"
    print_warning "  → Size:  ${DRIVE_SIZE_GB}GB (${DRIVE_SIZE_TB}TB)"
    print_warning ""
    print_warning "This action is IRREVERSIBLE!"
    print_warning "═══════════════════════════════════════════════════════"
    echo
    
    # Show current status
    print_info "Current drive info:"
    lsblk "$DRIVE" 2>/dev/null
    echo
    
    # Confirmation
    print_warning "Type 'DESTROY' to continue:"
    read -r confirmation
    if [[ "$confirmation" != "DESTROY" ]]; then
        print_error "Operation cancelled"
        exit 1
    fi
    
    START_TIME=$SECONDS
    
    print_success "Starting 6-pass secure wipe of $DRIVE"
    echo
    
    # Unmount partitions
    print_status "Unmounting partitions..."
    umount "${DRIVE}"* 2>/dev/null || true
    sync
    sleep 2
    
    #############################################
    # PASS 1: First Sanitize
    #############################################
    print_pass "1/6" "NVMe Sanitize (First Hardware Erase)"
    print_status "Starting sanitize operation..."
    
    sudo nvme sanitize "$DRIVE" --sanact=2
    sleep 2
    monitor_sanitize "$DRIVE"
    echo
    
    #############################################
    # PASS 2: Write Zeros (First)
    #############################################
    print_pass "2/6" "Overwrite with Zeros (First Pass)"
    print_status "Writing zeros to entire drive..."
    print_info "This will take approximately ${DRIVE_SIZE_GB} seconds"
    
    sudo dd if=/dev/zero of="$DRIVE" bs=1M status=progress 2>&1 || true
    
    print_success "Zero write completed"
    echo
    
    #############################################
    # PASS 3: Write Ones
    #############################################
    print_pass "3/6" "Overwrite with Ones (0xFF Pattern)"
    print_status "Writing ones (0xFF) to entire drive..."
    print_info "This will take approximately ${DRIVE_SIZE_GB} seconds"
    
    # Use the more efficient piped method
    tr '\000' '\377' < /dev/zero | sudo dd of="$DRIVE" bs=1M status=progress 2>&1 || true
    
    print_success "Ones write completed"
    echo
    
    #############################################
    # PASS 4: Write Zeros (Second)
    #############################################
    print_pass "4/6" "Overwrite with Zeros (Second Pass)"
    print_status "Writing zeros to entire drive..."
    print_info "This will take approximately ${DRIVE_SIZE_GB} seconds"
    
    sudo dd if=/dev/zero of="$DRIVE" bs=1M status=progress 2>&1 || true
    
    print_success "Zero write completed"
    echo
    
    #############################################
    # PASS 5: Second Sanitize
    #############################################
    print_pass "5/6" "NVMe Sanitize (Second Hardware Erase)"
    print_status "Starting sanitize operation..."
    
    sudo nvme sanitize "$DRIVE" --sanact=2
    sleep 2
    monitor_sanitize "$DRIVE"
    echo
    
    #############################################
    # PASS 6: Final Zero Write
    #############################################
    print_pass "6/6" "Final Zero Overwrite"
    print_status "Writing zeros to entire drive (final pass)..."
    print_info "This will take approximately ${DRIVE_SIZE_GB} seconds"
    
    sudo dd if=/dev/zero of="$DRIVE" bs=1M status=progress 2>&1 || true
    
    print_success "Final zero write completed"
    echo
    
    #############################################
    # Completion
    #############################################
    
    # Calculate total time
    TOTAL_TIME=$((SECONDS - START_TIME))
    HOURS=$((TOTAL_TIME / 3600))
    MINUTES=$(((TOTAL_TIME % 3600) / 60))
    
    echo
    print_success "═══════════════════════════════════════════════════════"
    print_success "       SECURE WIPE COMPLETED SUCCESSFULLY"
    print_success "═══════════════════════════════════════════════════════"
    print_success "Drive: $DRIVE (${DRIVE_SIZE_GB}GB)"
    print_success "Time: ${HOURS}h ${MINUTES}m"
    print_success ""
    print_success "Completed passes:"
    print_success "  ✓ Pass 1: NVMe Sanitize"
    print_success "  ✓ Pass 2: Zero Overwrite" 
    print_success "  ✓ Pass 3: Ones (0xFF) Overwrite"
    print_success "  ✓ Pass 4: Zero Overwrite"
    print_success "  ✓ Pass 5: NVMe Sanitize"
    print_success "  ✓ Pass 6: Final Zero Overwrite"
    print_success "═══════════════════════════════════════════════════════"
    echo
    print_info "To verify the drive is wiped (should show all zeros):"
    echo -e "${CYAN}sudo dd if=$DRIVE bs=512 count=10 | hexdump -C${NC}"
    echo
    print_info "Or check multiple locations:"
    echo -e "${CYAN}for i in 0 1073741824 10737418240; do"
    echo -e "  echo \"Offset \$i:\""
    echo -e "  sudo dd if=$DRIVE bs=512 count=1 skip=\$((i/512)) 2>/dev/null | hexdump -C | head -2"
    echo -e "done${NC}"
    echo
}

# Run main function
main "$@"
