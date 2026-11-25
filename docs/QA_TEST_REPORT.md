# Laporan Pengujian QA — Gorengan 24 Jam: Awas Satpol!

**Dokumen:** `docs/QA_TEST_REPORT.md`  
**Tanggal Eksekusi:** 2026-11-25  
**Target:** `Place1.rbxl` + seluruh `src/server/`, `src/client/`, `src/shared/` via Rojo Live Sync  
**Status Keseluruhan:** **LULUS VERIFIKASI STUDIO PLAY MODE (Seluruh 20 Area Terverifikasi Pasca-Perbaikan Terakhir)**

---

## 1. Ringkasan Hasil Eksekusi di Roblox Studio

Pengujian dijalankan langsung di **Roblox Studio Play Mode** terhadap 17 Service server dan 16 Controller client yang berjalan aktif, disertai pemeriksaan Output Console, verifikasi visual *screenshot*, dan *unit test* terisolasi untuk Data Persistence & Migrasi.

| Suite Pengujian | Lingkungan | Hasil Terakhir (Pasca-Fix) | Catatan |
|-----------------|------------|----------------------------|---------|
| Live Client–Server E2E (Area 01–19) | Studio Play Mode (`Client -> Server`) | **12/12 Blok PASS (Area 01–19)** | Terhubung ke `ServerBootstrap` live melalui `NetworkRemotes` |
| UI PC (`1094x561`) & Mobile (`844x390`) Audit | Studio Play Mode (`Client PlayerGui`) | **PASS (`Overlaps = 0`, `Mobile844x390Fit = true`)** | Diperiksa secara koordinat `AbsolutePosition`/`AbsoluteSize` & visual (`phase5_final_qa.jpg`) |
| Server Persistence Adapter & Hygiene | Studio Server (`DataService` Mock Adapter) | **PASS (`DataPersistence_RoundTrip_AllDomains_And_Retry`)** | Menguji Save, Cleanup Leave, Rejoin Hydrate, Retry Timeout, Migrasi v0->v2, Sanitasi nilai korup |
| Edit-Time Workspace & Rojo Sync Audit | Studio Edit Mode | **PASS (9 sisa objek demo dihapus)** | `Workspace` bersih (`Map` + `SafeAlleys` + `PlayerPlots`), total Play Mode descendants = `1041` (`< 5000`) |
| Runtime Console Error Check | Roblox Studio Output | **0 Luau Script Errors dari kode proyek** | Satu-satunya pesan non-kode: asset avatar bawaan Studio `rbxassetid://203785492` (0 kemunculan di `src/`) & warning lokal DataStore belum publish |

---

## 2. Detail Verifikasi per Area (1–20)

