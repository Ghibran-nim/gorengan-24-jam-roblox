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
- **Status:** Planned Mitigation
- **Deskripsi:** Jika network ownership model gerobak diserahkan sepenuhnya ke client yang mendorong demi kehalusan kontrol lokal, exploiter dapat memanipulasi posisi gerobak untuk berpindah seketika ke Safe Zone saat Satpol datang, atau melontarkan gerobak pemain lain.
- **Mitigasi:** Implementasi server validation loop: Server memantau kecepatan delta (`Magnitude(pos_now - pos_last) / delta_time`). Jika kecepatan melebihi batas gerobak maksimum (+ toleransi latensi), server membatalkan posisi dan mengembalikan ke titik aman sebelumnya.

---

### ISSUE-004: Potensi Beban CPU pada Spawning & Pathfinding Massal NPC
- **Tingkat Keparahan:** Medium (Server Performance)
- **Status:** Planned Mitigation
- **Deskripsi:** Jika terdapat 8 pemain dengan masing-masing 3-4 antrean pelanggan plus NPC Satpol PP dan pejalan kaki, total NPC aktif dapat mencapai 35-45 karakter di dalam satu server. Kalkulasi pathfinding simultan berpotensi menyebabkan micro-stuttering pada server thread.
- **Mitigasi:** 
  - Terapkan *global NPC budget cap* (maksimal 25-30 NPC aktif sekaligus).
  - Gunakan navigasi langsung (*raycast straight line*) untuk area trotoar terbuka dan hanya gunakan `PathfindingService` saat ada rintangan dinamis.
  - Staggering update loop NPC (jangan menghitung state seluruh NPC pada frame yang sama).

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
