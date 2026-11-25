# SECURITY AUDIT REPORT — GORENGAN 24 JAM: AWAS SATPOL!

**Tanggal Audit:** 2026-11-25  
**Skill Acuan:** `roblox-multiplayer-security`, `roblox-game-architecture`, `roblox-qa-testing`

> [!NOTE]
> Sesuai prinsip keamanan rekayasa: **tidak ada sistem yang diklaim 100% bebas exploit hanya dari inspeksi kode**. Dokumen ini mencatat celah yang ditemukan, perbaikan otoritatif yang telah diterapkan, pengujian yang benar-benar dijalankan di Studio, dan area yang tetap harus diuji dalam sesi server publik/multi-client.

---

## 1. Celah Keamanan yang Ditemukan, Risiko, Solusi & Verifikasi

| # | Celah / Vektor Serangan | Risiko | Perbaikan Server-Authoritative | Hasil Uji Studio |
|---|---|---|---|---|
| 1 | **Privilege Escalation pada Admin/Test Remotes (`SatpolService`, `EventService`, `SocialService`)**: `RequestForceRaidEvent`, `RequestForceWorldEvent`, dan `RequestTriggerCompetitionEvent` sebelumnya dapat dipanggil oleh pemain mana pun di server produksi. | **Kritis** | Menambahkan `NetworkBridge.IsAuthorizedAdmin(player)` (`RunService:IsStudio()` atau `game.CreatorId > 0 and player.UserId == game.CreatorId`) di ketiga handler + logging `SECURITY:` bila ditolak. | **Verified in Code & Studio**: Diizinkan di Studio untuk test suite; ditolak untuk non-creator pada server publik (simulasi multi-pemain produksi *Not Run* di live server). |
| 2 | **Free Paid-Ingredient Exploit di Kotak Gerobak (`InventoryService:RequestTakeIngredients`)**: Mengirim `"risol_skin"` (`Rp 6.000`), `"egg"`, dll. ke `RequestTakeIngredients` sebelumnya mengisikan bahan toko berbayar secara gratis. | **Tinggi** | Memisahkan endpoint: `RequestTakeIngredients` kini **hanya** mengizinkan `"batter"` dan `"veggies"` (`amount 1..10`, jarak `<= 20 studs`, tidak ragdoll), sedangkan pembelian toko memanggil internal `GrantPurchasedIngredients`. | **PASS (Live Remote Client→Server)** — `RequestTakeIngredients("risol_skin", 5)` & `("egg", 5)` & `("batter", 99)` ditolak dengan log `SECURITY`. |
| 3 | **Manipulasi `CFrame` & Orientasi Gerobak (`CartService:UpdateCartPosition`)**: Payload `newCFrame` sebelumnya tidak memvalidasi `typeof(newCFrame) == "CFrame"`, komponen `NaN`, atau rotasi miring/terbalik. | **Tinggi** | Validasi ketat `typeof == "CFrame"`, `NetworkBridge.IsFiniteVector3`, batas ketinggian `Y` (`-2..15`), dan kunci orientasi datar (`CFrame.Angles(0, yaw, 0)`), plus blokir saat ragdoll. | **PASS (Live Remote Client→Server & Server)** — Payload `"bad_cf"`, `NaN CFrame`, dan `Y = 999` ditolak. |
| 4 | **Validasi Input `RequestCheckSafeZone` & `RequestServeCustomer` (`SatpolService`, `CustomerService`)**: `checkPosition` dan `customerId` belum divalidasi tipe/`NaN`/status ragdoll sebelum diproses. | **Sedang** | Menambahkan `IsFiniteVector3` pada `RequestCheckSafeZone`, validasi string `customerId` (`1..40` char) + isolasi kepemilikan plot + blokir serve manual saat ragdoll di `CustomerService`. | **PASS (Live Remote Client→Server)** — `RequestCheckSafeZone("bad_pos")`, `NaN Vector3`, dan `RequestServeCustomer(12345)` ditolak. |
| 5 | **Flooding / Spam RemoteEvent & RemoteFunction (`NetworkBridge`)**: Memastikan batas frekuensi per pemain (`12 req/s`) berfungsi menahan banjir panggilan. | **Sedang** | Bucket rate limit per `UserId` (`RateLimitRequestsPerSecond = 12`) + cleanup memori pada `Players.PlayerRemoving`. | **PASS (Live Remote Client→Server)** — Pengiriman 16 request dalam 1 detik ditolak server dengan `"Rate limit exceeded"`. |

---

## 2. Audit Domain Keamanan Lainnya (Checklist PROMPT 16)

| Domain | Mekanisme Pertahanan Saat Ini | Status Verifikasi |
|---|---|---|
| **Manipulasi Uang & Duplikasi Transaksi** | Saldo `CarriedCash` & `BankedCash` hanya dimutasi oleh `EconomyService`; `BuyUpgrade`, `BuyIngredient`, `DepositToATM`, `WithdrawFromATM`, dan `BuyFromPlayerCart` memvalidasi `NaN`/`math.huge`/negatif/integer, kepemilikan, dan memotong kas/stok secara atomik. | **PASS** (Server & Live Remote Client tests). |
| **Manipulasi Hasil Memasak** | `CookingService` menghitung elapsed time dari `os.clock()` server (`StartTime`) dan batas `RecipesConfig`, memvalidasi jarak `<= 20 studs` & non-ragdoll; client tidak dapat mengirim kualitas hasil. | **PASS** (Server tests). |
| **Manipulasi RNG & Collection** | `ChiliService` menjalankan RNG `Random.new()` bobot basis-points (`10.000`) & pity `15x` sepenuhnya di server, menolak equip cabai yang belum dimiliki, dan mencatat hasil sebelum `FireClient`. | **PASS** (PROMPT 11: `6/6 Server + 3/3 Client`). |
| **Exploit Throwable & Ragdoll** | `ThrowableService` memvalidasi `Vector3` arah lempar (`NaN`/zero rejected), cooldown pelempar (`3.5s`), stok gosong server, cooldown per pasangan pelaku–target (`10s`), immunity target (`8s`), spawn protection (`5s`), Safe Zone immunity, serta stepped raycast anti-tembus tembok. | **PASS** (PROMPT 09, 13 & 16 tests). |
| **Manipulasi Progression & Akses Data Lain** | `ProgressionService` memvalidasi level & biaya sebelum unlock resep; `DataService` hanya menerima mutasi server, mengunci sesi lewat `UpdateAsync` + sanitasi anti-korup; `SocialService` melarang transaksi gerobak diri sendiri & memvalidasi jarak. | **PASS** (PROMPT 10, 13 & 14 tests). |

---

## 3. Batasan Pengujian Keamanan
- Verifikasi pembatasan `IsAuthorizedAdmin` pada mode non-Studio (`RunService:IsStudio() == false`) belum dapat dijalankan pada place lokal yang belum dipublish; wajib diuji ulang pada live Roblox server setelah publish dengan akun sekunder non-kreator.
- Uji *race condition* multi-pemain bersamaan pada dua jendela client nyata (*Local Server & 2+ Clients*) disarankan sebelum rilis beta publik.
