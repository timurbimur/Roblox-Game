--[[
	SettingsPanel
	-------------
	Toggle settings saved on the server (data.Settings):
	  SFX, Music, Auto Sell, Auto Collect, Rare Announcements, Low Graphics
]]

local ClientRoot = script.Parent.Parent
local UIKit = require(ClientRoot.UI.UIKit)
local Theme = require(ClientRoot.UI.Theme)
local State = require(ClientRoot.Lib.State)
local Net = require(ClientRoot.Lib.Net)

local SettingsPanel = {}

local window
local toggles = {}

local SETTINGS = {
	{ Key = "SFX", Name = "🔊 Sound Effects", Description = "Clicks, dumpsters, fusions" },
	{ Key = "Music", Name = "🎵 Music", Description = "Background music (set Config.MusicId)" },
	{ Key = "AutoSell", Name = "💸 Auto Sell", Description = "Needs the Auto Sell upgrade or pass" },
	{ Key = "AutoCollect", Name = "🤖 Auto Collect", Description = "Needs the Auto Collect upgrade" },
	{ Key = "Announcements", Name = "📢 Rare Find Banners", Description = "Show other players' rare finds" },
	{ Key = "LowGraphics", Name = "📉 Low Graphics", Description = "Fewer particles for slower devices" },
}

local function refresh()
	local settings = State.Get("Settings")
	if not settings then
		return
	end
	for key, button in pairs(toggles) do
		local on = settings[key] == true
		button.Label.Text = on and "ON" or "OFF"
		button:SetAttribute("Disabled", not on)
	end
end

function SettingsPanel.Init(controllers)
	local content
	window, content = UIKit.Window({
		Name = "SettingsWindow",
		Title = "Settings",
		Icon = "⚙️",
		Color = Theme.Colors.Gray,
		MaxSize = Vector2.new(620, 560),
		Parent = controllers.UIController.Root,
		OnClose = function()
			controllers.UIController.Close()
		end,
	})
	local list = UIKit.ScrollList({ Size = UDim2.fromScale(1, 1), Parent = content })
	for index, setting in ipairs(SETTINGS) do
		local card = UIKit.Card({ Size = UDim2.new(1, 0, 0, 66), LayoutOrder = index, Parent = list })
		UIKit.Label({ Text = setting.Name, Size = UDim2.new(0.65, 0, 0, 30), Position = UDim2.fromOffset(12, 5), TextXAlignment = Enum.TextXAlignment.Left, Parent = card }, 22)
		UIKit.Label({ Text = setting.Description, Size = UDim2.new(0.65, 0, 0, 20), Position = UDim2.fromOffset(12, 38), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.Colors.SubText, Font = Theme.BodyFont, Stroke = false, Parent = card }, 14)
		local button = UIKit.Button({
			Text = "ON",
			Color = Theme.Colors.Green,
			Size = UDim2.new(0.25, 0, 0, 46),
			Position = UDim2.new(1, -12, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Parent = card,
		})
		-- Handle clicks directly: the "Disabled" look doubles as the OFF state.
		button.Activated:Connect(function()
			local settings = State.Get("Settings")
			if settings then
				Net.RequestAsync("SetSetting", { Key = setting.Key, Value = not settings[setting.Key] })
			end
		end)
		toggles[setting.Key] = button
	end
	controllers.UIController.RegisterPanel("Settings", { Window = window, OnOpen = refresh })
end

function SettingsPanel.Start()
	State.Watch("Settings", refresh)
end

return SettingsPanel
