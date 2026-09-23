--[[
	Theme
	-----
	Visual constants for the whole UI: colors, gradients, fonts, radii.
]]

local Theme = {}

Theme.Font = Enum.Font.FredokaOne
Theme.BodyFont = Enum.Font.GothamBold

Theme.Colors = {
	Background = Color3.fromRGB(24, 26, 38),
	Panel = Color3.fromRGB(34, 37, 54),
	PanelLight = Color3.fromRGB(48, 52, 74),
	Cell = Color3.fromRGB(56, 60, 86),
	Text = Color3.fromRGB(255, 255, 255),
	SubText = Color3.fromRGB(180, 186, 210),
	Stroke = Color3.fromRGB(12, 12, 20),

	Green = Color3.fromRGB(70, 214, 110),
	Blue = Color3.fromRGB(64, 156, 255),
	Purple = Color3.fromRGB(166, 92, 255),
	Pink = Color3.fromRGB(255, 84, 160),
	Orange = Color3.fromRGB(255, 160, 40),
	Yellow = Color3.fromRGB(255, 205, 40),
	Red = Color3.fromRGB(240, 70, 80),
	Gray = Color3.fromRGB(110, 115, 140),
	Cash = Color3.fromRGB(110, 255, 140),
}

Theme.CornerRadius = UDim.new(0, 14)
Theme.SmallCorner = UDim.new(0, 10)

return Theme
