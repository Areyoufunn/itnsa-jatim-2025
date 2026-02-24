# LOMBA KOMPETENSI SISWA PENDIDIKAN MENENGAH
## TINGKAT PROVINSI TAHUN 2025

---

# TEST PROJECT
# MODUL A – LINUX ENVIRONMENT
## IT NETWORK SYSTEMS ADMINISTRATION

---

## Pendahuluan

Proyek Linux Environment ini adalah konfigurasi praktik untuk membantu Anda belajar cara membangun dan mengelola jaringan komputer yang aman menggunakan **Debian 12**. Anda akan mengonfigurasi server-server berbeda untuk peran tertentu:

- **Internal Server** – menangani DNS, login pengguna (LDAP), dan sertifikat digital
- **DMZ Servers** – menyediakan layanan email dan website yang dapat diakses dari internet
- **Firewall Server** – mengontrol lalu lintas yang diizinkan masuk dan keluar, serta mengatur koneksi VPN yang aman
- **Client Computer** – digunakan untuk menguji segalanya, seperti memeriksa apakah website dan email berfungsi dengan baik melalui VPN

Proyek ini membantu Anda memahami bagaimana perusahaan nyata mengelola dan melindungi jaringan mereka.

---

## Login

| Field    | Value      |
|----------|------------|
| Username | root/user  |
| Password | Skills39!  |

---

## Konfigurasi Sistem

| Parameter | Value         |
|-----------|---------------|
| Timezone  | Asia/Jakarta  |

---

## Konfigurasi Umum

| Fully Qualified Domain Name | IPv4 | Services |
|-----------------------------|------|----------|
| `fw.itnsa.id` | INT: `10.10.10.254/24`<br>DMZ: `10.10.20.254/24`<br>WAN: `100.100.100.254/24`<br>MGMT: `192.168.2.15/24` | VPN (wireguard), firewall (nftables) |
| `int-srv.itnsa.id` | INT: `10.10.10.10/24`<br>MGMT: `192.168.2.11/24` | DNS Server (bind9), LDAP (slapd), CA (openssl), ansible |
| `mail.itnsa.id` | DMZ: `10.10.20.10/24`<br>MGMT: `192.168.2.12/24` | Mail Server (postfix + dovecot) |
| `web-01.itnsa.id` | DMZ: `10.10.20.21/24`<br>MGMT: `192.168.2.13/24` | Virtual IP (keepalived), HAProxy, Web Server |
| `web-02.itnsa.id` | DMZ: `10.10.20.22/24`<br>MGMT: `192.168.2.14/24` | Virtual IP (keepalived), HAProxy, Web Server |
| `budi-clt.itnsa.id` | WAN: `100.100.100.100/24`<br>MGMT: `192.168.2.16/24` | E-mail client, VPN client |

---

## Networking

Untuk memudahkan pekerjaan Anda, networking telah dikonfigurasi sebelumnya pada semua mesin.

---

## Catatan Penting

> ⚠️ **PERHATIAN:** Untuk proses penilaian, kami menggunakan sistem yang mengandalkan layanan SSH. Oleh karena itu, Anda **dilarang keras** mengubah konfigurasi SSH!!!

---

# Part 1 – INT (Internal)

Server internal `int-srv.itnsa.id` bertanggung jawab menyediakan layanan infrastruktur inti, termasuk DNS, autentikasi LDAP, dan fungsi Certificate Authority (CA). Konfigurasi ini memastikan manajemen pengguna yang terpusat dan komunikasi yang aman di seluruh jaringan.

---

## int-srv.itnsa.id

### DNS

Siapkan server DNS menggunakan BIND9 untuk mengelola nama domain.

#### 1. Install & Konfigurasi BIND9

Install dan konfigurasi BIND9 pada server `int-srv.itnsa.id`.

#### 2. Buat DNS Zones

- Buat **forward zone** untuk: `itnsa.id`
- Buat **reverse zone** untuk rentang alamat IP internal (contoh: `10.10..`)

#### 3. Tambahkan DNS Records

Tambahkan record forward dan reverse untuk semua server yang tercantum dalam konfigurasi umum.

Tambahkan juga record berikut:

| Type  | Name      | Value/Target     |
|-------|-----------|------------------|
| A     | www       | 100.100.100.254  |
| A     | vrrp      | 10.10.20.100     |
| CNAME | www.int   | vrrp.itnsa.id    |
| MX    | @         | 10 mail.itnsa.id |

