# DEVELOPMENT STATUS — GORENGAN 24 JAM: AWAS SATPOL!

**Fase Berjalan:** Seluruh Fase 0–5 & Full Game QA Selesai (PROMPT 17 — 20 Area Terverifikasi di Studio Play Mode) — Siap Publish Private Beta  
**Terakhir Diperbarui:** 2026-11-25  

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

- **Throwable Burnt Food & Social Chaos System (PROMPT 09):**
  - Pengambilan gorengan gosong melalui `TakeBurntPrompt` di `EtalaseKaca`, modal Tas (`Ambil Gosong`), tombol HUD (`🎯 Bidik [Q]`), dan tombol lempar cepat (`🔥 Lempar [G]` / Touchscreen).
  - Otoritas server penuh (`ThrowableService.luau`): validasi payload anti-NaN/Inf, kepemilikan & pemotongan stok atomik, cooldown 3.5 detik, jarak maksimum 55 studs, dan simulasi proyektil balistik stepped raycast (anti-tembus-tembok & anti-fake-position).
  - Ragdoll sementara 2.0 detik mendukung rig modern `AnimationConstraint` maupun klasik `Motor6D`, dilengkapi proteksi Safe Zone, Spawn Protection (5s), serta Target Immunity Cooldown (8s) untuk mencegah *stunlock/griefing*.
  - Feedback lengkap: animasi ayunan lengan prosedural, proyektil berputar + asap hitam, ledakan partikel remah gosong + cincin kejut + teks komedi 3D (`BLETAK!`, `PAIT BANGET!`), bintang pusing di atas kepala korban, dan efek suara bawaan Roblox bebas error.

