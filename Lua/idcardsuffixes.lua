-- getting this from different text files from disabled languages is exorbitantly complicated in lua due to billion different types i have to register.
-- so fuck it just manual table
local suffixes = {
	English = "A ‖color:gui.blue‖printed donor card‖end‖ can be slotted into it.",
	Russian = "Можно вставить ‖color:gui.blue‖карту донора‖end‖ в слот.",
	["Simplified Chinese"] = "可以插入一张‖color:gui.blue‖打印的捐赠卡‖end‖。"
}

return suffixes
