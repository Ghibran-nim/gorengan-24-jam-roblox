# MAP & WORLD BUILDING DOCUMENTATION — GORENGAN 24 JAM: AWAS SATPOL!

**Versi Map:** 1.0.0 (Modular Low-Poly Indonesian Street)  
**Kapasitas Server:** 8 Pemain  
**Status Implementasi:** Aktif di `Workspace.Map` dan dikelola oleh `src/server/Services/MapService.luau`  

---

## 1. Konsep & Identitas Visual

Lingkungan game mengusung tema jalanan kota Indonesia dengan gaya visual *stylized low-poly 3D*:
- Aspal jalan raya dua arah dengan marka garis kuning dan zebra cross penyeberangan.
- Trotoar pejalan kaki yang dilengkapi ramp miring landai agar gerobak tidak tersangkut.
- Deretan ruko bertingkat dengan warna pastel khas perkotaan, rolling door, kanopi, dan jendela kaca.
- Tiang listrik beton dengan kabel gantung dan lampu jalan temaram.
- Gerbang selamat datang megah bertuliskan **"KAMPUNG GORENGAN 24 JAM"** di area spawn sentral.
- Gang aman (**Safe Zone**) berlampu neon hijau yang menjadi tempat perlindungan gerobak saat razia Satpol PP berlangsung.

---

## 2. Inventarisasi 10 Area Wajib & Koordinat Spasial

| No | Area / Landmark | Koordinat Pusat (X, Y, Z) | Dimensi (Studs) | Deskripsi & Fungsi Gameplay |
| :---: | :--- | :---: | :---: | :--- |
| **1** | **Main Street** | `(0, 0.5, 0)` | 380 × 1 × 32 | Jalan aspal utama dua lajur dengan marka garis tengah, menjadi jalur patroli razia Satpol PP dan lalu lintas NPC. |
| **2** | **8 Player Cart Plots** | 4 Utara & 4 Selatan | 18 × 1 × 10 per plot | Kavling sewa gerobak pemain. Setiap plot memiliki penanda papan nomor, titik parkir gerobak, meja racik wajan, dan 3 slot antrean pelanggan. |
| **3** | **Central Hub** | `(-160, 0.7, 0)` | 50 × 1.4 × 50 | Plaza utama persimpangan dengan `MainSpawnLocation` (bebas tabrakan), gerbang selamat datang, dan lampu gantung pasar malam. |
| **4** | **Ingredient Shop** | `(-15, 6.7, 38)` | 22 × 12 × 14 | Toko Bahan Baku "Sumber Rejeki" dengan tenda garis merah-putih untuk membeli adonan, tepung, minyak, dan pisang. |
| **5** | **Chili Gacha Shop** | `(55, 6.2, 38)` | 18 × 11 × 14 | Kios Cabai "Pedas Mampus" berkanopi hijau dengan papan cabai merah untuk gacha cabai langka pengali multiplier tip. |
| **6** | **Upgrade Shop** | `(-85, 7.2, 38)` | 24 × 13 × 14 | Bengkel Gerobak "Maju Lancar" dengan rolling door metal industrial untuk membeli upgrade wajan, kompor, dan roda gerobak. |
| **7** | **Safe Alleys (Gang Aman)** | `(-15, 7.5, -50)` & `(105, 7.5, -50)` | 16 × 15 × 42 | Dua gang ruko sempit beratap neon hijau dengan `ZonePart` transparan ber-tag `SafeZone` untuk melindungi gerobak dari sitaan Satpol PP. |
| **8** | **Ruko Area** | `(X, 9.7, -44)` | 24 × 18 × 18 per ruko | 8 unit ruko bertingkat dua dengan pintu gulung, kanopi kain, dan jendela atas sebagai latar lingkungan hidup. |
| **9** | **ATM / Bank Center** | `(135, 6.2, 38)` | 16 × 11 × 12 | Gedung mini ATM kaca modern dengan 2 unit mesin ATM interaktif untuk menyetorkan uang kas pedagang ke tabungan aman. |
| **10**| **Leaderboard Area** | `(-160, 7.0, 22)` | 26 × 10 × 1 | Papan ganda "TOP SULTAN GORENGAN" dan "PENGGORENG CRISPY TERBAIK" di Central Plaza. |

