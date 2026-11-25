# PERFORMANCE AUDIT REPORT — GORENGAN 24 JAM: AWAS SATPOL!

**Tanggal Audit:** 2026-11-25  
**Target:** Pengalaman stabil 60 FPS PC & perangkat mobile kelas menengah (hingga 8 pemain + NPC + random events)  
**Skill Acuan:** `roblox-performance`, `roblox-game-architecture`, `roblox-qa-testing`

---

## 1. Pengukuran Runtime Roblox Studio (`Place1.rbxl` — Play Solo)

Pengukuran diambil langsung dari `Stats` & `Workspace` saat seluruh **17 Server Services** & **16 Client Controllers** aktif berjalan:

| Metrik Runtime | Nilai Terukur | Ambang Batas Mobile | Status |
|---|---|---|---|
| **Server Total Memory** | `1027.3 MB` | `< 1500 MB` (lingkungan Studio all-in-one) | Normal (Studio overhead termasuk server+client) |
| **Client Total Memory** | `841.1 MB` | `< 1200 MB` di Studio | Normal |
| **Total `BasePart` (termasuk `MeshPart`)** | `466` parts (`20` `MeshPart` avatar/props) | `< 1500` parts | ✅ Sangat ringan |
| **`Workspace.Map` Unanchored Parts** | `0` (`100%` Anchored) | `0` | ✅ Bebas simulasi fisika liar |
| **Active `PointLight`** | `12` (`Shadows = false` di lampu jalan & gerobak) | `<= 30` | ✅ Optimal untuk GPU mobile |
| **Active `ParticleEmitter`** | `6` (dengan toggle **Low-FX** di Settings) | `<= 20` | ✅ Hemat fill-rate |

---

## 2. Audit Masalah Performa, Tingkat Risiko, Solusi & Verifikasi

| # | Area & Temuan | Risiko | Solusi yang Diimplementasikan | Hasil Verifikasi |
|---|---|---|---|---|
| 1 | **UI Rendering Thrashing (`TimeAndEventController._refreshEventPills`)**: Menghancurkan dan membuat ulang semua `Frame`, `UICorner`, dan `TextLabel` di `ActiveEventsContainer` setiap `0.5 detik` meskipun hanya detik countdown yang berubah. | **Tinggi** | Menyimpan cache objek pil di `_eventPills[eventId]`, melewatkan iterasi saat tidak ada event aktif, dan hanya memperbarui `Label.Text` ketika teks berubah. | **PASS** — Uji client membuktikan referensi `Frame` `EventPill_hujan_deras` tetap sama melintasi `> 2` siklus `0.5s` dan bersih saat event berhenti. |
| 2 | **Traversal `Map:GetDescendants()` Berulang (`TimeService:_setStreetLampsEnabled`)**: Memindai ratusan descendant `Workspace.Map` setiap transisi Sore/Malam dan fajar. | **Tinggi** | Meng-cache referensi `PointLight` milik `Bulb` dalam `self._cachedLampLights` (hanya ~9 lampu jalan) sehingga toggle berlangsung dalam $O(N_{\text{lamp}})$. | **PASS** — Uji server membuktikan `_cachedLampLights` terisi dan menyalakan/mematikan lampu tanpa traversal ulang. |
| 3 | **Scan `Workspace:GetChildren()` 20Hz & Leak Referensi Tombol UI (`AudioVFXController`)**: Loop animasi NPC memindai seluruh anak `Workspace` tiap `0.05s`, dan tabel `_hookedButtons` menahan referensi tombol modal yang sudah di-`Destroy()`. | **Tinggi** | Melacak rig `Customer_*` & `Satpol_*` berbasis event (`ChildAdded`/`ChildRemoved`) di `_trackedNpcRigs` + *distance culling* `95 studs`; membersihkan `_hookedButtons[inst] = nil` lewat `inst.Destroying`. | **PASS** — Diverifikasi lewat inspeksi kode & boot bersih Play Mode tanpa peringatan koneksi bocor. |
| 4 | **Pencarian Rekursif `FindFirstChild(..., true)` di Loop AI (`CustomerService:_runCustomerAI`)**: Mencari `"OrderBubble"` dan `"DialogueText"` secara rekursif setiap `0.25s` ketika kesabaran pelanggan `< 25%`. | **Sedang** | Diganti akses hierarki langsung (`Head -> OrderBubble -> BubbleFrame -> DialogueText`) dengan biaya $O(1)$. | **PASS** — Diverifikasi langsung pada kode & jalannya antrean `CustomerService` di Play Mode. |
| 5 | **Budget NPC, Pathfinding & Task Loops**: Pemeriksaan `GLOBAL_NPC_CAP = 16`, `MAX_CUSTOMERS_PER_QUEUE = 3`, dan seluruh `while` loop server/client. | **Rendah** | Seluruh loop memiliki batas `task.wait` terukur (`0.2s`–`60s`), `CustomerService` memakai `Humanoid:MoveTo` langsung pada jalur trotoar datar tanpa kalkulasi `PathfindingService` berat yang berulang, dan `NetworkBridge` membersihkan `playerRateLimits` saat `PlayerRemoving`. | **PASS** — Tidak ada loop tanpa yield (*unbounded spin*) atau pembengkakan jumlah part NPC. |

---

## 3. Catatan Keterbatasan Audit Performa
- Pengukuran memori `Stats:GetTotalMemoryUsageMb()` di Roblox Studio mencakup proses Studio + Client + Server dalam satu mesin PC, sehingga bukan angka absolut RAM perangkat HP Android/iOS nyata.
- Uji *frame time* nyata pada HP kelas menengah (mis. RAM 3–4 GB dengan 8 pemain aktif & 16 NPC bersamaan) perlu dikonfirmasi ulang di sesi QA perangkat mobile sebelum rilis publik.
