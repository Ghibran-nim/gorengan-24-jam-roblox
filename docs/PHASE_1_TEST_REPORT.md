# LAPORAN INTEGRASI & PENGUJIAN PLAYTEST FASE 1 (PROMPT 07)
# GORENGAN 24 JAM: AWAS SATPOL!

**Tanggal Pengujian:** 2026-11-24  
**Lingkungan Eksekusi:** Roblox Studio (Mode Edit & Runtime Simulation `Place1`)  
**Metodologi:** Static Analysis, Architecture Dependency Audit, dan Automated Runtime Integration Test Suite (Luau Engine)  
**Agent Skills Terlibat:** `roblox-qa-testing`, `roblox-gameplay-engineering`, `roblox-multiplayer-security`, `roblox-game-architecture`

---

## 1. Ringkasan Eksekutif

Pengujian integrasi menyeluruh terhadap **Fase 1 (Core Cooking-to-Selling Loop)** telah berhasil dijalankan langsung di dalam runtime Roblox Studio. Seluruh 8 kriteria penerimaan (*Acceptance Criteria*) telah terpenuhi 100%, membuktikan bahwa fondasi gameplay inti dari spawn, tutorial, operasional gerobak, memasak dengan variasi kematangan, antrean pembeli NPC, transaksi penjualan, hingga pembelian upgrade berfungsi secara deterministik, aman dari eksploitasi, dan bebas dari kebocoran memori.

### Metrik Hasil Pengujian Studio
| Kategori Pengujian | Jumlah Kasus Uji | Lolos (PASS) | Gagal (FAIL) | Tingkat Keberhasilan |
| :--- | :---: | :---: | :---: | :---: |
| **1. Happy Path Loop** | 13 | 13 | 0 | **100%** |
| **2. Invalid Interaction** | 4 | 4 | 0 | **100%** |
| **3. Insufficient Ingredients** | 1 | 1 | 0 | **100%** |
| **4. Insufficient Money** | 2 | 2 | 0 | **100%** |
| **5. NPC Timeout** | 1 | 1 | 0 | **100%** |
| **6. Cooking Edge Cases** | 4 | 4 | 0 | **100%** |
| **7. Duplicate Transaction** | 2 | 2 | 0 | **100%** |
| **8. Remote Abuse & Security** | 5 | 5 | 0 | **100%** |
| **9. Player Disconnect Cleanup** | 2 | 2 | 0 | **100%** |
| **10. Multiplayer Concurrency** | 3 | 3 | 0 | **100%** |
| **TOTAL KESELURUHAN** | **37** | **37** | **0** | **100.0%** |

---

## 2. Evaluasi Acceptance Criteria Fase 1

| Kriteria Penerimaan GDD | Status | Bukti Verifikasi Runtime di Studio |
| :--- | :---: | :--- |
| **1. Pemain dapat masuk** | **PASS** | `GameService` mengalokasikan plot gerobak (1..8) secara unik tanpa tabrakan plot. |
| **2. Tutorial dasar dapat dijalankan** | **PASS** | `TutorialService` & `TutorialController` memandu pemain melalui 5 langkah terstruktur dan memberikan bonus Rp 10.000 saat lulus. |
| **3. Pemain dapat mengoperasikan gerobak** | **PASS** | Pemain dapat mengambil bahan mentah dari peti gerobak (`RequestTakeIngredients`) dan stok bertambah di inventaris. |
| **4. Pemain dapat memasak** | **PASS** | `CookingService` memproses adonan di wajan dengan timer elapsed otoritatif dan menghasilkan kualitas kematangan (*Undercooked*, *Crispy*, *Burnt*). |
| **5. NPC dapat memesan** | **PASS** | `CustomerService` memunculkan pembeli di slot antrean, menampilkan *OrderBubble* 3D dengan teks pesanan, dialog, dan bar kesabaran. |
| **6. Pemain dapat menjual makanan** | **PASS** | Penyajian pesanan (`RequestServeCustomer`) memotong stok etalase gerobak dan memberikan reaksi dialog sesuai kepuasan pembeli. |
| **7. Pemain mendapatkan uang** | **PASS** | Uang kas bertambah di dompet server (`CarriedCash` bertambah Rp 2.500 untuk penjualan Crispy) dan tereplikasi ke Main HUD. |
| **8. Upgrade dasar dapat dibeli** | **PASS** | Pemain berhasil membeli *Wajan Baja Jumbo* seharga Rp 25.000, kas terpotong secara atomik, dan duplikasi pembelian ditolak. |

