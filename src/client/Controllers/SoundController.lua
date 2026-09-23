--[[
	SoundController
	---------------
	Local-only sound playback. Named sounds come from Config.Sounds.
	  SoundController.Play("Click")
	  SoundController.PlayAt("DumpsterOpen", part)   -- 3D positional
	Respects the player's SFX setting.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local State = require(script.Parent.Parent.Lib.State)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local SoundController = {}

local sounds = {}

local function sfxEnabled()
	local settings = State.Get("Settings")
	return not settings or settings.SFX ~= false
end

function SoundController.Play(name, volume, pitch)
	local sound = sounds[name]
	if not sound or not sfxEnabled() then
		return
	end
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = pitch or 1
	SoundService:PlayLocalSound(sound)
end

function SoundController.PlayAt(name, parent, volume)
	local id = Config.Sounds[name]
	if not id or not sfxEnabled() or not parent then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.6
	sound.RollOffMaxDistance = 80
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 4)
end

function SoundController.Init()
	for name, id in pairs(Config.Sounds) do
		local sound = Instance.new("Sound")
		sound.Name = "DFS_" .. name
		sound.SoundId = id
		sound.Parent = SoundService
		sounds[name] = sound
	end
	UIKit.ClickSound = function()
		SoundController.Play("Click", 0.35, 1.2)
	end
end

function SoundController.Start()
	if Config.MusicId == "" then
		return
	end
	local music = Instance.new("Sound")
	music.Name = "DFS_Music"
	music.SoundId = Config.MusicId
	music.Looped = true
	music.Volume = 0.25
	music.Parent = SoundService
	State.Watch("Settings", function(settings)
		local enabled = not settings or settings.Music ~= false
		if enabled and not music.IsPlaying then
			music:Play()
		elseif not enabled and music.IsPlaying then
			music:Pause()
		end
	end)
end

return SoundController
