# DOKUMENTASI SISTEM EKONOMI & CORE UI — GORENGAN 24 JAM: AWAS SATPOL!

**Status:** Selesai Diimplementasikan & Tervalidasi Nyata  
**Skill Acuan:** `roblox-game-economy`, `roblox-ui-ux`, `roblox-multiplayer-security`  

---

## 1. Arsitektur Dua Dompet (Two-Wallet Model)

Permainan memisahkan keuangan pemain secara tegas menjadi dua dompet mandiri yang dikelola oleh [`src/server/Services/EconomyService.luau`](file:///c:/Users/HP/Downloads/gorengan-24-jam-roblox/src/server/Services/EconomyService.luau):

| Jenis Saldo | Lokasi Penyimpanan | Aksesibilitas | Risiko Razia Satpol PP | Fungsi Utama |
| :--- | :--- | :--- | :---: | :--- |
| **Kas Pedagang (`CarriedCash`)** | Laci Kas di Gerobak | Langsung dapat dibelanjakan | **Rentan Sitaan (25% Disita)** | Digunakan untuk membeli bahan baku harian dan upgrade. Bertambah setiap kali melayani pembeli. |
| **Tabungan ATM (`BankedCash`)** | Rekening Bank / ATM 24 Jam | Harus disetor/tarik di ATM | **100% AMAN (Bebas Razia)** | Menyimpan keuntungan jangka panjang agar tidak hangus ketika tertangkap razia Satpol PP atau preman. |

---

## 2. Toko Bahan Baku ("Sumber Rejeki" — [`EconomyConfig.luau`](file:///c:/Users/HP/Downloads/gorengan-24-jam-roblox/src/shared/Config/EconomyConfig.luau))

Pemain dapat membeli paket persediaan bahan mentah di Toko Bahan Baku maupun melalui modal HUD:

| Nama Paket | Jumlah Isi | Harga Beli | Harga Satuan | Menu Terkait |
| :--- | :---: | :---: | :---: | :--- |
| **Adonan Tepung Bumbu (`batter`)** | 5 Porsi | Rp 2.500 | Rp 500 / porsi | Semua gorengan |
| **Sayuran Segar (`veggies`)** | 5 Porsi | Rp 2.500 | Rp 500 / porsi | Bakwan Sayur, Tahu Isi |
| **Pisang Kepok Manis (`banana`)** | 5 Sisir | Rp 3.000 | Rp 600 / porsi | Pisang Goreng Crispy |
| **Tahu Pong Gurih (`tofu`)** | 5 Potong | Rp 3.500 | Rp 700 / porsi | Tahu Isi Pedas (Jeletot) |
| **Tempe Daun Kedelai (`tempeh`)** | 5 Papan | Rp 3.000 | Rp 600 / porsi | Tempe Mendoan |
| **Tepung Tapioka Super (`acitapioca`)**| 5 Bungkus | Rp 4.000 | Rp 800 / porsi | Cireng Crispy |

---

## 3. Bengkel Upgrade Gerobak ("Maju Lancar" — [`UpgradesConfig.luau`](file:///c:/Users/HP/Downloads/gorengan-24-jam-roblox/src/shared/Config/UpgradesConfig.luau))

Upgrade memberikan peningkatan performa nyata pada gerobak dan peralatan memasak:

| Item Upgrade | Kategori | Biaya Kas | Efek Mekanik |
| :--- | :---: | :---: | :--- |
| **Wajan Baja Jumbo** | Wajan | Rp 25.000 | Mempercepat siklus memasak sebesar **+15%**. |
| **Kompor Gas Turbo** | Kompor | Rp 35.000 | Memperlebar window kematangan *"Crispy"* sebesar **+20%**. |
| **Roda Bearing Halus** | Roda | Rp 40.000 | Mendorong gerobak **+25% lebih cepat dan ringan** saat kabur dari kejaran Satpol PP. |
| **Etalase Kaca 2 Tingkat** | Etalase | Rp 50.000 | Kapasitas penyimpanan gorengan siap saji meningkat **2× lipat**. |
| **Spanduk Neon Kaki Lima** | Dekorasi | Rp 60.000 | Menarik perhatian pembeli sehingga antrean datang **+25% lebih cepat**. |

---

## 4. Antarmuka Pengguna Utama (Core UI / UX)

1. **Top Header Bar (Main HUD & Money Display):**
   - Menampilkan 💵 `Kas: Rp [CarriedCash]`, 🏦 `Bank: Rp [BankedCash]`, dan 🌟 `Reputasi: [Rep]`.
   - Terletak di kiri atas layar, aman dari tombol Core Roblox (Menu & Chat).
2. **Action Dock (Pojok Kanan Bawah — Mobile Friendly):**
   - 4 Tombol cepat berukuran besar (minimum 44×44 pt touch target):
     - 🛒 **[Toko]**: Membuka modal Toko Bahan Baku.
     - 🏧 **[ATM]**: Membuka modal ATM Center.
     - 🔧 **[Bengkel]**: Membuka modal Upgrade Gerobak.
     - 🎒 **[Tas]**: Membuka modal Inventaris Lengkap.
3. **Modal Dialogs Terpadu ([`ShopUIController.luau`](file:///c:/Users/HP/Downloads/gorengan-24-jam-roblox/src/client/Controllers/ShopUIController.luau)):**
   - Jendela pop-up berbingkai gelap modern dengan tombol tutup `[X]` dan backdrop klik-luar.
   - Tombol transaksi memiliki feedback interaktif (berubah menjadi abu-abu *"KAS KURANG"* jika saldo tidak mencukupi, dan *"TERPASANG"* jika upgrade sudah dimiliki).
4. **Toast Notification System:**
   - Animasi geser turun (*Back easing*) dengan aksen warna sesuai konteks (Emas untuk Crispy/Success, Biru untuk Warning, Merah untuk Error/Burnt).

---

## 5. Protokol Keamanan & Anti-Exploit
- **Validasi Nilai Non-Negatif:** Server menolak keras transaksi setor/tarik bernilai $\le 0$, desimal, atau `NaN`.
- **Atomic Operations:** Saldo dipotong terlebih dahulu sebelum stok atau upgrade dicatat. Jika salah satu langkah gagal, mutasi dibatalkan.
- **Client Zero-Authority:** Client tidak dapat mengubah saldo uang; saldo hanya tereplikasi satu arah dari server via `PlayerEconomyUpdated`.

---

## 6. Hasil Pengujian Runtime di Roblox Studio

Seluruh 10 kasus pengujian transaksi diverifikasi **100% PASS**:

```json
{
  "AllPassed": true,
  "Tests": [
    { "TestName": "Sale_Cash_Credit", "Passed": true, "Detail": "Saldo kas bertambah setelah penjualan: Rp 52500" },
    { "TestName": "Buy_Ingredient_Success", "Passed": true, "Detail": "Kas terpotong Rp 2500 dan adonan bertambah 5" },
    { "TestName": "Buy_Ingredient_Insufficient_Funds_Rejected", "Passed": true, "Detail": "Pembelian ditolak jika harga melebihi kas" },
    { "TestName": "Buy_Upgrade_Success", "Passed": true, "Detail": "Kas terpotong Rp 25.000 dan upgrade terpasang" },
    { "TestName": "Duplicate_Upgrade_Rejected", "Passed": true, "Detail": "Upgrade yang sudah dimiliki ditolak dari pembelian ulang" },
    { "TestName": "ATM_Deposit_Success", "Passed": true, "Detail": "Kas disetor Rp 15.000 ke tabungan aman" },
    { "TestName": "ATM_Negative_Deposit_Rejected", "Passed": true, "Detail": "Setoran bernilai negatif ditolak oleh validasi server" },
    { "TestName": "ATM_Excess_Deposit_Rejected", "Passed": true, "Detail": "Setoran melebihi kas ditolak server" },
    { "TestName": "ATM_Withdraw_Success", "Passed": true, "Detail": "Tabungan ditarik Rp 5.000 kembali ke uang kas" },
    { "TestName": "ATM_Excess_Withdraw_Rejected", "Passed": true, "Detail": "Penarikan melebihi saldo tabungan ditolak server" }
  ]
}
```
