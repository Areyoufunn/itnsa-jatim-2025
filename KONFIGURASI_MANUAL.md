# 📘 LKS ITNSA Jatim 2025 – Panduan Konfigurasi Manual (Lengkap)

> Dokumen ini berisi **seluruh langkah konfigurasi manual** dari awal sampai akhir
> berdasarkan soal **Modul A – Linux Environment** LKS Provinsi Jawa Timur 2025.

---

## 📋 Daftar Isi

1. [Info Umum & Topologi](#1-info-umum--topologi)
2. [Persiapan Proxmox (VM & Network)](#2-persiapan-proxmox)
3. [Part 1 – INT Server (DNS + LDAP + CA + Ansible)](#3-part-1--int-server)
4. [Part 2 – DMZ (Mail + HA Web)](#4-part-2--dmz)
5. [Part 3 – Firewall (nftables + WireGuard VPN)](#5-part-3--firewall)
6. [Part 4 – Client](#6-part-4--client)
7. [Verifikasi & Testing](#7-verifikasi--testing)

---

## 1. Info Umum & Topologi

### Login Credentials

| Field | Value |
|-------|-------|
| Username | `root` / `user` |
| Password | `Skills39!` |
| Timezone | `Asia/Jakarta` |

### Daftar Server

| FQDN | IP Address | Services |
|------|-----------|----------|
| `fw.itnsa.id` | INT: `10.10.10.254/24`, DMZ: `10.10.20.254/24`, WAN: `100.100.100.254/24`, MGMT: `192.168.2.15/24` | Firewall, VPN |
| `int-srv.itnsa.id` | INT: `10.10.10.10/24`, MGMT: `192.168.2.11/24` | DNS, LDAP, CA, Ansible |
| `mail.itnsa.id` | DMZ: `10.10.20.10/24`, MGMT: `192.168.2.12/24` | Postfix, Dovecot |
| `web-01.itnsa.id` | DMZ: `10.10.20.21/24`, MGMT: `192.168.2.13/24` | Keepalived (MASTER), HAProxy, Nginx |
| `web-02.itnsa.id` | DMZ: `10.10.20.22/24`, MGMT: `192.168.2.14/24` | Keepalived (BACKUP), HAProxy, Nginx |
| `budi-clt.itnsa.id` | WAN: `100.100.100.100/24`, MGMT: `192.168.2.16/24` | VPN Client, Email Client |

### Topologi Jaringan

```
                    ┌──────────┐
                    │ Internet │
                    └────┬─────┘
                         │
              ┌──────────┤         ┌──────────────┐
              │      WAN │         │  budi-clt    │
              │      ┌───┴──┐      │  100.100.100 │
              │      │  fw  │      │       .100   │
              │      └───┬──┘      └──────────────┘
              │          │
    ┌─────────┼──────────┼─────────────────────┐
    │  INT    │          │  DMZ                │
    │         │          │                     │
    │  ┌──────┴─┐   ┌────┴──┐  ┌──────┐  ┌────┴───┐
    │  │int-srv │   │ mail  │  │web01 │  │ web02  │
    │  └────────┘   └───────┘  └──────┘  └────────┘
    └────────────────────────────────────────────────┘
```

---

## 2. Persiapan Proxmox

### 2.1 Buat Network Bridges di Proxmox Host

Jalankan **SEKALI** di Proxmox host sebelum membuat VM:

```bash
cat >> /etc/network/interfaces << 'EOF'

# INT – Internal Network (10.10.10.0/24)
auto INT
iface INT inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0

# DMZ – Demilitarized Zone (10.10.20.0/24)
auto DMZ
iface DMZ inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0

# MGMT – Management Network (192.168.2.0/24)
auto MGMT
iface MGMT inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
EOF

ifreload -a
```

### 2.2 Buat Semua VM (via Cloud-Init Template)

> **Prasyarat:** Template VM ID `100` (Debian 13 Trixie + cloud-init) sudah ada.

```bash
TEMPLATE=100
STORAGE="local-lvm"
PASS="Skills39!"

# --- Helper function ---
clone_vm() {
  local id=$1 name=$2 mem=$3
  qm clone $TEMPLATE $id --name "$name" --full 1 --storage $STORAGE
  qm set $id --memory $mem --cores 2 --onboot 1
  qm set $id --ciuser root --cipassword "$PASS"
  qm set $id --searchdomain itnsa.id --nameserver 8.8.8.8
  qm set $id --ide2 $STORAGE:cloudinit 2>/dev/null || true
}
```

| VM ID | Hostname | RAM | Interface | IP Address |
|-------|----------|-----|-----------|-----------|
| 500 | juri | 2048 | WAN(DHCP) + MGMT | `192.168.2.100/24` |
| 501 | fw | 1024 | WAN(DHCP) + INT + DMZ + MGMT | `10.10.10.254/24`, `10.10.20.254/24`, `192.168.2.15/24` |
| 502 | int-srv | 2048 | INT + MGMT | `10.10.10.10/24` (gw: `10.10.10.254`), `192.168.2.11/24` |
| 503 | mail | 1024 | DMZ + MGMT | `10.10.20.10/24` (gw: `10.10.20.254`), `192.168.2.12/24` |
| 504 | web-01 | 1024 | DMZ + MGMT | `10.10.20.21/24` (gw: `10.10.20.254`), `192.168.2.13/24` |
| 505 | web-02 | 1024 | DMZ + MGMT | `10.10.20.22/24` (gw: `10.10.20.254`), `192.168.2.14/24` |
| 506 | budi-clt | 1024 | WAN(DHCP) + MGMT | `192.168.2.16/24` |

Contoh pembuatan VM fw:

```bash
clone_vm 501 "fw" 1024
qm set 501 \
  --net0 virtio,bridge=vmbr0 \
  --net1 virtio,bridge=INT \
  --net2 virtio,bridge=DMZ \
  --net3 virtio,bridge=MGMT \
  --ipconfig0 ip=dhcp \
  --ipconfig1 ip=10.10.10.254/24 \
  --ipconfig2 ip=10.10.20.254/24 \
  --ipconfig3 ip=192.168.2.15/24
qm start 501
```

### 2.3 Setup SSH Key dari Juri

Dari VM **juri** (`192.168.2.100`):

```bash
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
apt install -y sshpass

for host in 192.168.2.15 192.168.2.11 192.168.2.12 192.168.2.13 192.168.2.14 192.168.2.16; do
  sshpass -p "Skills39!" ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519.pub root@$host
done
```

---

## 3. Part 1 – INT Server

> Semua perintah di bawah dijalankan di **`int-srv`** (`10.10.10.10`)

---

### 3.1 DNS Server (BIND9)

#### Install

```bash
apt update && apt install -y bind9 bind9utils
```

#### Konfigurasi `/etc/bind/named.conf.options`

```bash
cat > /etc/bind/named.conf.options << 'EOF'
options {
    directory "/var/cache/bind";
    forwarders { 8.8.8.8; };
    dnssec-validation no;
    listen-on { any; };
    allow-query { any; };
};
EOF
```

#### Konfigurasi `/etc/bind/named.conf.local`

```bash
cat > /etc/bind/named.conf.local << 'EOF'
zone "itnsa.id" {
    type master;
    file "/etc/bind/db.itnsa.id";
};

zone "10.10.10.in-addr.arpa" {
    type master;
    file "/etc/bind/db.10.10.10";
};

zone "20.10.10.in-addr.arpa" {
    type master;
    file "/etc/bind/db.10.10.20";
};
EOF
```

#### Forward Zone `/etc/bind/db.itnsa.id`

```bash
cat > /etc/bind/db.itnsa.id << 'EOF'
$TTL 86400
@   IN  SOA  int-srv.itnsa.id. admin.itnsa.id. (
            2025010101 ; Serial
            3600       ; Refresh
            1800       ; Retry
            604800     ; Expire
            86400 )    ; Minimum

; NS Record
@          IN  NS   int-srv.itnsa.id.

; A Records – semua server
fw         IN  A    10.10.10.254
int-srv    IN  A    10.10.10.10
mail       IN  A    10.10.20.10
web-01     IN  A    10.10.20.21
web-02     IN  A    10.10.20.22
budi-clt   IN  A    100.100.100.100

; A Records – tambahan (sesuai soal)
www        IN  A    100.100.100.254
vrrp       IN  A    10.10.20.100

; CNAME
www.int    IN  CNAME vrrp.itnsa.id.

; MX Record
@          IN  MX   10 mail.itnsa.id.
EOF
```

#### Reverse Zone INT `/etc/bind/db.10.10.10`

```bash
cat > /etc/bind/db.10.10.10 << 'EOF'
$TTL 86400
@   IN  SOA  int-srv.itnsa.id. admin.itnsa.id. (
            2025010101 ; Serial
            3600       ; Refresh
            1800       ; Retry
            604800     ; Expire
            86400 )    ; Minimum

@   IN  NS   int-srv.itnsa.id.

10  IN  PTR  int-srv.itnsa.id.
254 IN  PTR  fw.itnsa.id.
EOF
```

#### Reverse Zone DMZ `/etc/bind/db.10.10.20`

```bash
cat > /etc/bind/db.10.10.20 << 'EOF'
$TTL 86400
@   IN  SOA  int-srv.itnsa.id. admin.itnsa.id. (
            2025010101 ; Serial
            3600       ; Refresh
            1800       ; Retry
            604800     ; Expire
            86400 )    ; Minimum

@   IN  NS   int-srv.itnsa.id.

10  IN  PTR  mail.itnsa.id.
21  IN  PTR  web-01.itnsa.id.
22  IN  PTR  web-02.itnsa.id.
100 IN  PTR  vrrp.itnsa.id.
254 IN  PTR  fw.itnsa.id.
EOF
```

#### Restart BIND9

```bash
systemctl enable named
systemctl restart named
```

#### Verifikasi DNS

```bash
dig @10.10.10.10 itnsa.id ANY
dig @10.10.10.10 www.itnsa.id
dig @10.10.10.10 www.int.itnsa.id
dig @10.10.10.10 -x 10.10.10.10
```

---

### 3.2 LDAP Server (slapd)

#### Install

```bash
apt update && apt install -y slapd ldap-utils debconf-utils
```

#### Konfigurasi via debconf

```bash
export DEBIAN_FRONTEND=noninteractive

debconf-set-selections <<< "slapd slapd/password1 password Skills39!"
debconf-set-selections <<< "slapd slapd/password2 password Skills39!"
debconf-set-selections <<< "slapd slapd/domain string itnsa.id"
debconf-set-selections <<< "slapd slapd/purge_database boolean true"

dpkg-reconfigure -f noninteractive slapd
```

#### Tambah User LDAP

Buat file `/tmp/users.ldif`:

```bash
cat > /tmp/users.ldif << 'EOF'
# OU Employees
dn: ou=Employees,dc=itnsa,dc=id
objectClass: organizationalUnit
ou: Employees

# User: boaz
dn: uid=boaz,ou=Employees,dc=itnsa,dc=id
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: boaz
cn: Boaz Salossa
sn: Salossa
mail: boaz.salossa@itnsa.id
userPassword: Skills39!
uidNumber: 1001
gidNumber: 1001
homeDirectory: /home/boaz
loginShell: /bin/bash

# User: budi
dn: uid=budi,ou=Employees,dc=itnsa,dc=id
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: budi
cn: Budi Sudarsono
sn: Sudarsono
mail: budi.sudarsono@itnsa.id
userPassword: Skills39!
uidNumber: 1002
gidNumber: 1002
homeDirectory: /home/budi
loginShell: /bin/bash
EOF
```

```bash
ldapadd -x -D "cn=admin,dc=itnsa,dc=id" -w "Skills39!" -f /tmp/users.ldif
```

#### Verifikasi LDAP

```bash
ldapsearch -x -D "cn=admin,dc=itnsa,dc=id" -w "Skills39!" -b "ou=Employees,dc=itnsa,dc=id"
```

---

### 3.3 Certificate Authority (CA) – OpenSSL

#### Install & Buat Directory

```bash
apt install -y openssl
mkdir -p /opt/grading/ca
```

#### Buat Root CA

```bash
# Generate CA private key
openssl genrsa -out /opt/grading/ca/ca.key 4096

# Generate Root CA certificate
openssl req -new -x509 -key /opt/grading/ca/ca.key \
  -out /opt/grading/ca/ca.pem -days 3650 \
  -subj "/C=ID/ST=Jakarta/O=ITNSA/CN=ITNSA Root CA"
```

#### Buat Sertifikat Web (SAN: www.itnsa.id, www.int.itnsa.id)

```bash
# Buat SAN config
cat > /opt/grading/ca/web-san.cnf << 'EOF'
[req]
distinguished_name = req_dn
req_extensions = v3_req
prompt = no
[req_dn]
C = ID
O = ITNSA
CN = www.itnsa.id
[v3_req]
subjectAltName = DNS:www.itnsa.id,DNS:www.int.itnsa.id
EOF

# Generate key + CSR
openssl genrsa -out /opt/grading/ca/web.key 2048
openssl req -new -key /opt/grading/ca/web.key \
  -out /opt/grading/ca/web.csr \
  -config /opt/grading/ca/web-san.cnf

# Sign dengan Root CA
openssl x509 -req -in /opt/grading/ca/web.csr \
  -CA /opt/grading/ca/ca.pem -CAkey /opt/grading/ca/ca.key \
  -CAcreateserial -out /opt/grading/ca/web.pem -days 365 \
  -extensions v3_req -extfile /opt/grading/ca/web-san.cnf
```

#### Buat Sertifikat Mail

```bash
openssl genrsa -out /opt/grading/ca/mail.key 2048
openssl req -new -key /opt/grading/ca/mail.key \
  -out /opt/grading/ca/mail.csr \
  -subj "/C=ID/O=ITNSA/CN=mail.itnsa.id"

openssl x509 -req -in /opt/grading/ca/mail.csr \
  -CA /opt/grading/ca/ca.pem -CAkey /opt/grading/ca/ca.key \
  -CAcreateserial -out /opt/grading/ca/mail.pem -days 365
```

#### Verifikasi Sertifikat

```bash
openssl x509 -in /opt/grading/ca/ca.pem -text -noout | head -20
openssl x509 -in /opt/grading/ca/web.pem -text -noout | grep -A2 "Subject Alternative"
openssl x509 -in /opt/grading/ca/mail.pem -text -noout | grep "Subject:"
```

### 3.4 Distribusi Sertifikat

#### Install CA cert di SEMUA server

Copy `ca.pem` ke semua server dan update trust store:

```bash
# Dari int-srv, SCP ke setiap server:
for host in 10.10.10.254 10.10.20.10 10.10.20.21 10.10.20.22 100.100.100.100; do
  scp -o StrictHostKeyChecking=no /opt/grading/ca/ca.pem root@$host:/usr/local/share/ca-certificates/itnsa-root-ca.crt
  ssh -o StrictHostKeyChecking=no root@$host "update-ca-certificates"
done

# Jangan lupa di int-srv sendiri:
cp /opt/grading/ca/ca.pem /usr/local/share/ca-certificates/itnsa-root-ca.crt
update-ca-certificates
```

#### Copy sertifikat ke mail & web servers

```bash
# Ke mail server
ssh root@10.10.20.10 "mkdir -p /opt/grading/ca"
scp /opt/grading/ca/{ca.pem,mail.pem,mail.key} root@10.10.20.10:/opt/grading/ca/

# Ke web-01 & web-02
for host in 10.10.20.21 10.10.20.22; do
  ssh root@$host "mkdir -p /opt/grading/ca"
  scp /opt/grading/ca/{ca.pem,web.pem,web.key} root@$host:/opt/grading/ca/
done
```

---

### 3.5 Ansible (dari int-srv)

#### Setup Ansible

```bash
apt install -y ansible
mkdir -p /etc/ansible/roles
```

#### `/etc/ansible/ansible.cfg`

```ini
[defaults]
inventory         = /etc/ansible/inventory
roles_path        = /etc/ansible/roles
host_key_checking = False
remote_user       = root
private_key_file  = ~/.ssh/id_ed25519

[privilege_escalation]
become = False
```

#### `/etc/ansible/inventory`

```ini
[int]
int-srv  ansible_host=192.168.2.11

[dmz_mail]
mail     ansible_host=192.168.2.12

[dmz_web]
web-01   ansible_host=192.168.2.13
web-02   ansible_host=192.168.2.14

[fw]
fw       ansible_host=192.168.2.15

[client]
budi-clt ansible_host=192.168.2.16

[all:vars]
ansible_user=root
```

#### Playbook `/etc/ansible/01-user.yml`

> **Soal:** Buat user di web-02 dengan password `Skills39!`, username dari variable.

```yaml
---
- name: Create user on web-02
  hosts: web-02
  tasks:
    - name: Create user {{ user_name }}
      ansible.builtin.user:
        name: "{{ user_name }}"
        password: "{{ 'Skills39!' | password_hash('sha512') }}"
        state: present
        create_home: true
        shell: /bin/bash
```

**Jalankan:**
```bash
ansible-playbook /etc/ansible/01-user.yml -e user_name=developer
```

#### Playbook `/etc/ansible/02-web-int.yml`

> **Soal:** Install Nginx di web-02, listen port 8081, tampilkan "This is web internal".

```yaml
---
- name: Install Nginx + vhost port 8081 on web-02
  hosts: web-02
  tasks:
    - name: Install nginx
      ansible.builtin.apt:
        name: nginx
        state: present
        update_cache: true

    - name: Create vhost port 8081
      ansible.builtin.copy:
        dest: /etc/nginx/sites-available/web-int
        content: |
          server {
              listen 8081;
              server_name _;
              root /var/www/web-int;
              index index.html;
          }

    - name: Create web root
      ansible.builtin.file:
        path: /var/www/web-int
        state: directory
        mode: '0755'

    - name: Create index.html
      ansible.builtin.copy:
        dest: /var/www/web-int/index.html
        content: "This is web internal\n"

    - name: Enable vhost
      ansible.builtin.file:
        src: /etc/nginx/sites-available/web-int
        dest: /etc/nginx/sites-enabled/web-int
        state: link

    - name: Restart nginx
      ansible.builtin.service:
        name: nginx
        state: restarted
        enabled: true
```

**Jalankan:**
```bash
ansible-playbook /etc/ansible/02-web-int.yml
```

---

## 4. Part 2 – DMZ

---

### 4.1 Mail Server (`mail.itnsa.id` – `10.10.20.10`)

> Semua perintah dijalankan di **mail server**.

#### Install Paket

```bash
export DEBIAN_FRONTEND=noninteractive
apt update && apt install -y postfix dovecot-imapd dovecot-ldap mailutils
```

#### Buat User vmail

```bash
useradd -u 5000 -d /var/mail/vhosts -s /usr/sbin/nologin vmail
mkdir -p /var/mail/vhosts/itnsa.id/budi/Maildir
mkdir -p /var/mail/vhosts/itnsa.id/boaz/Maildir
chown -R vmail:vmail /var/mail/vhosts
```

#### Konfigurasi Postfix – `/etc/postfix/main.cf`

```bash
cat > /etc/postfix/main.cf << 'EOF'
# Postfix – main.cf
myhostname = mail.itnsa.id
mydomain = itnsa.id
myorigin = $mydomain
mydestination =
mynetworks = 127.0.0.0/8 10.10.10.0/24 10.10.20.0/24

# Virtual Mailbox
virtual_mailbox_domains = itnsa.id
virtual_mailbox_base = /var/mail/vhosts
virtual_mailbox_maps = hash:/etc/postfix/vmailbox
virtual_minimum_uid = 100
virtual_uid_maps = static:5000
virtual_gid_maps = static:5000

# TLS
smtpd_tls_cert_file = /opt/grading/ca/mail.pem
smtpd_tls_key_file  = /opt/grading/ca/mail.key
smtpd_tls_security_level = may
smtp_tls_security_level  = may
EOF
```

#### Buat Virtual Mailbox Map

```bash
cat > /etc/postfix/vmailbox << 'EOF'
boaz.salossa@itnsa.id    itnsa.id/boaz/Maildir/
budi.sudarsono@itnsa.id  itnsa.id/budi/Maildir/
EOF

postmap /etc/postfix/vmailbox
```

#### Konfigurasi Dovecot – `/etc/dovecot/dovecot.conf`

> **PENTING:** Dovecot 2.4.1 (Debian 13/Trixie) menggunakan syntax baru.
> Setting LDAP harus **inline** dengan prefix `ldap_`, `passdb_ldap_`, dan `userdb_ldap_`.

```bash
cat > /etc/dovecot/dovecot.conf << 'EOF'
dovecot_config_version = 2.4.1
dovecot_storage_version = 2.4.1

protocols = imap

# TLS (Dovecot 2.4 syntax)
ssl = required
ssl_server {
  cert_file = /opt/grading/ca/mail.pem
  key_file  = /opt/grading/ca/mail.key
}

# Auth
auth_mechanisms = plain login

# LDAP connection settings (global, prefix: ldap_)
ldap_uris             = ldap://10.10.10.10
ldap_auth_dn          = cn=admin,dc=itnsa,dc=id
ldap_auth_dn_password = Skills39!
ldap_base             = ou=Employees,dc=itnsa,dc=id

# passdb (prefix: passdb_ldap_)
passdb ldap {
  passdb_ldap_bind   = yes
  passdb_ldap_filter = (&(objectClass=inetOrgPerson)(uid=%u))
}

# userdb (prefix: userdb_ldap_)
userdb ldap {
  userdb_ldap_filter = (&(objectClass=inetOrgPerson)(uid=%u))
  userdb_fields {
    uid  = 5000
    gid  = 5000
    home = /var/mail/vhosts/%Ld/%Ln
    mail = maildir:/var/mail/vhosts/%Ld/%Ln/Maildir
  }
}

# Maildir (Dovecot 2.4: mail_location di-split jadi mail_driver + mail_path)
mail_driver = maildir
mail_path = /var/mail/vhosts/%d/%n/Maildir

# Namespace
namespace inbox {
  inbox = yes
}
EOF
```

> ⚠️ **Catatan Dovecot 2.4.1:**
> - `dovecot_config_version` dan `dovecot_storage_version` WAJIB ada di baris pertama
> - SSL pakai block `ssl_server { cert_file = ...; key_file = ...; }`
> - LDAP setting pakai prefix: `ldap_uris` (bukan `hosts`), `ldap_auth_dn` (bukan `dn`), `ldap_auth_dn_password` (bukan `dnpass`)
> - Setting passdb: `passdb_ldap_bind`, `passdb_ldap_filter`
> - Setting userdb: `userdb_ldap_filter`, `userdb_fields { ... }` (block syntax)
> - `mail_location` di-split jadi `mail_driver` (format: maildir/mbox/sdbox) + `mail_path` (path directory)

#### Restart Services

```bash
systemctl enable postfix dovecot
systemctl restart postfix dovecot
```

#### Verifikasi Mail

```bash
# Cek Dovecot config
dovecot -n

# Test kirim email ke budi
echo "Test email" | mail -s "Test" budi.sudarsono@itnsa.id

# Cek maildir
ls -la /var/mail/vhosts/itnsa.id/budi/Maildir/
```

---

### 4.2 Web Servers (Nginx) – `web-01` & `web-02`

> Jalankan di **kedua** web server.

#### Install Nginx

```bash
apt update && apt install -y nginx
```

#### Konfigurasi Vhost Port 8080

```bash
cat > /etc/nginx/sites-available/web << 'EOF'
server {
    listen 8080;
    server_name _;
    root /var/www/html;
    index index.html;
}
EOF

ln -sf /etc/nginx/sites-available/web /etc/nginx/sites-enabled/web
rm -f /etc/nginx/sites-enabled/default
```

#### Buat index.html

```bash
# Di web-01:
echo "Hello from web-01" > /var/www/html/index.html

# Di web-02:
echo "Hello from web-02" > /var/www/html/index.html
```

#### Restart Nginx

```bash
systemctl enable nginx
systemctl restart nginx
```

---

### 4.3 HAProxy + Keepalived – `web-01` & `web-02`

> Jalankan di **kedua** web server.

#### Install

```bash
apt update && apt install -y haproxy keepalived
```

#### Gabung Sertifikat untuk HAProxy

```bash
mkdir -p /etc/haproxy/certs
cat /opt/grading/ca/web.pem /opt/grading/ca/web.key > /etc/haproxy/certs/web.pem
chmod 640 /etc/haproxy/certs/web.pem
```

#### Konfigurasi HAProxy – `/etc/haproxy/haproxy.cfg`

```bash
cat > /etc/haproxy/haproxy.cfg << 'EOF'
global
    log /dev/log local0
    maxconn 2000
    daemon

defaults
    log     global
    mode    http
    timeout connect 5s
    timeout client  50s
    timeout server  50s

# Frontend – HTTP redirect ke HTTPS
frontend http_in
    bind *:80
    redirect scheme https code 301

# Frontend – HTTPS dengan TLS termination
frontend https_in
    bind *:443 ssl crt /etc/haproxy/certs/web.pem
    http-response set-header via-proxy HOSTNAME_DISINI
    default_backend web_servers

# Backend – Load balance ke nginx port 8080
backend web_servers
    balance roundrobin
    server web01 10.10.20.21:8080 check
    server web02 10.10.20.22:8080 check
EOF
```

> **PENTING:** Ganti `HOSTNAME_DISINI` dengan hostname masing-masing server:
> - Di web-01: `via-proxy web-01`
> - Di web-02: `via-proxy web-02`

#### Konfigurasi Keepalived – `/etc/keepalived/keepalived.conf`

**Di web-01 (MASTER):**
```bash
cat > /etc/keepalived/keepalived.conf << 'EOF'
vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 101
    advert_int 1

    authentication {
        auth_type PASS
        auth_pass Skills39!
    }

    virtual_ipaddress {
        10.10.20.100/24 dev eth0
    }
}
EOF
```

**Di web-02 (BACKUP):**
```bash
cat > /etc/keepalived/keepalived.conf << 'EOF'
vrrp_instance VI_1 {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 100
    advert_int 1

    authentication {
        auth_type PASS
        auth_pass Skills39!
    }

    virtual_ipaddress {
        10.10.20.100/24 dev eth0
    }
}
EOF
```

#### Restart Services

```bash
systemctl enable haproxy keepalived
systemctl restart haproxy keepalived
```

#### Verifikasi HA

```bash
# Cek VIP
ip addr show eth0 | grep 10.10.20.100

# Test dari dalam DMZ
curl -k https://10.10.20.100
```

---

## 5. Part 3 – Firewall

> Semua perintah dijalankan di **fw** (`10.10.10.254`)

---

### 5.1 nftables Firewall

#### Install & Enable IP Forwarding

```bash
apt update && apt install -y nftables

echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-forward.conf
sysctl -p /etc/sysctl.d/99-forward.conf
```

#### Konfigurasi Rules – `/etc/nftables.conf`

```bash
cat > /etc/nftables.conf << 'EOF'
#!/usr/sbin/nft -f
# LKS 2025 – nftables ruleset untuk fw.itnsa.id
# Interface: eth0=WAN, eth1=INT, eth2=DMZ, eth3=MGMT

flush ruleset

define WAN  = eth0
define INT  = eth1
define DMZ  = eth2
define MGMT = eth3

define NET_INT  = 10.10.10.0/24
define NET_DMZ  = 10.10.20.0/24
define IP_DNS   = 10.10.10.10
define IP_VRRP  = 10.10.20.100
define IP_MAIL  = 10.10.20.10
define IP_LDAP  = 10.10.10.10

table inet filter {

    chain input {
        type filter hook input priority 0; policy drop;

        iif lo accept
        ct state established,related accept

        # [Soal 6] Allow semua traffic dari MGMT
        iif $MGMT accept

        # Allow ICMP
        ip protocol icmp accept

        # Allow SSH (JANGAN UBAH – soal memperingatkan)
        tcp dport 22 accept

        # [Soal 4] Allow WireGuard
        iif $WAN udp dport 51820 accept
    }

    chain forward {
        type filter hook forward priority 0; policy drop;

        ct state established,related accept

        # [Soal 1] INT & DMZ ke internet
        iif $INT oif $WAN accept
        iif $DMZ oif $WAN accept

        # [Soal 4] VPN client ke INT & DMZ (iifname karena wg0 belum tentu ada saat boot)
        iifname "wg0" oif $INT accept
        iifname "wg0" oif $DMZ accept

        # [Soal 5] Mail → LDAP (port 389)
        iif $DMZ oif $INT ip saddr $IP_MAIL ip daddr $IP_LDAP tcp dport 389 accept

        # [Soal 3] Port forward HTTP/HTTPS → VRRP (VIP)
        iif $WAN oif $DMZ ip daddr $IP_VRRP tcp dport { 80, 443 } accept

        # [Soal 3] Port forward DNS
        iif $WAN oif $INT ip daddr $IP_DNS tcp dport 53 accept
        iif $WAN oif $INT ip daddr $IP_DNS udp dport 53 accept
    }

    # [Soal 7] Default deny (policy drop sudah di atas)
    chain output {
        type filter hook output priority 0; policy accept;
    }
}

table ip nat {

    # [Soal 3] Port Forwarding (DNAT)
    chain prerouting {
        type nat hook prerouting priority -100;

        iif $WAN tcp dport { 80, 443 } dnat to $IP_VRRP
        iif $WAN tcp dport 53 dnat to $IP_DNS
        iif $WAN udp dport 53 dnat to $IP_DNS
    }

    # [Soal 2] NAT Masquerade
    chain postrouting {
        type nat hook postrouting priority 100;

        oif $WAN masquerade
    }
}
EOF
```

#### Cover Semua Requirement Soal

| Soal | Rule |
|------|------|
| 1. Internet access INT & DMZ | `iif $INT oif $WAN accept` + `iif $DMZ oif $WAN accept` |
| 2. NAT Masquerade | `oif $WAN masquerade` |
| 3. Port forward 80/443→VIP, 53→DNS | DNAT + forward rules |
| 4. VPN akses INT & DMZ | `iif wg0 oif $INT accept` + `iif wg0 oif $DMZ accept` |
| 5. Mail → LDAP | `iif $DMZ oif $INT ... tcp dport 389 accept` |
| 6. Allow MGMT | `iif $MGMT accept` |
| 7. Default deny | `policy drop` |

#### Apply & Enable

```bash
systemctl enable nftables
systemctl restart nftables
nft list ruleset  # verifikasi
```

---

### 5.2 WireGuard VPN Server

#### Install

```bash
apt install -y wireguard wireguard-tools
```

#### Generate Keys (di fw)

```bash
wg genkey | tee /etc/wireguard/server.key | wg pubkey > /etc/wireguard/server.pub
wg genpsk > /etc/wireguard/psk.key
chmod 600 /etc/wireguard/server.key /etc/wireguard/psk.key

# Catat ini – akan dipakai di client config:
cat /etc/wireguard/server.pub
cat /etc/wireguard/psk.key
```

#### Konfigurasi `/etc/wireguard/wg0.conf`

```bash
SERVER_PRIVKEY=$(cat /etc/wireguard/server.key)

cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $SERVER_PRIVKEY
Address    = 10.10.30.1/24
ListenPort = 51820

# Routing untuk client VPN
PostUp   = nft add rule ip nat postrouting oif eth0 masquerade
PostDown = nft delete rule ip nat postrouting oif eth0 masquerade

# === Client: budi-clt ===
[Peer]
# PublicKey diisi setelah generate key di budi-clt
PublicKey  = REPLACE_WITH_CLIENT_PUBKEY
PresharedKey = $(cat /etc/wireguard/psk.key)
AllowedIPs = 10.10.30.2/32
EOF

chmod 600 /etc/wireguard/wg0.conf
```

> ⚠️ **Setelah client generate key**, ganti `REPLACE_WITH_CLIENT_PUBKEY` dengan output `cat /etc/wireguard/client.pub` dari budi-clt.

#### Enable & Start

```bash
systemctl enable wg-quick@wg0
wg-quick up wg0
```

---

## 6. Part 4 – Client

> Semua perintah dijalankan di **budi-clt** (`100.100.100.100`)

### 6.1 Buat User Lokal

```bash
useradd -m -c "Budi Sudarsono" -s /bin/bash budi
echo "budi:Skills39!" | chpasswd

# Sudoer tanpa password
echo "budi ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/budi
chmod 440 /etc/sudoers.d/budi
```

### 6.2 WireGuard VPN Client

#### Install & Generate Keys

```bash
apt update && apt install -y wireguard wireguard-tools sudo

wg genkey | tee /etc/wireguard/client.key | wg pubkey > /etc/wireguard/client.pub
chmod 600 /etc/wireguard/client.key

# Catat public key ini → masukkan ke fw server config
cat /etc/wireguard/client.pub
```

#### Konfigurasi `/etc/wireguard/wg0.conf`

```bash
CLIENT_PRIVKEY=$(cat /etc/wireguard/client.key)

cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $CLIENT_PRIVKEY
Address    = 10.10.30.2/24
DNS        = 10.10.10.10

# Server: fw.itnsa.id
[Peer]
PublicKey    = REPLACE_WITH_SERVER_PUBKEY
PresharedKey = REPLACE_WITH_PSK
Endpoint     = 100.100.100.254:51820
AllowedIPs   = 0.0.0.0/0
PersistentKeepalive = 25
EOF

chmod 600 /etc/wireguard/wg0.conf
```

> **Ganti:**
> - `REPLACE_WITH_SERVER_PUBKEY` = output dari `cat /etc/wireguard/server.pub` di fw
> - `REPLACE_WITH_PSK` = output dari `cat /etc/wireguard/psk.key` di fw

#### Langkah Pertukaran Key

```
┌──────────────────────────────────────────────────────────┐
│ 1. Di fw:     cat /etc/wireguard/server.pub  → COPY     │
│ 2. Di fw:     cat /etc/wireguard/psk.key     → COPY     │
│ 3. Di client: paste ke wg0.conf (PublicKey & PSK)        │
│ 4. Di client: cat /etc/wireguard/client.pub  → COPY     │
│ 5. Di fw:     paste ke wg0.conf PublicKey peer           │
│ 6. Di fw:     wg-quick down wg0 && wg-quick up wg0      │
│ 7. Di client: wg-quick up wg0                            │
└──────────────────────────────────────────────────────────┘
```

#### Enable & Start

```bash
systemctl enable wg-quick@wg0
wg-quick up wg0
```

### 6.3 Verifikasi Client

```bash
# Test VPN tunnel
ping -c 3 10.10.10.10      # INT server via VPN
ping -c 3 10.10.20.10      # Mail server via VPN

# Test DNS via VPN
dig @10.10.10.10 www.itnsa.id

# Test HTTPS (via internet) 
curl -k https://www.itnsa.id

# Test HTTPS (via VPN)
curl -k https://www.int.itnsa.id
```

### 6.4 Email (Thunderbird)

Konfigurasi email di Thunderbird:

| Setting | Value |
|---------|-------|
| Name | Budi Sudarsono |
| Email | budi.sudarsono@itnsa.id |
| IMAP Server | mail.itnsa.id |
| IMAP Port | 993 (SSL/TLS) |
| SMTP Server | mail.itnsa.id |
| SMTP Port | 587 (STARTTLS) atau 25 |
| Username | budi |
| Password | Skills39! |

---

## 7. Verifikasi & Testing

### Checklist Final

| # | Test | Perintah / Cara |
|---|------|----------------|
| 1 | DNS resolve semua hostname | `dig @10.10.10.10 mail.itnsa.id` |
| 2 | DNS reverse lookup | `dig @10.10.10.10 -x 10.10.10.10` |
| 3 | LDAP users ada | `ldapsearch -x -b "dc=itnsa,dc=id" -H ldap://10.10.10.10` |
| 4 | CA cert valid | `openssl verify -CAfile /opt/grading/ca/ca.pem /opt/grading/ca/web.pem` |
| 5 | Postfix running | `systemctl status postfix` (di mail) |
| 6 | Dovecot running (no error) | `dovecot -n` (di mail) |
| 7 | Send email | `echo "test" \| mail -s "Test" budi.sudarsono@itnsa.id` |
| 8 | Nginx web-01 port 8080 | `curl http://10.10.20.21:8080` → "Hello from web-01" |
| 9 | Nginx web-02 port 8080 | `curl http://10.10.20.22:8080` → "Hello from web-02" |
| 10 | VIP active | `ip addr show` di web-01 → `10.10.20.100` |
| 11 | HAProxy HTTPS | `curl -k https://10.10.20.100` |
| 12 | HTTP redirect | `curl -I http://10.10.20.100` → `301 → https://` |
| 13 | via-proxy header | `curl -kI https://10.10.20.100` → `via-proxy: web-01/web-02` |
| 14 | Firewall default deny | `nft list ruleset` → policy drop |
| 15 | NAT masquerade | Dari int-srv: `ping 8.8.8.8` |
| 16 | Port forward HTTP | Dari WAN: `curl http://100.100.100.254` |
| 17 | WireGuard tunnel up | `wg show` (di fw dan client) |
| 18 | VPN → INT access | Dari client: `ping 10.10.10.10` |
| 19 | VPN → DMZ access | Dari client: `ping 10.10.20.10` |
| 20 | Ansible web-02 user | `ansible-playbook /etc/ansible/01-user.yml -e user_name=developer` |
| 21 | Ansible web-int | `ansible-playbook /etc/ansible/02-web-int.yml` → port 8081 |
| 22 | Email via Thunderbird | Login budi, kirim email ke diri sendiri |

---

> *Dokumen ini dibuat berdasarkan analisis soal LKS ITNSA Jatim 2025 – Modul A Linux Environment v1.0*
> *Semua konfigurasi telah disesuaikan untuk Debian 13 (Trixie) termasuk syntax Dovecot 2.4.1*
