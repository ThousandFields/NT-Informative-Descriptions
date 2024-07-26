if SERVER then return end
local modconfig = require("modconfig")
local TextFile = LuaUserData.CreateStatic("Barotrauma.TextFile", true)
local pkg
local FileList = {}

LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.GameSettings"], "currentConfig")
local ClientLanguage = tostring(GameSettings.currentConfig.Language)
local localizationTrimmed = string.sub(ClientLanguage, 2) .. ".xml"


for package in ContentPackageManager.EnabledPackages.All do
    local path = string.gsub(tostring(package.Dir),"\\","/")
    if path == NTID.Path then
        pkg = package
        break
    end
end


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

function EnableTextFiles(files)
    for file in files do
        file = StripModDir(file)
        file = string.gsub(file, "%%Language%%", ClientLanguage)
        if not EnableTextFile(file) then
            return false
        end
    end
    return true
end

function DisableTextPackage(workshopId)
    local targetPackage
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
        if LuaUserData.IsTargetType(file, "Barotrauma.TextFile") and string.endsWith(file.Path.Value, localizationTrimmed) then
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

    for _, value in pairs(modconfig) do
        local files = {}
        local modname = ""

        if ClientHasSupportedLanguage(value.supportedlanguages) then
            if value.IgnoreTargetModState or IsModEnabled(value.workshopId) then
                if value.workshopId ~= nil and value.workshopId ~= "" then
                    DisableTextPackage(value.workshopId)
                    modname = GetPackageById(value.workshopId).name
                end

                if EnableTextFiles(value.files) and modname ~= nil and modname ~= "" then
                    print("Enabled NTID patch for " .. modname)
                end
            end
        end
    end
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
        for file in package.Files do
            if LuaUserData.IsTargetType(file, "Barotrauma.TextFile") and string.endsWith(file.Path.Value, "nglish.xml") then
                file.LoadFile()
                --print("Reenabled " .. file.Path.Value .. " in package ", workshopId)
            end
        end
    end
end

Hook.Add("stop", "NTIDCleanUp", function ()
    UnloadPatches()
    ReloadModsLocalization()
end)


Game.AddCommand("reloadNTID", "Reloads  NT Informative Descriptions.", function()

    if pkg == nil then
        print("Package not found.")
        return
    end

    UnloadPatches()

    ClientLanguage = tostring(GameSettings.currentConfig.Language)
    modconfig = {}
    modconfig = dofile(NTID.Path .. "/Lua/modconfig.lua")
    LoadPatches()

    ContentPackageManager.EnabledPackages.EnableRegular(pkg)
    local result = ContentPackageManager.ReloadContentPackage(pkg)
    if result.IsFailure then
        print(result.Error)
        return
    end

    print("NTID reloaded.")
end, GetValidArguments)




LoadPatches()
ContentPackageManager.ReloadContentPackage(pkg)