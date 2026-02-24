# 🚀 ITNSA Jatim 2025 – LKS Modul A Automation

Automation penuh untuk **LKS 2025 Modul A – Linux Environment** menggunakan **Ansible** dan **Bash**, berbasis **Debian 13 Trixie** di atas **Proxmox**.

---

## 📋 Deskripsi

Repository ini berisi script automation untuk membangun infrastruktur jaringan LKS 2025:
- **Proxmox scripts** – clone 7 VM dari template secara otomatis
- **Ansible playbooks & roles** – konfigurasi semua service tanpa manual

---

## 🖧 Topologi

```
                    [ internet ]
                         │
              ┌──────────┤      [ juri – VM 500 ]
              │       ┌──┴──┐   Ansible controller
              │       │ fw  │   VM 501
              │       └──┬──┘
    ┌─────────┼──────────┼──────────────────────────┐
    │  INT    │          │  DMZ                     │
    │ [int-srv│   [mail] │  [web-01]   [web-02]     │
    │  VM502] │  VM503   │   VM504      VM505        │
    └──────────────────────────────────────────────-─┘
              [ budi-clt – VM 506 ]
```

| VM ID | Hostname | MGMT IP | Zona |
|-------|----------|---------|------|
| 500 | juri *(controller)* | 192.168.2.100 | WAN + MGMT |
| 501 | fw.itnsa.id | 192.168.2.15 | WAN + INT + DMZ + MGMT |
| 502 | int-srv.itnsa.id | 192.168.2.11 | INT + MGMT |
| 503 | mail.itnsa.id | 192.168.2.12 | DMZ + MGMT |
| 504 | web-01.itnsa.id | 192.168.2.13 | DMZ + MGMT |
| 505 | web-02.itnsa.id | 192.168.2.14 | DMZ + MGMT |
| 506 | budi-clt.itnsa.id | 192.168.2.16 | WAN + MGMT |

---

## 📁 Struktur Repository

```
├── proxmox/
│   ├── setup-bridges.sh   # Setup network bridge di Proxmox
│   └── create-vms.sh      # Clone VM dari template ID 100
├── ansible/
│   ├── ansible.cfg
│   ├── inventory
│   ├── group_vars/all.yml
│   ├── site.yml           # Master playbook
│   ├── 01-user.yml        # [Soal] Buat user developer
│   ├── 02-web-int.yml     # [Soal] Nginx vhost port 8081
│   └── roles/
│       ├── dns/           # BIND9
│       ├── ldap/          # slapd + users
│       ├── ca/            # OpenSSL Root CA + certs
│       ├── mail/          # Postfix + Dovecot 2.4
│       ├── haproxy/       # HAProxy + Keepalived
│       ├── nginx/         # Nginx port 8080
│       ├── firewall/      # nftables
│       ├── vpn/           # WireGuard server
│       └── client/        # WireGuard client + user budi
└── WALKTHROUGH.md
```

---

## ⚡ Quick Start

### 1. Proxmox – Setup & Create VMs
```bash
bash proxmox/setup-bridges.sh   # buat bridge (sekali)
bash proxmox/create-vms.sh      # clone 7 VM dari template 100
```

### 2. Copy Ansible ke VM Juri
```bash
scp -r ./ansible root@192.168.2.100:/etc/ansible
```

### 3. Jalankan dari VM Juri
```bash
ssh root@192.168.2.100
apt install -y ansible sshpass
ansible all -i /etc/ansible/inventory -m ping
ansible-playbook /etc/ansible/site.yml
```

### 4. Playbook Wajib Soal
```bash
ansible-playbook /etc/ansible/01-user.yml -e user_name=developer
ansible-playbook /etc/ansible/02-web-int.yml
```

---

## 🔧 Service yang Dikonfigurasi

| Service | Package | Node |
|---------|---------|------|
| DNS | bind9 | int-srv |
| LDAP | slapd | int-srv |
| CA | openssl | int-srv |
| Mail | postfix + dovecot | mail |
| Load Balancer | haproxy + keepalived | web-01/02 |
| Web Server | nginx | web-01/02 |
| Firewall | nftables | fw |
| VPN | wireguard | fw + budi-clt |

---

## 📝 Catatan Debian 13 Trixie

- **Dovecot 2.4+** – gunakan `hosts=` bukan `ldap_url=` di config LDAP
- **nftables** – sudah default, tidak perlu install manual
- **WireGuard** – built-in kernel, install `wireguard-tools` saja

---

## Login Default

| Field | Value |
|-------|-------|
| Username | root / user |
| Password | `Skills39!` |

---

*LKS Provinsi Jawa Timur 2025 – IT Network Systems Administration*
