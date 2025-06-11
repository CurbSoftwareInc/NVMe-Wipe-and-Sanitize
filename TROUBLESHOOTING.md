## Troubleshooting

### Common Issues

**"Sanitize In Progress" Error**
- The script automatically detects and aborts existing sanitize operations
- You can manually abort with: `sudo nvme sanitize /dev/nvme0n1 --sanact=0`

**"No space left on device" During DD**
- This is normal and means the write completed successfully
- The script handles this automatically

**Permission Denied**
- Ensure you're running with sudo or as root
- Check drive permissions: `ls -la /dev/nvme*`

**Drive Not Found**
- Verify drive path: `nvme list`
- Ensure drive is connected and recognized: `lsblk`

If you get the message:
```bash
=============================================
 PASS 1/6: NVMe Sanitize (SKIPPED)
=============================================

[INFO] Drive does not support this feature.
```

The output you're seeing shows the script is working perfectly and doing exactly what it's designed to do in this situation.

Here’s what it means and what you should do:

The message `[WARNING] Drive does not support NVMe Sanitize (sanicap=0)` means that your specific NVMe drive (sush as, `/dev/nvme1n1`) does not have the built-in, hardware-level erase feature.

The script correctly detected this and automatically adapted its plan:
* It is **skipping** the hardware-based `NVMe Sanitize` passes (Pass 1 and Pass 5).
* It is **proceeding** with the software-based passes (Passes 2, 3, 4, and 6), where it overwrites the entire drive with patterns of zeros and ones.

### What Should You Do?

**Nothing. You should let the script continue and finish its job.**

The multi-pass overwrite it's currently performing is the **next best and most thorough method** available for a drive that doesn't support the hardware sanitize command.

### Is It Still Secure?

**Yes, for all practical purposes, it is still very secure.**

While a hardware-level `Sanitize` is considered the gold standard, a multi-pass overwrite that writes zeros, then ones, then zeros again is extremely effective. This method will make your data unrecoverable by any standard software or commercial data recovery service.

To be completely transparent, the only theoretical weakness is that on an SSD, complex features like wear-leveling *could* mean there are retired blocks that don't get overwritten. However, recovering data from those blocks would require a highly sophisticated and expensive forensics lab.

**In summary:**

* **Is the script working?** Yes, perfectly.
* **Is my drive being erased?** Yes, very thoroughly using the best method available for your specific hardware.
* **What's my next step?** Just let the script run. It will take some time, but it's doing the right thing.

