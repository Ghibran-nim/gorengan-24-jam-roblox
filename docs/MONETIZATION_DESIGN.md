# Desain & Evaluasi Monetisasi — Gorengan 24 Jam: Awas Satpol!

**Dokumen:** `docs/MONETIZATION_DESIGN.md`  
**Skill Acuan:** `roblox-game-economy`, `roblox-multiplayer-security`  
**Status Implementasi Saat Ini:** **BELUM DIIMPLEMENTASIKAN DI KODE (`0` referensi `MarketplaceService` di `src/`).** Dokumen ini adalah rancangan evaluasi sebelum implementasi dan pengaktifan produk berbayar pada Roblox Creator Dashboard.

---

## 1. Prinsip Keseimbangan Free-to-Play (F2P)

Mengacu pada standar `roblox-game-economy`:
1. **Tanpa Paywall Progres Inti:** Seluruh 7 resep, 12 upgrade bengkel, 5 kelangkaan Cabai RNG, serta perlindungan Tabungan ATM 100% dapat dicapai secara gratis dengan waktu main wajar (~40 menit bermain aktif untuk mencapai tier puncak; lihat [docs/ECONOMY_BALANCING.md](docs/ECONOMY_BALANCING.md)).
2. **Larangan Pay-to-Win Destruktif / Griefing Server:** Tidak ada produk berbayar yang bisa memaksa penyitaan gerobak pemain lain tanpa perlindungan, menembus Safe Zone, atau memberikan pengganda omzet ekstrem yang merusak kompetisi leaderboard.
3. **Otoritas Server Penuh:** Semua Gamepass diverifikasi via `MarketplaceService:UserOwnsGamePassAsync` di server (disertai cache per sesi + listener `PromptGamePassPurchaseFinished`), dan semua Developer Products diproses tunggal (*idempotent receipt lock*) lewat `MarketplaceService.ProcessReceipt` dengan pencatatan transaksi di `DataService`.

---

## 2. Evaluasi Gamepasses yang Direkomendasikan (Opsional Pra-Publikasi)

| Nama Gamepass | Saran Harga (Robux) | Manfaat Nyata | Analisis Dampak Keseimbangan & Batasan |
|---|---|---|---|
| **VIP Gerobak Sultan** | `149–199 R$` | Cat/tema gerobak emas eksklusif + efek kembang api transaksi + **+15% XP Pedagang** | Tidak menggandakan uang tunai secara langsung (tidak merusak leaderboard *Omzet* Rp), hanya mempercepat buka level kosmetik/progres ringan. |
| **Asuransi Anti-Razia Kilat** | `199–249 R$` | Mengurangi penalti uang tunai saat tertangkap Satpol menjadi **10%** (atau **8%** jika digabung *Rangka Baja*) + efek lencana pelindung | Tidak memberi imunitas total dari pengejaran — pemain tetap harus kabur ke Safe Zone agar gorengan etalase tidak disita. Tetap mempertahankan ketegangan razia. |
| **Stok Otomatis Bahan Dasar** | `99–149 R$` | Tombol cepat *Refill Adonan & Sayur* 1-klik dari HUD tanpa membuka peti berulang kali *(tetap dibatasi kapasitas penyimpanan pemain `30`/`60`)* | Murni *Quality-of-Life* kenyamanan kontrol; tidak menambah batas kapasitas gratis tanpa upgrade *Kulkas Mini*. |
| **Tas Cabai Kolektor (2x Slots Visual)** | `79–99 R$` | Menampilkan 2 pajangan toples cabai di gerobak secara visual *(hanya 1 cabai tertinggi yang aktif memberi multiplier stat)* + efek aura cabai | Kosmetik kolektor murni; nol keuntungan statistik ganda. |

---

## 3. Evaluasi Developer Products (Consumables)

| Nama Product | Saran Harga (Robux) | Manfaat Nyata | Pengamanan Keseimbangan Leaderboard & Anti-Abuse |
|---|---|---|---|
| **Paket Modal Awal Kecil** | `49 R$` | `+Rp 25.000` langsung masuk ke **Tabungan ATM** (tidak dihitung sebagai `TotalEarnings` / `Omzet` leaderboard!) | Kritis: Uang pembelian Robux **DILARANG** menambah skor leaderboard *Omzet Penjualan*, agar peringkat server tetap mencerminkan murni usaha berdagang. |
| **Paket Modal Juragan** | `129 R$` | `+Rp 75.000` masuk ke **Tabungan ATM** *(juga tidak dihitung ke `Omzet` leaderboard)* | Sama dengan di atas; nilai relatif setara ~5–7 menit bermain level menengah agar tidak memotong keseruan progression awal. |
| **Traktir Pelanggan Jalanan (Server Boost 3 Menit)** | `79 R$` | Mengaktifkan aura server-wide **"Jam Ramai Traktiran"**: seluruh pemain di server mendapat **+15% tip pelanggan selama 3 menit** (cooldown server 10 menit) | Positif secara sosial (menguntungkan semua pemain termasuk F2P, bukan meng-grief pemain lain). |
| **Kupon Gacha Cabai Pedas (3x Roll)** | `89 R$` | Memberikan 3 tiket roll gratis di `ChiliService` menggunakan tabel probabilitas & pity 15x yang **identik** dengan roll Rp 10.000 | Peluang wajib identik dan transparan di UI sesuai kebijakan Roblox RNG disclosure. |

---

## 4. Kontrak Teknis Wajib Sebelum Mengaktifkan Monetisasi

Jika produk di atas diputuskan untuk diimplementasikan sebelum Public Beta:
1. Buat `src/shared/Config/MonetizationConfig.luau` dan `src/server/Services/MonetizationService.luau` (dilarang menaruh ID produk atau harga terpisah di client).
2. `MarketplaceService.ProcessReceipt` wajib menyimpan `PurchaseId` terakhir ke profil `DataService` sebelum mengembalikan `Enum.ProductPurchaseDecision.PurchaseGranted` agar tidak terjadi pemberian ganda (*double-grant*) maupun kehilangan item (*not-granted*) saat server crash.
3. Pisahkan field `BonusPurchasedCash` dari `Progression.TotalEarnings` / `leaderstats.Omzet` agar leaderboard tetap adil bagi pemain Free-to-Play.
4. Uji pembelian menggunakan **Roblox Studio Test Purchase** sebelum mengaktifkan harga produksi.
