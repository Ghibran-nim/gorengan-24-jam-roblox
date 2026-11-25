# Bug Tracker & Verifikasi Regresi — Gorengan 24 Jam: Awas Satpol!

**Dokumen:** `docs/BUG_TRACKER.md`  
**Audit Terakhir:** 2026-11-25 (Prompt 17 QA & Regression Testing)

---

## 1. Ringkasan Status Bug

| Tingkat Keparahan | Ditemukan (Prompt 17) | Diperbaiki & Terverifikasi | Masih Terbuka |
|-------------------|-----------------------|---------------------------|---------------|
| **Critical** | 0 | 0 | 0 |
| **High** | 3 | 3 | 0 |
| **Medium** | 3 | 3 | 0 |
| **Low** | 0 | 0 | 0 (2 keterbatasan lingkungan eksternal dicatat terpisah) |

---

## 2. Daftar Bug Ditemukan & Perbaikannya

### [BUG-001] High — Error Runtime `RightShoulder.C0` Read-Only pada Karakter R15 Modern (`AnimationConstraint`)
- **Lokasi:** `src/client/Controllers/AudioVFXController.luau` (`_tweenRightArmPose`, baris 206–275)
- **Gejala:** Saat pemain memasak (`SetCookingFeedback`), mengambil bahan, atau melayani, Studio Output memunculkan error: `TweenService:Create property named 'C0' on object 'RightShoulder' is read only` dan `Unable to assign property C0. Property is read only`.
- **Akar Masalah:** Rig avatar R15 Roblox Studio terbaru menggunakan `AnimationConstraint` pada `RightShoulder` (bukan `Motor6D`), di mana properti `C0` bersifat *read-only*.
- **Perbaikan:** Mengganti `TweenService:Create` pada `C0` dengan *procedural Heartbeat lerp* yang mendeteksi tipe sendi: memakai `.C0` untuk R6/R15 `Motor6D` dan `.Attachment0.CFrame` untuk `AnimationConstraint`, dengan token pembatalan agar pose bahu tidak bergeser saat dipicu berulang.
- **Verifikasi Pasca-Fix:** `19_AudioVFX_Animations_Clean` lulus 100% di Play Mode dengan **0 error** di Output.

### [BUG-002] High — Race Condition Pemicuan Razia Satpol PP Antara `SatpolService` dan `EventService`
- **Lokasi:** `src/server/Services/SatpolService.luau` (`_runRaidScheduler`, baris 752–770)
- **Gejala:** Ketika `EventService` memicu event acak `razia_satpol` (`StartRaidWarning`), log menunjukkan `RAZIA AKTIF DIMULAI!` langsung berjalan pada detik ke-0 bersama `Warning`, lalu berjalan kedua kalinya 15 detik kemudian.
- **Akar Masalah:** Loop `_runRaidScheduler()` mendeteksi `_currentRaidState ~= "Idle"`, keluar dari loop tidur `Idle`, lalu langsung jatuh (*fall-through*) ke pengecekan `if _currentRaidState == "Warning" then StartActiveRaid()` pada iterasi yang sama.
- **Perbaikan:** Menambahkan flag `interrupted = true` ketika `_currentRaidState ~= "Idle"` di dalam loop `Idle`; bila terinterupsi oleh pengendali eksternal (`EventService` atau `ForceRaidEvent`), scheduler menunggu hingga state kembali `"Idle"` lalu mengulang cooldown baru (`continue`).
- **Verifikasi Pasca-Fix:** Di Output Play Mode (`10:44:54` Warning -> `10:45:09` Active -> `10:45:54` Ended), peringatan razia berjalan tepat 15 detik tanpa double-trigger.

### [BUG-003] High — Tumpang Tindih HUD & Pemotongan Modal pada Viewport Menengah & Mobile Landscape (`844x390`)
- **Lokasi:**
  - `src/client/Controllers/TutorialController.luau` (`TutorialCard` & `UpdateTutorialCard`, baris 80–216)
  - `src/client/Controllers/HUDController.luau` (`TopHeaderBar` & `ToastContainer`, baris 73–215)
  - `src/client/Controllers/ChiliController.luau` (`ChiliModalContainer`, baris 182–195)
  - `src/client/Controllers/SocialController.luau` (`LeaderboardModal`, `CartVisitModal`, baris 173–250)
  - `src/client/Controllers/AudioVFXController.luau` (`SettingsModal` & `SettingsList`, baris 519–605)
- **Gejala:**
  1. Verifikasi visual screenshot (`media_0.jpg`) menunjukkan `ToastContainer` menutupi bagian kanan `TopHeaderBar` (`480px`), dan `UpdateTutorialCard` masih memakai offset `-240` meski `AnchorPoint = (0.5, 0)` sehingga menggeser `TutorialCard` ke kiri menumpuk `StockBar`.
  2. Modal `ChiliModalContainer` (`540x400`), `LeaderboardModal` (`460x360`), `CartVisitModal` (`420x350`), dan `SettingsModal` (`400x340`) memakai pixel fixed sehingga terpotong vertikal di layar mobile `844x390`.
