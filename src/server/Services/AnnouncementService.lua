--[[
	AnnouncementService
	-------------------
	Server -> client messaging:
	  * Toast(player, text, kind)      small notification for one player
	  * AnnounceFind(player, itemId)   server-wide banner for Legendary+ finds
	  * Broadcast(text, color)         server-wide banner/system message
	  * Rotating server tips every few minutes

	Announcements are throttled so a lucky streak can't spam every client.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local AnnouncementService = {}

local ANNOUNCE_COOLDOWN = 1.5 -- seconds between banners per player
local TIP_INTERVAL = 240

local lastAnnounce = setmetatable({}, { __mode = "k" }) -- weak keys: no leaks

local TIPS = {
	"💡 Fuse two items at the Fusion Machine to discover brand new junk!",
	"💡 Favorite your best items with the ⭐ button so they can never be sold.",
	"💡 Each zone has better dumpsters. Unlock them from the gates or the Shop!",
	"💡 Log in every day — Day 7 gives an exclusive Mythic item!",
	"💡 Luck upgrades make Legendary, Mythic and Secret items far more common.",
	"💡 Check your Quests for free boosts and cash.",
}

function AnnouncementService.Toast(player, text, kind)
	Remotes.Signal:FireClient(player, "Toast", { Text = text, Kind = kind or "Info" })
end

function AnnouncementService.AnnounceFind(player, itemId, isNew)
	local now = os.clock()
	if lastAnnounce[player] and now - lastAnnounce[player] < ANNOUNCE_COOLDOWN then
		return
	end
	lastAnnounce[player] = now
	Remotes.Signal:FireAllClients("Announce", {
		PlayerName = player.DisplayName,
		UserId = player.UserId,
		ItemId = itemId,
		IsNew = isNew,
	})
end

function AnnouncementService.Broadcast(text, colorHex)
	Remotes.Signal:FireAllClients("Broadcast", { Text = text, Color = colorHex })
end

function AnnouncementService.Init() end

function AnnouncementService.Start()
	task.spawn(function()
		local index = 0
		while true do
			task.wait(TIP_INTERVAL)
			index = index % #TIPS + 1
			Remotes.Signal:FireAllClients("Tip", { Text = TIPS[index] })
		end
	end)
end

return AnnouncementService
