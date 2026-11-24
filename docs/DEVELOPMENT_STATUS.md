# DEVELOPMENT STATUS — GORENGAN 24 JAM: AWAS SATPOL!

**Fase Berjalan:** Fase 2 Selesai & Diterima (Cart Push & Satpol PP System — 100% Runtime Studio PASS) — Bersiap Memulai Fase 3  
**Terakhir Diperbarui:** 2026-11-24  

---

## 1. Fitur yang Telah Diimplementasikan & Diverifikasi
- **Dokumen Tata Kelola & Standar:**
  - `AGENTS.md` dan `.agents/rules/roblox-project-standards.md`.
  - 10 Agent Skills terintegrasi di `.agents/skills/*`.
  - Dokumentasi teknis: `docs/PROJECT_AUDIT.md`, `docs/TECHNICAL_ARCHITECTURE.md`, `docs/DEVELOPMENT_ROADMAP.md`, `docs/KNOWN_ISSUES.md`, `docs/SETUP_GUIDE.md`, `docs/DECISIONS.md`, `docs/MAP_DOCUMENTATION.md`, `docs/COOKING_SYSTEM.md`, `docs/CUSTOMER_SYSTEM.md`, `docs/ECONOMY_SYSTEM.md`, `docs/PHASE_1_TEST_REPORT.md`.
- **Fondasi Teknis & Jaringan:**
  - Konfigurasi Rojo: `default.project.json` (termasuk StarterGui).
  - Shared contracts: `GameplayTypes.luau`, `GameConfig.luau`, `RecipesConfig.luau`, `EconomyConfig.luau`, `CustomerConfig.luau`.
  - Utility: `Logger.luau`, `Signal.luau`, `ServiceRunner.luau`.
  - Lapisan Jaringan: `Remotes.luau` dan `NetworkBridge.luau` (Rate-limiting, magnitude check, auto-creation).
- **World Building & Peta Modular:**
  - 10 Area wajib di `Workspace.Map` Roblox Studio (386 instance terjangkar, 0 unanchored).
  - 2 Zona Aman resmi: `SafeZone_Barat` (X = -15, Z = -50) & `SafeZone_Timur` (X = 105, Z = -50) dengan tag `CollectionService`.
- **Cart & Cooking System:**
  - Model gerobak fisik kaki lima lengkap di plot pemain.
  - Inventaris bahan baku & etalase siap saji (`InventoryService.luau`).
  - Otoritas memasak server (`CookingService.luau`) dengan ambang batas kematangan (Undercooked 0–30%, Crispy 31–80%, Burnt 81–100%).
  - Client Cooking HUD meteran waktu kematangan real-time (`CookingController.luau`).
- **Customer AI & Selling System:**
  - Customer AI State Machine (`Spawning` -> `Approaching` -> `InQueue` -> `WaitingForFood` -> `Served` / `LostPatience` -> `Leaving`).
  - Variasi 5 Arketipe Pelanggan: Mahasiswa, Driver Ojol, Food Vlogger, Pelanggan Sultan, Mbak Kunti.
  - Sistem antrean rapi (maksimal 3 slot per gerobak, anti-stacking, anti-collision).
  - Balon pesanan 3D (`OrderBubble`) dengan teks menu, meteran kesabaran, dan dialog khas Indonesia.
  - Otoritas transaksi server: verifikasi isi etalase, pemotongan stok, kalkulasi harga + tip bonus crispy, dan penambahan kas pedagang.
- **Economy, Money & Core UI:**
  - Model Dua Dompet Terpisah: Kas Pedagang di Gerobak (`CarriedCash` - rentan razia 25%) vs Tabungan ATM (`BankedCash` - 100% aman).
  - Toko Bahan Baku ("Sumber Rejeki"): Pembelian paket bahan mentah (adonan, sayur, pisang, tahu, tempe, aci tapioka) dengan validasi server.
  - Bengkel Upgrade Gerobak ("Maju Lancar"): Pembelian upgrade peralatan (Wajan Jumbo, Kompor Turbo, Roda Bearing, Etalase 2 Tingkat, Spanduk Neon).
  - ATM Center: Setor dan tarik tunai aman dengan proteksi anti-exploit (tolak nilai negatif, desimal, dan saldo berlebih).
  - Mobile-First Core UI: Top Header Bar (Kas, Bank, Reputasi), Action Dock 4 tombol sentuh ramah jempol (Toko, ATM, Bengkel, Tas), modal dialogs responsif, dan Toast notifications.
