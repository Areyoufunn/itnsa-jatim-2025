# 🧪 LKS ITNSA Jatim 2025 – Panduan Testing Juri

> Dokumen ini berisi **semua perintah test** yang dijalankan dari VM **juri** (`192.168.2.100`)
> atau SSH ke masing-masing server untuk memverifikasi konfigurasi peserta.

---

## ⚙️ Persiapan Juri

```bash
# Pastikan bisa SSH ke semua node
for h in 192.168.2.11 192.168.2.12 192.168.2.13 192.168.2.14 192.168.2.15 192.168.2.16; do
  echo "=== $h ===" && ssh -o ConnectTimeout=3 root@$h hostname
done
```

---

## Part 1 – INT Server (`int-srv` / `192.168.2.11`)

### 1.1 DNS (BIND9)

```bash
ssh root@192.168.2.11 << 'TEST'
echo "=== DNS SERVICE ==="
systemctl is-active named && echo "✅ BIND9 running" || echo "❌ BIND9 not running"

echo ""
echo "=== FORWARD LOOKUP ==="
for name in fw int-srv mail web-01 web-02 budi-clt www vrrp; do
  result=$(dig +short @127.0.0.1 ${name}.itnsa.id A)
  echo "${name}.itnsa.id → $result"
done

echo ""
echo "=== CNAME: www.int.itnsa.id ==="
dig +short @127.0.0.1 www.int.itnsa.id CNAME
dig +short @127.0.0.1 www.int.itnsa.id A

echo ""
echo "=== MX Record ==="
dig +short @127.0.0.1 itnsa.id MX

echo ""
echo "=== REVERSE LOOKUP ==="
for ip in 10.10.10.10 10.10.10.254 10.10.20.10 10.10.20.21 10.10.20.22 10.10.20.100; do
  result=$(dig +short @127.0.0.1 -x $ip)
  echo "$ip → $result"
done
TEST
```

**Expected Results:**

| Test | Expected |
|------|----------|
| `fw.itnsa.id` | `10.10.10.254` |
| `int-srv.itnsa.id` | `10.10.10.10` |
| `mail.itnsa.id` | `10.10.20.10` |
| `web-01.itnsa.id` | `10.10.20.21` |
| `web-02.itnsa.id` | `10.10.20.22` |
| `budi-clt.itnsa.id` | `100.100.100.100` |
| `www.itnsa.id` | `100.100.100.254` |
| `vrrp.itnsa.id` | `10.10.20.100` |
| `www.int.itnsa.id` CNAME | `vrrp.itnsa.id.` |
| MX | `10 mail.itnsa.id.` |
| Reverse `10.10.10.10` | `int-srv.itnsa.id.` |
| Reverse `10.10.20.10` | `mail.itnsa.id.` |

---

### 1.2 LDAP (slapd)

```bash
ssh root@192.168.2.11 << 'TEST'
echo "=== LDAP SERVICE ==="
systemctl is-active slapd && echo "✅ slapd running" || echo "❌ slapd not running"

echo ""
echo "=== LDAP SEARCH: users ==="
ldapsearch -x -D "cn=admin,dc=itnsa,dc=id" -w "Skills39!" \
  -b "ou=Employees,dc=itnsa,dc=id" uid cn mail 2>/dev/null | grep -E "^(dn|uid|cn|mail):"

echo ""
echo "=== VERIFY USER: boaz ==="
ldapsearch -x -b "dc=itnsa,dc=id" "(uid=boaz)" mail 2>/dev/null | grep "mail:"

echo ""
echo "=== VERIFY USER: budi ==="
ldapsearch -x -b "dc=itnsa,dc=id" "(uid=budi)" mail 2>/dev/null | grep "mail:"
TEST
```

**Expected Results:**

| Test | Expected |
|------|----------|
| slapd running | ✅ |
| User boaz exists | `mail: boaz.salossa@itnsa.id` |
| User budi exists | `mail: budi.sudarsono@itnsa.id` |
| OU Employees exists | `dn: ou=Employees,dc=itnsa,dc=id` |

