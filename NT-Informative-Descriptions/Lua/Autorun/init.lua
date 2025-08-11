NTID = {}
NTID.Name="Informative Descriptions"
NTID.Version = "1.17"
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



function EnableNTID()
    if NTC ~= nil or NT ~= nil or IsNTEnabled() then
        dofile(NTID.Path .. '/Lua/main.lua')
        -- Calling UpdateEntityList in short timer crashes subeditor with too many mods
        if CLIENT and Game.IsSubEditor then
            Timer.Wait(function()
                LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.SubEditorScreen"], "UpdateEntityList")
                Game.SubEditorScreen.UpdateEntityList()
            end, 5000)
        end
        return true
    end
    return false
end



-- longer timer fallback in case NT isnt registered yet on first lua pass
if EnableNTID() then
    return
end

Timer.Wait(function()
    if EnableNTID() then
        return
    end
    print("Error loading NT Informative Descriptions: it appears Neurotrauma isn't loaded!")
end,1000)
