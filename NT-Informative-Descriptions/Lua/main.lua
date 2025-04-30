InfDescriptions = {}

local rawconfig = require("rawconfig")

config = {
    Name = "infdescriptions", --Internal name, used for rawconfig.Configs.Name
    Label = "infdescriptions.modname", --String displayed in menus, can be localization tag
    Entries = {
        Enabled = {
            name = "infdescriptions.cfg.enabled", --String displayed in menus, can be localization tag
            default = true,
            type = "bool",
            description = "infdescriptions.cfg.enableddescription", --String displayed in tooltip, can be localization tag
            enforcment = rawconfig.Enforcment.Client,
        },
        Shared = {
            name = "infdescriptions.cfg.shared", --String displayed in menus, can be localization tag
            default = true,
            type = "bool",
            description = "infdescriptions.cfg.shareddescription", --String displayed in tooltip, can be localization tag
            enforcment = rawconfig.Enforcment.Server,
        },
    },
}


config = rawconfig.addConfig(config)
config:LoadConfig()

local pkg

for package in ContentPackageManager.EnabledPackages.All do
    local path = string.gsub(tostring(package.Dir),"\\","/")
    if path == NTID.Path then
        pkg = package
        break
    end
end


if SERVER and CSActive then

    LuaUserData.RegisterType("System.Collections.Immutable.ImmutableArray`1[[Barotrauma.ContentPackage,DedicatedServer]]")
    LuaUserData.RegisterType("System.Collections.Immutable.ImmutableArray`1+Builder[[Barotrauma.ContentPackage,DedicatedServer]]")

    BindingFlags = LuaUserData.CreateEnumTable("System.Reflection.BindingFlags")

    LuaUserData.RegisterType("System.Type")
    LuaUserData.RegisterType("System.Reflection.FieldInfo")

    LuaUserData.RegisterType("Barotrauma.Networking.ModSender")
    ModSender = LuaUserData.CreateStatic('Barotrauma.Networking.ModSender')
    LuaUserData.RegisterType("Barotrauma.SaveUtil")
    SaveUtil = LuaUserData.CreateStatic('Barotrauma.SaveUtil')
    LuaUserData.RegisterType("Barotrauma.Steam.SteamManager")
    SteamManager = LuaUserData.CreateStatic('Barotrauma.Steam.SteamManager')
    LuaUserData.RegisterType("Steamworks.SteamServer")
    SteamServer = LuaUserData.CreateStatic('Steamworks.SteamServer')

    LuaUserData.RegisterType("Barotrauma.Networking.ServerPeer`1")
    LuaUserData.RegisterType("Barotrauma.Networking.LidgrenServerPeer")
    LuaUserData.RegisterType("Barotrauma.Networking.P2PServerPeer")


    HasMultiplayerSyncedContent_fieldinfo = LuaUserData.GetType('Barotrauma.ContentPackage').GetField("<HasMultiplayerSyncedContent>k__BackingField", bit32.bor(BindingFlags.Instance, BindingFlags.NonPublic))

    if Game.IsDedicated then
        contentPackages_fieldinfo = LuaUserData.GetType('Barotrauma.Networking.LidgrenServerPeer').BaseType.GetField("contentPackages", bit32.bor(BindingFlags.Instance, BindingFlags.NonPublic))
    else
        contentPackages_fieldinfo = LuaUserData.GetType('Barotrauma.Networking.P2PServerPeer').BaseType.GetField("contentPackages", bit32.bor(BindingFlags.Instance, BindingFlags.NonPublic))
    end

    function InfDescriptions.AddToPublicModlist()
        HasMultiplayerSyncedContent_fieldinfo.SetValue(pkg, true)
        
        --Game.Server.ModSender.CompressMod(pkg)
        SaveUtil.CompressDirectory(pkg.Dir, ModSender.GetCompressedModPath(pkg))

        

        contentpackagestmp = contentPackages_fieldinfo.GetValue(Game.Server.serverPeer).ToBuilder()

        contentpackagestmp.Add(pkg)

        contentPackages_fieldinfo.SetValue(Game.Server.serverPeer, contentpackagestmp.ToImmutable())

        SteamServer.ClearKeys()

        SteamManager.RefreshServerDetails(Game.Server)
    end

    function InfDescriptions.RemoveFromPublicModlist()

        HasMultiplayerSyncedContent_fieldinfo.SetValue(pkg, false)

        SaveUtil.DeleteIfExists(ModSender.GetCompressedModPath(pkg))

        contentpackagestmp = contentPackages_fieldinfo.GetValue(Game.Server.serverPeer).ToBuilder()

        contentpackagestmp.Remove(pkg)

        contentPackages_fieldinfo.SetValue(Game.Server.serverPeer, contentpackagestmp.ToImmutable())

        SteamServer.ClearKeys()

        SteamManager.RefreshServerDetails(Game.Server)
    end
end

