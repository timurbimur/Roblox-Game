-- The full roster of brainrots. Add/remove/rename entries freely -- Id must stay
-- unique and stable (it's used as the save-data key and the model lookup name in
-- ServerStorage.Assets.Models). Names below are original placeholders; swap in
-- whatever brainrot characters you want the game to use.

local BrainrotConfig = {}

local raw = {
	-- Common
	{ Id = "SplashiniToosti", Name = "Splashini Toosti", Rarity = "Common", Value = 10 },
	{ Id = "BimboCalzoni", Name = "Bimbo Calzoni", Rarity = "Common", Value = 10 },
	{ Id = "NanoSpagoni", Name = "Nano Spagoni", Rarity = "Common", Value = 10 },
	{ Id = "RuffinoPastavia", Name = "Ruffino Pastavia", Rarity = "Common", Value = 10 },

	-- Uncommon
	{ Id = "VoltinoMozzarel", Name = "Voltino Mozzarel", Rarity = "Uncommon", Value = 25 },
	{ Id = "TrombettoSalami", Name = "Trombetto Salami", Rarity = "Uncommon", Value = 25 },
	{ Id = "ZiggoPistacchio", Name = "Ziggo Pistacchio", Rarity = "Uncommon", Value = 25 },
	{ Id = "CannoloZippers", Name = "Cannolo Zippers", Rarity = "Uncommon", Value = 25 },

	-- Rare
	{ Id = "LampardoVintaggio", Name = "Lampardo Vintaggio", Rarity = "Rare", Value = 60 },
	{ Id = "ScarpinoTurbolenzo", Name = "Scarpino Turbolenzo", Rarity = "Rare", Value = 60 },
	{ Id = "RavelloSprintone", Name = "Ravello Sprintone", Rarity = "Rare", Value = 60 },
	{ Id = "QuackoFormaggino", Name = "Quacko Formaggino", Rarity = "Rare", Value = 60 },

	-- Epic
	{ Id = "FulminoGorgonzola", Name = "Fulmino Gorgonzola", Rarity = "Epic", Value = 150 },
	{ Id = "SerpettoMarina", Name = "Serpetto Marina", Rarity = "Epic", Value = 150 },
	{ Id = "BazzarroLimoncello", Name = "Bazzarro Limoncello", Rarity = "Epic", Value = 150 },
	{ Id = "TrattoriaVoltrex", Name = "Trattoria Voltrex", Rarity = "Epic", Value = 150 },

	-- Legendary
	{ Id = "ColosseoDraghino", Name = "Colosseo Draghino", Rarity = "Legendary", Value = 400 },
	{ Id = "VespamentoFurioso", Name = "Vespamento Furioso", Rarity = "Legendary", Value = 400 },
	{ Id = "PalazzoInfernale", Name = "Palazzo Infernale", Rarity = "Legendary", Value = 400 },
	{ Id = "ObeliskoMarmorino", Name = "Obelisko Marmorino", Rarity = "Legendary", Value = 400 },

	-- Mythic
	{ Id = "TitanicoVesuvione", Name = "Titanico Vesuvione", Rarity = "Mythic", Value = 1000 },
	{ Id = "LeviatanoPompeiano", Name = "Leviatano Pompeiano", Rarity = "Mythic", Value = 1000 },
	{ Id = "ImperatoreVulcanico", Name = "Imperatore Vulcanico", Rarity = "Mythic", Value = 1000 },
	{ Id = "DraghezzaEtnea", Name = "Draghezza Etnea", Rarity = "Mythic", Value = 1000 },

	-- Secret
	{ Id = "AnticoSegreto", Name = "L'Antico Segreto", Rarity = "Secret", Value = 5000 },
	{ Id = "FantasmaDorato", Name = "Fantasma Dorato", Rarity = "Secret", Value = 5000 },
	{ Id = "OracoloNascosto", Name = "Oracolo Nascosto", Rarity = "Secret", Value = 5000 },
	{ Id = "IlCustodeEterno", Name = "Il Custode Eterno", Rarity = "Secret", Value = 5000 },
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
