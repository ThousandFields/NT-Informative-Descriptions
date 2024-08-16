NTID = {}
NTID.Name="Informative Descriptions"
NTID.Version = "1.6"
NTID.Path = table.pack(...)[1]
Timer.Wait(function() if NTC ~= nil and NTC.RegisterExpansion ~= nil then NTC.RegisterExpansion(NTID) end end,1)


--In case neurotrauma doesnt actually register NTC or NT on CLIENTs for MP, gonna bruteforce
NTworkshopIds = {
    "3190189044",
    "2776270649"
}


function IsNTEnabled()
    for package in ContentPackageManager.EnabledPackages.All do
        for NTworkshopId in NTworkshopIds do
            if tostring(package.UgcId) == NTworkshopId then
                return true
            end
        end
    end
    return false
end


-- if CLIENT or not Game.IsMultiplayer then
--     Timer.Wait(function()
--         if NTC ~= nil or NT ~= nil or IsNTEnabled() then
--             dofile(NTID.Path .. '/Lua/main.lua')
--             return
--         end
--         print("Error loading NT Informative Descriptions: it appears that Neurotrauma isn't enabled!")
--   end,1)
-- end


-- if CLIENT and Game.IsSubEditor then
--   Timer.Wait(function()
--     if NTC ~= nil or NT ~= nil or IsNTEnabled() then
--         LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.SubEditorScreen"], "UpdateEntityList")
--         Game.SubEditorScreen.UpdateEntityList()
--         return
--     end
--   end,1000)
-- end


if CLIENT or not Game.IsMultiplayer then
    if NTC ~= nil or NT ~= nil or IsNTEnabled() then
        dofile(NTID.Path .. '/Lua/main.lua')
        if Game.IsSubEditor then
            LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.SubEditorScreen"], "UpdateEntityList")
            Game.SubEditorScreen.UpdateEntityList()
        end
        return
    end
    Timer.Wait(function()
        print("Error loading NT Informative Descriptions: it appears Neurotrauma isn't loaded!")
    end,1)
end
