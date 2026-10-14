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
---@return string|number|nil file the class icon's texture file
---@return number fileWidth the file's width in pixels
---@return number fileHeight
---@return number[] coords left, right, top and bottom, as fractions of the file
function ClassIcon:Source(class)
	local atlas = self:Atlas(class)
	local info = atlas and C_Texture.GetAtlasInfo(atlas)
	local file = info and (info.file or info.filename)

	if file then
		local left, right = info.leftTexCoord, info.rightTexCoord
		local top, bottom = info.topTexCoord, info.bottomTexCoord
		local raw = info.rawSize
		local width, height = raw and raw.x or info.width, raw and raw.y or info.height

		if right > left and bottom > top then
			return file, width / (right - left), height / (bottom - top), { left, right, top, bottom }
		end
	end

	local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]

	if not coords then
		return nil, 0, 0, {}
	end

	return FALLBACK_FILE, FALLBACK_SIZE, FALLBACK_SIZE, coords
end

---Inline `|T` markup built from the atlas's file and coordinates: at size 0 it takes the text's height, where `|A`
---markup takes the atlas's own size.
---@param class string?
---@param size number? the icon's height and width in markup units, which are not font sizes; 0 or nil follows the
---text's height
---@return string markup an inline texture escape, or "" for an unknown class
function ClassIcon:Markup(class, size)
	local file, fileWidth, fileHeight, coords = self:Source(class)

	if not file then
		return ""
	end

	size = math.floor((size or 0) + 0.5)

	return ("|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d|t"):format(tostring(file), size, size, math.floor(fileWidth + 0.5),
		math.floor(fileHeight + 0.5), math.floor(coords[1] * fileWidth + 0.5), math.floor(coords[2] * fileWidth + 0.5),
		math.floor(coords[3] * fileHeight + 0.5), math.floor(coords[4] * fileHeight + 0.5))
end

---@return string? class the player's class file name, or nil while it is secret
function ClassIcon:PlayerClass()
	return LB:Readable(select(2, UnitClass("player")), nil)
end