- **Perbaikan:**
  - Menyeragamkan kolom kiri HUD menjadi `260px` (`TopHeaderBar`, `StockBar`, `ClockPanel`) dengan `TextScaled` + `UITextSizeConstraint`.
  - Menggunakan `AnchorPoint = Vector2.new(0.5, 0)`, `Size = UDim2.new(0.34, 0, 0, 76)`, `Position = UDim2.new(0.5, 0, 0, 68)` pada `TutorialCard` & `ToastContainer` beserta `UISizeConstraint` (`Min=270..280`, `Max=440..460`) dan menghapus offset `-240` pada seluruh tween `UpdateTutorialCard`.
  - Mengubah 4 modal tengah memakai `AnchorPoint = (0.5, 0.5)` + `Scale` + `UISizeConstraint`, serta mengubah isi `SettingsModal` menjadi `ScrollingFrame` dengan `AutomaticCanvasSize = Y`.
- **Verifikasi Pasca-Fix:** `20_UI_PC_And_Mobile_ZeroOverlap` lulus dengan `Overlaps = 0`, `Mobile844x390Fit = true`, serta dikonfirmasi secara visual melalui `phase5_final_qa.jpg`.

### [BUG-004] Medium — Sisa Objek Uji / Demo di `Place1.rbxl` Edit Mode
- **Lokasi:** `Place1.rbxl` (`Workspace` Edit-time)
- **Gejala:** Terdapat 9 sisa objek uji dari prompt-prompt awal (`Gerobak_Demo`, `Customer_Demo_1`, `Customer_Demo_2`, `Cust_CUST_TIMEOUT` x3, `Cust_CUST_HP_1`, `Gerobak_TestPlayer_Prompt08`, `SpawnLocation` root) dan folder `SatpolSquad` tersisa di `Workspace` Edit mode, menyebabkan duplikasi visual saat Play Mode dimulai.
- **Perbaikan:** Membersihkan seluruh sisa objek dummy tersebut di `Workspace` Edit mode tanpa menyentuh `Workspace.Map` maupun `MainSpawnLocation`, lalu menyimpan place cleanly.
- **Verifikasi Pasca-Fix:** `01_PlayerSpawning_And_Map` lulus; `Workspace:GetDescendants()` Play Mode hanya `1041` instance.

### [BUG-005] Medium — Keterlambatan Sinkronisasi `leaderstats` Saat Rejoin di `ProgressionService`
- **Lokasi:** `src/server/Services/ProgressionService.luau` (`DataService:RegisterDomain("Progression")` callback `Apply`, baris 94–103)
- **Gejala:** Apabila domain `Economy` diterapkan lebih dulu daripada `Progression` saat pemain rejoin, `SocialService:RefreshPlayerStats` berisiko membaca `Level` dan `TotalEarnings` lama sebelum `Progression` selesai dihidrasi.
- **Perbaikan:** Memanggil `socialService:RefreshPlayerStats(player)` dan `socialService:ScheduleLeaderboardBroadcast()` di akhir callback `Apply` domain `Progression`.
- **Verifikasi Pasca-Fix:** Terverifikasi pada kode & `DataPersistence_RoundTrip_AllDomains_And_Retry`.

### [BUG-006] Medium — Syntax Error Sisa Edit (`;`) pada `AudioVFXController` Saat Patch R15
- **Lokasi:** `src/client/Controllers/AudioVFXController.luau` (baris 260 sementara)
- **Gejala:** Semicolon awalan baris `;(animTarget :: any)[propName]` memicu parse error Luau saat Play Mode pertama pasca-edit.
- **Perbaikan:** Diganti dengan variabel bertipe lokal `local targetTbl: any = animTarget` -> `targetTbl[propName] = ...`.
- **Verifikasi Pasca-Fix:** Seluruh 16/16 controller client termuat sempurna tanpa error pada 2 run Play Mode beruntun.

---

## 3. Catatan Keterbatasan Eksternal (Bukan Bug Kode)

1. **`ContentId: rbxassetid://203785492 failed due to: Asset type does not match requested type`:** Dipastikan melalui pencarian rekursif pada `src/` (`0` kecocokan) dan inspeksi seluruh descendants `game` saat Play Mode (`0` kecocokan); pesan ini berasal dari asset internal avatar default Roblox Studio saat *Play Solo*.
2. **DataStore Lokal (`Place belum dipublish`):** `DataService` secara otomatis beralih ke mode aman ketika `DataStoreService` melempar error *unpublished place*. Verifikasi penuh terhadap cloud DataStore Roblox membutuhkan *Publish to Roblox* dan uji *Server & Clients*.
