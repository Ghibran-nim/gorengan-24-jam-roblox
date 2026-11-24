# PROJECT AUDIT REPORT — GORENGAN 24 JAM: AWAS SATPOL!

**Tanggal Audit:** 2026-11-24  
**Auditor:** Antigravity AI Orchestrator  
**Status Proyek:** Greenfield / Phase 0 (Baseline Setup)  
**Lingkungan:** Windows (Roblox Studio Edit Mode aktif, Rojo scaffold awal)

---

## 1. Ringkasan Eksekutif

Audit ini dilakukan terhadap repositori `gorengan-24-jam-roblox` untuk mengevaluasi kesiapan arsitektur, konfigurasi toolchain, keutuhan instruksi agen, kelayakan desain mekanik Game Design Document (GDD), serta mengidentifikasi risiko teknis sebelum implementasi fase berlanjut.

Hasil audit mengonfirmasi bahwa proyek saat ini berada pada tahap **Phase 0**. Seluruh 10 Agent Skills dan pedoman standar telah terintegrasi sempurna di repositori, namun kode gameplay aktual di `src/` masih berupa boilerplate murni ("Hello world"). Tidak ada kode warisan yang rusak, memberikan kesempatan ideal untuk membangun arsitektur modular yang kokoh sejak awal.

---

## 2. Inventarisasi File dan Direktori

### 2.1 Struktur Repositori Aktual
```text
gorengan-24-jam-roblox/
├── .agents/
│   ├── rules/
│   │   └── roblox-project-standards.md
│   └── skills/
│       ├── roblox-game-architecture/SKILL.md
│       ├── roblox-game-audio-vfx/SKILL.md
│       ├── roblox-game-economy/SKILL.md
│       ├── roblox-gameplay-engineering/SKILL.md
│       ├── roblox-multiplayer-security/SKILL.md
│       ├── roblox-npc-ai/SKILL.md
│       ├── roblox-performance/SKILL.md
│       ├── roblox-qa-testing/SKILL.md
│       ├── roblox-ui-ux/SKILL.md
│       └── roblox-world-building/SKILL.md
├── src/
│   ├── client/
│   │   └── init.client.luau          (35 bytes - boilerplate print)
│   ├── server/
│   │   └── init.server.luau          (35 bytes - boilerplate print)
│   └── shared/
│       └── Hello.luau                (46 bytes - boilerplate function)
├── .gitignore                        (122 bytes)
├── AGENTS.md                         (5,741 bytes - tata kelola agen)
├── default.project.json              (1,241 bytes - konfigurasi Rojo)
├── README.md                         (1,397 bytes - instruksi proyek)
└── rokit.toml                        (254 bytes - toolchain config)
```

### 2.2 Status File Kode Saat Ini
- `src/client/init.client.luau`: Hanya berisi `print("Hello world, from client!")`.
- `src/server/init.server.luau`: Hanya berisi `print("Hello world, from server!")`.
- `src/shared/Hello.luau`: Hanya berisi modul dummy function `return function() print("Hello, world!") end`.
- **Kesimpulan:** Belum ada logika gameplay, modul servis, kontroler, tipe data, konfigurasi resep, maupun antarmuka jaringan yang diimplementasikan.

---

## 3. Konfigurasi Toolchain & Dependency

### 3.1 Analisis `default.project.json`
- **Mapping DataModel:**
  - `ReplicatedStorage.Shared` -> `src/shared` (Sesuai konvensi).
  - `ServerScriptService.Server` -> `src/server` (Sesuai konvensi).
  - `StarterPlayer.StarterPlayerScripts.Client` -> `src/client` (Sesuai konvensi).
  - `Workspace`: Terdapat deklarasi part `Baseplate` (ukuran 512x20x512, anchored).
  - `Lighting`: Ambient `[0,0,0]`, Brightness 2, Technology `"Voxel"`.
    - *Catatan Kritis:* Teknologi pencahayaan `"Voxel"` sangat ringan untuk perangkat mobile low-end, namun kurang mendukung atmosfer malam perkotaan dan efek lampu jalan ruko yang mendalam jika dibandingkan dengan `"ShadowMap"` atau `"Future"`. Perlu dievaluasi untuk trade-off performa vs visual.
  - `SoundService`: `RespectFilteringEnabled: true`.
- **Kekurangan Mapping:**
  - `StarterGui` belum dipetakan. Jika UI dibuat secara deklaratif via Rojo/Fusion/Roact atau file `.rbxm`, perlu entri terpisah atau dibangun secara prosedural via kode kontroler client.
  - Belum ada folder khusus remotes/events di `ReplicatedStorage`.

### 3.2 Analisis `rokit.toml` dan Ekosistem CLI
- Isi: `rojo = "rojo-rbx/rojo@7.7.1"`.
- Pemeriksaan CLI: Perintah `rokit` dan `rojo` belum terdaftar pada `PATH` sistem lokal saat dieksekusi di terminal.
- Status Runtime Roblox Studio: Koneksi MCP `Roblox_Studio` aktif dan mendeteksi instance Studio yang berjalan pada mode `Edit` (`Place1`).
- *Catatan:* Verifikasi build runtime harus divalidasi langsung melalui sinkronisasi Studio / plugin Rojo atau peluncuran playtest aktual.

---

## 4. Evaluasi Kondisi dan Deteksi Agent Skills & Rules

