# KNOWN ISSUES & TECHNICAL DEBT — GORENGAN 24 JAM: AWAS SATPOL!

Dokumen ini mencatat masalah teknis yang teridentifikasi, keterbatasan sistem, dan area mitigasi yang harus dipantau selama pengembangan.

---

## 1. Masalah & Keterbatasan Teridentifikasi

### ISSUE-001: Ketiadaan Toolchain CLI Rokit/Rojo di Lingkungan Terminal
- **Tingkat Keparahan:** Medium (Workflow / Developer Experience)
- **Status:** Open / Workaround Available
- **Deskripsi:** Eksekusi `rokit` dan `rojo` pada sesi terminal lokal menghasilkan pesan *command not found* karena binary belum masuk ke sistem `PATH`.
- **Dampak:** Perintah sinkronisasi CLI otomatis via shell tidak dapat dijalankan langsung melalui skrip background terminal.
- **Mitigasi:** Menggunakan antarmuka plugin Roblox Studio atau MCP `Roblox_Studio` yang terhubung langsung ke instance Studio yang aktif, serta memelihara struktur file lokal secara cermat agar siap disinkronkan saat toolchain tersedia.

---

### ISSUE-002: Teknologi Pencahayaan "Voxel" pada `default.project.json`
- **Tingkat Keparahan:** Low (Visual Quality)
- **Status:** Open
- **Deskripsi:** Konfigurasi default pencahayaan diatur ke `"Voxel"`. Meskipun sangat ringan untuk platform mobile entry-level, teknologi Voxel tidak menghasilkan bayangan dinamis lampu jalan malam hari dan neon warung yang tajam.
- **Dampak:** Atmosfer malam (fase jam 21:00 - 04:00) yang menjadi daya tarik game berpotensi terlihat datar.
- **Mitigasi:** Uji coba peningkatan ke `"ShadowMap"` pada Fase 5 dengan profiling performa perangkat mobile untuk memastikan frame rate tetap di atas 30-60 FPS.

---

### ISSUE-003: Risiko Eksploitasi Network Ownership pada Mekanik Dorong Gerobak
- **Tingkat Keparahan:** High (Multiplayer / Security)
- **Status:** Mitigated (Prompt 08 & Prompt 16)
- **Deskripsi:** Jika posisi gerobak dimanipulasi client secara sepihak, exploiter dapat memindahkan gerobak seketika ke Safe Zone atau memiringkan model.
- **Mitigasi Terimplementasi:** `CartService.luau` memvalidasi `RequestUpdateCartPosition` di server dengan pemeriksaan `CFrame` finite/anti-`NaN`, anti-tilt, kecepatan delta maksimal, serta koreksi kembali ke posisi aman terakhir bila melampaui batas.

---

### ISSUE-004: Potensi Beban CPU pada Spawning & Pathfinding Massal NPC
- **Tingkat Keparahan:** Medium (Server Performance)
- **Status:** Mitigated (Prompt 06, Prompt 15, & Prompt 16)
- **Deskripsi:** Banyak pelanggan NPC, Satpol PP, dan event NPC bersamaan dapat membebani CPU server/client.
- **Mitigasi Terimplementasi:** Batas antrean 3 pelanggan per plot (+1 slot event), animasi walk swing NPC dipindahkan ke client (`AudioVFXController.luau`) dengan frequency `20Hz` + distance culling `<= 95 studs`, serta event-driven NPC tracking tanpa scan `Workspace` per frame.

---

### ISSUE-006: Place Masih Lokal & Belum Dipublish (`GameId = 0`, `PlaceId = 0`)
- **Tingkat Keparahan:** Critical for Release (Persistence & Dashboard Settings)
- **Status:** Open (Menunggu Persetujuan Publikasi Pemilik)
- **Deskripsi:** `Place1.rbxl` belum dipublish ke Roblox Cloud sehingga `DataStoreService` melempar error lokal dan otomatis memakai mode fallback memori sesi.
- **Mitigasi:** Publish privat ke Roblox, aktifkan *Studio Access to API Services*, dan uji round-trip cloud DataStore nyata sebelum Public Beta.

---

### ISSUE-007: Ketidaksesuaian `Players.MaxPlayers` Studio (`30`) vs Kapasitas Plot (`8`)
- **Tingkat Keparahan:** High for Release (Server Capacity)
- **Status:** Open (Belum Diubah Tanpa Izin Pemilik)
- **Deskripsi:** Pemeriksaan DataModel Studio menunjukkan `Players.MaxPlayers = 30`, sedangkan `GameConfig.MaxPlayers` dan `Workspace.Map.PlayerPlots` dirancang untuk maksimal **8 pemain**.
- **Mitigasi:** Wajib set `MaxPlayers = 8` pada Place Settings / Creator Dashboard sebelum server dibuka untuk pemain beta.

