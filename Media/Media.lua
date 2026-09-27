local LB = select(2, ...)

local LSM = LibStub("LibSharedMedia-3.0")

local PATH = [[Interface\AddOns\Levelbound\Media\]]

---@class LBMedia
---@field LSM table
---@field registered boolean
local Media = {
	LSM = LSM,
	registered = false,
}
LB.Media = Media

Media.textures = {
	logo = PATH .. [[Levelbound.tga]],
	gainArrow = PATH .. [[Textures\GainArrowUp-White.tga]],
	markerDisc = PATH .. [[Textures\MarkerDisc-White.tga]],
	markerTriangle = PATH .. [[Textures\MarkerTriangle-White.tga]],
	markerDiamond = PATH .. [[Textures\MarkerDiamond-White.tga]],
}

Media.icons = {
	speaker = [[Interface\Common\VoiceChat-Speaker]],
}

Media.sounds = {
	levelUp = PATH .. [[Sounds\LevelUp.ogg]],
}

Media.markerShapes = {
	DOT = Media.textures.markerDisc,
	NOTCH = Media.textures.markerTriangle,
	DIAMOND = Media.textures.markerDiamond,
}

Media.outlines = {
	{ value = "NONE", label = NONE },
	{ value = "OUTLINE", label = LB.L["Outline"] },
	{ value = "THICKOUTLINE", label = LB.L["Thick Outline"] },
	{ value = "SLUG", label = LB.L["Slug"] },
	{ value = "SLUG_OUTLINE", label = LB.L["Slug Outline"] },
	{ value = "SLUG_THICKOUTLINE", label = LB.L["Slug Thick Outline"] },
}

local OUTLINE_FLAGS = {
	NONE = "",
	OUTLINE = "OUTLINE",
	THICKOUTLINE = "THICKOUTLINE",
	SLUG = "SLUG",
	SLUG_OUTLINE = "SLUG, OUTLINE",
	SLUG_THICKOUTLINE = "SLUG, THICKOUTLINE",
}

local fonts = {
	[LB.DEFAULT_FONT] = PATH .. [[Fonts\GilroyBold.ttf]],
}

local borders = {
	["Levelbound Thick"] = PATH .. [[Borders\ThickBorderWhite.tga]],
	["Levelbound Ring Medium"] = PATH .. [[Borders\RingBorderMediumWhite.tga]],
	["Levelbound Ring Thick"] = PATH .. [[Borders\RingBorderThickWhite.tga]],
	["Levelbound Forever"] = PATH .. [[Borders\ForeverBorderWhite.tga]],
	["Levelbound Metallic"] = PATH .. [[Borders\MetallicBorderWhite.tga]],
}

function Media:Register()
	if self.registered then
		return
	end

	for name, path in pairs(fonts) do
		LSM:Register(LSM.MediaType.FONT, name, path, LSM.LOCALE_BIT_western)
	end

	for name, path in pairs(borders) do
		LSM:Register(LSM.MediaType.BORDER, name, path)
	end

	self.registered = true
end

---@param mediaType string one of LibSharedMedia's media types
---@param name string
---@return string? path nil when the name is not registered
function Media:Fetch(mediaType, name)
	return LSM:Fetch(mediaType, name, true)
end

---@param mediaType string
---@return string[] names
function Media:List(mediaType)
	return LSM:List(mediaType) or {}
end

---@param mediaType string
---@param name string
---@return string? path the requested media, or LibSharedMedia's default for the type
function Media:FetchOrDefault(mediaType, name)
	return LSM:Fetch(mediaType, name)
end

---@param fontString FontString
---@param style LBFontStyle
function Media:SetFont(fontString, style)
	local path = self:FetchOrDefault("font", style.font)

	if path then
		fontString:SetFont(path, style.size, OUTLINE_FLAGS[style.outline] or "")
	end
end