- **Agent Skills:** Seluruh 10 skills dalam `.agents/skills/` terdeteksi dan aktif:
  1. `roblox-game-architecture`
  2. `roblox-gameplay-engineering`
  3. `roblox-npc-ai`
  4. `roblox-game-economy`
  5. `roblox-multiplayer-security`
  6. `roblox-ui-ux`
  7. `roblox-world-building`
  8. `roblox-game-audio-vfx`
  9. `roblox-performance`
  10. `roblox-qa-testing`
- **Agent Rules:** Dokumen `.agents/rules/roblox-project-standards.md` dan `AGENTS.md` aktif dipatuhi sebagai aturan tata kelola absolut.

---

## 5. Evaluasi Kelayakan Mekanik GDD & Analisis Risiko

| Fitur / Mekanik GDD | Tingkat Kelayakan | Potensi Masalah & Risiko | Strategi Mitigasi Teknis |
| :--- | :--- | :--- | :--- |
| **Cooking Loop** (Mentah -> Matang Crispy -> Gosong) | **Tinggi** | Latensi jaringan dapat membuat timing gauge desinkron antara visual client dan kalkulasi server. Exploit auto-perfect. | Server mencatat timestamp `StartTime` dan menghitung durasi saat `RequestFinishCooking`. Client hanya menampilkan interpolasi visual dan telegraph audio. Toleransi window latensi terkontrol. |
| **Sistem Gerobak & Fisika Dorong** | **Sedang** | Network ownership fisika Roblox rentan manipulasi jika diberikan ke client (speed-hack, teleport gerobak, melempar gerobak pemain lain). | Gerobak di-anchor atau menggunakan constraint terkontrol. Kecepatan dibatasi di server. Posisi divalidasi per detik terhadap kecepatan maksimum logis. |
| **Siklus 24 Jam (12 Menit Real-Time)** | **Tinggi** | Transisi Lighting yang terlalu tajam atau desinkronisasi jam antar client. | Server mengelola waktu global `GameTime` (1 menit nyata = 2 jam in-game), mereplikasi properti atau menggunakan `TweenService` pada client untuk transisi mulus. |
| **Satpol PP Raid & Kejaran** | **Tinggi** | Pathfinding NPC Satpol PP bisa membebani CPU server jika menghitung ulang rute setiap frame untuk 8 pemain. | Gunakan throttled waypoint pathfinding, state machine yang jelas (`Idle` -> `Warning/Kentongan` -> `Patrol` -> `Chase` -> `Capture`), batasi jumlah Satpol aktif. |
| **Safe Zone Escape** | **Tinggi** | Exploit deteksi masuk Safe Zone, atau gerobak tersangkut di geometri jalan. | Server melakukan `SpatialQuery` (`workspace:GetPartsInPart`) terhadap bounding box gerobak di zona aman. Lebar gang ruko diatur minimal 12-14 studs agar gerobak tidak macet. |
| **Customer AI & Antrean** | **Tinggi** | NPC menumpuk di satu gerobak, saling dorong secara fisika, atau memesan resep yang belum di-unlock. | Slot antrean (Queue Waypoints) tetap per plot gerobak. CollisionGroup NPC diatur agar tidak tabrakan dengan sesama NPC/pemain. Validasi menu sesuai level unlock pemilik gerobak. |
| **Gorengan Gosong Lempar (Throwable)** | **Sedang** | Spam proyektil, lag partikel, griefing antar pemain. | Cooldown ketat di server, limit inventaris item gosong, raycast validation server-side untuk hit confirmation. Efek comedic ragdoll/slowdown sementara. |
| **Ekonomi: Carried Cash vs Banked Cash** | **Tinggi** | Pemain kehilangan uang karena exploit atau desinkronisasi. | Server mengelola dua field terpisah: `CarriedCash` (dapat disita sebagian oleh Satpol atau dicuri copet) dan `BankedCash` (aman di ATM). Transaksi atomik. |
| **Gacha Cabai & Rarity** | **Tinggi** | Exploit manipulasi RNG di client; kepatuhan regulasi platform mengenai transparansi loot/probabilitas. | RNG 100% diproses di server menggunakan tabel probabilitas terpusat. Persentase drop rate ditampilkan transparan di UI toko. |

---

## 6. Identifikasi Kerentanan Keamanan & Multiplayer

1. **Remote Exploitation:**
   - Karena belum ada remote yang terdaftar, semua remote baru wajib menerapkan verifikasi `Player`, jarak interaksi (`Magnitude <= 15 studs`), kepemilikan plot/gerobak, dan rate limiting (token bucket / debouncing).
2. **State Desynchronization:**
   - Menghindari pengiriman nilai kalkulasi dari client (misal: client mengirim `ServeOrder(orderId, 15000)`). Client hanya mengirim intensi aksi (`RequestServeCustomer(customerId)`), dan server menghitung harga, bonus crispy, dan mutasi saldo.
3. **Data Loss / Session Lock:**
   - `DataStoreService` harus menerapkan skema session locking agar data profil pemain tidak tertimpa saat berpindah server dengan cepat.

---

## 7. Status Pengujian Runtime

> [!IMPORTANT]
> **Catatan Kejujuran Teknis:** Sesuai aturan Master Prompt dan `AGENTS.md`, audit ini **belum** melakukan pengujian runtime playtest di Roblox Studio karena kode server/client masih tahap greenfield. Pengujian runtime akan dimulai pada Phase 1 saat verifikasi vertical slice pertama.