---

### 1.3 CA (Certificate Authority)

```bash
ssh root@192.168.2.11 << 'TEST'
echo "=== CA FILES ==="
ls -la /opt/grading/ca/{ca.pem,web.pem,mail.pem} 2>/dev/null && echo "✅ Files exist" || echo "❌ Missing files"

echo ""
echo "=== ROOT CA: CN ==="
openssl x509 -in /opt/grading/ca/ca.pem -noout -subject 2>/dev/null

echo ""
echo "=== ROOT CA: Key Usage & Basic Constraints ==="
openssl x509 -in /opt/grading/ca/ca.pem -noout -text 2>/dev/null | grep -A1 "Key Usage\|Basic Constraints"

echo ""
echo "=== WEB CERT: SAN ==="
openssl x509 -in /opt/grading/ca/web.pem -noout -text 2>/dev/null | grep -A1 "Subject Alternative"

echo ""
echo "=== WEB CERT: Verify Chain ==="
openssl verify -CAfile /opt/grading/ca/ca.pem /opt/grading/ca/web.pem

echo ""
echo "=== MAIL CERT: Subject ==="
openssl x509 -in /opt/grading/ca/mail.pem -noout -subject 2>/dev/null

echo ""
echo "=== MAIL CERT: Verify Chain ==="
openssl verify -CAfile /opt/grading/ca/ca.pem /opt/grading/ca/mail.pem
TEST
```

**Expected Results:**

| Test | Expected |
|------|----------|
| `ca.pem` subject | `CN = ITNSA Root CA` |
| CA Key Usage | `Certificate Sign` |
| CA Basic Constraints | `CA:TRUE` |
| `web.pem` SAN | `DNS:www.itnsa.id, DNS:www.int.itnsa.id` |
| `mail.pem` subject | `CN = mail.itnsa.id` |
| Web cert verify | `OK` |
| Mail cert verify | `OK` |

---

### 1.4 CA Installed di Semua Server

```bash
echo "=== CA TRUST CHECK ==="
for h in 192.168.2.11 192.168.2.12 192.168.2.13 192.168.2.14 192.168.2.15 192.168.2.16; do
  result=$(ssh root@$h "ls /usr/local/share/ca-certificates/itnsa-root-ca.crt 2>/dev/null && echo OK || echo MISSING")
  echo "$h: $result"
done
```

---

### 1.5 Ansible

```bash
ssh root@192.168.2.11 << 'TEST'
echo "=== ANSIBLE INSTALLED ==="
ansible --version | head -1

echo ""
echo "=== PING web-02 ==="
ansible web-02 -i /etc/ansible/inventory -m ping

echo ""
echo "=== 01-user.yml EXISTS ==="
ls -la /etc/ansible/01-user.yml

echo ""
echo "=== 02-web-int.yml EXISTS ==="
ls -la /etc/ansible/02-web-int.yml
TEST
```

#### Test Playbook 01-user.yml

```bash
ssh root@192.168.2.11 << 'TEST'
echo "=== RUN 01-user.yml ==="
ansible-playbook /etc/ansible/01-user.yml -e user_name=testjuri

echo ""
echo "=== VERIFY USER CREATED ==="
ssh root@192.168.2.14 "id testjuri"
TEST
```

#### Test Playbook 02-web-int.yml

```bash
ssh root@192.168.2.11 << 'TEST'
echo "=== RUN 02-web-int.yml ==="
ansible-playbook /etc/ansible/02-web-int.yml

echo ""
echo "=== VERIFY PORT 8081 ==="
curl -s http://192.168.2.14:8081
TEST
```

**Expected Results:**

| Test | Expected |
|------|----------|
| User `testjuri` on web-02 | `uid=...(testjuri)` |
| Port 8081 content | `This is web internal` |
| Playbook idempotent | Run 2x = `changed=0` |

---

## Part 2 – DMZ

### 2.1 Mail Server (`mail` / `192.168.2.12`)

