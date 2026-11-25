# LAPORAN AUDIT & PENGUJIAN PERSISTENCE DATA PEMAIN (PROMPT 14)

**Tanggal:** 2026-11-25  
**Modul Utama:** [`src/server/Services/DataService.luau`](file:///c:/Users/HP/Downloads/gorengan-24-jam-roblox/src/server/Services/DataService.luau) & [`src/shared/Config/DataConfig.luau`](file:///c:/Users/HP/Downloads/gorengan-24-jam-roblox/src/shared/Config/DataConfig.luau)  
**Solusi Penyimpanan:** Native Roblox `DataStoreService` (tanpa dependency eksternal ProfileStore; menggunakan `UpdateAsync`, session locking, `SaveCount` monotonik, dan fallback memori aman bila DataStore tidak aktif).

---

## 1. Domain Data yang Dipersistensikan (Skema `v2`)

Seluruh progres pemain disatukan ke dalam satu profil per pemain (key `Player_<UserId>`) di DataStore `Gorengan24Jam_PlayerProfile_v2`:

| Domain | Field yang Disimpan | Aturan Sanitasi & Keamanan |
|---|---|---|
| **Uang Tunai & Tabungan** | `Economy.CarriedCash`, `Economy.BankedCash`, `Economy.Reputation` | `CarriedCash` dibatasi `0 .. BaseCarriedCashCapacity` (`1.000.000`); `BankedCash` dibatasi non-negatif (`0 .. 100.000.000`); tolak `NaN` / `math.huge` / negatif. |
| **Inventory** | `Inventory.Ingredients`, `Inventory.CookedFood` | Validasi key bahan & resep terhadap `RecipesConfig`; batasi kapasitas bahan & stok matang agar bebas korup. |
| **Resep Terbuka** | `Progression.UnlockedRecipes`, `Progression.SelectedRecipeId` | `bakwan_sayur` selalu dipastikan terbuka; resep ilegal dihapus saat load/migrasi. |
| **Upgrade** | `Upgrades` (`{ [string]: boolean }`) | Hanya ID yang valid di `UpgradesConfig` yang diterima; visual & Kasir NPC dihidrasi ulang saat rejoin. |
| **Chili Collection** | `ChiliCollection` (`TotalRolls`, `PityCounter`, `EquippedChiliId`, `OwnedChilis`) | Validasi terhadap `ChiliGachaConfig`; `PityCounter` dibatasi `0 .. PityThreshold`; cabai terpasang langsung muncul di gerobak. |
| **Progression & Tutorial** | `Level`, `XP`, `TotalXP`, `TotalSales`, `TotalEarnings`, `TutorialStep`, `TutorialCompleted`, `TutorialSkipped` | Level & XP dihitung ulang secara deterministik dari `TotalXP` melalui `ProgressionConfig`. |
| **Statistik Pemain** | `Stats` (`TotalCooked`, `TotalCrispy`, `TotalUndercooked`, `TotalBurnt`, `RaidsSurvived`, `RaidsCaptured`, `PlayTimeSeconds`, `FirstJoinedAt`, `LastSavedAt`) | Pencatatan server-only via `CookingService` & `SatpolService`. |

---

## 2. Pengamanan Penyimpanan & Pencegahan Korupsi
1. **Session Locking & Monotonic `SaveCount`:** `LoadPlayerData` mengunci `Meta.SessionLock = { JobId, LockedAt }` melalui `UpdateAsync`. Server lain tidak bisa menimpa selama lock aktif (< `90 detik`), dan lock usang (> `90 detik`) dipulihkan otomatis.
2. **Throttling & Dirty Flag:** `RunAutoSaveCycle` berjalan tiap `60 detik` dan hanya menulis jika `_dirtyFlags[UserId] == true` serta melewati `MinSaveIntervalSeconds` (`10 detik`).
3. **Exponential Backoff Retry:** Baik load maupun save mencoba ulang hingga `3x` (`0.6s`, `1.2s`) pada error sementara.
4. **Urutan Bersih `PlayerRemoving` & `BindToClose`:** Service domain (`EconomyService`, `InventoryService`, `ProgressionService`, `TutorialService`, `ChiliService`) tidak lagi menghapus cache secara independen pada `PlayerRemoving`; `DataService` menyimpan snapshot akhir dan melepas lock terlebih dahulu, barulah memanggil callback `Cleanup` masing-masing domain.

---

## 3. Hasil Pengujian Studio (`8 PASS / 0 FAIL` via Simulated DataStore Adapter)
1. **`[PASS]` Probe `DataStoreService` Nyata:** Place lokal yang belum dipublish ditangani aman tanpa crash (`You must publish this place to the web to access DataStore`).
2. **`[PASS]` Join → Ubah Seluruh 8 Domain → Leave → Rejoin:** Seluruh `CarriedCash`, `BankedCash`, `Ingredients`, `CookedFood`, `UnlockedRecipes`, `Upgrades`, `ChiliCollection`, `Progression`, `Tutorial`, dan `Stats` bertahan akurat antar sesi dan memori dibersihkan saat keluar.
3. **`[PASS]` Throttling & Dirty Flag:** Profil bersih tidak menulis ke DataStore; save berulang dalam `< 10 detik` ditahan kecuali saat `PlayerRemoving`/`BindToClose`.
4. **`[PASS]` Kegagalan Sementara & Retry:** 2 kegagalan berturut-turut di-retry hingga sukses pada percobaan ke-3.
5. **`[PASS]` Kegagalan Total DataStore:** Load & save yang gagal total melaporkan `false` tanpa crash, inkremen metrik diagnostik, dan menjaga server tetap berjalan.
6. **`[PASS]` Migrasi Skema Lama (`v0` → `v2`) & Anti-Korup:** Data flat `v0` (`Cash`, `Bank`, array `UnlockedRecipes`/`Upgrades`) bermigrasi ke `v2`; angka `NaN`, nilai negatif (`Bank = -9999`, `Burnt = -3`), dan ID resep/upgrade/cabai ilegal dibersihkan aman.
7. **`[PASS]` Disconnect Saat Transaksi & `BindToClose`:** Transaksi pada pemain yang tidak terhubung ditolak; `HandleServerShutdown()` menyimpan seluruh profil aktif dan melepas `SessionLock`.
8. **`[PASS]` Proteksi Session Lock:** Lock aktif server lain menolak load ganda; lock basi (`> 90s`) pulih otomatis.

---

## 4. Status Verifikasi Lingkungan DataStore Nyata (**Penting**)
> [!WARNING]
> **Cloud DataStore Roblox Belum Diuji Secara Live:** File `Place1.rbxl` saat ini berstatus *unpublished place*, sehingga `DataStoreService:GetDataStore()` di Roblox Studio mengembalikan `"You must publish this place to the web to access DataStore"`. Karena itu, klaim keamanan persistensi di atas baru terverifikasi penuh terhadap adapter simulasi DataStore di Studio, **belum** terhadap server cloud DataStore Roblox secara langsung.

### Langkah Uji Wajib Setelah Place Dipublish:
1. Publish `Place1.rbxl` ke Roblox (*File → Publish to Roblox*).
2. Aktifkan *Game Settings → Security → Enable Studio Access to API Services*.
3. Jalankan Play Solo: pastikan log `DataService` menampilkan `[INFO] Profil ... siap` **tanpa** `[WARN] DataStoreService tidak tersedia`.
4. Beli bahan/upgrade, setor uang ke ATM, masak 1 resep, keluar dari Play Solo, lalu jalankan Play Solo ulang dan verifikasi seluruh saldo, resep, upgrade, dan etalase termuat kembali dari DataStore cloud.
