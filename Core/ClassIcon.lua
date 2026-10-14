local LB = select(2, ...)

local FALLBACK_FILE = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local FALLBACK_SIZE = 256

---Class icons by class file name (`"WARRIOR"`): Blizzard's `classicon-` atlas, or the character-creation class
---sheet where the client lacks that atlas.
---@class LBClassIcon
---@field atlases table<string, string|false> the checked atlas per class, false where the client lacks it
local ClassIcon = {
	atlases = {},
}
LB.ClassIcon = ClassIcon

---@param class string?
---@return string? atlas the class's atlas, or nil where the client lacks it
function ClassIcon:Atlas(class)
	if type(class) ~= "string" or class == "" then
		return nil
	end

	local atlas = self.atlases[class]

	if atlas == nil then
		atlas = GetClassAtlas and GetClassAtlas(class) or ("classicon-%s"):format(class:lower())

		if not (C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)) then
			atlas = false
		end

		self.atlases[class] = atlas
	end

	return atlas or nil
end

---@param class string?
---@param size number? the icon's height and width; 0 or nil follows the text's height
---@return string markup an inline texture escape, or "" for an unknown class
function ClassIcon:Markup(class, size)
	size = size or 0

	local atlas = self:Atlas(class)

	if atlas then
		return CreateAtlasMarkup(atlas, size, size)
	end

	local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]

	if not coords then
		return ""
	end

	return CreateTextureMarkup(FALLBACK_FILE, FALLBACK_SIZE, FALLBACK_SIZE, size, size, coords[1], coords[2], coords[3],
		coords[4])
end

---@return string? class the player's class file name, or nil while it is secret
function ClassIcon:PlayerClass()
	return LB:Readable(select(2, UnitClass("player")), nil)
end
