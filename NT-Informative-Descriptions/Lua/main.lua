if SERVER then return end
local modconfig = require("modconfig")
local idcardsuffixes = require("idcardsuffixes")
local TextFile = LuaUserData.CreateStatic("Barotrauma.TextFile", true)
LuaUserData.RegisterType("Barotrauma.TextPack+Text")

local pkg
local FileList = {}
local TextPacks = {}

local ClientLanguage = tostring(Game.Settings.CurrentConfig.Language)
local prev_language = ClientLanguage

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
                DisableTextPackage(patch.workshopId, language)
                modname = GetPackageById(patch.workshopId).name

                if not EnableTextFiles(patch.files, language) then
                    print("Errors enabling NTID files")
                end
            end
        end
    end

    AddPostFixes()
end


LuaUserData.RegisterType("System.Collections.Immutable.ImmutableList`1[[Barotrauma.TextPack,Barotrauma]]")
LuaUserData.RegisterType("System.Collections.Immutable.ImmutableList`1+Builder[[Barotrauma.TextPack,Barotrauma]]")
TextPack = LuaUserData.CreateStatic('Barotrauma.TextPack')

LuaUserData.RegisterType("System.Collections.Concurrent.ConcurrentDictionary`2")

function AddPostFixes()
    -- for _, patch in pairs(modconfig) do
    -- local files = {}
    -- local modname = ""
    TextPacks = {}
    DescriptionStrings = {}
    PostFixes = {}
    file = nil
    local blankXElement = XElement.Parse("<name></name>")
    local PostFixElement = XElement.Parse([[
        <infotexts language="English" nowhitespace="false" translatedname="English">
            <Override>
            </Override>
        </infotexts>
        ]])
    PostFixElementLanguage = PostFixElement.Attribute(XName.Get("language"))
    PostFixElementtranslatedname = PostFixElement.Attribute(XName.Get("translatedname"))
    
    --print(PostFixElement)


    -- test = XElement(XName.Get("testname"))
    -- test.Value = "XXXXXXXXXXX"
    -- PostFixElement.FirstNode.Add(test)
    -- --PostFixElement.FirstNode.AddString("blankXElement")
    -- PostFixElement.FirstNode.Add(blankXElement)

    print(PostFixElement)


    for language in TextManager.AvailableLanguages do
        print(language)
        DescriptionStrings = {}
        PostFixes = {}
        for textPack in TextManager.TextPacks[language] do
            print(textPack.ContentFile.ContentPackage.Name)
            if textPack.ContentFile.ContentPackage == pkg then
                print("TEST1 ")
                for identifier, text in pairs(textPack.Texts) do
                    id = identifier.ToString()
                    _, index = string.find(id, "^postfix.")
                    if index then
                        print("WHAT ", index)
                        PostFixes[string.sub(id, index+1)] = text[1].String
                    end
                end

            end
        end


        for id, postfix in pairs(PostFixes) do
            print("POSTFIX ", id)
            if DescriptionStrings[id] == nil then
                for textPack in TextManager.TextPacks[language] do
                    local text = textPack.Texts[Identifier(id)]
                    if text ~= nil then
                        DescriptionStrings[id] = text[1].String
                        file = textPack.ContentFile
                        print("FILE ", file)
                        break
                    end
                end
            end

            DescriptionStrings[id] = DescriptionStrings[id] .. "\n\n" .. postfix
        end

            for id, description in pairs(DescriptionStrings) do
                PostFixElement.FirstNode.Add(XElement(XName.Get(id), description))
            end
            if file ~= nil then

            PostFixElement = ContentXElement(file.ContentPackage, PostFixElement)
            --table.insert(TextPacks, TextPack(file, PostFixElement, language))

            --print(TextPackList)
            
                TextPackList = TextManager.TextPacks[language].ToBuilder()

                TextPackList.Add(TPack)
                TextPackList.Reverse()
                TextManager.TextPacks[language] = TextPackList.ToImmutable()
            end


    end
    TextManager.ClearCache()
    print(TextManager.Get("entitydescription.defibrillator"))





    -- for id, postfix in pairs(PostFixes) do
    --     description = TextManager.Get(id)
    --     --print(LuaUserData.TypeOf(description))
    --     description = LocalizedString.Replace(" ### ", description, postfix)
    --     --print(StringComparison.Ordinal)
    --     description.RetrieveValue()
    --     print(description)
    --     print(TextManager.Get(id))
    --     --print(id, " = ", postfix)
    -- end

    --TextManager.ClearCache()

    -- FileList = {}


    --     if patch.IgnoreTargetModState or IsModEnabled(patch.workshopId) then
    --         for language in patch.supportedlanguages do
                


    --             modname = GetPackageById(patch.workshopId).name

    --             if not EnableTextFiles(patch.files, language) then
    --                 print("Errors enabling NTID files")
    --             end
    --         end
    --     end
    -- end
    
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
    ReloadModsLocalization()
end

function ReloadIdCards()
    CleanUpIdCards()
    UpdateIdCards()
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




Game.AddCommand("reloadNTID", "Reloads  NT Informative Descriptions.", function()
    ReloadNTID()
    print("NTID reloaded.")
end, GetValidArguments)



LoadPatches()
CleanUpIdCards()
UpdateIdCards()
ReloadModsLocalization()
--ContentPackageManager.ReloadContentPackage(pkg)