```bash
ssh root@192.168.2.12 << 'TEST'
echo "=== POSTFIX ==="
systemctl is-active postfix && echo "✅ Postfix running" || echo "❌ Postfix not running"

echo ""
echo "=== DOVECOT ==="
systemctl is-active dovecot && echo "✅ Dovecot running" || echo "❌ Dovecot not running"

echo ""
echo "=== DOVECOT CONFIG CHECK ==="
dovecot -n 2>&1 | head -5
echo "Exit code: $?"

echo ""
echo "=== TLS CERT CHECK ==="
ls -la /opt/grading/ca/mail.pem /opt/grading/ca/mail.key 2>/dev/null && echo "✅ Certs exist" || echo "❌ Missing certs"

echo ""
echo "=== POSTFIX DOMAIN ==="
postconf mydomain
postconf virtual_mailbox_domains

echo ""
echo "=== MAILDIR EXISTS ==="
ls -d /var/mail/vhosts/itnsa.id/budi/Maildir 2>/dev/null && echo "✅ budi Maildir" || echo "❌ budi Maildir missing"
ls -d /var/mail/vhosts/itnsa.id/boaz/Maildir 2>/dev/null && echo "✅ boaz Maildir" || echo "❌ boaz Maildir missing"

echo ""
echo "=== SEND TEST EMAIL ==="
echo "Test dari juri $(date)" | mail -s "Grading Test" budi.sudarsono@itnsa.id
sleep 2

echo ""
echo "=== CHECK MAILDIR ==="
ls /var/mail/vhosts/itnsa.id/budi/Maildir/new/ 2>/dev/null
TEST
```

#### Test IMAP Login (LDAP Auth)

```bash
ssh root@192.168.2.12 << 'TEST'
echo "=== IMAP LOGIN TEST (budi via LDAP) ==="
# Install doveadm jika belum
doveadm auth login budi Skills39! 2>&1 || echo "(may need alternative test)"

echo ""
echo "=== ALTERNATIVE: openssl s_client IMAP ==="
echo -e "a1 LOGIN budi Skills39!\na2 LIST \"\" \"*\"\na3 LOGOUT" | \
  openssl s_client -connect 127.0.0.1:993 -quiet 2>/dev/null | grep -E "^a[0-9]|OK|NO|BAD"
TEST
```

**Expected Results:**

| Test | Expected |
|------|----------|
| Postfix running | ✅ |
| Dovecot running | ✅ |
| `dovecot -n` exit code | `0` (no errors) |
| mydomain | `itnsa.id` |
| virtual_mailbox_domains | `itnsa.id` |
| budi Maildir exists | ✅ |
| Send email | No errors |
| IMAP login budi | `OK` (authenticated via LDAP) |

---

### 2.2 Web Servers (Nginx)

```bash
echo "=== NGINX web-01 ==="
ssh root@192.168.2.13 "systemctl is-active nginx && curl -s http://127.0.0.1:8080"

echo ""
echo "=== NGINX web-02 ==="
ssh root@192.168.2.14 "systemctl is-active nginx && curl -s http://127.0.0.1:8080"
```

**Expected Results:**

| Test | Expected |
|------|----------|
| web-01 port 8080 | `Hello from web-01` |
| web-02 port 8080 | `Hello from web-02` |

---

### 2.3 Keepalived (Virtual IP)

```bash
echo "=== VIP CHECK ==="
ssh root@192.168.2.13 "ip addr show eth0 | grep 10.10.20.100 && echo '✅ VIP on web-01 (MASTER)' || echo 'VIP not on web-01'"
ssh root@192.168.2.14 "ip addr show eth0 | grep 10.10.20.100 && echo 'VIP on web-02' || echo 'VIP not on web-02 (expected as BACKUP)'"

echo ""
echo "=== KEEPALIVED STATUS ==="
ssh root@192.168.2.13 "systemctl is-active keepalived"
ssh root@192.168.2.14 "systemctl is-active keepalived"
```

#### Failover Test

