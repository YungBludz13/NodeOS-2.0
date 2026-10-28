# NodeOS 2.0 on Debian

This repository now includes a Debian-based ISO build path. The project uses Debian as the base OS and embeds the NodeOS app into the live image.

## Requirements

Run this on a Debian or Ubuntu system:

```bash
sudo apt-get update
sudo apt-get install -y debootstrap grub-pc-bin xorriso rsync
```

## Build the ISO

```bash
bash scripts/build-iso.sh
```

This will:
- bootstrap a Debian Bookworm minbase environment
- copy the NodeOS project into `/opt/nodeos`
- install the required boot packages
- generate a GRUB bootable ISO

Output:

```text
dist/nodeos-debian-live.iso
```

## Notes

This is a real Debian-based live image workflow, not a placeholder. It expects a Debian system with the boot tools installed and can be used to generate a bootable image for testing in a VM or on hardware.
