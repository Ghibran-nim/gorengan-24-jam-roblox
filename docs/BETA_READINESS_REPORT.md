# Laporan Kesiapan Public Beta — Gorengan 24 Jam: Awas Satpol!

**Dokumen:** `docs/BETA_READINESS_REPORT.md`  
**Tanggal Evaluasi:** 2026-11-25  
**Keputusan Kesiapan:** **SIAP UNTUK PRIVATE BETA TESTING (DENGAN CATATAN KONFIGURASI PRA-PUBLIKASI) — BELUM SIAP LANGSUNG RILIS PUBLIK MASSAL SEBELUM UJI MULTI-KLIEN & CLOUD DATASTORE NYATA.**

---

## 1. Fitur yang Sudah Diimplementasikan (100% Terbangun di `src/`)

- **Fondasi & Arsitektur (`17 Server Services`, `16 Client Controllers`, `10 Shared Configs`):**
  - Bootloader deterministik `init.server.luau` & `init.client.luau` dengan `ServiceRunner` (`Init -> Start`) dan kontrak jaringan tervalidasi di [NetworkBridge.luau](src/shared/Network/NetworkBridge.luau) (rate limit `12 req/s`, distance check, payload sanitization).
- **Gameplay Inti:**
  - Peta modular 10 area + 8 Plot + 2 Safe Zone ([MapService.luau](src/server/Services/MapService.luau)).
  - Tutorial 5 langkah berhadiah modal ([TutorialService.luau](src/server/Services/TutorialService.luau), [TutorialController.luau](src/client/Controllers/TutorialController.luau)).
  - Dorong gerobak PC `[F]` & Mobile Touch ([CartService.luau](src/server/Services/CartService.luau), [CartController.luau](src/client/Controllers/CartController.luau)).
  - Pengambilan bahan & pembelian toko ([InventoryService.luau](src/server/Services/InventoryService.luau)), memasak server-authoritative `Undercooked`/`Crispy`/`Burnt` ([CookingService.luau](src/server/Services/CookingService.luau)), dan 5 arketipe Customer AI ([CustomerService.luau](src/server/Services/CustomerService.luau)).
  - Ekonomi dua dompet (`CarriedCash` vs `BankedCash` ATM), 7 resep Nusantara, 12 upgrade nyata lintas 7 kategori termasuk Kasir NPC Mas Budi ([EconomyService.luau](src/server/Services/EconomyService.luau), [ProgressionService.luau](src/server/Services/ProgressionService.luau)).
- **Signature Survival, Chaos, Koleksi, & Dunia Hidup:**
  - Siklus Razia Satpol PP, AI kejaran adil `12.0 studs/s`, imunitas Safe Zone, dan penalti 25%/12% kas tunai ([SatpolService.luau](src/server/Services/SatpolService.luau)).
  - Lempar gorengan gosong balistik, ragdoll 2s, cooldown & proteksi anti-griefing ([ThrowableService.luau](src/server/Services/ThrowableService.luau)).
  - Gacha Cabai server-authoritative 5 rarity, pity 15x, dan halaman koleksi ([ChiliService.luau](src/server/Services/ChiliService.luau)).
  - Siklus siang/malam `720s` & 7 Random Events terkoordinasi ([TimeService.luau](src/server/Services/TimeService.luau), [EventService.luau](src/server/Services/EventService.luau)).
  - Sistem sosial antargerobak, leaderboard omzet, reaksi, dan `DataService` Schema `v2` ([SocialService.luau](src/server/Services/SocialService.luau), [DataService.luau](src/server/Services/DataService.luau)).
- **Polish & Kualitas Teknis:**
  - 14 slot audio legal `rbxasset://sounds/*`, animasi prosedural NPC & lengan pemain, `SettingsHUD` dengan Mode Low-FX, serta audit keamanan & performa.

> *Catatan Keterbukaan Fitur:* Tidak ditemukan modul placeholder/stub pada fitur yang sudah dibangun di `src/`. Namun **Monetisasi (`MarketplaceService` / Gamepass / Developer Product)** memang **belum diimplementasikan** dan baru tersedia sebagai rancangan di [docs/MONETIZATION_DESIGN.md](docs/MONETIZATION_DESIGN.md).

---

## 2. Fitur yang Sudah Diuji (Terverifikasi Runtime di Roblox Studio)

Mengacu pada [docs/QA_TEST_REPORT.md](docs/QA_TEST_REPORT.md):
- **Boot & Kebersihan Runtime:** 17 Server Services & 16 Client Controllers berjalan dengan **0 Luau runtime error** di Studio Play Mode.
- **Alur E2E Live Client–Server (`NetworkRemotes`):** Terverifikasi pada Area 01–19 (Spawning & Map, Tutorial, Push/Stop Gerobak, Bahan & Masak `Undercooked`, penolakan Customer palsu, ATM Deposit/Withdraw & tolak negatif/`NaN`, Upgrade & tolak ID palsu, Force Raid `Warning -> Ended` & SafeZone check, penolakan Throwable tanpa stok/koordinat spoofed, Recipe & Chili Gacha server-authoritative, Siklus 720s & 2 Event bersamaan bersih, `leaderstats`/Leaderboard & penolakan self-inspect/react, serta animasi lengan R15 `AnimationConstraint`).
- **Siklus Event `razia_satpol` Live:** Terverifikasi transisi persis `15s Warning` -> `45s Active` -> `Ended` tanpa *race condition* ganda.
- **Data Persistence & Migrasi (Mock DataStore Adapter):** Terverifikasi retry saat error `TRANSIENT_DATASTORE_TIMEOUT`, Save -> Leave Cleanup -> Rejoin Hydrate (`CarriedCash`, `Progression`, `Stats`, `Inventory`, `Chili`), dan migrasi `v0 -> v2` + sanitasi nilai korup.
- **UI PC & Simulasi Mobile + Visual Screenshot:** Terverifikasi `Overlaps = 0` di `1094x561` ([phase5_final_qa.jpg](C:/Users/HP/.gemini/antigravity/brain/16581b0f-de21-4949-ace6-9087b4531b72/phase5_final_qa.jpg)) dan `Mobile844x390Fit = true` untuk kartu tutorial dan seluruh modal (`UISizeConstraint` + `ScrollingFrame` Settings).
- **Rate Limiting Security:** Terbukti aktif di Play Mode memblokir burst `> 12 req/s` (`NetworkBridge`).

