#!/usr/bin/env bash

set -euo pipefail

cleanup() {
    echo "[!] Error occurred. Cleaning up VM ${TEMPLATE_ID}..."

    if qm status "$TEMPLATE_ID" &>/dev/null; then
        qm destroy "$TEMPLATE_ID" --destroy-unreferenced-disks 1 --purge 1 || true
    fi
}

trap cleanup ERR

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <qcow2-image>"
    exit 1
fi

QCOW2_IMAGE="$1"

read -rp "Template ID: " TEMPLATE_ID
read -rp "Template name: " TEMPLATE_NAME
read -rp "Storage: " STORAGE

BRIDGE="vmbr0"
TAGS="template"

if [[ ! -f "$QCOW2_IMAGE" ]]; then
    echo "QCOW2 image not found: $QCOW2_IMAGE"
    exit 1
fi

echo "[+] Creating VM..."

qm create "$TEMPLATE_ID" \
    --name "$TEMPLATE_NAME" \
    --memory 2048 \
    --cores 1 \
    --cpu host \
    --net0 virtio,bridge="$BRIDGE" \
    --tags "$TAGS"

echo "[+] Importing disk..."

qm importdisk "$TEMPLATE_ID" "$QCOW2_IMAGE" "$STORAGE"

echo "[+] Attaching disk..."

qm set "$TEMPLATE_ID" \
    --scsihw virtio-scsi-pci \
    --scsi0 "${STORAGE}:${TEMPLATE_ID}/vm-${TEMPLATE_ID}-disk-0.raw"

echo "[+] Adding cloud-init..."

qm set "$TEMPLATE_ID" \
    --ide2 "${STORAGE}:cloudinit"

echo "[+] Configuring boot..."

qm set "$TEMPLATE_ID" \
    --boot c \
    --bootdisk scsi0 \
    --serial0 socket \
    --vga serial0 \
    --agent enabled=1

echo "[+] Converting to template..."

qm template "$TEMPLATE_ID"

trap - ERR

echo "[+] Template created successfully."