config.SaveConfig = function()
    if CLIENT then
        if config:Get("Enabled",true) then
            EnableNTID()
        else
            DisableNTID()
        end
    end

    if SERVER then
        if config:Get("Shared",false) and not pkg.HasMultiplayerSyncedContent then
            InfDescriptions.AddToPublicModlist()
        elseif config:Get("Shared",false) == false and pkg.HasMultiplayerSyncedContent then
            InfDescriptions.RemoveFromPublicModlist()
        end
    end

    rawconfig.util.SaveConfig(config)
end

if SERVER then return end
local modconfig = require("modconfig")
local idcardsuffixes = require("idcardsuffixes")
local TextFile = LuaUserData.CreateStatic("Barotrauma.TextFile", true)

local FileList = {}

LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.GameSettings"], "currentConfig")
local ClientLanguage = tostring(GameSettings.currentConfig.Language)
local prev_language = ClientLanguage

LuaUserData.MakeFieldAccessible(Descriptors['Barotrauma.ContentPackageManager+EnabledPackages'], 'regular')
LuaUserData.MakeMethodAccessible(Descriptors['Barotrauma.ContentPackageManager+EnabledPackages'], 'SortContent')
LuaUserData.RegisterType("System.Collections.Generic.List`1[[Barotrauma.RegularPackage,Barotrauma]]")


function EnableTextFile(file, workshopId)
    local targetPackage
    local targetFile

    if workshopId == nil then
        targetPackage = pkg
    else
        for package in ContentPackageManager.AllPackages do
            if tostring(package.UgcId) == workshopId then
                targetPackage = package
                break
            end
        end
    end

    if targetPackage == nil then
        print("Could not find package to enable with workshop id ", workshopId)
        return false
    end

    if File.Exists(targetPackage.Dir .. "/" .. file) == false then
        print("Could not find file " .. file .. " in " .. targetPackage.name)
        return false
    end
    targetFile = TextFile(targetPackage, ContentPath.FromRaw(targetPackage, targetPackage.Dir .. "/" .. file))

    if targetFile == nil then
        print("Could not find file " .. file .. " in " .. targetPackage.name)
        return false
    end

    targetFile.LoadFile()
    table.insert(FileList, targetFile)

    --print("Enabled " .. targetFile.Path.Value .. " in package ", targetPackage.name)
    --print(targetFile.ContentPackage.Name)

    return true
end

function EnableTextFiles(files, language)
    if not language then language = ClientLanguage end
    for file in files do
        file = StripModDir(file)
        file = string.gsub(file, "%%Language%%", language)
        if not EnableTextFile(file) then
            return false
        end
    end
    return true
end

function DisableTextPackage(workshopId, language)
    local targetPackage
    local languageTrimmed = string.sub(language, 2) .. ".xml"
    for package in ContentPackageManager.EnabledPackages.All do
        if tostring(package.UgcId) == workshopId then
            targetPackage = package
            break
        end
    end

    if targetPackage == nil then
        print("Could not find package to disable with workshop id ", workshopId)
        return
    end

    for file in targetPackage.Files do
        if LuaUserData.IsTargetType(file, "Barotrauma.TextFile") and string.endsWith(file.Path.Value, languageTrimmed) then
            file.UnloadFile()
            --print("Disabled " .. file.Path.Value .. " in package ", workshopId)
            break
        end
    end
end

function ClientHasSupportedLanguage(supportedlanguages)
    local value = false
    for language in supportedlanguages do
        if language == ClientLanguage then
            value = true
            break
        end
    end
    return value
end

function IsModEnabled(workshopId)
    local value = false
    if workshopId == nil or workshopId == "" then
        return false
    end
    for package in ContentPackageManager.EnabledPackages.All do
        if tostring(package.UgcId) == workshopId then
            value = true
            break
        end
    end
    return value
end

function IsFirstHigherPriority(a, b)
    if a.loadpriority > b.loadpriority then
        return true
    else
        return false
    end
end

function GetPackageByName(name)
    for package in ContentPackageManager.EnabledPackages.All do
        if package.Name == name then
            return package
        end
    end

    return nil
end

function GetPackageById(id)
    for package in ContentPackageManager.EnabledPackages.All do
        if tostring(package.UgcId) == id then
            return package
        end
    end
end

function LoadPatches()
    table.sort(modconfig, IsFirstHigherPriority)

    for _, patch in pairs(modconfig) do
        local files = {}
        local modname = ""

        if patch.IgnoreTargetModState or IsModEnabled(patch.workshopId) then
            for language in patch.supportedlanguages do
                --DisableTextPackage(patch.workshopId, language)
                modname = GetPackageById(patch.workshopId).name

                if not EnableTextFiles(patch.files, language) then
                    print("Errors enabling NTID files")
                    break
                end
            end
        end
    end

    --For whatever reason content specific Sort isnt static method and i dont want to be sorting all the content in game
    --ContentPackageManager.EnabledPackages.SortContent()
    if FileList[1] then FileList[1].Sort() end
end

