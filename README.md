# NVMe Secure Wipe & Sanitize Guide

A simple, no-fluff Linux script for securely wiping NVMe drives and restoring them to a factory-like state. This document serves as both a user manual for the script and a general guide to NVMe data destruction.

#### ⚠️ CRITICAL WARNING ⚠️

**This script will PERMANENTLY and IRREVERSIBLY DESTROY ALL DATA on the specified drive. Use with extreme caution. Double-check your drive name before proceeding.**

---

## 1. Why Modern Drives Need Special Wiping

Modern NVMe SSDs are not like old hard drives. Due to complex internal features like wear-leveling and over-provisioned space (extra storage the user can't see), simply writing 0s and 1s across the drive is **not good enough** to guarantee all data is gone. Some data can be left behind in "hidden" areas, making it potentially recoverable.

The most effective method is to use the drive's built-in **`Sanitize`** command. This tells the drive's own controller to perform a hardware-level erase, which is the most reliable way to perform a "crypto erase" or factory reset on the NAND flash chips.

This script was created because most data destruction tools were designed for older SATA drives. It provides a robust, multi-pass method specifically for modern NVMe drives to ensure your data is irrecoverably destroyed.

## 2. What This Script Does

This script performs a "paranoid" 6-pass wipe designed to get into every hidden nook and cranny of the drive, making data recovery virtually impossible without nation-state-level forensic capabilities (like electron microscopes).

* **Hardware Erase (If Supported):** The script first tries to use the drive's powerful built-in `NVMe Sanitize` command.
* **Software Overwrites:** It then performs multiple full-disk overwrites with different data patterns (`0x00` and `0xFF`) to ensure maximum data destruction.

This combination ensures that even if a drive doesn't support the hardware sanitize feature, it is still wiped thoroughly. The script will unmount the target drive if needed; any partitions are irrelevant, as they will be destroyed too.

**The Wipe Process:**
1.  **Pass 1:** NVMe Sanitize (Hardware block erase, if supported)
2.  **Pass 2:** Overwrite with Zeros (`0x00`)
3.  **Pass 3:** Overwrite with Ones (`0xFF`)
4.  **Pass 4:** Overwrite with Zeros (`0x00`)
5.  **Pass 5:** NVMe Sanitize (A second hardware erase, if supported)
6.  **Pass 6:** Final Overwrite with Zeros (`0x00`)

## 3. When to Use This Script

This script is ideal for any situation where you need confidence that your data is gone for good.

* Selling or gifting a drive.
* Returning a drive for an RMA.
* Disposing of old drives.
* Complying with data destruction policies.

> **A Note on Extreme Security:** If your drive contained sensitive data like critical business secrets or, say, nuke codes, the safest method is always **physical destruction** (incinerate it and buy a new one). For everything else, this script is more than sufficient. You should also be encrypting your drives from the start!

## 4. Requirements

1.  A **Linux-based operating system**.
2.  The **`nvme-cli`** utility installed.

The safest and easiest way to use this script is by booting from a **Live USB** of a distribution like Ubuntu or Linux Mint. This ensures the target drive (even your main OS drive) is not in use.

### Installing `nvme-cli`

Open a terminal and run the command for your distribution:
* **Debian / Ubuntu:** `sudo apt update && sudo apt install -y nvme-cli`
* **Fedora / CentOS / RHEL:** `sudo dnf install -y nvme-cli`
* **Arch Linux:** `sudo pacman -S nvme-cli`

---

## 5. How to Use the Script

1.  **Download the Script**
    ```bash
    wget [https://raw.githubusercontent.com/CurbSoftwareInc/NVMe-Wipe-and-Sanitize/main/secure_wipe.sh](https://raw.githubusercontent.com/CurbSoftwareInc/NVMe-Wipe-and-Sanitize/main/secure_wipe.sh)
    ```

2.  **Make it Executable**
    ```bash
    chmod +x secure_wipe.sh
    ```

3.  **Identify Your Drive**
    Use `nvme list` or `lsblk` to find the correct device name (e.g., `/dev/nvme0n1`). **Be careful!**
    ```bash
    sudo nvme list
    # or
    lsblk -d | grep nvme
    ```

4.  **Run the Script**
    Execute the script with `sudo` and pass the drive name as an argument.
    ```bash
    # Example for the drive /dev/nvme0n1
    sudo ./secure_wipe.sh /dev/nvme0n1
    ```

5.  **Confirm Destruction**
    The script will show a final, critical warning. You must type **`DESTROY`** and press Enter to begin.

## 6. Verification

After the script finishes, you can run a few checks to verify the wipe.

1.  **Check for Partitions (Should be none)**
    ```bash
    lsblk /dev/nvme0n1
    ```

2.  **Read Sectors (Should be all zeros)**
    This command reads the first 5 KB of the drive and displays it in hexadecimal. The output should be all `00`s.
    ```bash
    sudo dd if=/dev/nvme0n1 bs=512 count=10 | hexdump -C
    ```

3.  **Spot-Check Random Locations**
    This loop checks the beginning of the drive, a spot 1 GB in, and a spot 10 GB in.
    ```bash
    for offset in 0 1073741824 10737418240; do
      echo "Checking offset $offset..."
      sudo dd if=/dev/nvme0n1 bs=512 count=1 skip=$((offset/512)) 2>/dev/null | hexdump -C | head -n 2
    done
    ```

## 7. Manual Execution Guide

If you prefer to run commands manually instead of using the script, here is a simplified sequence.

1.  **Unmount the Drive:** `sudo umount /dev/nvme0n1*`
2.  **Run Sanitize:** `sudo nvme sanitize /dev/nvme0n1 --sanact=2`
3.  **Monitor Progress:** `watch 'sudo nvme sanitize-log /dev/nvme0n1'`
4.  **Optional Overwrites:**
    * Zeros: `sudo dd if=/dev/zero of=/dev/nvme0n1 bs=1M status=progress oflag=direct`
    * Ones: `tr '\000' '\377' < /dev/zero | sudo dd of=/dev/nvme0n1 bs=1M status=progress oflag=direct`

---

## 8. Future Plans (To-Do)

* Add an option for a less-intensive 3-pass wipe to reduce wear on the drive.
* Compile resources and links for professional data recovery services.
* Add guides and resources for wiping older SATA HDDs and SSDs.
* Explore other Linux data destruction tools like `shred` and the `secure-delete` package.
* Investigate creating a "chaff" application to fill a drive with meaningless random data before wiping.

---

## 9. License & Acknowledgments

This project is licensed under the **MIT License**.

This script is a wrapper around the powerful [**linux-nvme/nvme-cli**](https://github.com/linux-nvme/nvme-cli) utility, which does all the heavy lifting.

- Add option in this or another script to choose 3 pass, limit read/write to less passes to avoid drive degredation further.
- Get drive data recovery links and resources
- Sata HDD find resources, bleachbit is a good start to wipe free space.
- Secure Delete package for linux, works (links to literature suggesting up to 38 passes required but dnd standard is 3 passes for sufficiency)
- Secure delete package for HDD takes a LONG time to complete.
- Using many passes on NVMe like for HDD recommendation will eventually degrade the NVMe SSD
- Consider creating a chaff app (Bleachbit has this feature - including Hillary's emails)

---

## License

This project is licensed under the **MIT License**.

## Repository

**Location:** [https://github.com/CurbSoftwareInc/NVMe-Wipe-and-Sanitize](https://github.com/CurbSoftwareInc/NVMe-Wipe-and-Sanitize)