---

### LDAP

Install dan konfigurasi LDAP menggunakan slapd untuk mengelola akun pengguna. Pengguna-pengguna ini akan digunakan untuk login ke mail server.

#### 1. Install LDAP menggunakan slapd

#### 2. Buat LDAP Users

Buat pengguna berikut di LDAP. Pengguna-pengguna ini akan digunakan untuk login email (autentikasi):

| Full Name       | Username (uid) | Password  | Organizational Unit (OU) | Email Address              |
|-----------------|----------------|-----------|--------------------------|----------------------------|
| Administrator   | admin          | Skills39! | -                        | -                          |
| Boaz Salossa    | boaz           | Skills39! | Employees                | boaz.salossa@itnsa.id      |
| Budi Sudarsono  | budi           | Skills39! | Employees                | budi.sudarsono@itnsa.id    |

---

### CA (Certificate Authority)

Gunakan OpenSSL untuk membuat Certificate Authority (CA) Anda sendiri dan menghasilkan sertifikat untuk server Anda (web dan mail).

#### 1. Buat Root CA

- Buat Root CA dengan nama: **"ITNSA Root CA"**
- Untuk field lain seperti Country, State, dll., Anda dapat menggunakan nilai apa saja.
- Tambahkan atribut berikut:

```
X509v3 Key Usage: critical
    Certificate Sign
X509v3 Basic Constraints: critical
    CA:TRUE
```

- Install **ITNSA Root CA** pada setiap server dan client.

#### 2. Buat Sertifikat untuk Server

Generate dan tandatangani sertifikat berikut langsung menggunakan Root CA:

- Sertifikat untuk **web server**, berlaku untuk: `www.itnsa.id`, `www.int.itnsa.id`
- Sertifikat untuk **mail server**, berlaku untuk: `mail.itnsa.id`

#### 3. Simpan Semua Sertifikat

Simpan sertifikat di folder berikut: `/opt/grading/ca`

| File       | Keterangan                |
|------------|---------------------------|
| `ca.pem`   | Root CA certificate       |
| `web.pem`  | Web server certificate    |
| `mail.pem` | Mail server certificate   |

---

### Ansible

Kita akan mengatur Ansible pada server `int-srv` dan membuatnya mengontrol server `web-02`. Semua file ansible (settings, playbooks, dan modules) harus disimpan di direktori `/etc/ansible`.

#### 1. Buat Playbook `01-user.yml`

- Playbook ini akan membuat user baru di server.
- Set password `Skills39!`, tetapi untuk username, kita akan menggunakan variabel agar dapat diubah dengan mudah.
- Buat playbook bersifat **idempotent**.
- Untuk menjalankan playbook, gunakan perintah:

```bash
ansible-playbook /etc/ansible/01-user.yml -e user_name=developer
```

#### 2. Buat Playbook `02-web-int.yml`

- Playbook ini akan menginstall Nginx.
- Juga akan membuat virtual host yang mendengarkan pada port **8081**.
- Ketika membuka website, akan menampilkan pesan: **"This is web internal"**
- Buat playbook bersifat **idempotent**.
- Untuk menjalankan playbook, gunakan perintah:

```bash
ansible-playbook /etc/ansible/02-web-int.yml
```

---

# Part 2 – DMZ (Demilitarized Zones)

Zona DMZ meng-host layanan yang menghadap publik seperti mail server dan web server dengan high-availability. Server-server ini diisolasi dari sistem internal tetapi harus berkomunikasi secara aman dengan mereka untuk fungsi seperti autentikasi LDAP dan verifikasi sertifikat.

---

## mail.itnsa.id

### Mail Server

Siapkan mail server menggunakan Postfix dan Dovecot agar pengguna dapat mengirim dan menerima email untuk domain `itnsa.id`.

#### 1. Install Software Mail Server

- **Postfix** (untuk mengirim dan menerima email)
- **Dovecot** (untuk mengizinkan pengguna membaca email mereka)

#### 2. Konfigurasi Mail Server

- Mail server harus mengirim dan menerima email untuk domain: `itnsa.id`
- Pengguna harus dapat membaca email mereka menggunakan **IMAP**
- Semua koneksi antara email client dan server harus menggunakan **TLS** (enkripsi):
  - Jika sudah menyelesaikan tugas "CA" (Certificate Authority), gunakan sertifikat yang telah dibuat untuk mail server.
  - Jika belum, buat **self-signed certificate**.
