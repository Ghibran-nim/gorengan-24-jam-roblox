# ARCHITECTURAL & DESIGN DECISIONS (ADR) — GORENGAN 24 JAM

Dokumen ini mencatat keputusan arsitektural dan desain penting, latar belakang alasan, serta konsekuensi teknisnya.

---

## ADR-001: Penggunaan Arsitektur Modular Service-Controller Mandiri Tanpa Framework Eksternal Berat
- **Tanggal:** 2026-11-24
- **Status:** Diterima
- **Konteks:** Proyek memerlukan arsitektur yang bersih, modular, mudah diuji, dan tidak rentan dependensi sirkular. Penggunaan framework pihak ketiga yang kompleks (seperti Knit) menambahkan kompleksitas instalasi atau overhead dependency yang tidak diperlukan untuk skala 8 pemain.
- **Keputusan:** Menggunakan pola Service-Controller ringan buatan sendiri (*lightweight custom runner*) dengan siklus `Init()` dan `Start()`. Server menggunakan Services di `src/server/Services`, Client menggunakan Controllers di `src/client/Controllers`.
- **Konsekuensi:** Kode sepenuhnya transparan, mudah di-maintain, tidak bergantung pada dependency package manager pihak ketiga.

---

## ADR-002: Wewenang Penuh Server untuk Seluruh Hasil Memasak dan Transaksi (Server-Authoritative)
- **Tanggal:** 2026-11-24
- **Status:** Diterima
- **Konteks:** Permainan multiplayer rentan terhadap exploit client-side jika perhitungan waktu goreng, kualitas masakan, atau penambahan uang dipercayakan pada client.
- **Keputusan:** Client hanya mengirimkan sinyal mulai (`RequestStartCooking`) dan selesai (`RequestCollectFood`). Server mencatat timestamp riil menggunakan waktu server (`os.clock()`), memvalidasi jeda waktu aktual, dan menentukan status masakan (`Undercooked`, `Crispy`, atau `Burnt`). Client hanya memvisualisasikan interpolasi meteran progress.
- **Konsekuensi:** Mengeliminasi 100% kemungkinan cheat "instant perfect fry" atau remote payload manipulasi uang dari client exploit.

---

## ADR-003: Pemisahan Ketat Carried Cash vs Banked Cash
- **Tanggal:** 2026-11-24
- **Status:** Diterima
- **Konteks:** Mekanik razia Satpol PP membutuhkan tensi risiko kehilangan uang, namun pemain tidak boleh merasa frustrasi hingga kehilangan seluruh hasil kerja keras tabungan jangka panjang.
- **Keputusan:** Saldo uang dipecah menjadi dua dompet:
  1. `CarriedCash`: Uang tunai yang ada di laci gerobak, bertambah saat melayani pembeli, dan dapat disita oleh Satpol PP (misal 20-30%) jika tertangkap razia.
  2. `BankedCash`: Saldo yang disetorkan pemain ke ATM, terlindungi 100% dari razia maupun copet.
- **Konsekuensi:** Mendorong loop gameplay taktis di mana pemain harus secara berkala meninggalkan gerobak sebentar untuk menyetorkan uang ke ATM.

---

## ADR-004: Pola Lifecycle Deterministik `ServiceRunner` & Abstraksi Lapisan Jaringan `NetworkBridge`
- **Tanggal:** 2026-11-24
- **Status:** Diterima
- **Konteks:** Inisialisasi multi-service di Roblox sering mengalami race-condition akibat `task.wait()` sembarangan atau client memanggil remote sebelum instance terbentuk di server.
- **Keputusan:** 
  1. `ServiceRunner` memisahkan fase secara tegas: seluruh `Init()` dieksekusi secara sinkron terlebih dahulu untuk memastikan pendaftaran listener selesai, baru kemudian seluruh `Start()` dieksekusi secara asinkron (`task.spawn`).
  2. `NetworkBridge` secara otomatis membuat folder `ReplicatedStorage.NetworkRemotes` dan seluruh RemoteEvent/RemoteFunction di server saat runtime, sedangkan client menggunakan bounded wait dengan timeout yang terukur.
  3. Menyertakan proteksi rate-limiting per pemain dan validasi jarak fisik (`HumanoidRootPart` magnitude check) di level NetworkBridge.
- **Konsekuensi:** Menghilangkan ketergantungan urutan require manual antar script, mencegah race-condition jaringan saat pemain bergabung, dan melindungi server dari banjir request remote.

---

