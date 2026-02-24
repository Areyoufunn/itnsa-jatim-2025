# Walkthrough – Ansible Autoconfiguration LKS 2025

**Platform:** Proxmox + Debian 13 Trixie | **Total file:** 32

---

## Topologi & VM IDs

```
                    [ internet ]
                         │
              ┌──────────┤      [ juri – VM 500 ]
              │       ┌──┴──┐   WAN: DHCP  MGMT: 192.168.2.100
              │       │ fw  │   VM 501
              │       └──┬──┘   WAN:100.100.100.254
              │          │      INT:10.10.10.254 / DMZ:10.10.20.254
    ┌─────────┼──────────┼─────────────────────────────┐
    │  INT    │          │  DMZ                        │
    │  ┌──────┴─┐   ┌────┴──┐  ┌────────┐  ┌─────────┐│
    │  │int-srv │   │ mail  │  │ web-01 │  │ web-02  ││
    │  │VM 502  │   │VM 503 │  │VM  504 │  │VM  505  ││
    └─────────────────────────────────────────────────-┘
                  [ budi-clt – VM 506 ]
                  WAN: 100.100.100.100  MGMT: 192.168.2.16
```

### Network Bridges (Proxmox Host)

| Bridge | Zona | Network |
|--------|------|---------|
| `vmbr0` | WAN | 100.100.100.0/24 |
| `INT` | INT | 10.10.10.0/24 |
| `DMZ` | DMZ | 10.10.20.0/24 |
| `MGMT` | MGMT | 192.168.2.0/24 |

> Interface di dalam VM juga diberi nama **INT**, **DMZ**, **MGMT** secara otomatis via udev rule (diatur oleh Ansible role `firewall`).

### Tabel VM

| VM ID | Hostname | MGMT IP | Bridge yang dipakai |
|-------|----------|---------|---------------------|
| **500** | **juri** | **192.168.2.100** | vmbr0 + MGMT |
| 501 | fw.itnsa.id | 192.168.2.15 | vmbr0 + INT + DMZ + MGMT |
| 502 | int-srv.itnsa.id | 192.168.2.11 | INT + MGMT |
| 503 | mail.itnsa.id | 192.168.2.12 | DMZ + MGMT |
| 504 | web-01.itnsa.id | 192.168.2.13 | DMZ + MGMT |
| 505 | web-02.itnsa.id | 192.168.2.14 | DMZ + MGMT |
| 506 | budi-clt.itnsa.id | 192.168.2.16 | vmbr0 + MGMT |

---

## Struktur File

```
lks2025/
├── proxmox/
│   ├── setup-bridges.sh    ← buat bridge INT, DMZ, MGMT di Proxmox host
│   ├── create-vms.sh       ← clone 7 VM dari template ID 100
│   └── setup-ssh-keys.sh   ← generate SSH key + copy ke semua node
└── ansible/
    ├── ansible.cfg          ← pakai SSH key (id_ed25519)
    ├── inventory            ← host via MGMT IP (tanpa password)
    ├── group_vars/all.yml   ← variabel: IP, domain, password
    ├── site.yml             ← master playbook
    ├── 01-user.yml          ← buat user (soal)
    ├── 02-web-int.yml       ← nginx port 8081 (soal)
    └── roles/
        ├── dns/             → BIND9 + zone itnsa.id
        ├── ldap/            → slapd + user boaz & budi
        ├── ca/              → OpenSSL Root CA + web/mail cert
        ├── mail/            → Postfix + Dovecot 2.4 + LDAP
        ├── haproxy/         → HAProxy + Keepalived VIP
        ├── nginx/           → Nginx port 8080
        ├── firewall/        → nftables + rename interface (WAN/INT/DMZ/MGMT)
        ├── vpn/             → WireGuard server
        └── client/          → user budi + WireGuard client
```

---

## Alur Penggunaan

### Step 1 – Di Proxmox Host

```bash
# Buat bridge INT, DMZ, MGMT (sekali saja)
bash proxmox/setup-bridges.sh

# Clone semua VM dari template 100
bash proxmox/create-vms.sh
```

### Step 2 – Clone repo ke VM Juri & Setup SSH Key

```bash
# Clone repo ke juri (repo public, tidak perlu login)
ssh root@192.168.2.100 "apt install -y git && \
  git clone https://github.com/Areyoufunn/itnsa-jatim-2025.git /opt/lks2025"

# Generate SSH key di juri & copy ke semua node (pakai sshpass sekali)
ssh root@192.168.2.100 "bash /opt/lks2025/proxmox/setup-ssh-keys.sh"
```

