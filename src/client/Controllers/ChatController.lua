--[[
	ChatController
	--------------
	Gold [VIP] chat tag for VIP pass owners (TextChatService).
	The server sets a "VIP" attribute on the Player after verifying the pass,
	so tags can't be faked by editing local data.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local ChatController = {}

function ChatController.Init() end

function ChatController.Start()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return
	end
	local color = Config.VIP.ChatTagColor
	local hex = string.format("#%02X%02X%02X", color.R * 255, color.G * 255, color.B * 255)

	TextChatService.OnIncomingMessage = function(message)
		local properties = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		if source then
			local player = Players:GetPlayerByUserId(source.UserId)
			if player and player:GetAttribute("VIP") then
				properties.PrefixText = ("<font color='%s'>[👑 VIP]</font> %s"):format(hex, message.PrefixText)
			end
		end
		return properties
	end
end

return ChatController
