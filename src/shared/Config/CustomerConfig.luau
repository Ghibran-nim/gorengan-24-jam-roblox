--!strict
--[[
    CustomerConfig.luau
    Konfigurasi variasi pelanggan (Customer Variety), karakteristik kesabaran,
    dialog lokal Indonesia, dan bobot kemunculan.
]]

export type CustomerArchetype = {
    Id: string,
    Name: string,
    Title: string,
    BasePatience: number,        -- Durasi kesabaran dalam detik (20 - 45s)
    SpawnWeight: number,         -- Bobot probabilitas kemunculan
    TipMultiplier: number,       -- Pengali bonus tip saat crispy
    ReputationReward: number,    -- Tambahan reputasi jika puas
    ReputationPenalty: number,   -- Pengurangan reputasi jika bosan/batal
    AllowedRecipes: { string },  -- Menu favorit yang biasa dipesan
    OrderQuantityMax: number,    -- Jumlah pesanan maksimal
    Colors: {
        Shirt: Color3,
        Pants: Color3,
        Skin: Color3,
    },
    Dialogues: {
        Ordering: { string },
        CrispyHappy: { string },
        UndercookedSad: { string },
        Impatient: { string },
        AngryLeave: { string },
    },
}

local Archetypes: { [string]: CustomerArchetype } = {
    ["mahasiswa"] = {
        Id = "mahasiswa",
        Name = "Mahasiswa",
        Title = "Anak Kos Lapar",
        BasePatience = 32.0,
        SpawnWeight = 40,
        TipMultiplier = 1.0,
        ReputationReward = 2,
        ReputationPenalty = 1,
        AllowedRecipes = { "bakwan_sayur", "tempe_mendoan", "tahu_isi" },
        OrderQuantityMax = 2,
        Colors = {
            Shirt = Color3.fromRGB(50, 110, 200), -- Kaos biru santai
            Pants = Color3.fromRGB(60, 60, 65),   -- Jeans gelap
            Skin = Color3.fromRGB(235, 195, 155),
        },
        Dialogues = {
            Ordering = { "Bang, gorengannya satu ya!", "Pesen bakwan anget dong kang!", "Mendoannya satu bungkus bang!" },
            CrispyHappy = { "Wah renyah banget, mantap!", "Kerenyesnya pas di lidah!", "Langganan nih besok mampir lagi!" },
            UndercookedSad = { "Yah agak lembek ya bang...", "Kurang garing nih adonannya...", "Gak papa deh buat ganjel perut." },
            Impatient = { "Masih lama kah bang? Keburu masuk kelas nih...", "Udah laper banget nih bang..." },
            AngryLeave = { "Kelamaan ah, cabut aja deh!", "Keburu telat kuliah, batal!", "Payah nih pelayanannya." },
        },
    },

    ["ojol"] = {
        Id = "ojol",
        Name = "Driver Ojol",
        Title = "Pengemudi Ojek Online",
        BasePatience = 24.0, -- Kesabaran lebih singkat karena buru-buru orderan
        SpawnWeight = 30,
        TipMultiplier = 1.25,
        ReputationReward = 3,
        ReputationPenalty = 2,
        AllowedRecipes = { "bakwan_sayur", "pisang_goreng", "cireng_crispy" },
        OrderQuantityMax = 2,
        Colors = {
            Shirt = Color3.fromRGB(35, 150, 55),  -- Jaket hijau ojol
            Pants = Color3.fromRGB(45, 45, 48),   -- Celana hitam
            Skin = Color3.fromRGB(225, 185, 145),
        },
        Dialogues = {
            Ordering = { "Bang pesen gorengan buat ganjel narik!", "Bungkusin pisang goreng cepet ya bang!", "Bakwan satu bang, buru-buru orderan!" },
            CrispyHappy = { "Alhamdulillah mantep renyah, bintang lima!", "Jos gandos gorengannya bang!", "Seger lagi nih buat narik penumpang!" },
            UndercookedSad = { "Kurang mateng dikit bang, tapi yaudahlah...", "Lembek bang, lain kali garangin ya." },
            Impatient = { "Bisa dicepetin gak bang? Customer saya nungguin!", "Aduh orderan masuk nih, buruan bang!" },
            AngryLeave = { "Aduh kelamaan bang, cancel aja deh orderan sebelah bunyi!", "Gak jadi bang, udah telat!" },
        },
    },

    ["food_vlogger"] = {
        Id = "food_vlogger",
        Name = "Food Vlogger",
        Title = "Konten Kreator Viral",
        BasePatience = 40.0, -- Lebih sabar karena sambil bikin konten
        SpawnWeight = 15,
        TipMultiplier = 2.0, -- Memberi tip besar jika crispy
        ReputationReward = 6, -- Viral boost reputasi
        ReputationPenalty = 4,
        AllowedRecipes = { "bakwan_sayur", "tahu_isi", "pisang_goreng", "cireng_crispy" },
        OrderQuantityMax = 3,
        Colors = {
            Shirt = Color3.fromRGB(230, 70, 90),  -- Kaos merah mencolok
            Pants = Color3.fromRGB(220, 220, 225), -- Celana putih modis
            Skin = Color3.fromRGB(240, 205, 165),
        },
        Dialogues = {
            Ordering = { "Halo foodies! Mau review gorengan viral nih bang!", "Bikinin yang paling crispy ya bang buat konten!", "Kasih yang paling renyah bang!" },
            CrispyHappy = { "GOKIL INI KRENYESNYA GAK ADA OBAT! 10/10!", "JUARA DUNIA CRISPY-NYA! Viral nih!", "Fix rekomendasi jajanan jalanan terenak!" },
            UndercookedSad = { "Hmm teksturnya basah dan lembek banget ya, rating 4/10 deh...", "Kecewa nih, kurang mateng..." },
            Impatient = { "Kameranya udah siap nih bang, ayo dong...", "Followers udah nungguin review-nya nih..." },
            AngryLeave = { "Kontennya gagal total, kelamaan nunggu!", "Gak jadi review deh, pelayanannya lelet!", "Next warung aja deh!" },
        },
    },

    ["misterius"] = {
        Id = "misterius",
        Name = "Pelanggan Sultan",
        Title = "Kolektor Rasa Misterius",
        BasePatience = 45.0,
        SpawnWeight = 10,
        TipMultiplier = 3.5, -- Memberi bayaran berkali-kali lipat!
        ReputationReward = 8,
        ReputationPenalty = 3,
        AllowedRecipes = { "tahu_isi", "cireng_crispy", "pisang_goreng" },
        OrderQuantityMax = 3,
        Colors = {
            Shirt = Color3.fromRGB(30, 30, 35),   -- Jas hitam elegan
            Pants = Color3.fromRGB(25, 25, 28),   -- Celana kain hitam
            Skin = Color3.fromRGB(220, 180, 140),
        },
        Dialogues = {
            Ordering = { "Bungkuskan gorengan terbaik yang kau punya.", "Saya mencari gorengan berkualitas tinggi di kota ini.", "Sajikan menu andalan gerobakmu." },
            CrispyHappy = { "Kerenyahan yang luar biasa. Ambil kembaliannya.", "Rasa autentik yang langka. Pertahankan kualitasmu.", "Sempurna. Ini bayaran pantas untukmu." },
            UndercookedSad = { "Kualitasnya di bawah standar...", "Mengecewakan. Rasanya setengah matang." },
            Impatient = { "Waktu saya sangat berharga...", "Jangan biarkan saya menunggu terlalu lama." },
            AngryLeave = { "Saya tidak punya waktu untuk pedagang lamban.", "Ternyata reputasimu hanya omong kosong.", "Selamat tinggal." },
        },
    },

    ["hantu"] = {
        Id = "hantu",
        Name = "Mbak Kunti",
        Title = "Pelanggan Tengah Malam",
        BasePatience = 35.0,
        SpawnWeight = 5, -- Sangat langka
        TipMultiplier = 2.5,
        ReputationReward = 5,
        ReputationPenalty = 2,
        AllowedRecipes = { "bakwan_sayur", "tempe_mendoan" },
        OrderQuantityMax = 1,
        Colors = {
            Shirt = Color3.fromRGB(240, 240, 245), -- Gaun putih
            Pants = Color3.fromRGB(240, 240, 245),
            Skin = Color3.fromRGB(210, 225, 230),  -- Kulit pucat
        },
        Dialogues = {
            Ordering = { "Hihihi... bakwan satuuu ya bang...", "Malam-malam dingin gini enaknya gorengan anget hihihi...", "Bungkusin tempe mendoan satuuu..." },
            CrispyHappy = { "Hihihihi... renyah dan guriiih... makasih ya bang hihihi...", "Enak banget hihihi... daunnya berubah jadi uang yaaa..." },
            UndercookedSad = { "Dingin dan lembek hihihi... kecewa aku...", "Hihihi... belum matang sempurna..." },
            Impatient = { "Hihihi... kok lama banget bang? Ayam jantan udah mau berkokok nih...", "Keburu subuh bang hihihi..." },
            AngryLeave = { "Huuuuaaa... keburu pagi hihihi! *menghilang*", "Gak jadi deeeh hihihi!" },
        },
    },
}

local CustomerConfig = {
    Archetypes = Archetypes,

    -- Pilih tipe pelanggan secara acak berbobot (weighted random)
    GetRandomArchetype = function(): CustomerArchetype
        local totalWeight = 0
        for _, arch in pairs(Archetypes) do
            totalWeight += arch.SpawnWeight
        end

        local roll = math.random(1, totalWeight)
        local accumulated = 0
        for _, arch in pairs(Archetypes) do
            accumulated += arch.SpawnWeight
            if roll <= accumulated then
                return arch
            end
        end
        return Archetypes["mahasiswa"]
    end,

    GetArchetype = function(id: string): CustomerArchetype?
        return Archetypes[id]
    end,
}

return table.freeze(CustomerConfig)