### Step 3 – Install Ansible & Jalankan dari Juri

```bash
ssh root@192.168.2.100

apt install -y ansible

# Pindah file ansible ke /etc/ansible
cp -r /opt/lks2025/ansible/* /etc/ansible/

# Test koneksi semua node via SSH key
ansible all -i /etc/ansible/inventory -m ping

# Jalankan semua konfigurasi
ansible-playbook /etc/ansible/site.yml

# Playbook wajib soal
ansible-playbook /etc/ansible/01-user.yml -e user_name=developer
ansible-playbook /etc/ansible/02-web-int.yml
```

---

## Ringkasan Ansible Roles

| Role | Target | Yang Dikonfigurasi |
|------|--------|--------------------|
| `dns` | int-srv | BIND9, zone itnsa.id, semua A/CNAME/MX record |
| `ldap` | int-srv | slapd itnsa.id, OU=Employees, user boaz & budi |
| `ca` | int-srv | Root CA "ITNSA Root CA", web cert (SAN), mail cert → `/opt/grading/ca/` |
| `mail` | mail | Postfix virtual mailbox, Dovecot IMAP + LDAP auth, TLS, Maildir |
| `nginx` | web-01/02 | Nginx port 8080, `Hello from <hostname>` |
| `haproxy` | web-01/02 | HTTP→HTTPS redirect, TLS termination, LB, Keepalived VIP |
| `firewall` | fw | udev rename (WAN/INT/DMZ/MGMT), nftables NAT + port forward |
| `vpn` | fw | WireGuard server port 51820, PSK, tunnel 10.10.30.1/24 |
| `client` | budi-clt | User budi + sudoer nopasswd, WireGuard client 10.10.30.2/24 |

---

## Catatan Debian 13 Trixie

| Service | Catatan |
|---------|---------|
| Dovecot 2.4+ | Gunakan `hosts=` bukan `ldap_url=` di dovecot-ldap.conf |
| nftables | Default firewall, tidak perlu install |
| WireGuard | Built-in kernel, install `wireguard-tools` saja |

---

## WireGuard Key Exchange (Manual setelah site.yml)

> ⚠️ Public key perlu ditukar manual antara fw dan budi-clt.

```bash
# Dari juri – ambil semua key sekaligus
SERVER_PUB=$(ssh root@192.168.2.15 cat /etc/wireguard/server.pub)
CLIENT_PUB=$(ssh root@192.168.2.16 cat /etc/wireguard/client.pub)
PSK=$(ssh root@192.168.2.15 cat /etc/wireguard/psk.key)

# Update wg0.conf di fw
ssh root@192.168.2.15 "sed -i 's/REPLACE_WITH_CLIENT_PUBKEY/$CLIENT_PUB/; s/REPLACE_WITH_PSK/$PSK/' /etc/wireguard/wg0.conf"

# Update wg0.conf di budi-clt
ssh root@192.168.2.16 "sed -i 's/REPLACE_WITH_SERVER_PUBKEY/$SERVER_PUB/; s/REPLACE_WITH_PSK/$PSK/' /etc/wireguard/wg0.conf"

# Restart kedua sisi
ssh root@192.168.2.15 systemctl restart wg-quick@wg0
ssh root@192.168.2.16 systemctl restart wg-quick@wg0
```

---

## Verifikasi Cepat

```bash
# DNS
dig @10.10.10.10 www.itnsa.id        # → 100.100.100.254
dig @10.10.10.10 vrrp.itnsa.id       # → 10.10.20.100

# LDAP
ldapsearch -x -H ldap://10.10.10.10 -b "dc=itnsa,dc=id" uid=budi

# CA
openssl verify -CAfile /opt/grading/ca/ca.pem /opt/grading/ca/web.pem

# Web
curl -sk https://10.10.20.100        # → Hello from web-01 / web-02

# Mail
echo "test" | mail -s "test" budi.sudarsono@itnsa.id

# WireGuard
wg show                              # di fw & budi-clt

# Idempoten (harus changed=0 di run ke-2)
ansible-playbook /etc/ansible/01-user.yml -e user_name=developer
ansible-playbook /etc/ansible/02-web-int.yml
```