---

## 3. Detail Plot Gerobak Pemain (8 Plots)

Penyebaran plot dirancang dengan jarak renggang (70 studs antar plot) guna memastikan antrean pembeli tidak bertabrakan:

- **Sisi Utara (North Sidewalk):**
  - **Plot 1:** `Vector3.new(-120, 1.45, 23)`
  - **Plot 2:** `Vector3.new(-50, 1.45, 23)`
  - **Plot 3:** `Vector3.new(20, 1.45, 23)`
  - **Plot 4:** `Vector3.new(90, 1.45, 23)`
- **Sisi Selatan (South Sidewalk):**
  - **Plot 5:** `Vector3.new(-120, 1.45, -23)`
  - **Plot 6:** `Vector3.new(-50, 1.45, -23)`
  - **Plot 7:** `Vector3.new(20, 1.45, -23)`
  - **Plot 8:** `Vector3.new(90, 1.45, -23)`

Setiap model plot berisi:
- `PavementPad`: Ubin penanda area kavling.
- `Sign_KAVLING_#X`: Papan penanda kayu nomor kavling dua sisi.
- `CartSpawn`: Titik letak gerobak saat pemain klaim plot.
- `PrepCounter` & `WajanBase`: Meja dapur memasak.
- `CustomerQueue`: 3 titik koordinat antrean pembeli berjarak wajar.

---

## 4. Mekanisme Safe Zone (Gang Aman)

- **Identifikasi Visual:**
  - Gerbang gang dilengkapi tulisan dua sisi bersinar: `"GANG AMAN (SAFE ZONE)"`.
  - Neon beacon hijau terang dengan `PointLight` hijau (Color: `50, 255, 100`, Range: `24 studs`) menyinari lantai paving merah.
- **Deteksi Logika Server:**
  - Di dalam setiap gang terpasang part transparan `ZonePart` (`Size = Vector3.new(16, 15, 42)`).
  - Menggunakan `CollectionService:AddTag(zonePart, "SafeZone")`.
  - Fungsi `MapService:IsPositionInSafeZone(position)` mengevaluasi koordinat gerobak secara matematis berbasis object-space box check.

---

## 5. Audit Performa & Optimasi Mobile

Sesuai panduan `roblox-performance`:
1. **Part Budget:**
   - Total instance di `Workspace.Map`: **386 instance** (sangat ringan untuk game Roblox skala multiplayer).
2. **Fisika & Collision:**
   - **Unanchored Parts: 0** (100% part lingkungan berstatus `Anchored = true`, tidak ada beban komputasi fisika pada server).
   - Kabel listrik, bohlam, kanopi, dan proyektor neon diatur `CanCollide = false` agar tidak menghalangi pergerakan pemain maupun pathfinding NPC.
   - Ramp trotoar memiliki ketinggian lereng rendah (0.4 studs) agar roda gerobak dapat meluncur naik/turun tanpa tersangkut tepi tajam.
3. **Lighting & Shadows:**
   - 9 tiang lampu jalan merkuri menggunakan `PointLight` hangat (Brightness 1.6, Range 28 studs).
   - **`Shadows = false`** pada seluruh sumber cahaya point light jalan dan safe zone untuk menghemat *draw calls* GPU dan mencegah *frame drops* di perangkat mobile entry-level.

---

## 6. Aspek yang Belum Dapat Diuji Runtime Secara Penuh

1. **Uji Beban 8 Gerobak Bergerak Bersamaan:**
   - Geometri jalan memiliki lebar 32 studs dan trotoar 12 studs yang secara teoretis cukup untuk 8 gerobak. Namun uji senggolan gerobak simultan antar 8 pemain nyata akan divalidasi pada Fase 2.
2. **Kalkulasi Pathfinding NPC Dinamis:**
   - Jalur jalan raya dan trotoar bebas hambatan, namun perhitungan deviasi rute `PathfindingService` saat ada gerobak pemain mangkal akan diuji pada Fase 1 & 2.
