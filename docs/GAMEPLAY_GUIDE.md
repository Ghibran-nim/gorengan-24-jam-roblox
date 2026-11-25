# Panduan Gameplay — Gorengan 24 Jam: Awas Satpol!

Dokumen ini merangkum seluruh mekanik gameplay, kontrol PC & Mobile, serta sistem sosial yang terimplementasi di dalam permainan.

---

## 1. Alur Permainan Inti (*Core Loop*)

1. **Masuk & Tutorial:** Pemain mendapat 1 dari 8 plot kavling gerobak di jalan utama dan dibimbing melalui 5 langkah tutorial interaktif (hadiah kelulusan: modal **Rp 10.000**).
2. **Stok Bahan Baku:** Ambil adonan & sayuran gratis secukupnya dari Peti Bahan gerobak, atau beli bahan lanjutan (*Tempe, Pisang, Tapioka, Tahu, Telur, Kulit Risol*) di **Toko Bahan Baku "Sumber Rejeki"** via Action Dock (`Toko`) maupun NPC/bangunan toko.
3. **Memasak di Wajan (`CookingService` & `CookingController`):**
   - Tekan `[E]` / tombol sentuh **Masak** di dekat wajan gerobak.
   - Angkat tepat di **Zona Crispy** (ditentukan di server berdasarkan waktu masak aktual) untuk mendapat gorengan **Crispy** (+bonus tip & XP).
   - Terlalu cepat -> **Undercooked** (harga -50%); terlalu lama (>80%) -> **Burnt / Gosong** (tidak laku dijual, tetapi dapat dilempar!).
4. **Melayani Pembeli (`CustomerService`):**
   - Hingga 3 NPC pembeli (*Mahasiswa, Driver Ojol, Food Vlogger, Pelanggan Sultan, Mbak Kunti*) antre per gerobak (+1 slot event VIP).
   - Dekati pelanggan atau gunakan tombol **Layani** saat stok *Crispy/Undercooked* sesuai pesanan tersedia. Pemilik upgrade **Kasir NPC (Mas Budi)** melayani antrean #1 otomatis setiap 2.5 detik.
5. **Mengamankan Uang ke ATM (`EconomyService`):**
   - **Kas Tunai (`CarriedCash`):** Hasil penjualan langsung masuk ke dompet gerobak; **25% disita** jika tertangkap razia (12% dengan *Rangka Baja Anti-Razia*).
   - **Tabungan ATM (`BankedCash`):** Setor lewat menu **ATM** di Action Dock atau mesin ATM; **100% aman** dari Satpol PP dan Copet.

---

## 2. Kontrol PC & Mobile (Paritas Penuh)

| Aksi | Kontrol PC | Kontrol Mobile / Layar Sentuh |
|---|---|---|
| Ambil Bahan / Masak / Layani / Beli Cabai | `[E]` (ProximityPrompt) | Tap tombol **ProximityPrompt** / tombol aksi |
| Dorong / Lepas Gerobak | `[F]` atau `PushCartPrompt` | Tombol HUD **Dorong Gerobak** |
| Bidik / Lempar Gorengan Gosong | `[Q]` Bidik / `[G]` Lempar | Tombol HUD **🎯 Bidik** & **🔥 Lempar** |
| Kunjungi & Beli dari Gerobak Tetangga | `[V]` / `SocialVisitPrompt` | Tap tombol prompt kunjungan di etalase tetangga |
| Menu ATM, Tas, Resep, Toko, Bengkel, Cabai, Peringkat, Pengaturan | Klik Mouse di Action Dock & Badge HUD | Tap langsung tombol sentuh berjarak aman |

---

## 3. Satpol PP, Safe Zone & Random Events

- **Siklus Razia (`SatpolService`):** Setiap ~120 detik (atau lewat event `razia_satpol`), terdengar **kentongan peringatan 15 detik** sebelum pasukan Satpol PP berpatroli selama **45 detik**.
- **Gang Aman (*Safe Zone*):** Terdapat 2 Safe Zone resmi (*Barat* dan *Timur* bertanda Pos Ronda & garis hijau neon). Dorong gerobak masuk ke zona aman untuk imunitas 100% dan pembatalan kejaran otomatis.
- **Siklus 24 Jam & 7 Event (`TimeService` & `EventService`):**
  - 1 hari penuh = **12 menit waktu nyata** (`720s`) melintasi fase *Pagi Cerah*, *Siang Terik*, *Sore Jingga*, dan *Pasar Malam*.
  - Event aktif maksimal 2 bersamaan: *Hujan Deras Tropis* (+25% harga), *Food Vlogger Viral*, *Pelanggan Misterius*, *Aksi Copet Jalanan*, *Preman Palak Lapak*, *Razia Satpol PP Mendadak*, dan *Malam Jumat Pasar Malam* (+30% tip malam).

---

## 4. Sistem Lanjutan (Throwable, Resep, Cabai RNG & Sosial)

- **Throwable Gosong (`ThrowableService`):** Gorengan gosong dari wajan bisa diambil dan dilempar (maks 55 studs, cooldown 3.5s) ke pemain di luar Safe Zone atau untuk mengusir NPC *Copet* & *Preman*. Korban terdampak ragdoll komedi 2 detik lalu kebal sementara 8 detik (*anti-griefing*).
- **Buku Resep & Upgrade:** Buka hingga 7 resep Indonesia dan beli 12 upgrade di **Bengkel "Maju Lancar"** sesuai Level Pedagang.
- **Kios Cabai Pedas Mampus (`ChiliService`):** Roll gacha berbiaya **Rp 10.000** dengan *pity guarantee* 15x untuk mengoleksi 5 cabai langka (`1.05x` hingga `1.55x` multiplier profit).
- **Interaksi Sosial (`SocialService`):** Lihat peringkat omzet server di `Peringkat`, kunjungi lapak tetangga untuk membeli gorengan *Crispy* (memberi bonus tetangga Rp 250), atau kirim reaksi cepat (`👍 Jempol`, `🔥 Semangat`, `🚨 Awas Satpol!`).