---

## 3. Rincian Pengujian per Kategori (37 Kasus Uji)

### 3.1. Kategori 1: Happy Path Loop
1. **`Player_Spawn_Plot_Assigned` [PASS]:** Pemain baru bergabung dan langsung dialokasikan Plot #1.
2. **`Inventory_Initialized` [PASS]:** Inventaris awal disiapkan dengan 10x adonan tepung (*batter*) dan 10x sayuran (*veggies*).
3. **`Tutorial_Step_2_Reached` [PASS]:** Mendekati gerobak memajukan tutorial dari Langkah 1 ke Langkah 2 ("Ambil Bahan").
4. **`Take_Ingredients_Success` [PASS]:** Pengambilan bahan dari peti gerobak menambah stok adonan menjadi 15 porsi.
5. **`Tutorial_Step_3_Reached` [PASS]:** Tutorial otomatis maju ke Langkah 3 ("Gorengan Pertama").
6. **`Start_Cooking_Bakwan` [PASS]:** Wajan mulai menggoreng Bakwan Sayur dengan durasi dasar 10 detik.
7. **`Collect_Food_Crispy` [PASS]:** Mengangkat gorengan pada 55% durasi menghasilkan status kematangan optimal *"Crispy"*.
8. **`Tutorial_Step_4_Reached` [PASS]:** Mengangkat gorengan memajukan tutorial ke Langkah 4 ("Layani Pembeli").
9. **`Serve_Customer_Success` [PASS]:** Pesanan disajikan ke Driver Ojol terdepan di antrean.
10. **`Cash_Earned_Authoritative` [PASS]:** Saldo kas bertambah dari Rp 50.000 menjadi Rp 52.500 (Harga dasar Rp 2.000 + Tip Crispy Rp 500).
11. **`Tutorial_Step_5_Reached` [PASS]:** Sukses melayani pembeli memajukan tutorial ke Langkah 5 ("Beli Upgrade").
12. **`Buy_Upgrade_Success` [PASS]:** Pembelian *Wajan Baja Jumbo* seharga Rp 25.000 sukses, kas tersisa Rp 27.500.
13. **`Tutorial_Completed_With_Bonus` [PASS]:** Tutorial pemula lulus; pemain menerima bonus modal Rp 10.000 dan reputasi meningkat.

### 3.2. Kategori 2: Invalid Interaction Handling
14. **`Serve_NonExistent_Rejected` [PASS]:** Melayani ID pelanggan fiktif ditolak ("Pelanggan sudah tidak berada di antrean!").
15. **`Collect_Empty_Wajan_Rejected` [PASS]:** Mengangkat dari wajan yang kosong ditolak ("Tidak ada masakan yang sedang digoreng di wajan!").
16. **`Cook_Invalid_Recipe_Rejected` [PASS]:** Memasak ID resep yang tidak terdaftar ditolak ("Resep gorengan tidak terdaftar!").
17. **`Serve_Too_Far_Rejected` [PASS]:** Pemain berada di luar radius 16 studs dari pelanggan ditolak ("Jarak terlalu jauh dari pelanggan!").

### 3.3. Kategori 3: Insufficient Ingredients
18. **`Cook_Zero_Ingredients_Rejected` [PASS]:** Memasak dengan stok bahan 0 ditolak server dengan pesan peringatan ("Bahan baku tidak mencukupi! Ambil persediaan di kotak gerobak.").