- Pastikan client yang mempercayai "ITNSA Root CA" dapat memverifikasi sertifikat.

#### 3. Integrasi LDAP (User Login)

- Konfigurasi folder **Maildir** untuk user `budi` dan `boaz`.
- Pastikan user LDAP bernama `budi` (yang dibuat pada tugas LDAP) dapat:
  - Login menggunakan username-nya (uid)
  - Mengakses inbox emailnya
  - Alamat email harus diambil dari field `mail` di LDAP.
- Test email budi dapat mengirim email ke dirinya sendiri menggunakan **mailutils**.

---

## web-01.itnsa.id & web-02.itnsa.id

### HA Web (High-Availability)

Siapkan sistem reverse proxy high-availability menggunakan HAProxy dan Keepalived pada dua server: `web-01` dan `web-02`.

#### 1. Konfigurasi Keepalived (Virtual IP)

- Buat **Virtual IP** (`10.10.20.100/24`) yang akan otomatis berpindah ke server backup jika server utama mati.
- **web-01**: bertindak sebagai **MASTER** dengan priority `101`
- **web-02**: bertindak sebagai **BACKUP** dengan priority `100`

#### 2. Konfigurasi HAProxy untuk Load Balancing

- Install dan konfigurasi HAProxy pada kedua server (`web-01` dan `web-02`) untuk mendistribusikan traffic ke dua web server Nginx:
  - **web-01**: `10.10.20.21:8080`
  - **web-02**: `10.10.20.22:8080`
- Semua permintaan HTTP harus diredirect ke HTTPS.
- HAProxy harus melakukan **TLS termination** (HAProxy menangani HTTPS dan meneruskan ke Nginx menggunakan HTTP).
- Tambahkan HTTP header `via-proxy: hostname` pada respons (ganti "hostname" dengan hostname proxy) untuk membantu troubleshooting.
- Jika sudah memiliki sertifikat dari CA, gunakan **web certificate** (`web.pem`).
- Pastikan client yang hanya mempercayai root CA dapat memvalidasi seluruh certificate chain.
- Jika tidak, buat **self-signed certificate**.

#### 3. Web Server Nginx

- Pada `web-01` dan `web-02`, install nginx dan dengarkan pada port **8080** dengan `index.html`:

```
Hello from ${hostname}
```

---

# Part 3 – Firewall

Server firewall `fw.itnsa.id` bertindak sebagai gateway yang aman untuk jaringan internal dan DMZ. Bertanggung jawab untuk mengontrol aliran traffic, menyediakan akses internet, forwarding layanan, dan mengamankan konektivitas VPN.

---

## fw.itnsa.id

### nftables

Buat aturan firewall dan NAT menggunakan nftables untuk mengontrol traffic mana yang diizinkan atau diblokir di jaringan Anda.

#### 1. Izinkan Akses Internet

- Perangkat di jaringan **INT** (internal) dan **DMZ** dapat mengakses internet.

#### 2. NAT Masquerade

- Saat mengirim traffic dari jaringan Anda ke internet (melalui WAN), firewall harus mengganti IP sumber dengan IP WAN-nya sendiri menggunakan **masquerade NAT**.

#### 3. Port Forwarding

Forward traffic masuk dari internet ke server-server di DMZ:

| Port | Protocol | Forward To    |
|------|----------|---------------|
| 80   | TCP      | 10.10.20.100  |
| 443  | TCP      | 10.10.20.100  |
| 53   | TCP/UDP  | 10.10.10.10   |

#### 4. Akses VPN

- Client VPN harus dapat menjangkau jaringan internal maupun DMZ.

#### 5. Mail Server ke LDAP

- Mail server harus diizinkan untuk melakukan query layanan LDAP yang berjalan di `int-srv01`.

#### 6. Izinkan Semua Traffic dari Interface MGMT

- Izinkan semua traffic yang masuk dari interface MGMT.

#### 7. Blokir Semua Selain yang Disebutkan

- Traffic lainnya yang tidak disebutkan di atas harus diblokir (**default deny**).

---

### WireGuard VPN

