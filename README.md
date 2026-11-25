# Gorengan 24 Jam: Awas Satpol!

Game multiplayer Roblox bertema tycoon, memasak, dan ketangkasan jalanan Indonesia (*stylized low-poly 3D*). Pemain mengelola gerobak gorengan kaki lima, meracik aneka menu gorengan khas Nusantara, menghadapi pelanggan unik, menjaga kas dari razia Satpol PP dengan mendorong gerobak ke Gang Aman, hingga berinteraksi dan berkompetisi omzet bersama hingga 8 pemain per server.

> **Status Proyek (2026-11-25):** Fitur inti Fase 0–5 selesai diimplementasikan dan terverifikasi pada **Roblox Studio Play Solo** ([QA Test Report](docs/QA_TEST_REPORT.md)). Place masih tersimpan lokal di [Place1.rbxl](Place1.rbxl) (`PlaceId = 0`, belum dipublikasikan ke Roblox Cloud).

---

## Ringkasan Fitur Utama

- **Core Loop Memasak & Gerobak:** Pengambilan bahan dari kotak gerobak & Toko Bahan Baku, simulasi wajan server-authoritative (`Undercooked` / `Crispy` / `Burnt`), dan etalase siap saji.
- **7 Resep & 12 Upgrade Progression:** Resep bertingkat mulai dari *Bakwan Sayur* hingga *Risol Mayo Spesial*, serta 12 upgrade nyata lintas 7 kategori (termasuk **Kasir NPC Mas Budi**, *Kompor Tekanan Tinggi Mawar*, *Roda Bearing*, *Etalase 2 Tingkat*, dan *Rangka Baja Anti-Razia*).
- **Razia Satpol PP & Safe Zone:** Siklus peringatan kentongan/sirine 15 detik, patroli & pengejaran adil (`12.0 studs/s`), 2 Gang Aman kebal razia, denda 25% uang tunai (`CarriedCash`), serta **Tabungan ATM** (`BankedCash`) yang 100% aman dari razia.
- **Throwable Gorengan Gosong:** Gorengan gosong dapat diambil dan dilempar ke pemain lain atau NPC Copet/Preman dengan efek *ragdoll* komedi 2 detik, cooldown, anti-griefing immunity, serta kontrol sentuh mobile.
- **Koleksi Cabai RNG:** 5 tingkat kelangkaan cabai dengan *pity guarantee* 15x, cashback duplikat, efek visual `ToplesCabai`, dan multiplier profit yang seimbang.
- **Siklus Siang/Malam & 7 Random Events:** 24 jam in-game per 12 menit real-time (`720s`) dengan 4 fase pencahayaan dan 7 event acak (*Hujan Deras*, *Food Vlogger Viral*, *Pelanggan Misterius*, *Copet*, *Preman*, *Razia Mendadak*, *Pasar Malam Mbak Kunti*).
- **Multiplayer Sosial & Persistensi:** Maksimal 8 plot gerobak, `leaderstats`, leaderboard kompetisi sesi, kunjungan & reaksi antargerobak, serta penyimpanan terpusat `DataService` Schema `v2` (`UpdateAsync`, *session lock*, *retry backoff*, migrasi `v0/v1 -> v2`).

---

## Mulai Cepat (Installation & Development)

1. Pasang **Roblox Studio** dan plugin **Rojo** (`v7.7.1`, lihat [rokit.toml](rokit.toml)).
2. Jalankan live sync dari root repositori:
   ```bash
   rojo serve
   ```
   Atau build langsung ke file `.rbxl`:
   ```bash
   rojo build default.project.json --output "Gorengan24Jam.rbxl"
   ```
3. Hubungkan plugin Rojo di Roblox Studio (port `34872`) pada [Place1.rbxl](Place1.rbxl), lalu tekan **Play (F5)** dan pantau Output.

Panduan instalasi dan pengembangan lebih detail tersedia di [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md).

---

## Indeks Dokumentasi

| Kategori | Dokumen | Ringkasan Isi |
|---|---|---|
| **Setup & Development** | [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md) | Panduan instalasi Rojo, struktur runtime, dan alur pengembangan |
| **Arsitektur Teknis** | [docs/TECHNICAL_ARCHITECTURE.md](docs/TECHNICAL_ARCHITECTURE.md) | Pemisahan Client–Server, `ServiceRunner`, jaringan, AI, dan skema data |
| **Desain Gameplay** | [docs/GAMEPLAY_GUIDE.md](docs/GAMEPLAY_GUIDE.md) | Kontrol PC/Mobile, alur memasak, Satpol PP, event, throwable, dan sosial |
| **Sistem Ekonomi** | [docs/ECONOMY_SYSTEM.md](docs/ECONOMY_SYSTEM.md), [docs/ECONOMY_BALANCING.md](docs/ECONOMY_BALANCING.md) | Dua dompet (Kas vs ATM), kurva profit 7 resep, payback 12 upgrade, simulasi 40 menit |
| **Chili RNG** | [docs/CHILI_RNG_DESIGN.md](docs/CHILI_RNG_DESIGN.md) | Peluang basis-points, tabel EV multiplier, pity 15x, dan ekonomi net-sink |
| **Monetisasi** | [docs/MONETIZATION_DESIGN.md](docs/MONETIZATION_DESIGN.md) | Evaluasi Gamepass & Developer Product ramah F2P (belum diimplementasikan di kode) |
| **Audit Keamanan & Performa** | [docs/SECURITY_AUDIT.md](docs/SECURITY_AUDIT.md), [docs/PERFORMANCE_AUDIT.md](docs/PERFORMANCE_AUDIT.md) | Audit remote/exploit, validasi server, memori, FPS mobile, dan perbaikan |
| **QA & Bug Tracking** | [docs/QA_TEST_PLAN.md](docs/QA_TEST_PLAN.md), [docs/QA_TEST_REPORT.md](docs/QA_TEST_REPORT.md), [docs/BUG_TRACKER.md](docs/BUG_TRACKER.md) | Rencana & hasil uji Studio Play Mode 20 area, log bug, dan regresi |
| **Known Issues & Release** | [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md), [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md), [docs/BETA_READINESS_REPORT.md](docs/BETA_READINESS_REPORT.md) | Daftar isu aktif, checklist sebelum publish, dan laporan kesiapan Public Beta |
| **Riwayat Keputusan & Status** | [docs/DECISIONS.md](docs/DECISIONS.md), [docs/DEVELOPMENT_STATUS.md](docs/DEVELOPMENT_STATUS.md) | Catatan ADR arsitektural (`ADR-001`..`ADR-018`) dan status progres proyek |
