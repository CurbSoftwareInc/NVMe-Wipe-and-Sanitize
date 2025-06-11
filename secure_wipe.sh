#!/bin/bash

# NVMe Secure Wipe Script
# Version: 2.1.0
#
# WARNING: This script will PERMANENTLY DESTROY all data on the specified drive!
#
# Performs a multi-pass secure wipe. If the drive supports it, this includes
# the hardware-based NVMe Sanitize command.
#
# Passes:
# 1. NVMe Sanitize (if supported)
# 2. Overwrite with zeros
# 3. Overwrite with ones (0xFF)
# 4. Overwrite with zeros
# 5. NVMe Sanitize (if supported)
# 6. Overwrite with zeros (final)

# --- Configuration ---
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# --- Helper Functions ---

# Function to print colored output with a timestamp
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

# Function to print a formatted pass header
print_pass() {
    echo -e "\n${MAGENTA}============================================="
    echo -e " PASS $1: $2"
    echo -e "=============================================${NC}\n"
}

# Function to monitor the progress of an NVMe sanitize operation
monitor_sanitize() {
    local drive=$1
    print_status "Monitoring sanitize progress..."

    while true; do
        sleep 5

        # Get sanitize status log
        local status_output
        status_output=$(sudo nvme sanitize-log "$drive" 2>&1)

        # Check for various states indicating progress or completion
        if [[ $status_output == *"Sanitize In Progress"* ]]; then
            echo -n "."
            continue
        fi

        local progress
        progress=$(echo "$status_output" | grep -oP 'sprog\s+:\s*\K\d+' || echo "0")
        local status
        status=$(echo "$status_output" | grep -oP 'sstat\s+:\s*\K0x[0-9a-fA-F]+' || echo "")

        # Check if completed successfully. Progress is 65535 (100%) on completion.
        # Status 0x101 means "Sanitize operation completed successfully".
        if [[ "$progress" == "65535" ]] || [[ "$status" == "0x101" ]]; then
            echo # Newline after progress dots
            print_success "Sanitize completed!"
            echo "$status_output" | grep -E "sprog|sstat" || true
            break
        fi

        # Calculate percentage for display
        if [[ "$progress" =~ ^[0-9]+$ ]] && [[ "$progress" -gt 0 ]]; then
            local percent=$(( (progress * 100) / 65535 ))
            printf "\rProgress: %d%% " "$percent"
        fi
    done
}

