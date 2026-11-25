# MULTIPLAYER & SOCIAL SYSTEMS TEST REPORT (PROMPT 13)

**Tanggal Pengujian:** 2026-11-25  
**Lingkungan Pengujian:** Roblox Studio (`Place1.rbxl` — Play Solo + Server Simulasi Multi-Pemain & Client Real Remote E2E)

---

## 1. Masalah Multiplayer yang Ditemukan Saat Audit & Perbaikannya

| # | Masalah / Celah Multiplayer | Dampak Risiko | Perbaikan Otoritatif |
|---|---|---|---|
| 1 | **Potensi Konflik Kepemilikan Plot (`GameService` & `CartService`)** | Dua pemain bisa menimpa plot yang sama jika `SpawnPlayerCart` dipanggil langsung tanpa kunci dua arah. | Menambahkan `_plotOwners[PlotId] = UserId` di `GameService`, validasi anti-konflik sebelum spawn di `CartService`, serta atribut `OwnerUserId` & `PlotId` pada model gerobak. |
| 2 | **Antrean Pelanggan Yatiman saat Pemain Keluar (`CustomerService`)** | NPC pelanggan tetap menunggu di plot yang pemiliknya sudah disconnect, berisiko mengganggu pemilik plot baru. | Menambahkan `ClearPlotCustomers(plotId)` yang dipanggil atomik di `GameService:_onPlayerRemoving` sebelum slot plot dilepas kembali. |
| 3 | **Sinkronisasi Late-Joiner untuk Event & Razia (`EventService` & `SatpolService`)** | Pemain yang bergabung di tengah event/razia tidak menerima sisa durasi akurat, ikon, warna banner, maupun status `RaidAlert`. | `EventService:GetActiveEventsList()` kini mengirim `Icon`, `BannerColor`, `RemainingSeconds`; `SatpolService:SyncRaidStateToPlayer` mengirim `RaidAlert` akurat saat `PlayerAdded`; `SocialService` menyinkronkan status kompetisi saat join. |
| 4 | **Celah Jarak & Ragdoll pada Memasak/Bahan (`CookingService` & `InventoryService`)** | Pemain dapat memicu `RequestStartCooking` atau `RequestTakeIngredients` dari jauh atau saat sedang sempoyongan terkena gorengan gosong. | Validasi server jarak maksimal (`<= 20 studs` dari gerobak sendiri), pengecekan `IsPlayerRagdolled`, dan sanitasi integer/string payload. |
| 5 | **Anti-Harassment Lemparan & Eksploitasi ATM (`ThrowableService` & `EconomyService`)** | Pemain dapat melempar target yang sama berulang tepat setelah kekebalan habis, atau mengirim `NaN`/`math.huge` ke ATM. | Menambahkan `_pairThrowCooldowns` (`10s` per pasangan pelaku–target) + pembersihan di `PlayerRemoving`, serta validasi anti-`NaN`/anti-`math.huge` di `DepositToATM`/`WithdrawFromATM`. |
| 6 | **Kebocoran Tabel Rate Limit (`NetworkBridge`) & Prompt Lintas Gerobak (`CartController`)** | Entri `playerRateLimits[UserId]` tidak terhapus saat pemain keluar; prompt gerobak lain tetap terlihat di client. | Pembersihan `playerRateLimits` di `Players.PlayerRemoving` dan penyembunyian prompt kepemilikan gerobak lain vs `SocialVisitPrompt` di client. |

---

## 2. Hasil Pengujian Runtime Studio

### A. Server Multiplayer & Security Tests (`6 PASS / 0 FAIL`)
1. **`[PASS]` Alokasi Maksimal 8 Plot, Anti-Konflik & Cleanup Disconnect:**  
   8 pemain menerima plot `#1`–`#8` unik; pemain ke-9 ditempatkan ke mode penonton (`nil`); permintaan plot yang sudah terisi ditolak; saat pemain keluar, gerobak didespawn, plot dibuka kembali dan dapat diklaim pemain baru.
2. **`[PASS]` Atribut Kepemilikan Gerobak Nyata, `SocialVisitPrompt` & `leaderstats`:**  
   Gerobak di `Workspace` memiliki `OwnerUserId` & `PlotId`, `SocialVisitPrompt` terpasang pada `EtalaseKaca`, dan `leaderstats` (`Omzet`, `Kas`, `Level`) terbuat di `Player`.
3. **`[PASS]` Isolasi Melayani Pelanggan & `ClearPlotCustomers`:**  
   Upaya pemain plot lain melayani pelanggan Plot `#1` ditolak; saat pemilik Plot `#1` keluar, pesanan aktif dihapus dan model NPC dihancurkan.
4. **`[PASS]` Keamanan Ekonomi, Sosial, Lemparan & Memasak:**  
   Penolakan setoran ATM negatif/`NaN`/`math.huge` dan penarikan melebihi saldo; penolakan transaksi/reaksi antargerobak pada diri sendiri atau target offline; penolakan arah lempar `NaN`/`Vector3.zero`; blokir memasak, melempar, dan mendorong gerobak saat dalam kondisi ragdoll.
5. **`[PASS]` Sinkronisasi Late-Joiner & Event Kompetisi Server-Wide:**  
   `GetActiveEventsList()` menyertakan `Icon`, `BannerColor`, dan `RemainingSeconds`; event `Lomba Omzet Gerobak` dapat dimulai dan dihentikan bersih.
6. **`[PASS]` Pengurutan Leaderboard & Pembersihan Memori:**  
   `GetLeaderboard()` mengurutkan peringkat secara deterministik dan membersihkan entri sementara tanpa sisa.

### B. Client–Server Real Remote & UI Tests (`3 PASS / 0 FAIL`)
1. **`[PASS]` Sinkronisasi `SocialLeaderboardHUD` & `leaderstats` dengan Server Hidup:**  
   `LeaderboardBadgeButton`, `LeaderboardModal`, `CartVisitModal`, `CompetitionBanner`, dan `RequestGetLeaderboard` terhubung penuh.
2. **`[PASS]` Penolakan Payload Ilegal/Abuse melalui RemoteFunction Nyata:**  
   `RequestBuyFromPlayerCart`, `RequestInspectPlayerCart`, `RequestSendSocialReaction`, `RequestDepositATM`, dan `RequestTakeIngredients` menolak input diri sendiri, target offline, tipe salah, `NaN`, angka negatif, dan jumlah berlebihan.
3. **`[PASS]` Klik UI Nyata & Event Kompetisi Server-Wide:**  
   `RequestTriggerCompetitionEvent("Start")` mengaktifkan `CompetitionBanner` pada HUD, dan klik mouse nyata (`user_mouse_input`) pada `LeaderboardBadgeButton` membuka `LeaderboardModal` beserta baris peringkat pemain.

---

## 3. Keterbatasan Lingkungan Uji
- Fitur multi-pemain diuji menggunakan **Play Solo + simulasi multi-pemain di server + remote client nyata** pada `Place1.rbxl` karena MCP Studio belum menjalankan sesi *Local Server & Multiple Clients* terpisah secara otomatis. Uji 2+ jendela client paralel direkomendasikan saat QA akhir sebelum rilis beta.