Siapkan WireGuard sebagai VPN server agar workstation eksternal (client) dapat terhubung secara aman ke jaringan internal.

#### 1. Koneksi VPN yang Aman

- Gunakan **WireGuard** untuk membuat tunnel aman dari client ke jaringan internal.
- Semua traffic internet dari client harus dirutekan melalui tunnel VPN.

#### 2. Pre-Shared Key (PSK)

- Untuk keamanan tambahan, tambahkan **pre-shared key** pada tunnel (digunakan bersama dengan public/private keys).

#### 3. Konfigurasi DNS

- Client harus menggunakan server DNS internal (bukan DNS publik) untuk me-resolve hostname saat terhubung.

#### 4. IP Addressing

- Gunakan rentang IP untuk tunnel berdasarkan **Tabel Konfigurasi Umum** (cek pengaturan jaringan yang diberikan).

#### 5. Simpan & Aktifkan Konfigurasi

- Simpan konfigurasi WireGuard sebagai:

```
/etc/wireguard/wg0.conf
```

- Start menggunakan perintah:

```bash
sudo wg-quick up wg0
```

- Aktifkan agar berjalan saat boot (system service):

```bash
sudo systemctl enable wg-quick@wg0
```

---

# Part 4 – Client

Mesin client `budi-clt.itnsa.id` merepresentasikan workstation jarak jauh yang terhubung secara aman ke layanan internal dan DMZ melalui VPN. Digunakan untuk memvalidasi keseluruhan infrastruktur dengan menguji akses ke layanan web, DNS, dan email.

---

## Konfigurasi Umum

#### 1. Buat User Lokal Baru

- Buat user lokal baru bernama `budi` (Budi Sudarsono) dengan password `Skills39!`
- Jadikan user `budi` sebagai **sudoer tanpa password**

#### 2. Konfigurasi VPN WireGuard ke fw.itnsa.id

- Simpan konfigurasi WireGuard sebagai:

```
/etc/wireguard/wg0.conf
```

- Start menggunakan perintah:

```bash
sudo wg-quick up wg0
```

- Aktifkan agar berjalan saat boot (system service):

```bash
sudo systemctl enable wg-quick@wg0
```

#### 3. Akses Website

- Dapat mengakses `https://www.itnsa.id` melalui **internet**
- Dapat mengakses `https://www.int.itnsa.id` melalui **VPN**
- Keduanya harus dapat diakses **tanpa error sertifikat**

#### 4. Konfigurasi Email di Thunderbird

- Siapkan email `budi.sudarsono@itnsa.id` di **Thunderbird**
- Pastikan dapat mengirim email ke dirinya sendiri

---

# Topologi Jaringan

```
                    ┌──────────┐
                    │ internet │
                    └────┬─────┘
                         │
              ┌──────────┤         ┌──────────────┐
              │          │         │  budi-clt    │
              │      ┌───┴──┐      │ (WAN:        │
              │      │  fw  │      │ 100.100.100  │
              │      └───┬──┘      │      .100)   │
              │          │         └──────────────┘
    ┌─────────┼──────────┼─────────────────────┐
    │  INT    │          │  DMZ                │
    │         │          │                     │
    │  ┌──────┴─┐   ┌────┴──┐  ┌──────┐  ┌────┴───┐
    │  │int-srv │   │ mail  │  │web01 │  │ web02  │
    │  └────────┘   └───────┘  └──────┘  └────────┘
    └────────────────────────────────────────────────┘
```

### Keterangan Topologi

| Node       | Zona | IP Address         | Keterangan               |
|------------|------|--------------------|--------------------------|
| fw         | ALL  | INT: 10.10.10.254<br>DMZ: 10.10.20.254<br>WAN: 100.100.100.254 | Firewall & VPN Gateway |
| int-srv    | INT  | 10.10.10.10        | DNS, LDAP, CA, Ansible   |
| mail       | DMZ  | 10.10.20.10        | Mail Server              |
| web-01     | DMZ  | 10.10.20.21        | HAProxy + Nginx (Master) |
| web-02     | DMZ  | 10.10.20.22        | HAProxy + Nginx (Backup) |
| budi-clt   | WAN  | 100.100.100.100    | Client / Tester          |

---

*Dokumen ini adalah bagian dari Test Project LKS Provinsi 2025 – IT Network Systems Administration*
*Version: 1.0 | Date: 20.04.25*