---

## 3. Fitur yang Belum Diuji Secara Langsung

1. **Cloud `DataStoreService` Roblox Nyata:** Tidak dapat dijalankan saat `Place1.rbxl` masih lokal (`PlaceId = 0`). Baru teruji menggunakan *Mock Store Adapter* memori.
2. **Sesi Multi-Klien Nyata (2–8 Pemain Serentak di Server):** Belum dijalankan melalui *Studio Local Server (2+ Players)* maupun server Roblox online. Interaksi antarpemain lintas klien (beli dari gerobak tetangga live, lempar gorengan gosong ke karakter pemain lain, kepadatan 8 gerobak + puluhan NPC sekaligus, dan *late-joiner* nyata) baru diuji lewat unit/remote logic server + 1 klien Play Solo.
3. **Perangkat Mobile Fisik (Android / iOS Touch & Thermal/FPS Profiling) & Jaringan Latency Nyata:** Ukuran layar `844x390` baru diverifikasi lewat perhitungan layout Studio desktop; kenyamanan tombol sentuh di ponsel nyata dan dampak `StreamingEnabled = true` pada jaringan nyata belum diuji.
4. **Monetisasi (`Gamepasses` & `Developer Products`):** Belum ada implementasi maupun pengujian pembelian (*Test Purchase*) karena belum diaktifkan.

---

## 4. Bug yang Masih Ada

- **Critical:** **0**
- **High:** **0** (seluruh 3 bug High di Prompt 17 — `BUG-001` animasi R15, `BUG-002` race Satpol, `BUG-003` overlap HUD/modal — sudah diperbaiki & lulus regresi)
- **Medium / Low Kode:** **0 terbuka** di [docs/BUG_TRACKER.md](docs/BUG_TRACKER.md).
- **Pesan Log Eksternal Non-Kode:** `ContentId: rbxassetid://203785492 failed due to: Asset type does not match requested type` muncul saat Play Solo akibat aset internal avatar bawaan Roblox Studio (terverifikasi `0` kecocokan di seluruh codebase & scene game).

---

## 5. Risiko yang Belum Diselesaikan (Configuration & Scale Risks)

1. **`Players.MaxPlayers` Studio Masih `30` (Risiko Tinggi Jika Langsung Publish):** `GameConfig.MaxPlayers` dan `Workspace.Map.PlayerPlots` hanya mendukung **8 pemain**. Jika dipublikasikan tanpa mengubah `Players.MaxPlayers` ke `8`, pemain ke-9 dst. tidak akan mendapat plot gerobak.
2. **Place Belum Dipublikasikan (`GameId = 0`, `PlaceId = 0`):** Data pemain belum tersimpan persisten antar-sesi setelah Studio ditutup, dan Experience Settings (Permissions, Guidelines, Metadata) belum terbuat.
3. **`Workspace.StreamingEnabled = true` Belum Diuji Multi-Area Jarak Jauh:** Berpotensi menyembunyikan instance model di luar radius stream pada klien koneksi lambat bila tidak dikonfirmasi pada pengujian server private.
4. **Toolchain CLI `rokit` / `rojo` Tidak Ada di `PATH` Lokal:** Sinkronisasi otomatis bergantung pada Studio + plugin Rojo aktif atau instalasi CLI manual.
5. **Ketiadaan Monetisasi Siap Pakai (Bila Diharapkan Saat Launch):** Memerlukan tambahan `MonetizationService` + uji *ProcessReceipt* jika Public Beta langsung menargetkan pendapatan Robux.

---

## 6. Rekomendasi Sebelum Publikasi Public Beta

1. **Jangan langsung rilis ke Public** — lakukan **Publish Private** terlebih dahulu ke Roblox Experience Anda.
2. Ubah **`Players.MaxPlayers = 8`** di Roblox Studio / Creator Dashboard, aktifkan **Studio Access to API Services**, dan lengkapi **Experience Questionnaire** (termasuk pengungkapan odds gacha cabai).
3. Jalankan **2–4 Pemain Test di Private Server / Studio Local Server**: uji pembelian antargerobak, lemparan gosong antar-pemain, razia 8 plot, `StreamingEnabled`, serta persistensi *cloud DataStore* (`Leave -> Rejoin`).
4. Lakukan uji **15–30 menit di HP Android/iOS** kelas menengah untuk mengonfirmasi ergonomi sentuh dan stabilitas FPS saat event `hujan_deras` + `razia_satpol`.
5. Putuskan apakah Public Beta dirilis **100% Free-to-Play dulu** (direkomendasikan untuk validasi retensi awal) atau mengimplementasikan paket opsional di [docs/MONETIZATION_DESIGN.md](docs/MONETIZATION_DESIGN.md) sebelum pembukaan publik.
