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

---

## ADR-011: Simulasi Proyektil Server-Authoritative & Ragdoll Dual-Rig Anti-Griefing
- **Tanggal:** 2026-11-25
- **Status:** Diterima
- **Konteks:** Gorengan gosong sebagai senjata lempar komedi harus terasa seru dan responsif di PC maupun layar sentuh, namun tidak boleh mengizinkan exploiter mengirim posisi benturan palsu atau melakukan stunlock terhadap pedagang yang sedang berjualan di Safe Zone.
- **Keputusan:**
  1. **Niat-Saja dari Client:** Client hanya mengirim vektor arah (`aimDirection`) ke `RequestThrowBurntFood`. Server memvalidasi tipe, menampik `NaN`/`Inf`/vektor nol, menegakkan cooldown 3.5 detik, memotong 1 stok `Burnt` secara atomik, dan menghitung `origin` serta `velocity` dari `HumanoidRootPart` server.
  2. **Simulasi Terpisah:** Server menjalankan stepped ballistic raycast (`dt = 0.03s`, maks 55 studs) untuk otoritas tumbukan dan anti-tembus-tembok, sementara client merender proyektil visual 60fps yang tersinkronisasi melalui `BurntFoodThrown` & `BurntFoodImpact`.
  3. **Dukungan Dual-Rig (AnimationConstraint & Motor6D):** Avatar Roblox modern menggunakan `AnimationConstraint` + `BallSocketConstraint` bawaan, sedangkan rig klasik memakai `Motor6D`. `ThrowableService` mendeteksi dan mengelola kedua tipe sendi secara aman dengan token pemulihan 2.0 detik.
  4. **Anti-Griefing:** Korban di dalam Safe Zone, baru spawn (<5s), atau dalam masa kebal pasca-ragdoll (8s) terlindungi dari ragdoll, dan gerobak yang sedang didorong otomatis dihentikan dengan aman sebelum ragdoll diterapkan.
- **Konsekuensi:** Menghadirkan mekanik kekacauan sosial yang lucu, responsif di PC/mobile, bebas error aset suara eksternal, dan aman dari manipulasi exploit multiplayer.

---

## ADR-012: Level-Gated Progression & Pemfilteran Pesanan Pembeli Berdasarkan Resep Terbuka
- **Tanggal:** 2026-11-25
- **Status:** Diterima
- **Konteks:** Modal awal Rp 50.000 tetap dipertahankan demi kompatibilitas alur pemula/tutorial, namun tanpa *level-gating*, pemain baru dapat membeli terlalu banyak konten di menit awal, sementara pembeli NPC berisiko memesan menu mahal yang belum dibuka pemain.
- **Keputusan:**
  1. Seluruh resep (7 menu) dan upgrade (12 item di 7 kategori) memiliki `UnlockLevel` / `RequiredLevel` (Lv.1–Lv.6) serta `PrerequisiteId` opsional yang divalidasi di server (`ProgressionService` & `EconomyService`).
  2. `CustomerService:SpawnCustomerForPlot` selalu menyaring `AllowedRecipes` arketipe dengan daftar resep yang sudah dibuka pemilik plot (`ProgressionService:GetUnlockedRecipeIds`).
  3. Setiap upgrade terhubung ke efek mekanik dan visual nyata (termasuk `Kasir Mas Budi` NPC auto-serve yang menggunakan jalur transaksi atomik yang sama dengan pelayanan manual).
- **Konsekuensi:** Menjaga pacing permainan tetap bertahap selama 30–40 menit ke endgame tanpa menghukum pemain dengan pesanan mustahil.

---

## ADR-013: Gacha Cabai Basis-Points Server-Authoritative & Cashback Net-Sink
- **Tanggal:** 2026-11-25
- **Status:** Diterima
- **Konteks:** Sistem collectible cabai membutuhkan RNG yang transparan, aman dari manipulasi client, adil terhadap pemain kurang beruntung, dan tidak merusak ekonomi game dengan eksploitasi cashback duplikat.
- **Keputusan:**
  1. Seluruh bobot probabilitas didefinisikan dalam integer basis-points (`TotalWeight = 10000`) menggunakan `Random.new()` eksklusif di server (`ChiliService.luau`).
  2. Diterapkan jaminan *pity* 15 roll untuk minimal `Rare+` yang diungkapkan secara eksplisit di UI.
  3. Cashback duplikat memiliki nilai ekspektasi Rp 3.380 terhadap biaya roll Rp 10.000 (*net cash sink* Rp 6.620/roll).
  4. Penyimpanan koleksi memakai `DataStoreService:UpdateAsync` dengan penjagaan versi/monotonic roll count dan fallback memori lokal di lingkungan Studio yang belum terpublikasi.