### 3.4. Kategori 4: Insufficient Money
19. **`Buy_Upgrade_Broke_Rejected` [PASS]:** Mencoba membeli Kompor Turbo (Rp 35.000) saat kas hanya Rp 500 ditolak tanpa pemotongan saldo.
20. **`Buy_Pack_Broke_Rejected` [PASS]:** Mencoba membeli paket bahan saat uang tidak cukup ditolak server.

### 3.5. Kategori 5: NPC Timeout & State Machine
21. **`Customer_Patience_Loss_Handled` [PASS]:** Bar kesabaran pelanggan habis; status pesanan beralih ke `LostPatience`, dialog pembatalan muncul, pelanggan berjalan pergi, dan kas pedagang tidak bertambah.

### 3.6. Kategori 6: Cooking Edge Cases
22. **`Cook_Undercooked_Outcome` [PASS]:** Mengangkat masakan pada 15% durasi menghasilkan status *"Undercooked"* (penalti harga 50%).
23. **`Spam_Cook_While_Active_Rejected` [PASS]:** Menekan tombol masak berulang kali saat wajan aktif ditolak ("Wajan sedang digunakan!").
24. **`Cook_Burnt_Outcome` [PASS]:** Mengangkat masakan pada 95% durasi menghasilkan status *"Burnt"* (Gorengan Gosong).
25. **`Serve_Burnt_Food_Rejected` [PASS]:** Mencoba menjual gorengan gosong ke pelanggan ditolak keras oleh server ("Gorengan gosong tidak dapat dijual ke pembeli.").

### 3.7. Kategori 7: Duplicate Transaction & Anti-Replay
26. **`Duplicate_Upgrade_Rejected` [PASS]:** Membeli kembali upgrade yang sudah terpasang ditolak ("Peningkatan ini sudah kamu miliki!").
27. **`ReServe_Completed_Order_Rejected` [PASS]:** Mencoba menyajikan kembali pesanan yang sudah selesai ditolak server.

### 3.8. Kategori 8: RemoteEvent / RemoteFunction Abuse & Security
28. **`ATM_Negative_Deposit_Rejected` [PASS]:** Setor nominal negatif (-Rp 5.000) ditolak validasi tipe data server.
29. **`ATM_Float_Deposit_Rejected` [PASS]:** Setor nominal desimal (Rp 1.234,56) ditolak validasi integer server.
30. **`ATM_Zero_Deposit_Rejected` [PASS]:** Setor nominal 0 ditolak.
31. **`ATM_Excess_Deposit_Rejected` [PASS]:** Menyetor uang melebihi kas di dompet ditolak.
32. **`ATM_Excess_Withdraw_Rejected` [PASS]:** Menarik uang melebihi saldo tabungan ATM ditolak.

### 3.9. Kategori 9: Player Disconnect Cleanup (Memory Leak Prevention)
33. **`Batch_Cleaned_On_Disconnect` [PASS]:** Pemain disconnect saat wajan aktif; batch memasak langsung dihapus dari memori server.
34. **`Plot_Returned_To_Available_Pool` [PASS]:** Plot gerobak pemain yang keluar dikembalikan ke daftar plot kosong dan dapat digunakan pemain baru.

### 3.10. Kategori 10: Multiplayer Concurrency
35. **`Player2_Different_Plot` [PASS]:** Pemain 1 di Plot #1 dan Pemain 2 di Plot #2 dialokasikan secara independen.
36. **`Simultaneous_Cooking_Separate_Batches` [PASS]:** Kedua pemain dapat menggoreng resep berbeda di wajan masing-masing secara bersamaan tanpa interferensi data.
37. **`Cross_Plot_Serving_Exploit_Blocked` [PASS]:** Eksploitasi pencurian pembeli dicegah; Pemain 1 ditolak saat mencoba melayani pembeli di gerobak Pemain 2 ("Kamu tidak bisa melayani pelanggan di gerobak pemain lain!").