- **Tutorial & Onboarding System (Fase 1):**
  - `TutorialService.luau` (Server) & `TutorialController.luau` (Client).
  - 5 Langkah Interaktif: (1) Temukan Gerobak -> (2) Ambil Bahan -> (3) Masak Crispy -> (4) Layani Pembeli -> (5) Beli Upgrade.
  - Hadiah Bonus Modal Rp 10.000 + Reputasi saat lulus tutorial.
- **Cart Push Mobility System (Fase 2 — PROMPT 08):**
  - Pemain dapat mendorong, menghentikan, dan mengarahkan gerobak menuju Safe Zone (`CartService.luau`).
  - Paritas input PC (tombol `[F]` & ProximityPrompt `PushCartPrompt`) dan Mobile (tombol sentuh `ContextActionService`).
  - Mekanik kecepatan adaptif: kecepatan dorong standar 10 studs/s, meningkat menjadi 13.5 studs/s dengan upgrade *Roda Bearing*, kembali normal 16 studs/s saat dilepas.
  - Proteksi anti-speedhack & validasi jarak server-authoritative (`RequestUpdateCartPosition`) mencegah eksploitasi teleportasi gerobak.
- **Satpol PP Raid & AI System (Fase 2 — PROMPT 08):**
  - Siklus Razia Terjadwal & Acak (`Idle` -> `Warning` 15 detik -> `Active` 45 detik -> `Ended`).
  - Peringatan Kentongan & Sirine dengan HUD Countdown Banner animasi dinamis (`RaidController.luau`).
  - Pasukan Satpol PP dengan seragam dinas khaki, baret hijau, lencana emas, dan overhead dialog billboard.
  - AI Patroli, Deteksi (35 studs, cone-of-vision 160°, raycast LOS), dan Pengejaran adil berkecepatan 12.0 studs/s.
  - **Garansi Imunitas Safe Zone:** Gerobak di dalam Safe Zone 100% kebal dari deteksi dan pengejaran; pengejaran otomatis dibatalkan jika gerobak berhasil memasuki Safe Zone.
  - **Penalti Penangkapan:** Sitaan 25% uang kas tunai (`CarriedCash`) dan penghapusan etalase gorengan matang, sementara uang tabungan di ATM (`BankedCash`) dijamin 100% AMAN.
  - Efek komedi layar pusing (*comedic dazed vignette*) dengan getaran kamera ringan saat tertangkap.

## 2. Hasil Audit & Pengujian Runtime Studio (Phase 2 Playtest — PROMPT 08)
- **Total Pengujian Otomatis Live Runtime:** **12 Kasus Uji (12/12 PASS — 100%)**.
- `[PASS]` Cart Spawn & HandlePush Verification.
- `[PASS]` Cart Push Start Standard Speed (10 studs/s).
- `[PASS]` Cart Push Bearing Upgrade Speed Bonus (13.5 studs/s).
- `[PASS]` Cart Push Stop restores normal WalkSpeed (16 studs/s).
- `[PASS]` Anti-Speedhack rejects excessive movement (teleportasi ditolak).
- `[PASS]` Legitimate movement is accepted.
- `[PASS]` Safe Zone Spatial Check (Inside Barat/Timur vs Outside Street).
- `[PASS]` Satpol Raid Warning Trigger (15s state transition).
- `[PASS]` Satpol Active Raid Spawns Squad with 12 studs/s speed.
- `[PASS]` Satpol Capture penalizes 25% CarriedCash while BankedCash remains untouched.
- `[PASS]` Safe Zone Immunity Guarantee: Satpol cannot capture inside SafeZone.
- `[PASS]` Satpol Raid End despawns all officers cleanly.

## 3. Langkah Konkret Selanjutnya (Fase 3: Recipes, Economy, Chili Gacha & Persistence)
1. Ekspansi resep gorengan lanjutan (Tahu Isi Pedas, Pisang Goreng Crispy, Tempe Mendoan, Cireng Crispy).
2. Sistem Gacha Cabai Rawit (Toko Cabai Pak Kumis) dengan variasi tingkat kepedasan & multiplier margin profit.
3. Sistem persistensi data DataStore2 / ProfileService (tabungan ATM, level gerobak, resep terbuka, riwayat reputasi).
4. Mekanik proyektil gorengan gosong (*throwable burnt item*) untuk melempar preman / pengganggu jalanan.
