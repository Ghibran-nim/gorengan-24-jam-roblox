# SETUP & RUN GUIDE — GORENGAN 24 JAM: AWAS SATPOL!

Panduan resmi untuk menyinkronkan repositori dengan Roblox Studio menggunakan Rojo, menjalankan bootloader, dan melakukan verifikasi teknis.

---

## 1. Prasyarat Lingkungan

1. **Roblox Studio:** Versi terbaru terpasang di sistem (Windows/macOS).
2. **Rojo Plugin di Roblox Studio:**
   - Pasang plugin resmi Rojo dari Roblox Creator Store atau via repository [Rojo GitHub Releases](https://github.com/rojo-rbx/rojo/releases).
3. **Rojo CLI (Opsional namun direkomendasikan):**
   - Jika menggunakan toolchain Rokit, jalankan:
     ```bash
     rokit install
     ```
   - Atau unduh binary `rojo.exe` v7.7.x dan letakkan pada folder yang terdaftar di environment variable `PATH`.

---

## 2. Cara Sinkronisasi Repositori ke Roblox Studio

### Metode A: Menggunakan Rojo Plugin di Roblox Studio (Rekomendasi)
1. Buka **Roblox Studio**.
2. Buka tempat permainan (*Place*) kosong atau tempat kerja game (`Place1`).
3. Buka terminal di folder root proyek (`gorengan-24-jam-roblox`) dan jalankan server Rojo:
   ```bash
   rojo serve
   ```
   *(Server Rojo default berjalan pada port `34872`)*.
4. Di Roblox Studio, buka tab **Plugins** -> klik ikon **Rojo**.
5. Klik tombol **Connect** (Port default: `34872`).
6. Dalam hitungan detik, struktur script berikut akan tersinkronisasi otomatis ke DataModel Studio:
   - `ReplicatedStorage.Shared` <- `src/shared`
   - `ServerScriptService.Server` <- `src/server`
   - `StarterPlayer.StarterPlayerScripts.Client` <- `src/client`

### Metode B: Build Langsung Menjadi File `.rbxl`
Jika ingin menghasilkan file tempat permainan langsung tanpa koneksi live-sync:
```bash
rojo build default.project.json --output "Gorengan24Jam.rbxl"
```
Buka file `Gorengan24Jam.rbxl` yang dihasilkan langsung menggunakan Roblox Studio.

---

## 3. Struktur Runtime DataModel di Roblox Studio

Setelah proses sinkronisasi selesai, struktur pohon instance di Explorer akan terbentuk sebagai berikut:

```text
DataModel
├── ReplicatedStorage/
│   ├── Shared/
│   │   ├── Config/
│   │   │   └── (10 modul konfigurasi: GameConfig, EconomyConfig, RecipesConfig, UpgradesConfig, ProgressionConfig, ChiliGachaConfig, CustomerConfig, TimeScheduleConfig, EventsConfig, DataConfig)
│   │   ├── Network/
│   │   │   ├── NetworkBridge
│   │   │   └── Remotes
│   │   ├── Types/
│   │   │   └── GameplayTypes
│   │   └── Utility/
│   │       ├── Logger
│   │       ├── ServiceRunner
│   │       └── Signal
│   └── NetworkRemotes/           <-- Dibuat otomatis saat Server berjalan
│       ├── CookStateChanged (RemoteEvent)
│       ├── FoodCollected (RemoteEvent)
│       ├── RequestStartCooking (RemoteFunction)
│       └── ...
│
├── ServerScriptService/
│   └── Server/ (Script -> init.server.luau)
│       └── Services/ (17 Services: Game, Network, Map, Cart, Inventory, Cooking, Customer, Economy, Satpol, Throwable, Progression, Chili, Time, Event, Social, Data, Tutorial)
│
├── StarterPlayer/
│   └── StarterPlayerScripts/
│       └── Client/ (LocalScript -> init.client.luau)
│           └── Controllers/ (16 Controllers: HUD, Game, Network, Cart, Inventory, Cooking, CustomerUI, ShopUI, Raid, Throwable, Progression, Chili, TimeAndEvent, Social, AudioVFX, Tutorial)
│
└── StarterGui/
    (ResetPlayerGuiOnSpawn: false)
```

---

## 4. Memverifikasi Hasil Bootloader

1. Di Roblox Studio, tekan tombol **Play** (F5).
2. Buka jendela **Output** (`View` -> `Output`).
3. Pastikan log `Initializing 17 registered modules...` (server) dan `Initializing 16 registered modules...` (client) selesai tanpa Luau runtime error.

---

## 5. Panduan Pengembangan (*Development Guide*)

1. **Pemisahan Tanggung Jawab:** Letakkan seluruh logika otoritatif (uang, stok, masak, RNG, AI, cooldown, penyimpanan) pada `src/server/Services/`. Controller client di `src/client/Controllers/` hanya menangani input PC/Mobile, animasi/suara, dan rendering UI.
2. **Konfigurasi Terpusat:** Tambah atau ubah angka balancing hanya pada `src/shared/Config/*.luau` dan definisi remote baru pada `src/shared/Network/Remotes.luau` + `NetworkBridge.luau`.
3. **Standar Kode & Keamanan:** Gunakan `--!strict`, validasi tipe/jarak/kepemilikan/rate-limit pada setiap handler remote, dan jalankan uji di **Roblox Studio Play Mode** (dan *Local Server* untuk fitur multiplayer) sebelum memperbarui [docs/DEVELOPMENT_STATUS.md](docs/DEVELOPMENT_STATUS.md).

---

## 5. Troubleshooting & FAQ

- **Error: `Client timed out waiting for NetworkRemotes in ReplicatedStorage`:**
  - *Penyebab:* Server belum selesai membuat folder `NetworkRemotes` sebelum client meminta.
  - *Solusi:* Pastikan `init.server.luau` berjalan dan tidak ada syntax error pada service yang menghentikan eksekusi server.
- **Rojo Connection Refused:**
  - *Penyebab:* Perintah `rojo serve` belum berjalan di terminal, atau port 34872 diblokir oleh firewall lokal.
- **Perubahan File Tidak Terupdate di Studio:**
  - Pastikan tombol **Connect** di plugin Rojo Roblox Studio menyala hijau (*Connected*).