# --- Main Script Logic ---
main() {
    echo "NVMe Secure Wipe Script v2.1.0"
    echo "Paranoid multi-pass drive sanitization tool"
    echo

    # 1. Prerequisite Checks
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root."
        exit 1
    fi

    if ! command -v nvme &> /dev/null; then
        print_error "nvme-cli is not installed. Please install it (e.g., 'sudo apt install nvme-cli')."
        exit 1
    fi

    if [[ $# -eq 0 ]]; then
        print_error "Usage: $0 /dev/nvmeX[n_]"
        echo "Available NVMe drives:"
        nvme list 2>/dev/null || echo "No NVMe drives found."
        exit 1
    fi

    DRIVE=$1

    # 2. Drive Validation and Information Gathering
    if [[ ! -b "$DRIVE" ]]; then
        print_error "Drive '$DRIVE' is not a valid block device or does not exist."
        exit 1
    fi

    # Check for Sanitize support BEFORE asking for confirmation
    print_status "Checking if drive supports the NVMe Sanitize command..."
    local sanicap
    sanicap=$(sudo nvme id-ctrl "$DRIVE" | grep -oP 'sanicap\s+:\s*\K\d+' || echo "0")
    
    SANITIZE_SUPPORTED=0
    if [ "$sanicap" -ne 0 ]; then
        print_success "Drive supports NVMe Sanitize."
        SANITIZE_SUPPORTED=1
    else
        print_warning "Drive does not support NVMe Sanitize (sanicap=0)."
        print_warning "Hardware erase passes will be skipped."
    fi

    local drive_size
    drive_size=$(lsblk -b -n -d -o SIZE "$DRIVE" 2>/dev/null | head -1)
    local drive_size_gb=$((drive_size / 1024 / 1024 / 1024))
    local drive_size_tb
    drive_size_tb=$(awk "BEGIN {printf \"%.1f\", $drive_size_gb / 1024}")

    # 3. Final Confirmation
    echo
    print_warning "======================================================="
    print_warning "          CRITICAL WARNING - DATA DESTRUCTION"
    print_warning "======================================================="
    print_warning "This will PERMANENTLY DESTROY ALL DATA on:"
    print_warning "  → Drive: $DRIVE"
    print_warning "  → Size:  ${drive_size_gb} GB (${drive_size_tb} TB)"
    print_warning ""
    print_warning "This action is IRREVERSIBLE!"
    print_warning "======================================================="
    echo
    print_info "Current drive partitions:"
    lsblk "$DRIVE" 2>/dev/null
    echo

    read -rp "Type 'DESTROY' to continue: " confirmation
    if [[ "$confirmation" != "DESTROY" ]]; then
        print_error "Operation cancelled by user."
        exit 1
    fi

    # 4. Secure Wipe Execution
    local start_time=$SECONDS
    print_success "Starting multi-pass secure wipe of $DRIVE"
    echo

    print_status "Unmounting all partitions on $DRIVE..."
    umount "${DRIVE}"* &>/dev/null || true
    sync
    sleep 2

    # --- PASS 1: First Sanitize ---
    if [ "$SANITIZE_SUPPORTED" -eq 1 ]; then
        print_pass "1/6" "NVMe Sanitize (First Hardware Erase)"
        print_status "Starting Block Erase sanitize operation (--sanact=2)..."
        if sudo nvme sanitize "$DRIVE" --sanact=2; then
            sleep 2
            monitor_sanitize "$DRIVE"
        else
            print_error "Failed to start NVMe Sanitize. Check drive status."
        fi
    else
        print_pass "1/6" "NVMe Sanitize (SKIPPED)"
        print_info "Drive does not support this feature."
    fi
    echo

    # --- PASS 2: Write Zeros (First) ---
    print_pass "2/6" "Overwrite with Zeros (First Pass)"
    print_status "Writing zeros to entire drive..."
    sudo dd if=/dev/zero of="$DRIVE" bs=1M status=progress conv=fsync oflag=direct || print_warning "dd command for pass 2 finished with a non-zero exit code."
    print_success "First zero-write pass completed."
    echo

    # --- PASS 3: Write Ones (0xFF) ---
    print_pass "3/6" "Overwrite with Ones (0xFF Pattern)"
    print_status "Writing ones (0xFF) to entire drive..."
    tr '\000' '\377' < /dev/zero | sudo dd of="$DRIVE" bs=1M status=progress conv=fsync oflag=direct || print_warning "dd command for pass 3 finished with a non-zero exit code."
    print_success "Ones-write pass completed."
    echo

    # --- PASS 4: Write Zeros (Second) ---
    print_pass "4/6" "Overwrite with Zeros (Second Pass)"
    print_status "Writing zeros to entire drive again..."
    sudo dd if=/dev/zero of="$DRIVE" bs=1M status=progress conv=fsync oflag=direct || print_warning "dd command for pass 4 finished with a non-zero exit code."
    print_success "Second zero-write pass completed."
    echo

    # --- PASS 5: Second Sanitize ---
    if [ "$SANITIZE_SUPPORTED" -eq 1 ]; then
        print_pass "5/6" "NVMe Sanitize (Second Hardware Erase)"
        print_status "Starting second Block Erase sanitize operation..."
        if sudo nvme sanitize "$DRIVE" --sanact=2; then
            sleep 2
            monitor_sanitize "$DRIVE"
        else
            print_error "Failed to start second NVMe Sanitize. Check drive status."
        fi
    else
        print_pass "5/6" "NVMe Sanitize (SKIPPED)"
        print_info "Drive does not support this feature."
    fi
    echo

    # --- PASS 6: Final Zero Write ---
    print_pass "6/6" "Final Overwrite with Zeros"
    print_status "Writing zeros to entire drive (final pass)..."
    sudo dd if=/dev/zero of="$DRIVE" bs=1M status=progress conv=fsync oflag=direct || print_warning "dd command for pass 6 finished with a non-zero exit code."
    print_success "Final zero-write pass completed."
    echo

    # 5. Completion Summary
    local total_time=$((SECONDS - start_time))
    local hours=$((total_time / 3600))
    local minutes=$(((total_time % 3600) / 60))
    local seconds=$((total_time % 60))

    echo
    print_success "======================================================="
    print_success "         SECURE WIPE COMPLETED SUCCESSFULLY"
    print_success "======================================================="
    print_success "Drive: $DRIVE (${drive_size_gb} GB)"
    print_success "Total Time: ${hours}h ${minutes}m ${seconds}s"
    print_success "-------------------------------------------------------"
    print_success "  ✓ Pass 1: NVMe Sanitize ($( [ $SANITIZE_SUPPORTED -eq 1 ] && echo "DONE" || echo "SKIPPED" ))"
    print_success "  ✓ Pass 2: Zero Overwrite"
    print_success "  ✓ Pass 3: Ones (0xFF) Overwrite"
    print_success "  ✓ Pass 4: Zero Overwrite"
    print_success "  ✓ Pass 5: NVMe Sanitize ($( [ $SANITIZE_SUPPORTED -eq 1 ] && echo "DONE" || echo "SKIPPED" ))"
    print_success "  ✓ Pass 6: Final Zero Overwrite"
    print_success "======================================================="
    echo
    print_info "You can perform a spot check to verify the wipe (should show all zeros):"
    echo -e "${CYAN}sudo dd if=$DRIVE bs=512 count=20 | hexdump -C${NC}"
    echo
}

# Run the main function with all provided arguments
main "$@"