- **Recipes, Upgrades & Progression System (PROMPT 10):**
  - Sistem resep modular 7 menu gorengan khas Indonesia (`RecipesConfig.luau`) lengkap dengan kesulitan, level unlock, biaya unlock, bahan baku, dan zona *Crispy* dinamis.
  - 12 item upgrade lintas 7 kategori (`Gerobak`, `Wajan`, `Kecepatan`, `Penyimpanan`, `Bisnis`, `Kasir`, `Dekorasi`) di `UpgradesConfig.luau` dengan persyaratan level & prasyarat.
  - Seluruh upgrade terhubung nyata ke mekanik server & visual gerobak: percepatan masak (`CookingService`), kapasitas bahan/etalase (`InventoryService`), denda Satpol 25%→12% (`SatpolService`), visual gerobak + neon + lampu + rak 2 tingkat (`CartService`), spawner pembeli & bonus harga/tip + **Kasir NPC (Mas Budi)** auto-serve (`CustomerService`).
  - Sistem Level 1–10, XP bar, dan **Buku Resep UI** (`ProgressionService.luau`, `ProgressionController.luau`, `ShopUIController.luau`) serta pembaruan dokumentasi balancing ekonomi di [docs/ECONOMY_BALANCING.md](file:///c:/Users/HP/Downloads/gorengan-24-jam-roblox/docs/ECONOMY_BALANCING.md).

- **Chili RNG & Collection System (PROMPT 11):**
  - 5 kelangkaan cabai Nusantara (`ChiliGachaConfig.luau`) dengan bobot basis-points eksak (10.000): *Cabai Rawit Hijau* (55%, 1.05x), *Merah Domba* (28%, 1.12x), *Setan Nusantara* (12%, 1.22x + 10% cook speed), *Emas Sultan* (4.2%, 1.35x + 15% XP), *Pelangi Legendaris* (0.8%, 1.55x + 25% XP).
  - Server-authoritative RNG (`ChiliService.luau`) dengan pity guarantee 15x, cashback duplikat net-sink, validasi kepemilikan & cooldown, efek visual toples bercahaya (`ToplesCabai`) di gerobak, serta persistensi `DataStoreService:UpdateAsync` (dengan fallback memori aman di Studio offline).
  - UI lengkap (`ChiliController.luau`) terhubung ke `ChiliShopPrompt` & badge HUD: pengungkapan peluang resmi transparan, animasi roulette pengungkapan hasil gacha, dan tab halaman **Koleksi Cabai**.
  - Dokumentasi analisis probabilitas & ekonomi di [docs/CHILI_RNG_DESIGN.md](file:///c:/Users/HP/Downloads/gorengan-24-jam-roblox/docs/CHILI_RNG_DESIGN.md).

- **Day/Night Cycle & Random Events System (PROMPT 12):**
  - Siklus 24 jam penuh berdurasi 12 menit real-time (`720` detik) di `TimeScheduleConfig.luau` & `TimeService.luau` dengan 4 fase atmosfer (`Pagi`, `Siang`, `Sore`, `Malam`), sinkronisasi `Lighting` ke seluruh pemain via `TimeStateUpdated`, dan pengendalian lampu jalan `Bulb` (`PointLight`) otomatis saat `Sore`/`Malam`.
  - Orkestrasi 7 Random Events (`EventsConfig.luau` & `EventService.luau`): `hujan_deras` (+25% harga jual + VFX partikel & suara hujan), `food_vlogger` (spawn Vlogger Viral), `pelanggan_misterius` (spawn Sultan Misterius), `copet` (NPC Copet di `Workspace.EventNPCs` + counterplay usir/lempar gosong), `preman` (NPC Preman di `Workspace.EventNPCs` + opsi bayar keamanan/usir/lempar gosong), `razia_satpol` (terkoordinasi dengan `SatpolService`), dan `pasar_malam_hantu` (khusus fase `Malam`, auto-berhenti saat fajar, +30% bonus tip).
  - Pembatasan maksimal 2 event bersamaan, cooldown per event, larangan event duplikat, dan pembersihan berbasis token (0 sisa koneksi/NPC/VFX setelah berhenti).
  - HUD waktu & event aktif di client (`TimeAndEventController.luau`: `WorldTimeHUD`, pill durasi event, partikel & suara hujan lokal).

- **Multiplayer & Social Systems (PROMPT 13):**
  - Manajemen eksklusif maksimal 8 plot pemain dengan kunci dua arah (`_playerPlots` & `_plotOwners` di `GameService.luau`), atribut `OwnerUserId`/`PlotId` pada model gerobak (`CartService.luau`), serta pembersihan antrean pelanggan (`ClearPlotCustomers`) saat pemain disconnect.
  - Interaksi antargerobak otoritatif (`SocialService.luau` & `SocialController.luau`): `SocialVisitPrompt` di `EtalaseKaca`, inspeksi menu tetangga (`RequestInspectPlayerCart`), pembelian gorengan Crispy antarpemain (`RequestBuyFromPlayerCart` dengan bonus tetangga `Rp 250` dan validasi atomik anti-disconnect), serta 3 reaksi sosial (`👍 Jempol`, `🔥 Semangat`, `🚨 Awas Satpol!`) dengan teks melayang 3D.
  - Kompetisi pendapatan & Leaderboard real-time (`leaderstats` `Omzet`/`Kas`/`Level`, ranking sesi di `SocialLeaderboardHUD`, pengumuman #1 Raja Gorengan, dan event server-wide `Lomba Omzet Gerobak` +20%).
  - Penguatan keamanan multiplayer: cooldown pembelian (`2s`), cooldown reaksi per-pasangan (`10s`), cooldown anti-harassment lemparan per-pasangan (`10s`), validasi jarak & anti-ragdoll pada memasak/bahan/dorong, sanitasi `NaN`/`math.huge`, pembersihan `NetworkBridge` rate limit saat keluar, serta sinkronisasi event/razia untuk pemain yang bergabung terlambat (*late-joiner*).
  - Laporan uji lengkap di [docs/MULTIPLAYER_TEST_REPORT.md](file:///c:/Users/HP/Downloads/gorengan-24-jam-roblox/docs/MULTIPLAYER_TEST_REPORT.md).

- **Player Data & Persistence (`DataService.luau` & `DataConfig.luau` — PROMPT 14):**
  - Penyimpanan terpusat skema `v2` (`Gorengan24Jam_PlayerProfile_v2`) mencakup: `CarriedCash`, `BankedCash`, `Reputation`, `Inventory` (bahan & etalase), `UnlockedRecipes` & `SelectedRecipeId`, `Upgrades`, `ChiliCollection`, `Progression` & status `Tutorial`, serta `Stats` pemain.
  - Mekanisme aman `DataStoreService:UpdateAsync`, *session locking* berbasis `JobId` & timeout `90s`, `SaveCount` monotonik, retry exponential backoff `3x`, dirty-flag throttling (`10s` min interval / `60s` autosave), migrasi otomatis `v0`/`v1` → `v2` + sanitasi anti-korup (`NaN`/negatif/ID palsu), serta koordinasi `PlayerRemoving` & `game:BindToClose` bersama 5 domain service (`Economy`, `Inventory`, `Progression`, `Tutorial`, `ChiliCollection`).
  - Dokumentasi lengkap dan batasan verifikasi cloud di [docs/PERSISTENCE_REPORT.md](file:///c:/Users/HP/Downloads/gorengan-24-jam-roblox/docs/PERSISTENCE_REPORT.md).

- **Visual, Audio, Animation & UI Polish (PROMPT 15):**
  - **World & Visual Polish (`MapService.luau`, `TimeService.luau`, `CartService.luau`):** Landmark *Tugu Gorengan Nusantara* di Central Hub, 2 *Pos Ronda & Kentongan Bambu* di gerbang Safe Zone, 10 pohon tropis low-poly, bangku trotoar, tong sampah, umbul-umbul Merah Putih, atmosfer & efek `GorenganBloom`/`GorenganSunRays`, detail gerobak (Tabung Gas Melon 3kg, botol sambal/kecap, pajangan etalase, strip kanopi, serta partikel emas `CrispySparkles`).
  - **NPC Rigs & Procedural Animation (`CustomerService.luau`, `SatpolService.luau`, `AudioVFXController.luau`):** Lengan, kaki `Motor6D`, mata ekspresif, dan aksesori arketipe (helm Ojol, kamera Food Vlogger, kacamata Sultan, ransel Mahasiswa, pentungan Satpol); animasi jalan prosedural client-side (20Hz, distance-culled `<= 95 studs`) serta animasi aksi memasak, mengambil bahan, melayani, dan mendorong gerobak.
  - **Audio Legal & Settings UI (`AudioVFXController.luau`, `CookingController.luau`, `ShopUIController.luau`, `CartController.luau`, `TimeAndEventController.luau`):** 14 slot efek suara `rbxasset://sounds/*` terverifikasi `IsLoaded == true` (minyak mendesis & splash, lonceng Crispy, mesin kasir, kentongan bambu, sirine Satpol, roda gerobak, hujan, ambience jalanan, klik UI), `UISizeConstraint` responsif untuk modal mobile, serta tombol **Pengaturan** (SFX, Ambience, Volume, Mode Grafis Hemat Low-FX).
- **Performance & Security Audit (PROMPT 16):**
  - **Keamanan (`NetworkBridge.luau`, `SatpolService.luau`, `EventService.luau`, `SocialService.luau`, `InventoryService.luau`, `CartService.luau`, `CustomerService.luau`):** Proteksi admin-only `IsAuthorizedAdmin` untuk 3 remote test/event, penutupan celah ambil bahan toko gratis di `RequestTakeIngredients` (`batter`/`veggies` only), validasi `CFrame` anti-`NaN`/orientasi miring di `UpdateCartPosition`, validasi `Vector3`/`customerId`/anti-ragdoll pada SafeZone & Serve.
  - **Performa (`TimeAndEventController.luau`, `TimeService.luau`, `AudioVFXController.luau`, `CustomerService.luau`):** Reuse cached `EventPill` UI (0 alloc churn per 0.5s), caching lampu jalan `PointLight`, pelacakan NPC berbasis event (0 scan `Workspace:GetChildren()` 20Hz), pembersihan `_hookedButtons` via `Destroying`, dan penghapusan pencarian rekursif `FindFirstChild(..., true)` di loop kesabaran NPC.
  - Laporan lengkap di [docs/PERFORMANCE_AUDIT.md](file:///c:/Users/HP/Downloads/gorengan-24-jam-roblox/docs/PERFORMANCE_AUDIT.md) dan [docs/SECURITY_AUDIT.md](file:///c:/Users/HP/Downloads/gorengan-24-jam-roblox/docs/SECURITY_AUDIT.md).

## 2. Hasil Audit & Pengujian Runtime Studio (Phase 2, PROMPT 09–16)
- **Phase 2 Playtest (PROMPT 08):** **12/12 PASS (100%)**.
- **Throwable Burnt Food (PROMPT 09):** **9/9 Server & Security Tests PASS + 5/5 Real Client-Server Flow PASS (100%)**.
- **Recipes, Upgrades & Progression (PROMPT 10):** **6/6 Server Progression/Upgrade Tests PASS + 3/3 Real Client-Server UI Flow PASS (100%)**.
- **Chili RNG & Collection (PROMPT 11):** **6/6 Server RNG & Security Tests PASS + 3/3 Real Client-Server Gacha Flow PASS (100%)**:
  - `[PASS]` Bobot probabilitas tepat `10.000` (`100.00%`).
  - `[PASS]` Uji statistik 10.000 roll Luau server sesuai peluang resmi.
  - `[PASS]` Pity 15x menjamin `Rare+` di 200/200 percobaan.
  - `[PASS]` Penolakan roll saat kas kurang & spam cooldown `1.2s`.
  - `[PASS]` Penolakan pasang cabai palsu/belum dimiliki & pemasangan `ToplesCabai` di gerobak.
  - `[PASS]` Integrasi multiplier penjualan (`1.22x`/`1.55x`), bonus XP (`+25%`), dan kecepatan masak *Cabai Setan* (`9.0s → 8.18s`).
  - `[PASS]` Alur nyata Client→Server (`RequestRollChiliGacha` → update live `ChiliHUD` & `ToplesCabai` + penolakan `RequestEquipChili` ilegal).
- **Day/Night Cycle & Random Events (PROMPT 12):** **5/5 Server Cycle/Events Tests PASS + 2/2 Real Client-Server HUD/VFX Tests PASS (100%)**:
  - `[PASS]` Siklus 24 jam (`720s`) & transisi pencahayaan `Pagi`/`Siang`/`Sore`/`Malam` + toggle lampu jalan `Bulb`.
  - `[PASS]` Seluruh 7 Random Events (`hujan_deras`, `food_vlogger`, `pelanggan_misterius`, `copet`, `preman`, `razia_satpol`, `pasar_malam_hantu`) mulai, berjalan, dan bersih total saat `StopEvent`.
  - `[PASS]` Pembatasan event malam (`pasar_malam_hantu`) ditolak pada siang/pagi dan otomatis berhenti saat fajar (`06:00`).
  - `[PASS]` Spawn `Copet_*` & `Preman_*` di `Workspace.EventNPCs` serta counterplay lemparan gorengan gosong (`OnNpcHitByBurntFood`).
  - `[PASS]` Maksimal 2 event bersamaan (`hujan_deras` + `food_vlogger`), penolakan duplikat & event ke-3, serta `StopAllEvents()` meninggalkan 0 sisa NPC/VFX.
  - `[PASS]` Client `WorldTimeHUD`, pill event aktif, `ClientRainVFX`, dan `ClientRainAmbience` muncul saat `Start` dan bersih saat `Stop`.
- **Multiplayer & Social Systems (PROMPT 13):** **6/6 Server Multiplayer & Security Tests PASS + 3/3 Real Client–Server HUD/Remote Tests PASS (100%)**:
  - `[PASS]` Alokasi maksimal 8 plot, anti-konflik kepemilikan, dan pembukaan slot otomatis saat disconnect.
  - `[PASS]` Atribut kepemilikan gerobak (`OwnerUserId`, `PlotId`), `SocialVisitPrompt`, dan `leaderstats` (`Omzet`, `Kas`, `Level`).
  - `[PASS]` Isolasi transaksi antarpemain & `ClearPlotCustomers` saat pemilik plot keluar.
  - `[PASS]` Pengamanan ATM (`NaN`/negatif/`math.huge`), penolakan interaksi/lemparan tidak valid, dan blokir aksi saat ragdoll.
  - `[PASS]` Sinkronisasi *late-joiner* (`Icon`, `BannerColor`, `RemainingSeconds`, status razia) & Event Kompetisi Server-Wide.
  - `[PASS]` Real client UI click membuka `LeaderboardModal`, merender baris peringkat, dan menolak payload remote abuse.
- **Player Data & Persistence (PROMPT 14):** **8/8 Server Persistence & Migration Tests PASS** (menggunakan Simulated DataStore Adapter di Studio; *live Roblox cloud DataStore belum terverifikasi karena `Place1.rbxl` belum dipublish*):
  - `[PASS]` Probe DataStore offline aman tanpa crash; round-trip Leave & Rejoin mempertahankan seluruh 8 domain data (`Cash`, `Bank`, `Inventory`, `Recipes`, `Upgrades`, `Chili`, `Progression`, `Stats`).
  - `[PASS]` Dirty flag & throttling `MinSaveIntervalSeconds`, retry `3x` pada error sementara, penolakan bersih saat outage total, migrasi skema `v0`→`v2` + pembersihan `NaN`/negatif/ID ilegal, `BindToClose` shutdown flush, serta *session locking* anti-duplikasi sesi.
- **Visual, Audio & UI Polish (PROMPT 15):** **4/4 Server Visual/NPC Rig Tests PASS + 2/2 Client Audio/Settings/Responsive UI Tests PASS (100%)**:
  - `[PASS]` `Map.PolishDecorations` (`TuguGorenganNusantara`, `PosRonda_Barat/Timur`, `PohonTropis`), `GorenganAtmosphere`/`Bloom`/`SunRays`, serta detail gerobak (`TabungGasMelon`, `CrispySparkles`).
  - `[PASS]` NPC `Customer_CUST_*` dan `Satpol_*` memiliki joint `Motor6D` lengan/kaki lengkap & aksesori (`SatpolBaton`).
  - `[PASS]` Seluruh channel audio `GorenganAudioBank` berstatus `IsLoaded == true`, `SettingsHUD` (`DisplayOrder = 20`) & `ModalsHUD` memiliki `UISizeConstraint` responsif, dan tangkapan layar UI/Landmark terverifikasi bebas overlap.
- **Performance & Security Audit (PROMPT 16):** **4/4 Server Audit Tests PASS + 4/4 Live Client–Server Security & UI Perf Tests PASS (100%)**:
  - `[PASS]` Metrik Studio terukur: `466` BaseParts (`0` unanchored map), `12` PointLights, `6` ParticleEmitters, reuse `EventPill` tanpa alokasi ulang UI, caching lampu jalan `TimeService`.
  - `[PASS]` Penolakan live remote atas bahan toko via peti gratis, `CFrame` invalid/`NaN`/terbang, `SafeZone NaN`, `ServeCustomer` invalid, serta rate limiter `12 req/s`.
- **Full Game QA & Regression Testing (PROMPT 17):** **20 Area Gameplay & Teknis Lulus Verifikasi Studio Play Mode**:
  - `[PASS]` Client–Server Live E2E (`01`–`19`), Audio/Animasi R15 `AnimationConstraint` (0 error Console), Satpol scheduler isolation, Data Persistence round-trip & migrasi `v0`→`v2`, serta UI PC (`1094x561` `Overlaps=0`) & simulasi mobile (`844x390` `Mobile844x390Fit=true`).
  - `[FIXED]` `BUG-001`..`BUG-006` (animasi `RightShoulder.C0` R15, race condition scheduler `SatpolService` vs `EventService`, overlap HUD `TopHeaderBar`/`ToastContainer`/`TutorialCard` + modal responsif, sinkronisasi `leaderstats` saat rejoin, pembersihan 9 objek dummy di `Place1.rbxl`).
  - Dokumentasi lengkap: [docs/QA_TEST_PLAN.md](file:///c:/Users/HP/Downloads/gorengan-24-jam-roblox/docs/QA_TEST_PLAN.md), [docs/QA_TEST_REPORT.md](file:///c:/Users/HP/Downloads/gorengan-24-jam-roblox/docs/QA_TEST_REPORT.md), dan [docs/BUG_TRACKER.md](file:///c:/Users/HP/Downloads/gorengan-24-jam-roblox/docs/BUG_TRACKER.md).

## 3. Langkah Konkret Selanjutnya (Release & Private Beta)
1. Publish `Place1.rbxl` ke Roblox (Private) dan aktifkan *Studio Access to API Services* untuk verifikasi live cloud `DataStoreService`.
2. Uji *Roblox Studio Local Server (2+ Players)* dan perangkat mobile fisik nyata untuk verifikasi sentuhan & replikasi multiplayer lintas klien sebelum rilis publik.
