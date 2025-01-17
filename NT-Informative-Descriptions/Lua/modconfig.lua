-- Config to enable language files based on enabled mods.

local config = {
	{
		--Neurotrauma guns fork
		supportedlanguages = {"English","Simplified Chinese","Russian"}, -- which languages patch supports for this specific mod {"English","German","Russian"} etc
		IgnoreTargetModState = false, -- doesnt check for target mod being enabled. Still respects supported languages.
		workshopId = "3190189044", -- id of the mod being patched and which language files we disable, "" means nothing gets disabled
		loadpriority = 0, -- patches with higher priotiry would override ones with lower when enabled. works similiar to game modlist
		files = {	-- path to language files we want to use instead of originals, %Language% is automatically replaced with client language
			"%ModDir%/Localization/%Language%/Items.xml", -- if files is empty (files = {}) then it would just disable mod language files
			"%ModDir%/Localization/%Language%/Afflictions.xml"
			}
	},

	
	{
		-- Curly's Surgery Plus (not yet ready)
		supportedlanguages = {"English","Simplified Chinese","Russian"},
		IgnoreTargetModState = false,
		workshopId = "",
		loadpriority = 1,
		files = {
			--"%ModDir%/Localization/%Language%/SurgeryPlus.xml"
			}
	},
	
	{
		-- Cybernetics
		supportedlanguages = {"English","Russian"},
		IgnoreTargetModState = false,
		workshopId = "2788543375",
		loadpriority = 0,
		files = {"%ModDir%/Localization/%Language%/Cybernetics.xml"}
	},
	
	{
		-- Cybernetics Improved
		supportedlanguages = {"English"},
		IgnoreTargetModState = false,
		workshopId = "2963474291",
		loadpriority = 0,
		files = {"%ModDir%/Localization/%Language%/Cybernetics.xml"}
	},

	{
		-- Cybernetics Enhanced
		supportedlanguages = {"English","Russian"},
		IgnoreTargetModState = false,
		workshopId = "3324062208",
		loadpriority = 0,
		files = {"%ModDir%/Localization/%Language%/Cybernetics.xml"}
	},

	{
		-- Immersive Repairs NT Cybernetics
		supportedlanguages = {"English"},
		IgnoreTargetModState = false,
		workshopId = "3153498101",
		loadpriority = 0,
		files = {"%ModDir%/Localization/%Language%/ImmersiveRepairs.xml"}
	}
	-- Example blank, you dont need to add localization for this
	-- {
	-- 	supportedlanguages = {"English"},
	-- 	IgnoreTargetModState = false,
	-- 	workshopId = "", -- if empty doesnt announce patch being enabled or check for other mods 
	-- 	loadpriority = 1, -- patches with same priority would load in random order
	-- 	files = {
	-- 		"%ModDir%/Localization/%Language%/dummy.xml"
	-- 		} 
	-- }
}

return config
