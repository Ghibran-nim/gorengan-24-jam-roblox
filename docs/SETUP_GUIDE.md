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
│   │   │   ├── EconomyConfig
│   │   │   ├── GameConfig
│   │   │   └── RecipesConfig
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
│   └── Server/ (Script)
│       ├── init.server.luau
│       └── Services/
│           ├── CookingService (ModuleScript)
│           ├── EconomyService (ModuleScript)
│           ├── GameService (ModuleScript)
│           └── NetworkService (ModuleScript)
│
├── StarterPlayer/
│   └── StarterPlayerScripts/
│       └── Client/ (LocalScript)
│           ├── init.client.luau
│           └── Controllers/
│               ├── GameController (ModuleScript)
│               ├── HUDController (ModuleScript)
│               └── NetworkController (ModuleScript)
│
└── StarterGui/
    (ResetPlayerGuiOnSpawn: false)
```

---

## 4. Memverifikasi Hasil Bootloader

1. Di Roblox Studio, tekan tombol **Play** (F5).
2. Buka jendela **Output** (`View` -> `Output`).
3. Periksa log yang dihasilkan saat startup:

**Log Server yang Diharapkan:**
```text
[xx:xx:xx] [INFO] [ServerBootstrap]: Memulai server bootloader 'Gorengan 24 Jam: Awas Satpol!'...
[xx:xx:xx] [INFO] [ServiceRunner]: Initializing 4 registered modules...
[xx:xx:xx] [INFO] [NetworkBridge]: Server network remotes successfully initialized in ReplicatedStorage.
[xx:xx:xx] [INFO] [ServiceRunner]: All modules successfully initialized.
[xx:xx:xx] [INFO] [ServiceRunner]: Starting 4 registered modules...
[xx:xx:xx] [INFO] [GameService]: Pemain bergabung: Player1 (ID: xxxxx)
[xx:xx:xx] [INFO] [GameService]: Plot gerobak #1 dialokasikan untuk pemain Player1
[xx:xx:xx] [INFO] [EconomyService]: Dompet awal disiapkan untuk Player1: Rp 50000 Kas | Rp 0 Tabungan
[xx:xx:xx] [INFO] [ServerBootstrap]: Server bootloader berhasil diselesaikan. Server siap melayani pemain.
```

**Log Client yang Diharapkan:**
```text
[xx:xx:xx] [INFO] [ClientBootstrap]: Memulai client bootloader 'Gorengan 24 Jam: Awas Satpol!'...
[xx:xx:xx] [INFO] [NetworkBridge]: Client network remotes linked successfully.
[xx:xx:xx] [INFO] [ServiceRunner]: Initializing 3 registered modules...
[xx:xx:xx] [INFO] [ServiceRunner]: All modules successfully initialized.
[xx:xx:xx] [INFO] [ServiceRunner]: Starting 3 registered modules...
[xx:xx:xx] [INFO] [HUDController]: HUD Update -> Kas: Rp 50000 | Bank: Rp 0 | Reputasi: 100
[xx:xx:xx] [INFO] [ClientBootstrap]: Client bootloader berhasil diselesaikan. UI dan Controller siap berinteraksi.
```

---

## 5. Troubleshooting & FAQ

- **Error: `Client timed out waiting for NetworkRemotes in ReplicatedStorage`:**
  - *Penyebab:* Server belum selesai membuat folder `NetworkRemotes` sebelum client meminta.
  - *Solusi:* Pastikan `init.server.luau` berjalan dan tidak ada syntax error pada service yang menghentikan eksekusi server.
- **Rojo Connection Refused:**
  - *Penyebab:* Perintah `rojo serve` belum berjalan di terminal, atau port 34872 diblokir oleh firewall lokal.
- **Perubahan File Tidak Terupdate di Studio:**
  - Pastikan tombol **Connect** di plugin Rojo Roblox Studio menyala hijau (*Connected*).