function StripModDir(filepath)
    local div = string.find(filepath, "%%[/\\]" )
    if div == nil then
        filepath = filepath
    else
        --moddir = string.sub(filepath, 1, div)
        filepath = string.sub(filepath, div+2)
    end
    return filepath
end

function UnloadPatches()
    for file in FileList  do
        --print("Unloading ", file.Path.Value)
        file.UnloadFile()
    end
    FileList = {}
end

function ReloadModsLocalization()
    for package in ContentPackageManager.EnabledPackages.All do
        for _, patch in pairs(modconfig) do
            if tostring(package.UgcId) == patch.workshopId then
                for file in package.Files do
                    if LuaUserData.IsTargetType(file, "Barotrauma.TextFile") then
                        file.LoadFile()
                        --print("Reenabled " .. file.Path.Value .. " in package ", workshopId)
                    end
                end
                break
            end
        end
    end
end


function AppendIdcard(instance, spawnPoint, character)
    if spawnPoint ~= nil and spawnPoint.IdCardDesc ~= nil then
        if string.find(spawnPoint.IdCardDesc, "%S") then
            obj = instance.item
            obj.Description = obj.Description .. " " .. idcardsuffixes[ClientLanguage]
        end
    end
end


function UpdateIdCards()
    -- retuns empty string if unsupported localization
    local idcard_suffix = idcardsuffixes[ClientLanguage]
    if idcard_suffix == nil or idcard_suffix == "" then
        return
    end

    -- characterInfos = Game.GameSession.CrewManager.characterInfos

    -- for info in characterInfos do 
    --     print(info.Name)
    -- end

    -- mainSubSpawnPoints = WayPoint.SelectCrewSpawnPoints(characterInfos, Submarine.MainSub)

    for item in Item.ItemList do
        if item.Prefab.Identifier.Value == "idcard" then
            OriginalDescription = TextManager.Get("EntityDescription." .. item.Prefab.Identifier.Value)
            if item.Description ~= OriginalDescription then
                item.Description = tostring(item.Description) .. " " .. idcard_suffix
            end
        end
    end
end


function CleanUpIdCards()
    local description
    for item in Item.ItemList do
        if item.Prefab.Identifier.Value == "idcard" then
            OriginalDescription = TextManager.Get("EntityDescription." .. item.Prefab.Identifier.Value)
            if item.Description ~= OriginalDescription then
                description = tostring(item.Description)
                for suffix in idcardsuffixes do
                    description = string.gsub(description, " " .. suffix, "")
                end
                item.Description = description
            end
        end
    end

end

function LanguageChanged()
    ClientLanguage = tostring(GameSettings.currentConfig.Language)
    if ClientLanguage ~= prev_language then
        prev_language = ClientLanguage
        return true
    end
    return false
end

function ReloadNTID()
    if pkg == nil then
        print("Package not found.")
        return
    end

    UnloadPatches()

    ClientLanguage = tostring(GameSettings.currentConfig.Language)
    modconfig = {}
    modconfig = dofile(NTID.Path .. "/Lua/modconfig.lua")
    LoadPatches()
    CleanUpIdCards()
    UpdateIdCards()
end

function ReloadIdCards()
    CleanUpIdCards()
    UpdateIdCards()
end


function EnableNTID()
    if pkg == nil then
        print("Package not found.")
        return
    end

    ClientLanguage = tostring(GameSettings.currentConfig.Language)
    modconfig = {}
    modconfig = dofile(NTID.Path .. "/Lua/modconfig.lua")
    LoadPatches()
    CleanUpIdCards()
    UpdateIdCards()
end

function DisableNTID()
    if pkg == nil then
        print("Package not found.")
        return
    end

    UnloadPatches()
    --ReloadModsLocalization()
    CleanUpIdCards()
end


Hook.Add("stop", "NTIDCleanUp", function ()
    UnloadPatches()
    --ReloadModsLocalization()
end)


Hook.Patch("Barotrauma.GameSettings", "SaveCurrentConfig", function(instance, ptable)
    if LanguageChanged() then
        ReloadIdCards()
    end
end, Hook.HookMethodType.After)


Hook.Patch("Barotrauma.Items.Components.IdCard", "Initialize", function(instance, ptable)
    AppendIdcard(instance, ptable["spawnPoint"], ptable["character"])
end, Hook.HookMethodType.After)

-- Hook.Patch("Barotrauma.Items.Components.IdCard", "OnItemLoaded", function(instance, ptable)
--     print("id card testing 2")
--     AppendIdcard(instance)
-- end, Hook.HookMethodType.After)




Game.AddCommand("reloadNTID", "Reloads NT Informative Descriptions.", function()
    ReloadNTID()
    print("NTID reloaded.")
end, GetValidArguments)

ContentPackageManager.EnabledPackages.regular.Remove(pkg)
ContentPackageManager.EnabledPackages.regular.Insert(0, pkg)

if config:Get("Enabled",true) then
    EnableNTID()
else
    DisableNTID()
end
--ContentPackageManager.ReloadContentPackage(pkg)