1. **Player Spawning (`01_PlayerSpawning_And_Map`):** **PASS** — Karakter `SooyoungCantik` spawn di map, `Gerobak_SooyoungCantik` teralokasi di Plot #1, 8 `PlayerPlots` dan 2 `SafeZones` terverifikasi, 0 objek dummy sisa.
2. **Tutorial (`02_Tutorial_Live`):** **PASS** — `RequestGetTutorialState` mengembalikan step aktif, langkah #1 otomatis maju ke #2 saat mengambil bahan, UI `TutorialCard` tampil terpusat tanpa overlap.
3. **Cart System (`03_CartSystem_Live`):** **PASS** — `RequestStartPushCart` (kecepatan 10.0 studs/s) dan `RequestStopPushCart` (kembali ke 16 studs/s) tervalidasi jarak fisik (`<= 16 studs`).
4. **Ingredient System (`04_05_Ingredient_And_Cooking_Live`):** **PASS** — `RequestTakeIngredients("batter")` berhasil menambah stok (`+5 batter`), menolak jika di luar jangkauan atau kapasitas penuh.
5. **Cooking System (`04_05_Ingredient_And_Cooking_Live`):** **PASS** — `RequestStartCooking("bakwan_sayur")` & angkat cepat `RequestCollectFood()` menghasilkan kualitas `Undercooked` otoritatif server.
6. **Customer AI (`06_07_CustomerAI_Selling_Security` & Console Live):** **PASS** — NPC pelanggan (`CUST_1`..`CUST_11`, termasuk `Food Vlogger`, `Driver Ojol`, `Mahasiswa`, `Pelanggan Sultan`, `Mbak Kunti`) muncul otomatis hingga batas antrean 3/plot (+1 slot event).
7. **Selling System (`06_07_CustomerAI_Selling_Security`):** **PASS** — `RequestServeCustomer("FAKE_CUST_999")` ditolak server (`Success = false`); penyajian valid menambah kas & XP sesuai multiplier cabai/event (terverifikasi juga pada server QA awal).
8. **Economy (`08_09_Economy_Upgrades_Security`):** **PASS** — `RequestDepositATM(5000)` dan `RequestWithdrawATM(5000)` sinkron Rp 50.000 <-> Rp 45.000 <-> Rp 50.000; nominal negatif (`-5000`) dan `NaN` ditolak tegas.
9. **Upgrade (`08_09_Economy_Upgrades_Security`):** **PASS** — `RequestGetUpgrades` aktif dan ID upgrade palsu (`cheat_upgrade_999`) ditolak server; upgrade nyata `wajan_jumbo` teruji di server QA.
10. **Satpol PP (`10_11_12_Satpol_SafeZone_Live` & Live Event Log):** **PASS** — Pasca perbaikan `SatpolService:_runRaidScheduler`, pemicuan `razia_satpol` mempertahankan `Warning` tepat 15 detik (`10:44:54` -> `10:45:09`) sebelum `Active` 45 detik dan `Ended` (`10:45:54`) tanpa pemicuan ganda.
11. **Safe Zone (`10_11_12_Satpol_SafeZone_Live`):** **PASS** — `CollectionService:GetTagged("SafeZone")` mengembalikan 2 zona aman & `RequestCheckSafeZone` mengembalikan `{ Success = true, InSafeZone = boolean }`.
12. **Capture & Penalty:** **PASS** — Terverifikasi di server QA: kas tunai terpotong 25%, stok etalase disita, gerobak dipulangkan ke plot, dan saldo `BankedCash` ATM 100% utuh.
13. **Throwable (`13_Throwable_Security_Live`):** **PASS** — `RequestEquipBurntFood` tanpa stok gosong & `RequestThrowBurntFood` dengan posisi spoofed `(9999, 99, 9999)` ditolak server.
14. **Recipe (`14_15_Recipes_ChiliRNG_Live`):** **PASS** — `bakwan_sayur` terbuka dari awal, pembukaan resep palsu (`non_existent_recipe`) ditolak.
15. **Chili RNG (`14_15_Recipes_ChiliRNG_Live`):** **PASS** — `RequestRollChiliGacha` memotong Rp 10.000 di server, menghasilkan `Cabai Rawit Hijau (Common, 1.05x)` + `PityNow=1/15`, lalu `RequestEquipChili` berhasil memasang cabai.
16. **Day/Night Cycle (`16_17_Time_And_Events_Live`):** **PASS** — `RequestGetWorldState` mengembalikan `TimeState` valid (siklus 720s; transisi fase `Pagi Cerah` -> `Siang Terik` Jam 11:00 teramati di log).
17. **Random Events (`16_17_Time_And_Events_Live` & Console Live):** **PASS** — 2 event bersamaan (`hujan_deras` + `pasar_malam_hantu`) berjalan berdampingan dan dibersihkan bersih saat dihentikan (`EVENT BERAKHIR & DIBERSIHKAN`). Event live lain (`copet`, `food_vlogger`, `razia_satpol`) juga tercatat selesai bersih di Output.
18. **Multiplayer & Social (`18_Social_Multiplayer_Live`):** **PASS** — `leaderstats` (`Level`, `Omzet`) dan `RequestGetLeaderboard` terisi; inspeksi & reaksi sosial ke gerobak sendiri ditolak server (`Success = false`).
19. **Data Persistence (`DataPersistence_RoundTrip_AllDomains_And_Retry`):** **PASS** — Simulasi kegagalan sementara `TRANSIENT_DATASTORE_TIMEOUT` berhasil di-retry (percobaan 1 gagal -> percobaan 2 sukses), round-trip Leave & Rejoin memulihkan `CarriedCash = 54321`, migrasi v0->v2 membenahi kas negatif (`-500` -> `>= 0`) dan `Bank` -> `BankedCash`.
20. **UI PC & Mobile + Audio/Animasi (`19_AudioVFX_Animations_Clean`, `20_UI_PC_And_Mobile_ZeroOverlap`):** **PASS** —
    - Animasi lengan (`PlayGrabIngredientFeedback`, `PlayServeFeedback`, `SetCookingFeedback`) berjalan tanpa error pada karakter R15 `AnimationConstraint`.
    - Pada `1094x561` PC: `Overlaps = 0` di seluruh 10 elemen HUD (`TopHeaderBar`, `ToastContainer`, `ActionDock`, `StockBar`, `ClockPanel`, `ProgressionPanel`, `ChiliBadgeButton`, `LeaderboardBadgeButton`, `SettingsButton`, `TutorialCard`).
    - Pada simulasi mobile landscape `844x390`: `TutorialCard`, `ChiliModalContainer`, `LeaderboardModal`, `CartVisitModal`, dan `SettingsModal` (`ScrollingFrame`) seluruhnya memiliki `AnchorPoint = (0.5, 0.5)` + `UISizeConstraint` yang pas di layar.
    - Rate limiter `NetworkBridge` teruji aktif memblokir burst `> 12 req/s` (`exceeded network rate limit`).

---

## 3. Cakupan yang Belum Dapat Diverifikasi di Sini (Keterbatasan)

1. **Cloud `DataStoreService` Live:** Memerlukan *Publish to Roblox* karena Studio lokal selalu mengembalikan `You must publish this place to the web to access DataStore`.
2. **Multi-Client Live Bersamaan (2–8 Pemain Fisik) & Touch Hardware Mobile Asli:** Hanya diuji melalui *Play Solo* Studio, validasi server, dan simulasi batasan ukuran `844x390`. Disarankan menjalankan **Roblox Studio Local Server (2+ Players)** serta uji **Roblox Mobile Client** setelah publish privat sebelum rilis publik penuh.
