# Walkthrough – LKS 2025 Modul A Automation

**Proxmox + Debian 13 Trixie | Ansible + Bash**

---

## Topologi

```
                    [ internet ]
                         │
              ┌──────────┤      [ juri – VM 500 ]
              │       ┌──┴──┐   MGMT: 192.168.2.100
              │       │ fw  │   VM 501
              │       └──┬──┘   WAN: 100.100.100.254
              │          │      INT: 10.10.10.254  DMZ: 10.10.20.254
    ┌─────────┼──────────┼────────────────────────────┐
    │  INT    │          │  DMZ                       │
    │  ┌──────┴─┐   ┌────┴──┐  ┌───────┐  ┌────────┐│
    │  │int-srv │   │ mail  │  │web-01 │  │ web-02 ││
    │  │ VM502  │   │ VM503 │  │ VM504 │  │ VM505  ││
    └────────────────────────────────────────────────-┘
              [ budi-clt – VM 506 ]  WAN: 100.100.100.100
```

| VM ID | Hostname | MGMT IP | Bridge |
|-------|----------|---------|--------|
| 500 | juri | 192.168.2.100 | vmbr0 + MGMT |
| 501 | fw | 192.168.2.15 | vmbr0 + INT + DMZ + MGMT |
| 502 | int-srv | 192.168.2.11 | INT + MGMT |
| 503 | mail | 192.168.2.12 | DMZ + MGMT |
| 504 | web-01 | 192.168.2.13 | DMZ + MGMT |
| 505 | web-02 | 192.168.2.14 | DMZ + MGMT |
| 506 | budi-clt | 192.168.2.16 | vmbr0 + MGMT |

---

## Persiapan Template (Sekali Saja)

Template VM ID **100** harus punya cloud-init:

```bash
# Ubah template jadi VM biasa, start, masuk console
qm set 100 --template 0
qm start 100
# Login ke VM 100 via Proxmox console (root / Skills39!)

apt update
apt install -y cloud-init qemu-guest-agent
systemctl enable cloud-init-local cloud-init cloud-config cloud-final
systemctl enable qemu-guest-agent
poweroff

# Convert kembali ke template
qm template 100
```

---

## Alur Automation (Step by Step)

### Step 1 – Di Proxmox Host: Buat Bridge & VM

```bash
# Clone repo
git clone https://github.com/Areyoufunn/itnsa-jatim-2025.git /opt/lks
cd /opt/lks

# Buat bridge INT, DMZ, MGMT (sekali saja)
bash proxmox/setup-bridges.sh

# Buat 7 VM dari template 100
bash proxmox/create-vms.sh

# Tunggu ~1 menit sampai semua VM boot
```

### Step 2 – Setup SSH Key dari VM Juri

```bash
# SSH ke juri
ssh root@192.168.2.100
# password: Skills39!

# Clone repo di juri
apt install -y git
git clone https://github.com/Areyoufunn/itnsa-jatim-2025.git /opt/lks

# Generate SSH key & copy ke semua node
bash /opt/lks/proxmox/setup-ssh-keys.sh

# Install Ansible
apt install -y ansible
```

### Step 3 – Copy Ansible & Jalankan

```bash
# Copy ansible config ke /etc/ansible
cp -r /opt/lks/ansible/* /etc/ansible/

# Test koneksi
ansible all -i /etc/ansible/inventory -m ping

# Jalankan SEMUA konfigurasi
ansible-playbook /etc/ansible/site.yml

# Playbook wajib soal
ansible-playbook /etc/ansible/01-user.yml -e user_name=developer
ansible-playbook /etc/ansible/02-web-int.yml
```

### Step 4 – WireGuard Key Exchange

```bash
# Ambil key dari fw dan budi-clt
SERVER_PUB=$(ssh root@192.168.2.15 cat /etc/wireguard/server.pub)
CLIENT_PUB=$(ssh root@192.168.2.16 cat /etc/wireguard/client.pub)
PSK=$(ssh root@192.168.2.15 cat /etc/wireguard/psk.key)

# Update config kedua sisi
ssh root@192.168.2.15 "sed -i \"s|REPLACE_WITH_CLIENT_PUBKEY|$CLIENT_PUB|;s|REPLACE_WITH_PSK|$PSK|\" /etc/wireguard/wg0.conf"
ssh root@192.168.2.16 "sed -i \"s|REPLACE_WITH_SERVER_PUBKEY|$SERVER_PUB|;s|REPLACE_WITH_PSK|$PSK|\" /etc/wireguard/wg0.conf"

# Restart WireGuard
ssh root@192.168.2.15 systemctl restart wg-quick@wg0
ssh root@192.168.2.16 systemctl restart wg-quick@wg0
```

---

## Reset / Ulang dari Awal

```bash
# Di Proxmox host
bash /opt/lks/proxmox/delete-vms.sh   # hapus semua VM
bash /opt/lks/proxmox/create-vms.sh   # buat ulang
```

---

## Verifikasi

```bash
# DNS
dig @10.10.10.10 www.itnsa.id        # → 100.100.100.254
dig @10.10.10.10 vrrp.itnsa.id       # → 10.10.20.100

# LDAP
ldapsearch -x -H ldap://10.10.10.10 -b "dc=itnsa,dc=id" uid=budi

# CA
openssl verify -CAfile /opt/grading/ca/ca.pem /opt/grading/ca/web.pem

# Web
curl -sk https://10.10.20.100        # → Hello from web-01/web-02

# Mail
echo "test" | mail -s "test" budi.sudarsono@itnsa.id

# WireGuard
wg show
```

---

## Catatan Debian 13 Trixie

| Service | Catatan |
|---------|---------|
| Dovecot 2.4+ | `hosts=` bukan `ldap_url=` |
| cloud-init | Enable 4 service: `cloud-init-local`, `cloud-init`, `cloud-config`, `cloud-final` |
| nftables | Default, tidak perlu install |
| WireGuard | Built-in kernel, install `wireguard-tools` saja |