```bash
echo "=== FAILOVER TEST ==="
echo "1. Stop keepalived di web-01..."
ssh root@192.168.2.13 "systemctl stop keepalived"
sleep 3

echo "2. Check VIP pindah ke web-02..."
ssh root@192.168.2.14 "ip addr show eth0 | grep 10.10.20.100 && echo '✅ VIP failover ke web-02' || echo '❌ VIP tidak pindah'"

echo "3. Restore keepalived di web-01..."
ssh root@192.168.2.13 "systemctl start keepalived"
sleep 3

echo "4. Check VIP kembali ke web-01..."
ssh root@192.168.2.13 "ip addr show eth0 | grep 10.10.20.100 && echo '✅ VIP kembali ke web-01' || echo '❌ VIP tidak kembali'"
```

**Expected Results:**

| Test | Expected |
|------|----------|
| VIP `10.10.20.100` on web-01 | ✅ (MASTER priority 101) |
| VIP NOT on web-02 | ✅ (BACKUP priority 100) |
| Stop web-01 → VIP pindah ke web-02 | ✅ |
| Start web-01 → VIP kembali ke web-01 | ✅ |

---

### 2.4 HAProxy (Load Balancing + TLS)

```bash
echo "=== HAPROXY STATUS ==="
ssh root@192.168.2.13 "systemctl is-active haproxy"
ssh root@192.168.2.14 "systemctl is-active haproxy"

echo ""
echo "=== HTTP → HTTPS REDIRECT ==="
ssh root@192.168.2.13 "curl -sI http://127.0.0.1 2>/dev/null | grep -i location"

echo ""
echo "=== HTTPS via VIP ==="
ssh root@192.168.2.13 "curl -sk https://10.10.20.100"

echo ""
echo "=== VIA-PROXY HEADER ==="
ssh root@192.168.2.13 "curl -skI https://10.10.20.100 | grep -i via-proxy"

echo ""
echo "=== LOAD BALANCE (multiple requests) ==="
for i in 1 2 3 4; do
  ssh root@192.168.2.13 "curl -sk https://10.10.20.100 2>/dev/null"
done

echo ""
echo "=== TLS CERT CHECK ==="
ssh root@192.168.2.13 "echo | openssl s_client -connect 10.10.20.100:443 2>/dev/null | openssl x509 -noout -subject -issuer"
```

**Expected Results:**

| Test | Expected |
|------|----------|
| HTTP redirect | `301` → `https://` |
| HTTPS content | `Hello from web-01` / `Hello from web-02` |
| `via-proxy` header | `via-proxy: web-01` atau `web-02` |
| Load balance | Bergantian web-01 dan web-02 |
| TLS cert subject | `CN = www.itnsa.id` |
| TLS cert issuer | `CN = ITNSA Root CA` |

---

## Part 3 – Firewall (`fw` / `192.168.2.15`)

### 3.1 nftables

```bash
ssh root@192.168.2.15 << 'TEST'
echo "=== NFTABLES SERVICE ==="
systemctl is-active nftables && echo "✅ nftables running" || echo "❌ nftables not running"

echo ""
echo "=== IP FORWARDING ==="
sysctl net.ipv4.ip_forward

echo ""
echo "=== RULESET SUMMARY ==="
nft list ruleset | grep -E "policy|chain|iif|oif|dnat|masquerade|dport" | head -30
TEST
```

#### Test: INT → Internet (Soal 1)

```bash
echo "=== INT → INTERNET ==="
ssh root@192.168.2.11 "ping -c 2 -W 3 8.8.8.8 && echo '✅ INT can reach internet' || echo '❌ INT blocked'"
```

#### Test: DMZ → Internet (Soal 1)

```bash
echo "=== DMZ → INTERNET ==="
ssh root@192.168.2.12 "ping -c 2 -W 3 8.8.8.8 && echo '✅ DMZ can reach internet' || echo '❌ DMZ blocked'"
```

#### Test: NAT Masquerade (Soal 2)

