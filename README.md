# NVMe Wipe and Sanitize

A simple, no-fluff Linux script for securely wiping and sanitizing NVMe drives, restoring them to factory settings.

This script was created because most data destruction tools are designed for older SATA drives (HDDs and SSDs), not modern NVMe drives. It provides a robust, multi-pass method to ensure your data is irrecoverably destroyed for security purposes, such as when reselling a drive.  The script aims to get every hidden nook and cranny.

## ⚠️ CRITICAL WARNING ⚠️

**This script will PERMANENTLY and IRRECOVERABLY DESTROY ALL DATA on the specified drive. Use with extreme caution. Double-check your drive name before proceeding.**

---

## License

This project is licensed under the **MIT License**.

## Repository

**Location:** [https://github.com/CurbSoftwareInc/NVMe-Wipe-and-Sanitize](https://github.com/CurbSoftwareInc/NVMe-Wipe-and-Sanitize)

---

## About the Script

The script performs a paranoid 6-pass wipe to ensure every bit of data is sanitized. This process gets into every nook and cranny of the drive, making data recovery virtually impossible without nation-state-level forensic capabilities (like electron microscopes).
Note: If the NVMe contained sensive data like business secrets or nuke codes etc., best to incinerate the drive and buy a new one.  The script will unmount the target drive if required, partitions are irrelevant, they'll be gone too.

The wipe process is as follows:
1.  **Pass 1:** NVMe Sanitize (Hardware-level block erase)
2.  **Pass 2:** Overwrite with Zeros (`0x00`)
3.  **Pass 3:** Overwrite with Ones (`0xFF`)
4.  **Pass 4:** Overwrite with Zeros (`0x00`)
5.  **Pass 5:** NVMe Sanitize (Second hardware-level block erase)
6.  **Pass 6:** Overwrite with Zeros (`0x00`) (Final pass)

A healthy drive can achieve speeds of around 1 GB/s for each pass, though performance may throttle on later passes due to heat.

## Requirements

* A Linux-based operating system.
* `nvme-cli` installed.

The easiest and safest method is to boot from a **Live USB** of a Linux distribution like Ubuntu or Linux Mint. This allows you to choose and even wipe the drive your main operating system is/was on.

### Installing `nvme-cli`

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y nvme-cli
```

**RHEL/CentOS/Fedora:**
```bash
sudo yum install -y nvme-cli
# or
sudo dnf install -y nvme-cli
```

**Arch Linux:**
```bash
sudo pacman -S nvme-cli
```

> **Acknowledgments:** This script relies entirely on the powerful `nvme-cli` utility. You can find its official documentation and repository here: [linux-nvme/nvme-cli on GitHub](https://github.com/linux-nvme/nvme-cli).

## How to Use

1.  **Download the Script**

    ```bash
    wget https://raw.githubusercontent.com/CurbSoftwareInc/NVMe-Wipe-and-Sanitize/main/secure_wipe.sh
    ```
    OR
    ```bash
    git clone https://github.com/CurbSoftwareInc/NVMe-Wipe-and-Sanitize && cd NVMe-Wipe-and-Sanitize
    ```
    

3.  **Make it Executable**

    ```bash
    chmod +x secure_wipe.sh
    ```

4.  **Run the Script**
    First, identify your NVMe drive name using `lsblk` or `nvme list`. Then, run the script with the target drive name.

    ```bash
    # List all NVMe drives
    nvme list

    # Show drive details
    lsblk -d | grep nvme

    # Show partitions
    lsblk /dev/nvme0n1
    ```
    Then:

    ```bash
    # Example for the drive /dev/nvme0n1
    sudo ./secure_wipe.sh /dev/nvme0n1
    ```

6.  **Confirm Destruction**
    The script will display a final warning. You must type `DESTROY` and press Enter to begin the wipe process.

## Manual Commands (The "Without-the-Script" Way)

If you prefer to run the commands manually, here is a simplified sequence to perform a basic sanitize and wipe after installing `nvme-cli`.

1.  **Unmount the drive (replace `nvme0n1` with your drive)**

    ```bash
    # This command attempts to unmount all partitions on the specified drive
    sudo umount /dev/nvme0n1*
    ```

2.  **Run the NVMe Sanitize Command**
    This uses the drive's built-in hardware erase function, which is fast and effective.

    ```bash
    # --sanact=2 specifies a Block Erase
    sudo nvme sanitize /dev/nvme0n1 --sanact=2
    ```

3.  **Monitor Progress**
    You can check the status in a separate terminal. Repeat the command until the progress shows `65535` (100%) and the status indicates completion.

    ```bash
    watch 'sudo nvme sanitize-log /dev/nvme0n1'
    ```

4.  **(Optional) Overwrite with Zeros**
    For an extra layer of security, you can perform a full overwrite with zeros after the sanitize is complete.

    ```bash
    sudo dd if=/dev/zero of=/dev/nvme0n1 bs=1M status=progress
    ```

5.  **(Optional) Overwrite with Ones**

    ```bash
    tr '\000' '\377' < /dev/zero | sudo dd of=/dev/nvme0n1 bs=1M status=progress
    ```

### Another option

Some people use the method of encrypting the entire drive, filling it with chaff until all disk space is full, then unmounting and formatting it, you can combine with this script if you want.
The issue I had with that method is for reselling you might want to do a sort of factory reset and ensure every block, including manufacturer ones are overwritten.  Check out nvme-cli because they are the pros. 