- **Konsekuensi:** Peluang drop akurat, bebas eksploitasi ekonomi maupun spoofing hasil RNG client, dan tahan terhadap kegagalan penyimpanan DataStore.


## ADR-014: Siklus Waktu 24 Jam & Orkestrasi Random Events (Prompt 12)
- **Konteks:** Permainan membutuhkan atmosfer jalanan Indonesia 24 jam (12 menit real-time = 720 detik) yang tersinkron ke seluruh pemain serta variasi Random Events dinamis (Hujan Deras, Food Vlogger, Pelanggan Misterius, Copet, Preman, Razia Satpol PP, dan Pasar Malam Hantu) tanpa membebani performa atau menumpuk konflik state.
- **Keputusan:**
  - `TimeService` menjadi sumber otoritatif `ClockTime` (`720s` per siklus), interpolasi `Lighting` untuk 4 fase (`Pagi`, `Siang`, `Sore`, `Malam`), pengendalian `PointLight` pada `Bulb` lampu jalan saat `Sore`/`Malam`, dan broadcast `TimeStateUpdated` tiap perubahan fase serta berkala.
  - `EventService` memberlakukan batas maksimal `MaxConcurrentEvents = 2`, cooldown per event, larangan event duplikat bersamaan, pembatasan fase (mis. `pasar_malam_hantu` hanya `Malam` dan otomatis berhenti saat fajar), serta pelacakan berbasis token (`Token`, `Connections`, `SpawnedInstances`, `CleanupCallbacks`) agar penghentian event selalu bersih tanpa kebocoran instance atau koneksi.
  - NPC ancaman event (`Copet`, `Preman`) mendukung interaksi ProximityPrompt sekaligus counterplay lemparan gorengan gosong melalui `ThrowableService -> EventService:OnNpcHitByBurntFood`.
- **Konsekuensi:** Seluruh status waktu, cuaca, dan event berjalan deterministik di server, mudah diuji via remote/service API, serta bebas kebocoran memori maupun tumpang tindih mekanik.


## ADR-015: Sistem Multiplayer, Interaksi Antargerobak & Pengamanan Sosial (Prompt 13)
- **Konteks:** Permainan mendukung hingga 8 pedagang secara bersamaan dalam satu server sehingga membutuhkan isolasi plot bebas konflik, interaksi sosial antargerobak yang adil, kompetisi omzet berbasis leaderboard, sinkronisasi *late-joiner*, serta pertahanan terhadap eksploitasi remote/ragdoll/disconnect.
- **Keputusan:**
  - `GameService` mengelola kunci plot dua arah (`_playerPlots` & `_plotOwners`, maks 8 plot) dan memanggil `CartService:DespawnPlayerCart` + `CustomerService:ClearPlotCustomers` sebelum melepas plot saat `PlayerRemoving`.
  - `SocialService` menjadi otoritas server untuk `leaderstats` (`Omzet`, `Kas`, `Level`), ranking leaderboard real-time (`ScheduleLeaderboardBroadcast` ter-throttle 1 detik), pembelian gerobak tetangga (`RequestBuyFromPlayerCart` dengan bonus `Rp 250`, cooldown `2s`, validasi stok/jarak/koneksi atomik), reaksi sosial (`10s` per pasangan), dan event kompetisi server-wide `Lomba Omzet Gerobak`.
  - `ThrowableService`, `CookingService`, `InventoryService`, `EconomyService`, `EventService`, dan `SatpolService` diperkuat dengan cooldown anti-harassment per-pasangan (`10s`), validasi anti-ragdoll & jarak gerobak, pembersihan rate-limit saat keluar, dan sinkronisasi penuh status aktif ke pemain yang baru bergabung.
- **Konsekuensi:** Interaksi sosial dan kompetisi antarpemain aman dari kecurangan client, bebas konflik plot maupun antrean yatiman saat pemain keluar/masuk, dan siap diuji lanjut di sesi multi-client penuh pada Fase 5.