```bash
echo "=== NAT MASQUERADE ==="
ssh root@192.168.2.15 "nft list ruleset | grep masquerade && echo '✅ Masquerade rule exists' || echo '❌ Missing'"
```

#### Test: Port Forward (Soal 3)

```bash
echo "=== PORT FORWARD: HTTP/443 → VIP ==="
ssh root@192.168.2.15 "nft list ruleset | grep 'dnat to 10.10.20.100' && echo '✅ HTTP/HTTPS forward' || echo '❌ Missing'"

echo ""
echo "=== PORT FORWARD: DNS → int-srv ==="
ssh root@192.168.2.15 "nft list ruleset | grep 'dnat to 10.10.10.10' && echo '✅ DNS forward' || echo '❌ Missing'"
```

#### Test: Mail → LDAP (Soal 5)

```bash
echo "=== MAIL → LDAP ==="
ssh root@192.168.2.12 "ldapsearch -x -H ldap://10.10.10.10 -b 'dc=itnsa,dc=id' '(uid=budi)' mail 2>/dev/null | grep 'mail:' && echo '✅ Mail can query LDAP' || echo '❌ LDAP blocked'"
```

#### Test: Default Deny (Soal 7)

```bash
echo "=== DEFAULT DENY ==="
ssh root@192.168.2.15 "nft list ruleset | grep 'policy drop' && echo '✅ Default deny active'"
```

**Expected Results:**