---

### ISSUE-008: Evaluasi `Workspace.StreamingEnabled = true` Belum Diuji Multi-Pemain Jaringan Nyata
- **Tingkat Keparahan:** Medium (Replication / Streaming)
- **Status:** Open (Requires Live Private Server Check)
- **Deskripsi:** Properti `StreamingEnabled = true` aktif di `Place1.rbxl`. Pada skenario jaringan publik dengan bandwidth lambat, objek gerobak/NPC jauh berpotensi mengalami delay stream.
- **Mitigasi:** Uji pada server private Roblox; nonaktifkan atau atur `ModelStreamingMode` bila ditemukan kendala visibilitas antargerobak.

---

### ISSUE-009: Monetisasi (Gamepasses & Developer Products) Belum Terimplementasi
- **Tingkat Keparahan:** Low (Opsional untuk Beta F2P)
- **Status:** Open / Deferred
- **Deskripsi:** Belum ada integrasi `MarketplaceService` (`ProcessReceipt` / `UserOwnsGamePassAsync`) di codebase. Permainan berjalan 100% Free-to-Play.
- **Mitigasi:** Rancangan lengkap & pengaman keseimbangan tersedia di `docs/MONETIZATION_DESIGN.md` bila monetisasi akan diaktifkan.

---

### ISSUE-005: Mapping `StarterGui` Belum Ada di `default.project.json`
- **Tingkat Keparahan:** Low (Architecture)
- **Status:** Resolved
- **Deskripsi:** `default.project.json` sebelumnya belum memetakan `StarterGui`.
- **Resolusi:** `StarterGui` telah dipetakan secara eksplisit di `default.project.json` dengan konfigurasi `ResetPlayerGuiOnSpawn: false`. Seluruh UI client dibangun secara terprogram melalui controller modern (`HUDController`, `ShopUIController`, `CookingController`, `CustomerUIController`, `TutorialController`).

---

## 2. Masalah yang Diselesaikan pada Integrasi & Playtest Fase 1 (PROMPT 07)

### RESOLVED-001: Ketiadaan Sistem Panduan Tutorial Pemula (Onboarding Flow)
- **Status:** Resolved
- **Deskripsi:** Acceptance criteria Fase 1 mewajibkan tutorial pemula dapat dijalankan.
- **Resolusi:** Diimplementasikan `TutorialService.luau` di server dan `TutorialController.luau` di client yang membimbing pemain melalui 5 langkah konkret dengan kartu HUD visual dan hadiah bonus modal Rp 10.000 saat lulus.

### RESOLVED-002: Nil Indexing pada Dialog Arketipe Pelanggan
- **Status:** Resolved
- **Deskripsi:** Pemanggilan `_handleCustomerLostPatience` menyebabkan crash `attempt to index nil with 'Dialogues'` jika ID arketipe tidak cocok.
- **Resolusi:** Ditambahkan defensive fallback `local arch = archetype or CustomerConfig.GetArchetype(order.ArchetypeId) or CustomerConfig.GetRandomArchetype()`, serta penanganan string dialog bawaan yang aman.

### RESOLVED-003: Indefinite Yield pada `Humanoid.MoveToFinished:Wait()`
- **Status:** Resolved
- **Deskripsi:** Dalam situasi rintangan atau saat pengujian simulasi tanpa langkah fisika aktif, `MoveToFinished:Wait()` menggantung selamanya (*hang*).
- **Resolusi:** Diganti dengan *bounded wait loop* bertenggang waktu maksimal 5 detik dengan pemutusan koneksi otomatis saat tiba atau timeout tercapai.

### RESOLVED-004: Eksekusi Siklus Kesabaran Pembeli secara Sinkron
- **Status:** Resolved
- **Deskripsi:** `_setupActiveCustomerOrder` berjalan di thread utama sehingga memblokir pemanggilan fungsi lain selama 30 detik durasi kesabaran.
- **Resolusi:** Dibungkus dalam `task.spawn` terisolasi sehingga state machine pembeli berjalan asinkron di latar belakang.

### RESOLVED-005: Lompatan Ganda Langkah Tutorial (Double Step Progression)
- **Status:** Resolved
- **Deskripsi:** Dua pernyataan `if` berturut-turut pada `OnIngredientsTaken` menyebabkan Langkah 1 dan Langkah 2 terselesaikan sekaligus.
- **Resolusi:** Dibuat hook eksplisit `OnCartApproached` untuk Langkah 1 dan percabangan `elseif` yang aman untuk Langkah 2.
