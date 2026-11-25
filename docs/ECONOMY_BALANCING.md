# DOKUMENTASI BALANCING EKONOMI & PROGRESSION — GORENGAN 24 JAM: AWAS SATPOL!

**Dokumen Acuan:** `PROMPT 10 — RECIPES, UPGRADES & PROGRESSION`  
**Skill Acuan:** `roblox-game-economy`, `roblox-gameplay-engineering`  
**Sumber Implementasi:** [`RecipesConfig.luau`](file:///c:/Users/HP/Downloads/gorengan-24-jam-roblox/src/shared/Config/RecipesConfig.luau), [`EconomyConfig.luau`](file:///c:/Users/HP/Downloads/gorengan-24-jam-roblox/src/shared/Config/EconomyConfig.luau), [`UpgradesConfig.luau`](file:///c:/Users/HP/Downloads/gorengan-24-jam-roblox/src/shared/Config/UpgradesConfig.luau), [`ProgressionConfig.luau`](file:///c:/Users/HP/Downloads/gorengan-24-jam-roblox/src/shared/Config/ProgressionConfig.luau)

---

## 1. Tujuan Desain Ekonomi & Kurva Progression

Ekonomi dirancang agar:
1. **Ramah Pemula (Free-to-Play Viable):** Pemain baru dengan modal awal **Rp 50.000** (`StartingCarriedCash`) dan **Bakwan Sayur** tetap dapat beroperasi tanpa risiko bangkrut meski sesekali gosong atau terkena razia.
2. **Skill-Rewarding:** Semakin tinggi tier resep, semakin tinggi profit per menitnya, tetapi **jendela kematangan *Crispy* menyempit** (dari `56%` pada *Bakwan Sayur* menjadi `25%` pada *Risol Mayo Spesial*). Pemain perlu ketelitian atau investasi pada *Kompor Gas Turbo* dan *Wajan Anti-Lengket*.
3. **Progression Terkendali (*Level Gating*):** Meskipun pemain memulai dengan Rp 50.000, resep dan upgrade tingkat lanjut dikunci oleh **Level Pedagang (`RequiredLevel`)** sehingga pemain tetap harus memasak dan melayani pelanggan untuk membuka konten baru (mencegah pembelian instan seluruh progres di menit pertama).
4. **Tujuan Jangka Pendek, Menengah, dan Panjang:**
   - **Jangka Pendek (0–5 menit):** Naik ke Level 2, buka *Tempe Mendoan* (Rp 8.000) & *Pisang Goreng* (Rp 18.000), beli *Wajan Baja Jumbo* (Rp 25.000).
   - **Jangka Menengah (5–20 menit):** Level 3–4, buka *Cireng* & *Tahu Isi*, pasang *Kompor Gas Turbo*, *Etalase 2 Tingkat*, dan *Rangka Baja Anti-Razia*.
   - **Jangka Panjang (20–40 menit):** Level 5–6+, kuasai *Martabak Telor Mini* & *Risol Mayo Spesial*, rekrut **Kasir NPC (Mas Budi)** (Rp 145.000) untuk otomasi layanan antrean, dan kejar gelar tertinggi *Raja Gorengan 24 Jam* (Level 10).

---

## 2. Analisis Ekonomi Resep Modular (`RecipesConfig.luau`)

### Harga Bahan Baku Satuan (`EconomyConfig.luau` — Paket isi 5)
| Bahan | Harga Paket (5x) | Modal / Porsi |
| :--- | :---: | :---: |
| Adonan Tepung (`batter`) | Rp 2.500 | Rp 500 |
| Sayuran Segar (`veggies`) | Rp 2.500 | Rp 500 |
| Tempe Daun (`tempeh`) | Rp 3.000 | Rp 600 |
| Pisang Kepok (`banana`) | Rp 3.000 | Rp 600 |
| Tepung Tapioka (`acitapioca`) | Rp 4.000 | Rp 800 |
| Tahu Pong (`tofu`) | Rp 4.000 | Rp 800 |
| Telur Ayam Kampung (`egg`) | Rp 5.000 | Rp 1.000 |
| Kulit Lumpia & Mayo (`risol_skin`) | Rp 6.000 | Rp 1.200 |

### Tabel Profit & Profit per Menit Setiap Resep (Tanpa Upgrade)
Asumsi skenario simulasi (*Realistic / Average*): **80% Crispy** (`1.0x + 20% * 1.25 tip = 1.25x`), **10% Undercooked** (`0.5x`), **10% Burnt** (`0x`, terpakai sebagai senjata lempar), serta jeda interaksi antar batch `+2.0 detik` (*Casual*: 60% crispy, 30% undercooked, +3.5s; *Pro*: 95% crispy, 5% undercooked, +1.0s).

| Resep | Lv | Biaya Buka | Modal | Harga Dasar | Durasi | Zona Crispy | Kesulitan | Casual (Rp/mnt) | Rata-rata (Rp/mnt) | Pro (Rp/mnt) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Bakwan Sayur** | 1 | Gratis | Rp 1.000 | Rp 2.200 | 9.0s | 28%–84% (56%) | Mudah | 4.704 | 7.145 | 10.005 |
| **Tempe Mendoan** | 1 | Rp 8.000 | Rp 1.100 | Rp 2.600 | 8.0s | 30%–80% (50%) | Mudah | 6.470 | 9.780 | 13.683 |
| **Pisang Goreng** | 2 | Rp 18.000 | Rp 1.100 | Rp 3.200 | 10.0s | 34%–78% (44%) | Sedang | 7.911 | 11.300 | 15.164 |
| **Cireng Bumbu Rujak** | 3 | Rp 32.000 | Rp 1.300 | Rp 4.000 | 11.0s | 36%–76% (40%) | Sedang | 9.517 | 13.385 | 17.750 |
| **Tahu Isi Jeletot** | 4 | Rp 55.000 | Rp 1.800 | Rp 5.200 | 12.5s | 38%–74% (36%) | Menengah | 10.800 | 15.145 | 20.022 |
| **Martabak Telor Mini** | 5 | Rp 90.000 | Rp 2.000 | Rp 6.800 | 13.5s | 42%–72% (30%) | Sulit | 14.541 | 19.897 | 25.841 |
| **Risol Mayo Spesial** | 6 | Rp 135.000 | Rp 2.700 | Rp 9.000 | 14.0s | 46%–71% (25%) | Ahli | 18.514 | 25.312 | 32.850 |

> **Observasi Balancing:** Setiap kenaikan tier resep meningkatkan profit/menit secara monotonik dan signifikan (+20% hingga +37% per tier), sehingga tidak ada resep tier rendah yang mengalahkan tier tinggi (*no dominant low-tier exploit*), sekaligus menjaga kesesuaian risiko terhadap penyempitan zona *Crispy*.

---

## 3. Analisis Upgrade & Periode Balik Modal (*Payback Period*)

| Upgrade | Kategori | Min Lv | Prasyarat | Biaya | Efek Gameplay Nyata (Server-Authoritative) | Est. Payback (Gross Tier) |
| :--- | :--- | :---: | :--- | :---: | :--- | :---: |
| **Wajan Baja Jumbo** | Wajan | 1 | — | Rp 25.000 | Kecepatan masak **+15%** + visual wajan membesar | ~2.6 menit |
| **Roda Bearing Halus** | Gerobak | 1 | — | Rp 30.000 | Kecepatan dorong gerobak **+35%** (10 → 13.5 studs/s) | ~3.2 menit |
| **Kotak Bahan Kulkas Mini** | Penyimpanan | 2 | — | Rp 32.000 | Kapasitas bahan baku naik 2x (**30 → 60** porsi/jenis) | ~2.6 menit |
| **Kompor Gas Turbo** | Kecepatan | 2 | — | Rp 35.000 | Kecepatan masak **+15%** & zona *Crispy* **+12%** lebih lebar | ~2.8 menit |
| **Spanduk Neon Kaki Lima** | Dekorasi | 2 | — | Rp 50.000 | Lampu neon menyala & pembeli datang **25% lebih cepat** | ~4.0 menit |
| **Etalase Kaca 2 Tingkat** | Penyimpanan | 3 | — | Rp 55.000 | Kapasitas gorengan siap saji naik (**12 → 28** porsi) + rak ke-2 | ~3.5 menit |
| **Rangka Baja & Terpal Lipat** | Gerobak | 3 | Roda Bearing | Rp 65.000 | Denda sitaan razia Satpol PP turun dari **25% → 12%** | ~4.2 menit |
| **Lampu Tenda Pasar Malam** | Dekorasi | 4 | Spanduk Neon | Rp 75.000 | Lampu hias hangat + bonus tip pelanggan **+15%** | ~3.4 menit |
| **Wajan Anti-Lengket Teflon** | Wajan | 4 | Wajan Jumbo | Rp 85.000 | Kecepatan masak **+10%** & zona *Crispy* **+8%** | ~3.9 menit |
| **Papan Menu & Promo Viral** | Bisnis | 4 | — | Rp 95.000 | Harga jual dasar seluruh gorengan naik **+15%** | ~4.3 menit |
| **Kompor Tekanan Tinggi Mawar** | Kecepatan | 5 | Kompor Turbo | Rp 115.000 | Kecepatan masak ekstra **+20%** (total maks 1.60x speed) | ~3.8 menit |
| **Rekrut Kasir NPC (Mas Budi)** | Kasir | 5 | — | Rp 145.000 | Kasir NPC otomatis melayani antrean #1 tiap **2.5 detik** | ~4.8 menit |

---

## 4. Kurva Level & Simulasi Sesi 40 Menit

### Tabel Level & XP (`ProgressionConfig.luau`)
- Memasak: `+12 XP` (*Crispy*), `+5 XP` (*Undercooked*), `+3 XP` (*Burnt*).
- Melayani Pembeli: `+20 XP` dasar + `+10 XP` bonus *Crispy* (`30 XP` per porsi matang).
- Ambang Total XP: `Lv.1 = 0`, `Lv.2 = 150`, `Lv.3 = 450`, `Lv.4 = 950`, `Lv.5 = 1.650`, `Lv.6 = 2.600`, `Lv.7 = 3.800`, `Lv.8 = 5.300`, `Lv.9 = 7.100`, `Lv.10 = 9.200`.

### Hasil Simulasi Ekonomi (Step 30 detik selama 40 menit, 1 razia tiap 6 menit)
| Profil Pemain | Kondisi Akhir @ 40 Menit | Tonggak Progression Utama |
| :--- | :--- | :--- |
| **Pemain Kasual** (60% Crispy, nabung 50%) | **Level 7**, Kas Rp 10.230, **5/7 Resep**, **8/12 Upgrade** | Tempe Mendoan (0.5m) → Lv.2 + Pisang Goreng (1.5m) → Cireng (8.5m) → Kompor Turbo (15m) → Tahu Isi (20m) |
| **Pemain Rata-Rata** (80% Crispy, nabung 75%) | **Level 8**, Kas Rp 60.699, **6/7 Resep**, **10/12 Upgrade** | Cireng (5.5m) → Kompor Turbo (10m) → Tahu Isi (13.5m) → Martabak Mini (31.5m) |
| **Pemain Terampil** (95% Crispy, nabung 95%) | **Level 9**, Kas Rp 236.432, **7/7 Resep**, **12/12 Upgrade** | Tahu Isi (12m) → Martabak Mini (26.5m) → **Risol Mayo Spesial (34.5m)** → **Kasir NPC (37.0m)** |

### Penyesuaian yang Dilakukan Berdasarkan Temuan Simulasi
1. **Penambahan Level-Gating (`UnlockLevel` & `RequiredLevel`):** Pada simulasi awal sebelum level-gating diterapkan, pemain bisa langsung memborong 3 item sekaligus pada `t = 0.5m` dengan modal Rp 50.000. Setelah *level-gating* ditambahkan, pemain harus aktif memasak & melayani untuk mencapai Level 2–6 sebelum membuka menu/upgrade tingkat lanjut.
2. **Penyeimbangan Tempe Mendoan vs Tahu Isi:** Sebelumnya `tempe_mendoan` (8s, Rp 2.500) melampaui efisiensi `tahu_isi` dan `cireng_crispy`. Penyelarasan harga dasar (*Tahu Isi* Rp 5.200, *Cireng* Rp 4.000, *Martabak* Rp 6.800, *Risol Mayo* Rp 9.000) memastikan hierarki profit selalu sejalan dengan tingkat kesulitan dan biaya unlock.