| Soal | Test | Expected |
|------|------|----------|
| 1 | INT → internet | ✅ ping 8.8.8.8 |
| 1 | DMZ → internet | ✅ ping 8.8.8.8 |
| 2 | Masquerade | ✅ rule exists |
| 3 | Port forward 80/443 → VIP | ✅ DNAT rule |
| 3 | Port forward 53 → DNS | ✅ DNAT rule |
| 5 | Mail → LDAP query | ✅ returns data |
| 6 | MGMT allowed | ✅ (we're SSH-ing via MGMT) |
| 7 | Default deny | ✅ `policy drop` |

---

### 3.2 WireGuard VPN

```bash
ssh root@192.168.2.15 << 'TEST'
echo "=== WIREGUARD SERVICE ==="
systemctl is-active wg-quick@wg0 && echo "✅ WireGuard running" || echo "❌ WireGuard not running"

echo ""
echo "=== WG SHOW ==="
wg show

echo ""
echo "=== WG0 INTERFACE ==="
ip addr show wg0 | grep inet
TEST
```

**Expected Results:**

| Test | Expected |
|------|----------|
| wg-quick@wg0 active | ✅ |
| wg0 address | `10.10.30.1/24` |
| ListenPort | `51820` |
| Peer (budi-clt) | connected, handshake recent |

---

## Part 4 – Client (`budi-clt` / `192.168.2.16`)

### 4.1 User budi

```bash
ssh root@192.168.2.16 << 'TEST'
echo "=== USER BUDI ==="
id budi && echo "✅ User exists" || echo "❌ User missing"

echo ""
echo "=== SUDOER CHECK ==="
su - budi -c "sudo -n whoami" && echo "✅ Passwordless sudo" || echo "❌ Sudo failed"
TEST
```

### 4.2 WireGuard Client

```bash
ssh root@192.168.2.16 << 'TEST'
echo "=== WIREGUARD CLIENT ==="
systemctl is-active wg-quick@wg0 && echo "✅ WireGuard running" || echo "❌ WireGuard not running"

echo ""
echo "=== WG SHOW ==="
wg show

echo ""
echo "=== WG0 IP ==="
ip addr show wg0 | grep inet

echo ""
echo "=== DNS via VPN ==="
dig +short @10.10.10.10 mail.itnsa.id

echo ""
echo "=== PING INT via VPN (Soal 4) ==="
ping -c 2 -W 3 10.10.10.10 && echo "✅ VPN → INT OK" || echo "❌ VPN → INT FAIL"

echo ""
echo "=== PING DMZ via VPN (Soal 4) ==="
ping -c 2 -W 3 10.10.20.10 && echo "✅ VPN → DMZ OK" || echo "❌ VPN → DMZ FAIL"
TEST
```

### 4.3 Website Access

```bash
ssh root@192.168.2.16 << 'TEST'
echo "=== HTTPS www.itnsa.id (via internet / WAN) ==="
curl -s --connect-to www.itnsa.id:443:100.100.100.254:443 -k https://www.itnsa.id
echo ""

echo ""
echo "=== HTTPS www.int.itnsa.id (via VPN) ==="
curl -s --connect-to www.int.itnsa.id:443:10.10.20.100:443 -k https://www.int.itnsa.id
echo ""

echo ""
echo "=== CERT VERIFICATION (tanpa -k, pakai CA trust) ==="
curl -s --cacert /usr/local/share/ca-certificates/itnsa-root-ca.crt \
  --connect-to www.itnsa.id:443:100.100.100.254:443 https://www.itnsa.id && echo "✅ Cert trusted" || echo "❌ Cert error"
TEST
```

**Expected Results:**

| Test | Expected |
|------|----------|
| User budi exists | ✅ |
| Passwordless sudo | ✅ `root` |
| wg0 address | `10.10.30.2/24` |
| VPN → INT | ✅ ping `10.10.10.10` |
| VPN → DMZ | ✅ ping `10.10.20.10` |
| www.itnsa.id | `Hello from web-01/02` |
| www.int.itnsa.id (via VPN) | `Hello from web-01/02` |
| Cert tanpa error | ✅ Trusted by ITNSA Root CA |

---

## 📊 Ringkasan Penilaian

### Tabel Skor

| # | Komponen | Sub-item | Max | ✅/❌ |
|---|---------|----------|-----|-------|
| **Part 1 – INT** | | | | |
| 1.1 | DNS – BIND9 installed & running | | 2 | |
| 1.2 | DNS – Forward zone (semua A record benar) | | 3 | |
| 1.3 | DNS – CNAME `www.int` → `vrrp` | | 1 | |
| 1.4 | DNS – MX record | | 1 | |
| 1.5 | DNS – Reverse zone (PTR records) | | 2 | |
| 1.6 | LDAP – slapd running | | 1 | |
| 1.7 | LDAP – User boaz (dengan email) | | 1 | |
| 1.8 | LDAP – User budi (dengan email) | | 1 | |
| 1.9 | CA – Root CA (CN=ITNSA Root CA) | | 1 | |
| 1.10 | CA – Key Usage: Certificate Sign, CA:TRUE | | 1 | |
| 1.11 | CA – Web cert (SAN: www + www.int) | | 2 | |
| 1.12 | CA – Mail cert (CN=mail.itnsa.id) | | 1 | |
| 1.13 | CA – Installed di semua server | | 1 | |
| 1.14 | CA – Cert files di `/opt/grading/ca` | | 1 | |
| 1.15 | Ansible – `01-user.yml` works | | 2 | |
| 1.16 | Ansible – `02-web-int.yml` works (port 8081) | | 2 | |
| 1.17 | Ansible – Playbooks idempotent | | 1 | |
| **Part 2 – DMZ** | | | | |
| 2.1 | Mail – Postfix running, domain itnsa.id | | 2 | |
| 2.2 | Mail – Dovecot running (no errors) | | 2 | |
| 2.3 | Mail – TLS configured | | 1 | |
| 2.4 | Mail – LDAP auth (budi login IMAP) | | 3 | |
| 2.5 | Mail – Send/receive email budi | | 2 | |
| 2.6 | Mail – Maildir configured | | 1 | |
| 2.7 | Web – Nginx port 8080 (web-01 & web-02) | | 2 | |
| 2.8 | HA – Keepalived VIP `10.10.20.100` | | 2 | |
| 2.9 | HA – Failover test (VIP pindah) | | 2 | |
| 2.10 | HA – HAProxy HTTPS TLS termination | | 2 | |
| 2.11 | HA – HTTP → HTTPS redirect | | 1 | |
| 2.12 | HA – `via-proxy` header | | 1 | |
| 2.13 | HA – Load balance (roundrobin) | | 1 | |
| 2.14 | HA – Cert chain valid (CA trust) | | 1 | |
| **Part 3 – Firewall** | | | | |
| 3.1 | FW – nftables running | | 1 | |
| 3.2 | FW – INT & DMZ → internet | | 2 | |
| 3.3 | FW – NAT masquerade | | 1 | |
| 3.4 | FW – Port forward 80/443 → VIP | | 2 | |
| 3.5 | FW – Port forward 53 → DNS | | 1 | |
| 3.6 | FW – Mail → LDAP allowed | | 1 | |
| 3.7 | FW – MGMT allowed | | 1 | |
| 3.8 | FW – Default deny | | 1 | |
| 3.9 | VPN – WireGuard running (fw) | | 2 | |
| 3.10 | VPN – PSK configured | | 1 | |
| 3.11 | VPN – Client uses internal DNS | | 1 | |
| **Part 4 – Client** | | | | |
| 4.1 | User budi exists + passwordless sudo | | 2 | |
| 4.2 | VPN – WireGuard running (client) | | 2 | |
| 4.3 | VPN – Can reach INT | | 1 | |
| 4.4 | VPN – Can reach DMZ | | 1 | |
| 4.5 | Web – https://www.itnsa.id accessible | | 1 | |
| 4.6 | Web – https://www.int.itnsa.id via VPN | | 1 | |
| 4.7 | Web – No cert error (CA trusted) | | 1 | |
| 4.8 | Email – Thunderbird configured (manual check) | | 2 | |

---

## 🔥 Quick One-Liner Full Test

Jalankan dari juri untuk test cepat semua service sekaligus:

```bash
echo "========== QUICK GRADING ==========" && \
echo "--- DNS ---" && ssh root@192.168.2.11 "dig +short @127.0.0.1 www.itnsa.id" && \
echo "--- LDAP ---" && ssh root@192.168.2.11 "ldapsearch -x -b 'dc=itnsa,dc=id' '(uid=budi)' uid 2>/dev/null | grep uid:" && \
echo "--- CA ---" && ssh root@192.168.2.11 "openssl verify -CAfile /opt/grading/ca/ca.pem /opt/grading/ca/web.pem 2>/dev/null" && \
echo "--- POSTFIX ---" && ssh root@192.168.2.12 "systemctl is-active postfix" && \
echo "--- DOVECOT ---" && ssh root@192.168.2.12 "systemctl is-active dovecot" && \
echo "--- NGINX web-01 ---" && ssh root@192.168.2.13 "curl -s http://127.0.0.1:8080" && \
echo "--- NGINX web-02 ---" && ssh root@192.168.2.14 "curl -s http://127.0.0.1:8080" && \
echo "--- VIP ---" && ssh root@192.168.2.13 "ip a show eth0 | grep -q 10.10.20.100 && echo 'VIP OK'" && \
echo "--- HAPROXY ---" && ssh root@192.168.2.13 "curl -sk https://10.10.20.100" && \
echo "--- NFTABLES ---" && ssh root@192.168.2.15 "systemctl is-active nftables" && \
echo "--- WG SERVER ---" && ssh root@192.168.2.15 "systemctl is-active wg-quick@wg0" && \
echo "--- WG CLIENT ---" && ssh root@192.168.2.16 "systemctl is-active wg-quick@wg0" && \
echo "--- VPN→INT ---" && ssh root@192.168.2.16 "ping -c 1 -W 2 10.10.10.10 >/dev/null && echo OK" && \
echo "--- VPN→DMZ ---" && ssh root@192.168.2.16 "ping -c 1 -W 2 10.10.20.10 >/dev/null && echo OK" && \
echo "--- BUDI USER ---" && ssh root@192.168.2.16 "id budi" && \
echo "========== DONE =========="
```

---

> *Testing guide untuk LKS ITNSA Jatim 2025 – Modul A Linux Environment*
> *Dijalankan dari VM juri (192.168.2.100) via MGMT network*
