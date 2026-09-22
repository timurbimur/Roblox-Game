-- The full roster of brainrots, sourced from a Toolbox model pack. `Id` is the
-- permanent save-data key -- never change it once players start collecting.
-- `ModelName` is the exact name of the model as it sits in
-- ServerStorage.Assets.Models (copied verbatim from the pack); if it doesn't
-- match exactly, that entry silently falls back to the placeholder block.
-- `Name` is just the display text and can be edited freely.

local BrainrotConfig = {}

local raw = {
	-- Common
	{ Id = "Boneca", Name = "Boneca", ModelName = "Boneca", Rarity = "Common", Value = 10 },
	{ Id = "BrrEstehPatipum", Name = "Brr Esteh Patipum", ModelName = "Brr esteh patipum", Rarity = "Common", Value = 10 },
	{ Id = "Fluriflura", Name = "Fluriflura", ModelName = "Fluriflura", Rarity = "Common", Value = 10 },
	{ Id = "FrigoCamelo", Name = "Frigo Camelo", ModelName = "Frigo Camelo", Rarity = "Common", Value = 10 },
	{ Id = "LosOrcaleritosDicen", Name = "Los Orcaleritos", ModelName = "Los orcaleritos dicen", Rarity = "Common", Value = 10 },
	{ Id = "LosOrcaleritosDicenOrcala", Name = "Los Orcaleritos Orcala", ModelName = "los orcaleritos dicen orcala", Rarity = "Common", Value = 10 },
	{ Id = "MatTeo", Name = "Mat Teo", ModelName = "Mat_teo", Rarity = "Common", Value = 10 },
	{ Id = "PiPiWatermelon", Name = "Pi Pi Watermelon", ModelName = "Pi Pi Watermelon", Rarity = "Common", Value = 10 },
	{ Id = "PipiAvocado", Name = "Pipi Avocado", ModelName = "Pipi Avocado", Rarity = "Common", Value = 10 },
	{ Id = "PipiCorni", Name = "Pipi Corni", ModelName = "Pipi Corni", Rarity = "Common", Value = 10 },
	{ Id = "PipiKiwi", Name = "Pipi Kiwi", ModelName = "Pipi_Kiwi", Rarity = "Common", Value = 10 },
	{ Id = "PotHotspot", Name = "Pot Hotspot", ModelName = "Pot Hotspot", Rarity = "Common", Value = 10 },
	{ Id = "SigmaBoy", Name = "Sigma Boy", ModelName = "Sigma Boy", Rarity = "Common", Value = 10 },
	{ Id = "SpioniroGolubiro", Name = "Spioniro Golubiro", ModelName = "Spioniro Golubiro", Rarity = "Common", Value = 10 },
	{ Id = "StatutinoLibertino", Name = "Statutino Libertino", ModelName = "Statutino Libertino", Rarity = "Common", Value = 10 },
	{ Id = "StrawberrelliFlamingelli", Name = "Strawberrelli Flamingelli", ModelName = "Strawberrelli Flamingelli", Rarity = "Common", Value = 10 },
	{ Id = "SvininaBombardino", Name = "Svinina Bombardino", ModelName = "Svinina Bombardino", Rarity = "Common", Value = 10 },
	{ Id = "TaTaTaTaSahur", Name = "Ta Ta Ta Ta Sahur", ModelName = "Ta Ta Ta Ta Sahur", Rarity = "Common", Value = 10 },
	{ Id = "TalpaDiFero", Name = "Talpa Di Fero", ModelName = "Talpa Di Fero", Rarity = "Common", Value = 10 },
	{ Id = "TiTiTiSahur", Name = "Ti Ti Ti Sahur", ModelName = "Ti Ti Ti Sahur", Rarity = "Common", Value = 10 },
	{ Id = "TigriliniWatermelini", Name = "Tigrilini Watermelini", ModelName = "Tigrilini Watermelini", Rarity = "Common", Value = 10 },
	{ Id = "TrenostruzzoTurbo3000", Name = "Trenostruzzo Turbo 3000", ModelName = "Trenostruzzo_Turbo_3000", Rarity = "Common", Value = 10 },
	{ Id = "TricTracBaraboom", Name = "Tric Trac Baraboom", ModelName = "Tric_Trac_Baraboom", Rarity = "Common", Value = 10 },
	{ Id = "TukannoBananno", Name = "Tukanno Bananno", ModelName = "Tukanno Bananno", Rarity = "Common", Value = 10 },
	{ Id = "Udindindindin", Name = "Udindindindin", ModelName = "Udindindindin", Rarity = "Common", Value = 10 },
	{ Id = "UnclitoSamito", Name = "Unclito Samito", ModelName = "Unclito_Samito", Rarity = "Common", Value = 10 },

	-- Uncommon
	{ Id = "AgarriniLaPalini", Name = "Agarrini La Palini", ModelName = "Agarrini la Palini", Rarity = "Uncommon", Value = 25 },
	{ Id = "AvocadiniGuffo", Name = "Avocadini Guffo", ModelName = "Avocadini Guffo", Rarity = "Uncommon", Value = 25 },
	{ Id = "Avocadorilla", Name = "Avocadorilla", ModelName = "Avocadorilla", Rarity = "Uncommon", Value = 25 },
	{ Id = "BallerinoLololo", Name = "Ballerino Lololo", ModelName = "Ballerino Lololo", Rarity = "Uncommon", Value = 25 },
	{ Id = "BambiniCrostini", Name = "Bambini Crostini", ModelName = "Bambini_Crostini", Rarity = "Uncommon", Value = 25 },
	{ Id = "BananitaDolphinita", Name = "Bananita Dolphinita", ModelName = "Bananita Dolphinita", Rarity = "Uncommon", Value = 25 },
	{ Id = "BanditoBobritto", Name = "Bandito Bobritto", ModelName = "Bandito_Bobritto", Rarity = "Uncommon", Value = 25 },
	{ Id = "BlueberrinniOctopusini", Name = "Blueberrinni Octopusini", ModelName = "Blueberrinni_Octopusini", Rarity = "Uncommon", Value = 25 },
	{ Id = "CactoHipopotamo", Name = "Cacto Hipopotamo", ModelName = "Cacto Hipopotamo", Rarity = "Uncommon", Value = 25 },
	{ Id = "CavalloVirtuoso", Name = "Cavallo Virtuoso", ModelName = "Cavallo_Virtuoso", Rarity = "Uncommon", Value = 25 },
	{ Id = "ChefCrabracadabra", Name = "Chef Crabracadabra", ModelName = "Chef Crabracadabra", Rarity = "Uncommon", Value = 25 },
	{ Id = "ChicleteiraBicicleteira", Name = "Chicleteira Bicicleteira", ModelName = "Chicleteira Bicicleteira", Rarity = "Uncommon", Value = 25 },
	{ Id = "CocofantoElefanto", Name = "Cocofanto Elefanto", ModelName = "Cocofanto Elefanto", Rarity = "Uncommon", Value = 25 },
	{ Id = "CocosiniMama", Name = "Cocosini Mama", ModelName = "Cocosini Mama", Rarity = "Uncommon", Value = 25 },
	{ Id = "DragonCannelloni", Name = "Dragon Cannelloni", ModelName = "Dragon Cannelloni", Rarity = "Uncommon", Value = 25 },
	{ Id = "EspressoSignora", Name = "Espresso Signora", ModelName = "Espresso Signora", Rarity = "Uncommon", Value = 25 },
	{ Id = "GanganzelliTrulala", Name = "Ganganzelli Trulala", ModelName = "Ganganzelli Trulala", Rarity = "Uncommon", Value = 25 },
	{ Id = "GangsterFootera", Name = "Gangster Footera", ModelName = "Gangster Footera", Rarity = "Uncommon", Value = 25 },
	{ Id = "GaramaAndMadundung", Name = "Garama and Madundung", ModelName = "Garama_and_Madundung", Rarity = "Uncommon", Value = 25 },
	{ Id = "GattatinoNeonino", Name = "Gattatino Neonino", ModelName = "Gattatino Neonino", Rarity = "Uncommon", Value = 25 },
	{ Id = "GattatinoNyanino", Name = "Gattatino Nyanino", ModelName = "Gattatino_Nyanino", Rarity = "Uncommon", Value = 25 },
	{ Id = "LionelCactuseli", Name = "Lionel Cactuseli", ModelName = "Lionel_Cactuseli", Rarity = "Uncommon", Value = 25 },
	{ Id = "OdinDinDinDun", Name = "Odin Din Din Dun", ModelName = "Odin Din Din Dun", Rarity = "Uncommon", Value = 25 },
	{ Id = "OrangutiniAnanassini", Name = "Orangutini Ananassini", ModelName = "Orangutini Ananassini", Rarity = "Uncommon", Value = 25 },
	{ Id = "PandacciniBananini", Name = "Pandaccini Bananini", ModelName = "Pandaccini Bananini", Rarity = "Uncommon", Value = 25 },
	{ Id = "PenguinoCocosino", Name = "Penguino Cocosino", ModelName = "Penguino Cocosino", Rarity = "Uncommon", Value = 25 },
	{ Id = "PerochelloLemonchello", Name = "Perochello Lemonchello", ModelName = "Perochello_Lemonchello", Rarity = "Uncommon", Value = 25 },
	{ Id = "PiccioneMacchina", Name = "Piccione Macchina", ModelName = "Piccione Macchina", Rarity = "Uncommon", Value = 25 },
	{ Id = "RhinoToasterino", Name = "Rhino Toasterino", ModelName = "Rhino Toasterino", Rarity = "Uncommon", Value = 25 },
	{ Id = "SalaminoPenguino", Name = "Salamino Penguino", ModelName = "Salamino Penguino", Rarity = "Uncommon", Value = 25 },
	{ Id = "SammyniSpyderini", Name = "Sammyni Spyderini", ModelName = "Sammyni_Spyderini", Rarity = "Uncommon", Value = 25 },

	-- Rare
	{ Id = "BallerinaCappuccina", Name = "Ballerina Cappuccina", ModelName = "Ballerina Cappuccina", Rarity = "Rare", Value = 60 },
	{ Id = "BombombiniGusini", Name = "Bombombini Gusini", ModelName = "Bombombini Gusini", Rarity = "Rare", Value = 60 },
	{ Id = "BurbaloniLoliloli", Name = "Burbaloni Loliloli", ModelName = "Burbaloni Loliloli", Rarity = "Rare", Value = 60 },
	{ Id = "GorilloWatermelondrillo", Name = "Gorillo Watermelondrillo", ModelName = "Gorillo Watermelondrillo", Rarity = "Rare", Value = 60 },
	{ Id = "GraipussMedussi", Name = "Graipuss Medussi", ModelName = "Graipuss Medussi", Rarity = "Rare", Value = 60 },
	{ Id = "LaVaccaSaturnoSaturnita", Name = "La Vacca Saturno Saturnita", ModelName = "La_Vacca_Saturno_Saturnita", Rarity = "Rare", Value = 60 },
	{ Id = "LasTralaleritas", Name = "Las Tralaleritas", ModelName = "Las Tralaleritas", Rarity = "Rare", Value = 60 },
	{ Id = "LasVaquitasSaturnitas", Name = "Las Vaquitas Saturnitas", ModelName = "Las Vaquitas Saturnitas", Rarity = "Rare", Value = 60 },
	{ Id = "LosTralaleritos", Name = "Los Tralaleritos", ModelName = "Los Tralaleritos", Rarity = "Rare", Value = 60 },
	{ Id = "LosTungtungtungcitos", Name = "Los Tungtungtungcitos", ModelName = "Los Tungtungtungcitos", Rarity = "Rare", Value = 60 },
	{ Id = "NoobiniPizzanini", Name = "Noobini Pizzanini", ModelName = "Noobini Pizzanini", Rarity = "Rare", Value = 60 },
	{ Id = "NuclearoDinossauro", Name = "Nuclearo Dinossauro", ModelName = "Nuclearo Dinossauro", Rarity = "Rare", Value = 60 },
	{ Id = "OrcaleroOrcala", Name = "Orcalero Orcala", ModelName = "Orcalero Orcala", Rarity = "Rare", Value = 60 },
	{ Id = "TigroligreFrutonni", Name = "Tigroligre Frutonni", ModelName = "Tigroligre Frutonni", Rarity = "Rare", Value = 60 },
	{ Id = "TimCheese", Name = "Tim Cheese", ModelName = "Tim Cheese", Rarity = "Rare", Value = 60 },
	{ Id = "TorrtuginniDragonfrutini", Name = "Torrtuginni Dragonfrutini", ModelName = "Torrtuginni Dragonfrutini", Rarity = "Rare", Value = 60 },
	{ Id = "TrippiTroppi", Name = "Trippi Troppi", ModelName = "Trippi Troppi", Rarity = "Rare", Value = 60 },
	{ Id = "TrippiTroppiII", Name = "Trippi Troppi II", ModelName = "Trippi_Troppi", Rarity = "Rare", Value = 60 },
	{ Id = "TrulimeroTrulicina", Name = "Trulimero Trulicina", ModelName = "Trulimero Trulicina", Rarity = "Rare", Value = 60 },
	{ Id = "ZibraZubraZibralini", Name = "Zibra Zubra Zibralini", ModelName = "Zibra Zubra Zibralini", Rarity = "Rare", Value = 60 },

	-- Epic
	{ Id = "BonecaAmbalabu", Name = "Boneca Ambalabu", ModelName = "Boneca Ambalabu", Rarity = "Epic", Value = 150 },
	{ Id = "BrrBrrPatapim", Name = "Brr Brr Patapim", ModelName = "Brr Brr Patapim", Rarity = "Epic", Value = 150 },
	{ Id = "CappuccinoAssassino", Name = "Cappuccino Assassino", ModelName = "Cappuccino Assassino", Rarity = "Epic", Value = 150 },
	{ Id = "ChimpanziniBananini", Name = "Chimpanzini Bananini", ModelName = "Chimpanzini Bananini", Rarity = "Epic", Value = 150 },
	{ Id = "ChimpanziniSpiderini", Name = "Chimpanzini Spiderini", ModelName = "Chimpanzini Spiderini", Rarity = "Epic", Value = 150 },
	{ Id = "GirafaCelestre", Name = "Girafa Celestre", ModelName = "Girafa_Celestre", Rarity = "Epic", Value = 150 },
	{ Id = "GlorboFruttodrillo", Name = "Glorbo Fruttodrillo", ModelName = "Glorbo Fruttodrillo", Rarity = "Epic", Value = 150 },
	{ Id = "LaGrandeCombinasion", Name = "La Grande Combinasion", ModelName = "La_Grande_Combinasion", Rarity = "Epic", Value = 150 },
	{ Id = "LiriliLarila", Name = "Lirilì Larilà", ModelName = "Lirilì Larilà", Rarity = "Epic", Value = 150 },
	{ Id = "LosCombinasionas", Name = "Los Combinasionas", ModelName = "Los Combinasionas", Rarity = "Epic", Value = 150 },
	{ Id = "LosCrocodillitos", Name = "Los Crocodillitos", ModelName = "Los Crocodillitos", Rarity = "Epic", Value = 150 },
	{ Id = "TrippiTroppiTroppaTrippa", Name = "Trippi Troppi Troppa Trippa", ModelName = "Trippi Troppi Troppa Trippa", Rarity = "Epic", Value = 150 },
	{ Id = "TungTungTungSahur", Name = "Tung Tung Tung Sahur", ModelName = "Tung Tung Tung Sahur", Rarity = "Epic", Value = 150 },
	{ Id = "TungTungSahur", Name = "Tung Tung Sahur", ModelName = "TungTungSahur", Rarity = "Epic", Value = 150 },

	-- Legendary
	{ Id = "BombardiroCrocodilo", Name = "Bombardiro Crocodilo", ModelName = "Bombardiro Crocodilo", Rarity = "Legendary", Value = 400 },
	{ Id = "LosBonecaAmbalabusitosAmbalabuu", Name = "Los Boneca Ambalabusitos", ModelName = "Los Boneca_Ambalabusitos dicen AMBALABUU", Rarity = "Legendary", Value = 400 },
	{ Id = "LosGaramaAndMadungdungSitosGaramAndMadu", Name = "Los Garama and Madungdung Sitos", ModelName = "Los Garama_And_Madungdung Sitos dicen GARAM AND MADU", Rarity = "Legendary", Value = 400 },
	{ Id = "LosMateositosMateoo", Name = "Los Mateositos", ModelName = "Los Mateositos dicen MATEOO", Rarity = "Legendary", Value = 400 },
	{ Id = "LosMokelSitosMokell", Name = "Los Mokel Sitos", ModelName = "Los Mokel sitos dicen Mokell", Rarity = "Legendary", Value = 400 },
	{ Id = "LosPotHotspotsitosHotspott", Name = "Los Pot Hotspotsitos", ModelName = "Los Pot Hotspotsitos dicen HOTSPOTT", Rarity = "Legendary", Value = 400 },
	{ Id = "LosTaTaTasitosSahur", Name = "Los Ta Ta Tasitos", ModelName = "Los Ta ta Tasitos dicen Sahur", Rarity = "Legendary", Value = 400 },
	{ Id = "LosTungTungTungsitosSahur", Name = "Los Tung Tung Tungsitos", ModelName = "Los tung tung tungsitos dicen sahur", Rarity = "Legendary", Value = 400 },
	{ Id = "TralaleroTralala", Name = "Tralalero Tralala", ModelName = "Tralalero Tralala", Rarity = "Legendary", Value = 400 },

	-- Mythic
	{ Id = "LosBonecaAmbalabuDoubleBonecaa", Name = "Los Boneca Ambalabu Double", ModelName = "Los Boneca_AmbalabuDouble dicen BONECAA", Rarity = "Mythic", Value = 1000 },
	{ Id = "LosTungTungDoubleSahurr", Name = "Los Tung Tung Double", ModelName = "Los tung tungDouble Dicen sahurr", Rarity = "Mythic", Value = 1000 },
	{ Id = "MythicLuckyBlock", Name = "Mythic Lucky Block", ModelName = "Mythic Lucky Block", Rarity = "Mythic", Value = 1000 },

	-- Secret
	{ Id = "SecretLuckyBlock", Name = "Secret Lucky Block", ModelName = "Secret Lucky Block", Rarity = "Secret", Value = 5000 },
	{ Id = "BrainrotGodLuckyBlock", Name = "Brainrot God Lucky Block", ModelName = "Brainrot God Lucky Block", Rarity = "Secret", Value = 5000 },
}

BrainrotConfig.List = raw
BrainrotConfig.ById = {}
BrainrotConfig.ByRarity = {}

for _, entry in ipairs(raw) do
	BrainrotConfig.ById[entry.Id] = entry

	local bucket = BrainrotConfig.ByRarity[entry.Rarity]
	if not bucket then
		bucket = {}
		BrainrotConfig.ByRarity[entry.Rarity] = bucket
	end
	table.insert(bucket, entry)
end

return BrainrotConfig
