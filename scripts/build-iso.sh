#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$ROOT_DIR/build/iso-root"
OUT_DIR="$ROOT_DIR/dist"
ISO_NAME="${1:-nodeos-live.iso}"

mkdir -p "$WORK_DIR/boot/grub" "$OUT_DIR"
rm -rf "$WORK_DIR"/*

cp -R "$ROOT_DIR/iso/." "$WORK_DIR/"

cat > "$WORK_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=5
set default=0

menuentry "NodeOS 2.0 Live" {
    linux /boot/vmlinuz root=/dev/ram0 rw console=tty0 splash
    initrd /boot/initrd.img
}
EOF

if ! command -v grub-mkrescue >/dev/null 2>&1; then
    echo "ERROR: grub-mkrescue is required to build the ISO." >&2
    echo "Install it with: apt-get install grub-pc-bin xorriso" >&2
    exit 1
fi

if [ ! -f "$WORK_DIR/boot/vmlinuz" ] || [ ! -f "$WORK_DIR/boot/initrd.img" ]; then
    echo "WARNING: No Linux kernel/initrd were found in $WORK_DIR/boot." >&2
    echo "The ISO will not boot until you add a real kernel and initramfs image." >&2
    echo "Expected files: $WORK_DIR/boot/vmlinuz and $WORK_DIR/boot/initrd.img" >&2
    exit 2
fi

grub-mkrescue -o "$OUT_DIR/$ISO_NAME" "$WORK_DIR" >/dev/null

echo "Created ISO: $OUT_DIR/$ISO_NAME"