## ADR-008: Validasi Mobilitas Gerobak & Pencegahan Anti-Speedhack (Cart Push Mobility)
- **Tanggal:** 2026-11-24
- **Status:** Diterima
- **Konteks:** Mekanik mendorong gerobak adalah signature survival mechanic saat razia Satpol PP. Client harus merasakan responsivitas gerakan yang halus tanpa latensi input, namun posisi gerobak tidak boleh dipercayai mentah-mentah dari client untuk mencegah eksploitasi teleportasi atau speedhack menuju safe zone.
- **Keputusan:**
  1. Client memprediksi dan merender interpolasi posisi gerobak di depannya secara lokal pada tingkat frame-rate display (`RenderStepped`).
  2. Client mengirimkan posisi CFrame ke server dengan frekuensi terbatas (*throttled 10 Hz / 0.1s*).
  3. Server melakukan validasi kalkulasi delta jarak per delta waktu: `(deltaDist / dt) <= maxAllowedSpeed * 1.6 + 2.5` studs tolerance.
  4. Server memvalidasi jarak karakter terhadap gerobak (maks 18 studs) dan batas ketinggian vertikal peta (-5 < Y < 40).
  5. Kecepatan pemain dibatasi menjadi 10 studs/s saat mendorong (13.5 studs/s dengan upgrade *Roda Bearing*), dan otomatis kembali ke 16 studs/s saat gerobak dilepas.
- **Konsekuensi:** Menghadirkan pengalaman gameplay gerobak yang terasa berat namun responsif, dengan jaminan keamanan anti-exploit server-authoritative.

---

## ADR-009: Sistem Razia Satpol PP, AI Pengejaran Adil & Imunitas Safe Zone Mutlak
- **Tanggal:** 2026-11-24
- **Status:** Diterima
- **Konteks:** Razia Satpol PP harus memberikan tensi kepanikan yang seru namun tetap adil (*fair*), tidak membuat pemain frustrasi, dan tidak memungkinkan Satpol PP mengetahui posisi pemain secara tidak masuk akal (wallhack / omniscience).
- **Keputusan:**
  1. Diberikan jeda peringatan 15 detik sebelum razia aktif dengan sirine visual dan kentongan alarm di HUD.
  2. Deteksi Satpol PP berbasis aturan indra realistis: jarak maksimum 35 studs, bidang pandang kerucut (*cone of vision*) ~160 derajat, dan raycasting garis pandang (*line of sight*) untuk mencegah tembus dinding ruko.
  3. Kecepatan patroli dan pengejaran Satpol PP dibatasi 12.0 studs/s. Ini dirancang adil: pemain berjalan biasa (16 studs/s) pasti dapat melarikan diri, pemain mendorong gerobak standar (10 studs/s) harus bergegas sejak peringatan 15 detik berbunyi, dan pemain dengan upgrade *Roda Bearing* (13.5 studs/s) dapat mengungguli kecepatan Satpol PP.
  4. **Garansi Imunitas Safe Zone:** Pengecekan spasial kotak pembatas 3D (*Object-Space Bounding Box*) memastikan bahwa gerobak di dalam Safe Zone 100% tidak akan ditarget. Jika gerobak yang sedang dikejar berhasil masuk ke bibir Safe Zone, Satpol PP seketika membatalkan pengejaran dan melontarkan dialog komedi.
- **Konsekuensi:** Menghasilkan signature chase-and-escape gameplay yang mendebarkan, adil, dan memuaskan saat pemain berhasil menyelamatkan dagangannya.

---

## ADR-010: Isolasi Dua Dompet & Penalti Komedi Saat Tertangkap Razia
- **Tanggal:** 2026-11-24
- **Status:** Diterima
- **Konteks:** Penangkapan oleh Satpol PP harus memiliki konsekuensi yang terasa nyata agar pemain waspada, namun tidak menghapus seluruh tabungan jangka panjang pemain.
- **Keputusan:**
  1. Saat tertangkap di luar Safe Zone (jarak <= 8 studs):
     - Uang kas yang dibawa (`CarriedCash`) disita sebesar 25% melalui `EconomyService:PenalizeCarriedCash`.
     - Seluruh stok gorengan siap saji di etalase gerobak disita bersih oleh petugas (`InventoryService:ClearCookedFood`).
     - **Tabungan di ATM (`BankedCash`) dijamin 100% UTUH dan AMAN.**
     - Gerobak dan pemain diteleportasikan kembali ke plot pangkalan pedagang (`CartService:ReturnCartToPlot`).
  2. Client menampilkan efek komedi pusing (*dazed screen vignette*) dengan pesan denda dan pengingat bahwa uang di ATM aman.
  3. Diberikan *grace period* 12 detik pasca penangkapan agar pemain tidak terkena denda berulang secara tidak sengaja.
- **Konsekuensi:** Mengukuhkan fungsi strategis ATM Center sebagai mekanisme mitigasi risiko, menciptakan gameplay loop yang seimbang antara berjualan di jalan raya vs menyimpan uang di bank.
