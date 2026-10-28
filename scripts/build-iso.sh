#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$ROOT_DIR/build/debian-rootfs"
ISO_ROOT="$ROOT_DIR/build/iso-root"
OUT_DIR="$ROOT_DIR/dist"
ISO_NAME="${1:-nodeos-debian-live.iso}"
DEBIAN_MIRROR="${DEBIAN_MIRROR:-http://deb.debian.org/debian}"

# Check for required host tools
for cmd in debootstrap grub-mkrescue rsync mksquashfs; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required tool: $cmd" >&2
    echo "Install it on Debian/Ubuntu with:"
    echo "sudo apt-get install debootstrap grub-pc-bin grub-efi-amd64-bin xorriso rsync squashfs-tools mtools"
    exit 1
  fi
done

mkdir -p "$OUT_DIR" "$ISO_ROOT/boot/grub" "$ISO_ROOT/live"
rm -rf "$WORK_DIR" "$ISO_ROOT"/*

if [ ! -d "$WORK_DIR" ]; then
  echo "🔹 Bootstrapping Debian base system..."
  debootstrap --variant=minbase --arch=amd64 bookworm "$WORK_DIR" "$DEBIAN_MIRROR"
fi

# Copy the NodeOS project into the Debian filesystem.
mkdir -p "$WORK_DIR/opt/nodeos"
cp -a "$ROOT_DIR/src" "$ROOT_DIR/package.json" "$ROOT_DIR/README.md" "$ROOT_DIR/.gitignore" "$WORK_DIR/opt/nodeos/"

# Create a helper script
cat > "$WORK_DIR/opt/nodeos/run-nodeos.sh" <<'EOF'
#!/usr/bin/env bash
set -e
cd /opt/nodeos
node src/index.js
EOF
chmod +x "$WORK_DIR/opt/nodeos/run-nodeos.sh"

# Create the systemd service with TTY hijacking
cat > "$WORK_DIR/etc/systemd/system/nodeos.service" <<'EOF'
[Unit]
Description=NodeOS 2.0 boot status
After=network.target getty.target
Conflicts=getty@tty1.service

[Service]
Type=simple
WorkingDirectory=/opt/nodeos
ExecStart=/usr/bin/node /opt/nodeos/src/index.js
StandardOutput=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes

[Install]
WantedBy=multi-user.target
EOF

echo "🔹 Installing packages..."
chroot "$WORK_DIR" /bin/bash -lc "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends nodejs systemd-sysv linux-image-amd64 grub2-common grub-pc-bin xorriso live-boot live-boot-initramfs-tools squashfs-tools" >/dev/null

# Enable the NodeOS service
chroot "$WORK_DIR" /bin/bash -lc "systemctl enable nodeos.service"

# Compress the root filesystem into a SquashFS image
mkdir -p "$ISO_ROOT/live"
echo "🔹 Creating squashfs image..."
mksquashfs "$WORK_DIR" "$ISO_ROOT/live/filesystem.squashfs" -e boot -comp xz >/dev/null

# Extract kernel and initrd for the ISO bootloader
KERNEL_FILE="$(find "$WORK_DIR/boot" -maxdepth 1 -type f -name 'vmlinuz-*' | head -n 1)"
INITRD_FILE="$(find "$WORK_DIR/boot" -maxdepth 1 -type f -name 'initrd.img-*' | head -n 1)"

if [ -z "$KERNEL_FILE" ]; then
  echo "No Debian kernel found in $WORK_DIR/boot" >&2
  exit 1
fi

cp "$KERNEL_FILE" "$ISO_ROOT/boot/vmlinuz"
cp "$INITRD_FILE" "$ISO_ROOT/boot/initrd.img"

# Generate GRUB configuration for a Live System
cat > "$ISO_ROOT/boot/grub/grub.cfg" <<'EOF'
set timeout=5
set default=0

menuentry "NodeOS 2.0 (Debian)" {
    linux /boot/vmlinuz boot=live components quiet splash
    initrd /boot/initrd.img
}
EOF

echo "🔹 Generating ISO..."
grub-mkrescue -o "$OUT_DIR/$ISO_NAME" "$ISO_ROOT" >/dev/null

echo "✅ Created ISO: $OUT_DIR/$ISO_NAME"