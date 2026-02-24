# Walkthrough – Ansible Autoconfiguration LKS 2025

**Platform:** Proxmox + Debian 13 Trixie | **Total file:** 31

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

### Network Bridges (Proxmox)

| Bridge | Zona | Network |
|--------|------|---------|
| `vmbr0` | WAN | 100.100.100.0/24 |
| `vmbr-int` | INT | 10.10.10.0/24 |
| `vmbr-dmz` | DMZ | 10.10.20.0/24 |
| `vmbr-mgmt` | MGMT | 192.168.2.0/24 |

### Tabel VM

| VM ID | Hostname | MGMT IP | Interface |
|-------|----------|---------|-----------|
| **500** | **juri** | **192.168.2.100** | vmbr0 (DHCP) + vmbr-mgmt |
| 501 | fw.itnsa.id | 192.168.2.15 | vmbr0 + vmbr-int + vmbr-dmz + vmbr-mgmt |
| 502 | int-srv.itnsa.id | 192.168.2.11 | vmbr-int + vmbr-mgmt |
| 503 | mail.itnsa.id | 192.168.2.12 | vmbr-dmz + vmbr-mgmt |
| 504 | web-01.itnsa.id | 192.168.2.13 | vmbr-dmz + vmbr-mgmt |
| 505 | web-02.itnsa.id | 192.168.2.14 | vmbr-dmz + vmbr-mgmt |
| 506 | budi-clt.itnsa.id | 192.168.2.16 | vmbr0 + vmbr-mgmt |

---

## Struktur File

```
lks2025/
├── proxmox/
│   ├── setup-bridges.sh   ← buat bridge di Proxmox host (sekali)
│   └── create-vms.sh      ← clone 7 VM dari template ID 100
└── ansible/
    ├── ansible.cfg
    ├── inventory           ← host via MGMT IP
    ├── group_vars/all.yml  ← variabel: IP, domain, password
    ├── site.yml            ← master playbook
    ├── 01-user.yml         ← buat user (soal)
    ├── 02-web-int.yml      ← nginx port 8081 (soal)
    └── roles/
        ├── dns/            → BIND9 + zone itnsa.id
        ├── ldap/           → slapd + user boaz & budi
        ├── ca/             → OpenSSL Root CA + web/mail cert
        ├── mail/           → Postfix + Dovecot 2.4 + LDAP
        ├── haproxy/        → HAProxy + Keepalived VIP
        ├── nginx/          → Nginx port 8080
        ├── firewall/       → nftables ruleset
        ├── vpn/            → WireGuard server
        └── client/         → user budi + WireGuard client
```

---

## Alur Penggunaan

### 1. Di Proxmox Host

```bash
# Buat bridges (sekali saja)
bash setup-bridges.sh

# Cek template ID 100 tersedia
qm list | grep 100

# Buat semua VM
bash create-vms.sh
```

### 2. Copy Ansible ke VM Juri

```bash
scp -r ./ansible root@192.168.2.100:/etc/ansible
```

### 3. Konfigurasi dari VM Juri

```bash
ssh root@192.168.2.100

apt install -y ansible sshpass

# Test ping semua node
ansible all -i /etc/ansible/inventory -m ping

# Jalankan semua konfigurasi
ansible-playbook /etc/ansible/site.yml

# Playbook wajib soal
ansible-playbook /etc/ansible/01-user.yml -e user_name=developer
ansible-playbook /etc/ansible/02-web-int.yml
```

---

## Ringkasan Ansible Roles

| Role | Target | Service |
|------|--------|---------|
| `dns` | int-srv | BIND9, forward + reverse zone, semua A/CNAME/MX record |
| `ldap` | int-srv | slapd itnsa.id, OU=Employees, user boaz & budi |
| `ca` | int-srv | Root CA "ITNSA Root CA", web cert (SAN), mail cert → `/opt/grading/ca/` |
| `mail` | mail | Postfix virtual mailbox, Dovecot IMAP + LDAP auth, TLS, Maildir |
| `nginx` | web-01/02 | Nginx port 8080, `Hello from <hostname>` |
| `haproxy` | web-01/02 | HTTP→HTTPS redirect, TLS termination, LB, Keepalived VIP 10.10.20.100 |
| `firewall` | fw | nftables: masquerade NAT, DNAT 80/443→VIP, 53→DNS, default drop |
| `vpn` | fw | WireGuard server port 51820, PSK, tunnel 10.10.30.1/24 |
| `client` | budi-clt | User budi + sudoer nopasswd, WireGuard client 10.10.30.2/24 |

---

## Catatan Debian 13 Trixie

| Service | Catatan penting |
|---------|----------------|
| Dovecot 2.4+ | Gunakan `hosts=` bukan `ldap_url=` di dovecot-ldap.conf |
| nftables | Default firewall, tidak perlu install extra |
| WireGuard | Built-in kernel, cukup install `wireguard-tools` |

---

## WireGuard Key Exchange (Manual setelah site.yml)

> ⚠️ Public key server dan client perlu ditukar manual setelah deploy.

```bash
# Ambil server pubkey (dari fw)
ssh root@192.168.2.15 cat /etc/wireguard/server.pub

# Ambil PSK (dari fw)
ssh root@192.168.2.15 cat /etc/wireguard/psk.key

# Ambil client pubkey (dari budi-clt)
ssh root@192.168.2.16 cat /etc/wireguard/client.pub

# Edit wg0.conf di fw → isi REPLACE_WITH_CLIENT_PUBKEY & PSK
# Edit wg0.conf di budi-clt → isi REPLACE_WITH_SERVER_PUBKEY & PSK

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

# Web (dari budi-clt via VPN)
curl -sk https://10.10.20.100        # → Hello from web-01 / web-02

# Mail
echo "test" | mail -s "test" budi.sudarsono@itnsa.id

# WireGuard
wg show

# Idempoten check (changed=0 di run ke-2)
ansible-playbook /etc/ansible/01-user.yml -e user_name=developer
ansible-playbook /etc/ansible/02-web-int.yml
```
