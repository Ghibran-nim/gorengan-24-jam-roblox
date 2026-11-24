# DOKUMENTASI SISTEM GEROBAK & MEMASAK — GORENGAN 24 JAM: AWAS SATPOL!

**Status:** Selesai Diimplementasikan & Tervalidasi  
**Skill Acuan:** `roblox-gameplay-engineering`, `roblox-game-architecture`, `roblox-ui-ux`  

---

## 1. Arsitektur Sistem Gerobak (Cart System)

### 1.1 Komponen Model Gerobak (`CartService.luau`)
Setiap pemain yang bergabung dialokasikan ke salah satu plot (Plot 1..8) dan diberikan gerobak gorengan tradisional (*stylized low-poly*):
1. **Chassis Kayu & Roda:** Struktur gerobak dengan pegangan dorong (*push handle*) dan roda ganda.
2. **Etalase Kaca Makanan:** Tempat memajang hasil gorengan siap saji (`Undercooked`, `Crispy`, `Burnt`).
3. **Kompor & Wajan:**
   - Wajan logam berisi minyak goreng mendidih (`MinyakGoreng` Neon).
   - Part visual dinamis `FoodVisual` dengan emitor partikel desis (`SizzleParticles`) dan asap gosong (`SmokeParticles`).
   - `CookPrompt` (ProximityPrompt) untuk memulai proses memasak.
4. **Kotak Bahan Baku (`KotakBahan`):**
   - Wadah kayu di samping gerobak berisi persediaan adonan dan sayur.
   - `TakeIngredientsPrompt` (ProximityPrompt) untuk mengambil persediaan bahan.
5. **Spanduk Gerobak:**
   - Terpal kanopi bergaris hijau-kuning khas pedagang kaki lima Indonesia.
   - Papan nama dua sisi berlabel `"GORENGAN [NAMA PEMAIN]"`.

---

## 2. Sistem Bahan Baku & Inventaris (`InventoryService.luau`)

- **Bahan Baku Mentah:**
  - `batter` (Adonan Tepung): Starter 10x.
  - `veggies` (Irisan Kol & Wortel): Starter 10x.
  - `banana` (Pisang Kepok): Starter 5x.
  - `tofu` (Tahu Pong): Starter 5x.
  - `tempeh` (Tempe Mendoan): Starter 5x.
  - `acitapioca` (Tepung Tapioka): Starter 5x.
- **Validasi Server-Authoritative:**
  - Server memeriksa kecukupan bahan sebelum mengizinkan memasak.
  - Jika bahan kurang, permintaan memasak ditolak dengan pesan error: `"Bahan baku tidak mencukupi! Ambil persediaan di kotak gerobak."`.
  - Pemotongan bahan dilakukan secara atomik saat batch memasak resmi dimulai.
- **Penyimpanan Etalase:**
  - Gorengan yang matang langsung dimasukkan ke inventaris etalase gerobak pemain sesuai kualitasnya.

---

## 3. Sistem Memasak & Ambang Kematangan (Cooking System)

### 3.1 Kategori Kematangan (Sesuai GDD)
Durasi total siklus memasak dinormalisasi menjadi skala persentase (0–100%):

| Kategori | Persentase Waktu | Efek Nilai Jual | Karakteristik Visual & Efek |
| :--- | :---: | :---: | :--- |
| **Undercooked (Mentah)** | **0 – 30%** | Potong 50% | Warna adonan pucat (`#F5EBD2`), desis minyak ringan. Pelanggan kecewa jika disajikan. |
| **Crispy (Sempurna)** | **31 – 80%** | **100% + 20% Tip** | Warna kuning keemasan (`#E6A523`), minyak bergejolak, kilau uap hangat. Memberikan profit optimal. |
| **Burnt (Gosong)** | **81 – 100%+** | 0% (Tidak laku) | Warna hitam pekat arang (`#282323`), kepulan asap hitam tebal (`SmokeParticles`). Menjadi proyektil lempar (*throwable item*). |

### 3.2 Karakteristik Resep (`RecipesConfig.luau`)
- **Bakwan Sayur:** Total durasi 10.0 detik (Window Crispy: detik 3.1 s/d 8.0). Bahan: 1 Batter + 1 Veggies.
- **Pisang Goreng:** Total durasi 12.0 detik (Window Crispy: detik 3.7 s/d 9.6). Bahan: 1 Banana + 1 Batter.
- **Tahu Isi:** Total durasi 14.0 detik (Window Crispy: detik 4.3 s/d 11.2). Bahan: 1 Tofu + 1 Veggies.
- **Tempe Mendoan:** Total durasi 8.0 detik (Window Crispy: detik 2.5 s/d 6.4). Bahan: 1 Tempeh + 1 Batter.
- **Cireng Crispy:** Total durasi 11.0 detik (Window Crispy: detik 3.4 s/d 8.8). Bahan: 1 Acitapioca.

---

## 4. Antarmuka Client & Quality Feedback

- **CookingScreenHUD (`CookingController.luau`):**
  - Panel meteran interaktif dengan 3 zona warna:
    - Biru (0–30%): "⏳ Masih Mentah"
    - Emas (31–80%): "🌟 CRISPY EMAS! (ANGKAT SEKARANG!)"
    - Merah (81–100%): "🔥 GOSONG!"
  - Jarum bergerak secara mulus per frame (`RenderStepped`) mengikuti selisih waktu `os.clock() - startTime`.
  - Tombol sentuh besar **"ANGKAT GORENGAN [E]"** ramah untuk layar sentuh ponsel dan shortcut keyboard.
- **InventoryHUD (`InventoryController.luau`):**
  - Menampilkan stok bahan baku di gerobak dan jumlah gorengan di etalase secara real-time.
- **Toast Notifications (`HUDController.luau`):**
  - Animasi pop-up turun saat makanan selesai diangkat dengan border warna sesuai kualitas yang didapatkan.

---

## 5. Hasil Pengujian Sistem

| Kasus Pengujian | Kondisi Uji | Hasil Ekspektasi | Hasil Aktual | Status |
| :--- | :--- | :--- | :--- | :---: |
| **Memasak Tanpa Bahan** | Sayur = 0, Adonan = 1 | Server menolak permintaan | Ditolak dengan pesan error | **PASS** |
| **Memasak Dengan Bahan** | Sayur = 5, Adonan = 5 | Bahan terpotong 1, batch mulai | Bahan tersisa 4, batch aktif | **PASS** |
| **Angkat Terlalu Cepat** | Diangkat pada 2.0 detik (20%) | Kualitas `Undercooked` | `Undercooked` | **PASS** |
| **Angkat di Window Emas** | Diangkat pada 5.5 detik (55%) | Kualitas `Crispy` | `Crispy` | **PASS** |
| **Angkat Terlalu Lama** | Diangkat pada 9.0 detik (90%) | Kualitas `Burnt` | `Burnt` | **PASS** |
| **Eksploitasi Waktu Client** | Client mengirim durasi palsu | Server mengabaikan, pakai `os.clock()` | Waktu dihitung 100% di server | **PASS** |
| **Memasak Berulang Kali** | Memulai masak saat wajan aktif | Server menolak duplicate start | Ditolak: wajan sedang dipakai | **PASS** |
