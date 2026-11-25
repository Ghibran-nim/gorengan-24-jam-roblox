# Rencana Pengujian QA — Gorengan 24 Jam: Awas Satpol!

**Dokumen:** `docs/QA_TEST_PLAN.md`  
**Fase:** Prompt 17 — Full Game QA & Regression Testing  
**Cakupan:** Seluruh 20 area fungsional & teknis + 8 jenis pengujian (Functional, Integration, Multiplayer, Edge Case, Regression, Performance, Mobile, Security).

---

## 1. Tujuan & Kriteria Kelulusan

1. Memverifikasi alur inti *vertical slice* (spawn -> tutorial -> ambil bahan -> masak -> layani pelanggan -> uang/ATM -> upgrade -> razia Satpol PP -> kabur ke Safe Zone) berjalan tanpa *blocking bug* atau error di Output Roblox Studio.
2. Memverifikasi sistem fase lanjutan: Throwable gosong, Resep & Progression, Chili RNG Gacha & Koleksi, Siklus Siang/Malam 12 menit (720s), 7 Random Events (termasuk event bersamaan & pembersihan), Multiplayer Sosial (maks 8 plot, leaderboard, interaksi antargerobak), Data Persistence Schema v2 (DataStore retry, session lock, migrasi v0/v1 -> v2).
3. Memverifikasi keamanan server-authoritative (validasi tipe, range, jarak fisik, kepemilikan, cooldown, rate limit 12 req/s, anti-exploit DataStore/Economy/RNG).
4. Memverifikasi tata letak UI bebas tumpang tindih (*zero overlap*) di PC (`1094x561`+) serta kepatuhan ukuran layar mobile landscape (`844x390`) dan anggaran performa (`< 5000` Workspace descendants).

---

## 2. Matriks 20 Area Pengujian

| # | Area | Tipe Pengujian | Skenario Utama |
|---|------|----------------|----------------|
| 1 | Player Spawning | Functional, Map Hygiene | Karakter spawn di map, Plot #1..8 teralokasi, `Gerobak_<Player>` muncul, tidak ada sisa objek dummy |
| 2 | Tutorial | Functional, Persistence | Ambil status tutorial, maju langkah 1..5, kelulusan / skip tersimpan & bonus modal diberikan sekali |
| 3 | Cart System | Functional, Integration, Security | Dorong/henti gerobak (`RequestStartPushCart` / `Stop`), validasi jarak `<= 16 studs`, sinkronisasi kecepatan |
| 4 | Ingredient System | Functional, Edge Case | Ambil `batter`/`veggies` dari kotak gerobak (`RequestTakeIngredients`), penolakan saat kapasitas penuh atau bahan berbayar |
| 5 | Cooking System | Functional, Security | Mulai masak (`RequestStartCooking`), angkat cepat -> `Undercooked`, tepat waktu -> `Crispy`, gosong -> `Burnt` di server |
| 6 | Customer AI | Functional, Integration | Auto-spawner antrean maks 3/plot (+1 slot event VIP), sabar habis -> despawn, tolak `FAKE_CUST_999` |
| 7 | Selling System | Integration, Economy | Sajikan gorengan matang sesuai pesanan -> kas bertambah sesuai multiplier cabai/event + tercatat di Omzet |
| 8 | Economy | Functional, Security | Setor & tarik ATM (`RequestDepositATM`/`WithdrawATM`), tolak nominal negatif/NaN/melebihi saldo |
| 9 | Upgrade | Functional, Integration, Security | Beli upgrade valid (`wajan_jumbo`, dll.), tolak ID palsu (`cheat_upgrade_999`), idempoten |
| 10 | Satpol PP | Integration, Regression | Siklus scheduler Warning (15s) -> Active (45s) -> Ended tanpa *race condition* ganda saat event dipicu |
| 11 | Safe Zone | Functional, Spatial | Deteksi `CollectionService:GetTagged("SafeZone")` & `RequestCheckSafeZone` saat gerobak aman vs di jalan |
| 12 | Capture & Penalty | Integration, Security | Sita 25% `CarriedCash` (12% dengan `rangka_anti_razia`), bersihkan etalase, `BankedCash` ATM 100% aman |
| 13 | Throwable | Functional, Security | Tolak equip/lempar tanpa stok gosong, tolak koordinat spoofed jarak jauh, hormati cooldown 3.5s |
| 14 | Recipe | Functional, Progression | Cek level & biaya buka resep (`pisang_goreng`, dll.), tolak ID resep palsu, pilih resep aktif |
| 15 | Chili RNG | Functional, Security | Server-authoritative gacha (`RequestRollChiliGacha`), pity counter, cash deduction, equip cabai |
| 16 | Day/Night Cycle | Functional, Integration | Siklus 24h = 720s, sinkronisasi `PhaseId` & lighting antar pemain via `RequestGetWorldState` |
| 17 | Random Events | Integration, Edge Case, Cleanup | Start/stop `hujan_deras`, `pasar_malam_hantu`, `razia_satpol`, 2 event bersamaan bersih tanpa memory leak |
| 18 | Multiplayer | Integration, Security | `leaderstats` Level & Omzet, `RequestGetLeaderboard`, tolak inspeksi/reaksi ke gerobak sendiri |
| 19 | Data Persistence | Unit, Failure, Migration | Round-trip save -> leave cleanup -> rejoin hydrate (Kas, Progression `TotalEarnings`, `leaderstats`), retry saat timeout, migrasi v0->v2 |
| 20 | UI PC & Mobile | Visual, Layout, Animation | 0 overlap HUD pada `1094x561`, semua modal responsif `AnchorPoint=(0.5,0.5)` + `UISizeConstraint` untuk `844x390`, animasi lengan R15 `AnimationConstraint` bebas error |

---

## 3. Lingkungan & Batasan Pengujian

- **Dijalankan Langsung di Roblox Studio (`Place1.rbxl`):** Live Client-to-Server Remotes (`NetworkRemotes`), Play Mode Console Output, Inspection Visual Screenshot, Server Unit Test DataStore Adapter, dan Edit-mode Workspace Verification.
- **Batasan Terbuka (Wajib Diungkapkan):**
  - *Cloud Roblox DataStoreService* tidak aktif di mode lokal karena place belum dipublikasikan ke web Roblox (diuji menggunakan *Mock Store Adapter* yang mensimulasikan `UpdateAsync`, *transient timeout retry*, *session lock*, dan migrasi).
  - Pengujian dilakukan dalam sesi **Studio Play Solo** (1 pemain aktif + simulasi viewport mobile `844x390` + uji validasi *multi-handler* server); uji multi-client fisik lintas perangkat PC/Android/iOS belum dijalankan pada sesi server live terpublikasi.
