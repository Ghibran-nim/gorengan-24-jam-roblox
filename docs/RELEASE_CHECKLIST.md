# Release Checklist — Public Beta (Gorengan 24 Jam: Awas Satpol!)

**Dokumen:** `docs/RELEASE_CHECKLIST.md`  
**Aturan Penting:** Checklist ini **TIDAK** memublikasikan game secara otomatis. Seluruh langkah di bagian Creator Dashboard & Pengujian Multi-Klien Jaringan harus dikonfirmasi secara manual oleh pemilik proyek.

---

## A. Verifikasi Kode & Build Lokal (Status Saat Ini)

- [x] Seluruh 17 Server Services & 16 Client Controllers terinisialisasi bersih di Roblox Studio (`0` error Luau).
- [x] `default.project.json` memetakan `ReplicatedStorage.Shared`, `ServerScriptService.Server`, `StarterPlayerScripts.Client`, dan `StarterGui` (`ResetPlayerGuiOnSpawn: false`).
- [x] Tidak ada placeholder `TODO` / `FIXME` / stub di seluruh `src/**/*.luau`.
- [x] Seluruh mutasi ekonomi, resep, upgrade, RNG cabai, lemparan gosong, dan penangkapan Satpol PP bersifat server-authoritative.
- [x] Sisa objek dummy edit-time di `Place1.rbxl` sudah dibersihkan (`1041` descendants di Play Mode) dan disimpan secara lokal.
- [x] HUD PC (`1094x561`) terverifikasi `Overlaps = 0` dan modal UI responsif terhadap simulasi mobile `844x390`.

---

## B. Konfigurasi Wajib di Roblox Studio & Creator Dashboard (Menunggu Persetujuan Pemilik)

- [ ] **Publish Place (Private Terlebih Dahulu):** Publish [Place1.rbxl](Place1.rbxl) ke Roblox Experience milik akun/grup resmi (`GameId` & `PlaceId` tidak boleh `0`).
- [ ] **Perbaiki `Players.MaxPlayers` dari `30` -> `8`:**
  - *Temuan Audit Studio:* Properti `Players.MaxPlayers` di `Place1.rbxl` saat ini bernilai **30**, padahal `GameConfig.MaxPlayers` dan `Workspace.Map.PlayerPlots` hanya menyediakan **8 plot**!
  - Wajib atur **Max Players = 8** di *Place Settings / Configure Place -> Access* sebelum membuka server ke pemain.
- [ ] **Aktifkan API & DataStore:**
  - Studio: *Game Settings -> Security -> Enable Studio Access to API Services = ON*.
  - Creator Dashboard: Pastikan tempat tidak memakai akses pihak ke-3 yang tidak diperlukan (`HttpService.HttpEnabled = false` sudah aman).
- [ ] **Permissions & Akses Beta:**
  - Atur pengalaman ke **Private** terlebih dahulu untuk pengujian internal tim, lalu ubah ke **Public** (atau Group Beta) hanya setelah uji multi-klien lulus.
  - Periksa *Team Create / Collaborator Permissions* sesuai daftar pengembang resmi.
- [ ] **Asset & Audio Permissions:**
  - Seluruh audio saat ini memakai asset bawaan engine `rbxasset://sounds/*` (bebas izin creator pihak ketiga). Jika nanti menambah *Asset ID* audio/decal/mesh kustom (`rbxassetid://...`), wajib menggunakan asset milik Experience/Grup yang diizinkan.
- [ ] **Experience Guidelines & Compliance:**
  - Isi **Experience Questionnaire** (Age Rating) di Creator Dashboard — cantumkan keterangan RNG/Gacha Cabai (*paid/in-game virtual currency RNG odds*) secara akurat sesuai tabel di [docs/CHILI_RNG_DESIGN.md](docs/CHILI_RNG_DESIGN.md) agar mematuhi regulasi region tertentu.
  - Lengkapi Game Icon, Thumbnail (dapat diambil dari visual landmark/gerobak), Deskripsi Bahasa Indonesia, dan Genre (`Tycoon / Simulation`).
- [ ] **Monetization (Opsional — Jika Diaktifkan di Beta):**
  - Saat ini belum ada Gamepass/Developer Product di kode (`0` integrasi `MarketplaceService`). Jika ingin mengaktifkan monetisasi untuk Public Beta, implementasikan `MonetizationService` mengikuti [docs/MONETIZATION_DESIGN.md](docs/MONETIZATION_DESIGN.md), buat ID produk di Creator Dashboard, dan uji via *Test Purchase*.

---

## C. Pengujian Pra-Publikasi Wajib (Belum Dapat Dijalankan Penuh di Studio Lokal)

- [ ] **Uji Cloud `DataStoreService` Nyata (Setelah Publish Private):**
  - Join server private -> masak, jual, setor ATM, gacha cabai, beli upgrade -> leave -> tunggu 10s -> rejoin -> pastikan seluruh 8 domain tersimpan dan dipulihkan sempurna.
- [ ] **Uji *Local Server & Multiple Clients* (Minimal 2–4 Klien, Disarankan 8 Klien):**
  - Verifikasi alokasi Plot #1–#8 tanpa konflik saat bergabung bersamaan.
  - Verifikasi pembelian antargerobak (`RequestBuyFromPlayerCart`), reaksi sosial, lemparan gorengan gosong antar-pemain, dan sinkronisasi leaderboard `Omzet`.
  - Verifikasi *session locking* jika pemain langsung pindah server (*server-hop*).
- [ ] **Evaluasi `Workspace.StreamingEnabled = true`:**
  - Properti `StreamingEnabled` saat ini aktif (`true`) di `Place1.rbxl`. Uji di *Live Private Server* apakah ada gerobak tetangga, Safe Zone, atau NPC di ujung jalan yang gagal di-*stream* saat pemain berinteraksi atau melihat leaderboard jarak jauh; matikan `StreamingEnabled` atau sesuaikan `StreamingMinRadius`/`ModelStreamingMode = Persistent` bila ditemukan delay referensi.
- [ ] **Uji Perangkat Mobile Fisik (Android & iOS Low/Mid-Range):**
  - Verifikasi kenyamanan jempol pada Action Dock, ProximityPrompt, tombol Dorong Gerobak, tombol Lempar Gosong, dan kelancaran FPS saat `Hujan Deras` + `Razia Satpol PP` aktif (uji pula tombol *Mode Grafis Hemat Low-FX*).