## ADR-016: Arsitektur Persistensi Profil Terpusat & Session Locking (Prompt 14)
- **Konteks:** Sebelumnya hanya `ChiliService` yang mengakses DataStore terpisah sementara ekonomi, inventaris, upgrade, resep, dan progres pemain hanya berada di memori. Tidak ada library eksternal seperti ProfileStore di `rokit.toml`.
- **Keputusan:**
  - Membangun `DataService.luau` berbasis native `DataStoreService` dengan satu profil terpadu (`Gorengan24Jam_PlayerProfile_v2`, skema `v2`), kontrak `RegisterDomain(Apply, Collect, Cleanup)`, `UpdateAsync` session locking (`JobId` + timeout `90s`), `SaveCount` monotonik, exponential backoff `3x`, dirty-flag throttling, migrasi otomatis `v0`/`v1` → `v2`, serta pembersihan memori terkoordinasi sesudah save selesai di `PlayerRemoving` / `BindToClose`.
  - Menginjeksi `SetStoreAdapter` untuk memungkinkan pengujian deterministik kegagalan jaringan, retry, migrasi, dan round-trip di Studio lokal tanpa ketergantungan eksternal.
- **Konsekuensi:** Konsistensi transaksi lintas domain terjamin (misalnya kas vs cashback/pembelian upgrade tersimpan dalam satu snapshot atomik), bebas duplikasi kuota DataStore, dan siap diverifikasi langsung di cloud DataStore setelah place dipublish ke Roblox.


## ADR-017: Audio Legal Bawaan Roblox, Animasi Prosedural Client-Side & Pengaturan Low-FX (Prompt 15)
- **Konteks:** Permainan membutuhkan suara memasak, transaksi, kentongan/sirine, hujan, feedback UI, serta animasi karakter/NPC tanpa bergantung pada asset audio/animasi berbayar atau ID eksternal yang berisiko gagal dimuat di Studio.
- **Keputusan:**
  - Seluruh efek suara di `AudioVFXController.luau` menggunakan aset bawaan Roblox (`rbxasset://sounds/*.wav` / `*.mp3`) yang telah lolos verifikasi `IsLoaded == true` di Studio.
  - Animasi jalan NPC (`Customer_*` & `Satpol_*`) digerakkan melalui `Motor6D` di sisi client pada 20Hz dan hanya untuk model dalam radius 95 studs (`distance culled`) sehingga tidak membebani jaringan maupun server.
  - Menyediakan menu **Pengaturan (`SettingsHUD`)** berisi kontrol SFX, suara lingkungan/hujan, preset volume, dan mode grafis hemat (**Low-FX**) untuk kompatibilitas perangkat mobile spesifikasi rendah.
- **Konsekuensi:** Bebas error pemuatan asset, hemat CPU/memori pada perangkat mobile, tetap responsif secara visual/audio di PC maupun layar sentuh.


## ADR-018: Optimasi UI/NPC & Pemisahan Otorisasi Remote Audit (Prompt 16)
- **Konteks:** Audit performa dan keamanan menemukan 3 remote pemicu event/razia tanpa guard otorisasi produksi, celah pengambilan bahan toko lewat `RequestTakeIngredients`, validasi `CFrame` dorong gerobak yang belum menyaring `NaN`/pitch-roll, serta alokasi ulang frame pil event UI tiap `0.5s` dan scan `Workspace` 20Hz.
- **Keputusan:**
  - Menambahkan `NetworkBridge.IsAuthorizedAdmin`, `IsFiniteNumber`, dan `IsFiniteVector3` sebagai gerbang terpusat.
  - Memisahkan `InventoryService:GrantPurchasedIngredients` (khusus toko internal) dari `RequestTakeIngredients` (kotak bahan dasar `"batter"`/`"veggies"` saja).
  - Mengganti pola rebuild UI pil event, scan lampu jalan berulang, scan `Workspace` 20Hz, dan pencarian rekursif AI menjadi caching & event-driven tracking dengan pembersihan `Destroying`.
- **Konsekuensi:** Menutup vektor eskalasi hak akses, celah ekonomi/fisika gerobak, dan menurunkan alokasi objek UI serta overhead CPU client pada perangkat mobile.