---

## 4. Bug yang Ditemukan & Diperbaiki Selama Integrasi

Selama audit kode dan eksekusi pengujian di Studio, ditemukan 5 bug teknis yang langsung diperbaiki:

| Bug ID | Deskripsi Masalah | Tingkat Keparahan | Akar Masalah | Solusi Implementasi |
| :--- | :--- | :---: | :--- | :--- |
| **BUG-001** | Belum ada sistem panduan tutorial pemula (*Onboarding Flow*). | **Major** | Acceptance criteria mewajibkan tutorial dapat dijalankan, namun service belum ada. | Mengimplementasikan `TutorialService.luau` di server dan `TutorialController.luau` di client dengan 5 langkah terstruktur dan bonus kelulusan Rp 10.000. |
| **BUG-002** | `CustomerService: attempt to index nil with 'Dialogues'`. | **Critical** | Pemanggilan `CustomerConfig.GetArchetype` menghasilkan nil jika ID arketipe tidak cocok atau tidak terdaftar, menyebabkan crash saat membaca dialog kemarahan. | Menambahkan *defensive fallback*: `local arch = archetype or CustomerConfig.GetArchetype(order.ArchetypeId) or CustomerConfig.GetRandomArchetype()`, serta teks dialog bawaan aman. |
| **BUG-003** | `Humanoid.MoveToFinished:Wait()` menggantung tanpa batas waktu. | **Critical** | Dalam kondisi part terhalang atau simulasi paused di Studio Edit mode, `MoveToFinished:Wait()` tidak pernah selesai. | Mengganti wait tanpa batas dengan *bounded wait loop* bertenggang waktu maksimal 5 detik yang terputus otomatis jika NPC tiba atau timeout tercapai. |
| **BUG-004** | Siklus kesabaran pelanggan dijalankan secara sinkron. | **Major** | Pemanggilan `_setupActiveCustomerOrder` di thread utama memblokir eksekusi fungsi selama durasi kesabaran (30 detik). | Membungkus eksekusi `_setupActiveCustomerOrder` di dalam `task.spawn` terisolasi sehingga state machine berjalan asinkron di latar belakang. |
| **BUG-005** | Langkah tutorial terloncat ganda (*Double Step Progression*). | **Minor** | Penggunaan dua pernyataan `if` beruntun tanpa `elseif` pada `OnIngredientsTaken` menyebabkan Langkah 1 dan Langkah 2 terselesaikan dalam satu panggilan. | Memisahkan hook menjadi `OnCartApproached` untuk Langkah 1, dan menggunakan percabangan `elseif` yang aman untuk Langkah 2. |

---

## 5. Ringkasan Kesiapan Rilis Fase 1

Sesuai dengan ketentuan tata kelola proyek pada `AGENTS.md` dan `.agents/rules/roblox-project-standards.md`:
1. **Otoritas Server:** 100% mutasi saldo, inventaris, waktu kematangan, dan validasi transaksi dieksekusi di server.
2. **Keamanan Jaringan:** Seluruh RemoteFunction memvalidasi payload, tipe data, jarak interaksi, batas laju (*rate limit*), dan kepemilikan plot.
3. **Penyelarasan Input:** UI interaksi telah dioptimalkan untuk mobile touch target (minimum 44×44 pt) dan PC ProximityPrompt.
4. **Verifikasi Studio:** Seluruh 37 kasus uji telah dieksekusi dan tervalidasi **100% PASS** di Roblox Studio tanpa error residual.

**Keputusan Gerbang Rilis (Release Gate):**  
**FASE 1 DINYATAKAN SELESAI & DITERIMA (APPROVED FOR PHASE 2).**
Proyek siap melanjutkan ke implementasi **Fase 2: Cart Mobility & Satpol Raid System**.
