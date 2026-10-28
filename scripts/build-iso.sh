#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$ROOT_DIR/build/debian-rootfs"
ISO_ROOT="$ROOT_DIR/build/iso-root"
OUT_DIR="$ROOT_DIR/dist"
ISO_NAME="${1:-nodeos-debian-live.iso}"
DEBIAN_MIRROR="${DEBIAN_MIRROR:-http://deb.debian.org/debian}"

for cmd in debootstrap grub-mkrescue rsync; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required tool: $cmd" >&2
    echo "Install it on Debian with: sudo apt-get install debootstrap grub-pc-bin xorriso rsync" >&2
    exit 1
  fi
done

mkdir -p "$OUT_DIR" "$ISO_ROOT/boot/grub"
rm -rf "$WORK_DIR" "$ISO_ROOT"/*

if [ ! -d "$WORK_DIR" ]; then
  echo "Bootstrapping Debian base system..."
  debootstrap --variant=minbase --arch=amd64 bookworm "$WORK_DIR" "$DEBIAN_MIRROR"
fi

# Copy the NodeOS project into the Debian filesystem.
mkdir -p "$WORK_DIR/opt/nodeos"
cp -a "$ROOT_DIR/src" "$ROOT_DIR/package.json" "$ROOT_DIR/README.md" "$ROOT_DIR/.gitignore" "$WORK_DIR/opt/nodeos/"

cat > "$WORK_DIR/opt/nodeos/run-nodeos.sh" <<'EOF'
#!/usr/bin/env bash
set -e
cd /opt/nodeos
node src/index.js
EOF
chmod +x "$WORK_DIR/opt/nodeos/run-nodeos.sh"

cat > "$WORK_DIR/etc/systemd/system/nodeos.service" <<'EOF'
[Unit]
Description=NodeOS 2.0 boot status
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/nodeos
ExecStart=/usr/bin/node /opt/nodeos/src/index.js

[Install]
WantedBy=multi-user.target
EOF

chroot "$WORK_DIR" /bin/bash -lc "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends nodejs systemd-sysv linux-image-amd64 grub2-common grub-pc-bin xorriso" >/dev/null

# Prepare a live ISO root filesystem.
rsync -a --delete "$WORK_DIR/" "$ISO_ROOT/"

# Ensure a kernel is available in the ISO root layout.
if [ -n "$(find "$WORK_DIR/boot" -maxdepth 1 -type f -name 'vmlinuz-*' -print -quit)" ]; then
  KERNEL_FILE="$(find "$WORK_DIR/boot" -maxdepth 1 -type f -name 'vmlinuz-*' | head -n 1)"
  INITRD_FILE="$(find "$WORK_DIR/boot" -maxdepth 1 -type f -name 'initrd.img-*' | head -n 1)"
  cp "$KERNEL_FILE" "$ISO_ROOT/boot/vmlinuz"
  cp "$INITRD_FILE" "$ISO_ROOT/boot/initrd.img"
else
  echo "No Debian kernel found in $WORK_DIR/boot" >&2
  exit 1
fi

cat > "$ISO_ROOT/boot/grub/grub.cfg" <<'EOF'
set timeout=5
set default=0

menuentry "NodeOS 2.0 (Debian)" {
    linux /boot/vmlinuz root=/dev/ram0 rw console=tty0
    initrd /boot/initrd.img
}
EOF

grub-mkrescue -o "$OUT_DIR/$ISO_NAME" "$ISO_ROOT" >/dev/null

echo "Created ISO: $OUT_DIR/$ISO_NAME"
