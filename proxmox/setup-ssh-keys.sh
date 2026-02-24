#!/bin/bash
# ============================================================
# LKS 2025 – Setup SSH Key untuk Ansible (dari VM Juri)
# Jalankan SEKALI setelah semua VM hidup
# ============================================================

PASS="Skills39!"

# Semua target node (via MGMT interface)
HOSTS=(
  192.168.2.15   # fw
  192.168.2.11   # int-srv
  192.168.2.12   # mail
  192.168.2.13   # web-01
  192.168.2.14   # web-02
  192.168.2.16   # budi-clt
)

# Generate SSH key jika belum ada
if [ ! -f ~/.ssh/id_ed25519 ]; then
  echo "[+] Generating SSH key..."
  ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
fi

# Install sshpass untuk copy key tanpa manual input password
apt install -y sshpass

# Copy public key ke semua node
for host in "${HOSTS[@]}"; do
  echo "[+] Copying SSH key ke $host..."
  sshpass -p "$PASS" ssh-copy-id \
    -o StrictHostKeyChecking=no \
    -i ~/.ssh/id_ed25519.pub \
    root@$host
done

echo ""
echo "============================================================"
echo " SSH key sudah terpasang di semua node!"
echo " Test: ansible all -i /etc/ansible/inventory -m ping"
echo "============================================================"
