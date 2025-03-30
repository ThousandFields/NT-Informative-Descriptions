
local LockedStr = TextManager.ContainsTag("rawconfig.enforcedtooltip") and TextManager.Get("rawconfig.enforcedtooltip") or "This setting is enforced by server"
local UnlockedStr = TextManager.ContainsTag("rawconfig.notenforcedtooltip") and TextManager.Get("rawconfig.notenforcedtooltip") or "This setting is not enforced by server"

local Version = 0.2

local rawconfig = {}
rawconfig.Version = Version


local configDirectoryPath = Game.SaveFolder .. "/ModConfigs"
local configFilePath = configDirectoryPath .. "/Neurotrauma.json"


rawconfig.Configs = {}
rawconfig.gui = {}
rawconfig.util = {}
rawconfig.util.DirectoryPath = Game.SaveFolder .. "/ModConfigs"
rawconfig.util.Buffer = {}


--Which side provides config value. Optional adds a Lock icon which can be toggled by Owner.
--Clientside entires can be bypassed with some "hacking" but also by not having clientside lua so either use Clientsidelua Enforced
--Or dont use clientside entries for anythign critical
rawconfig.Enforcment = {
    Client = 0,
    Server = 1,
    Optional = 2,
}


if CLIENT then
    Hook.Patch("rawconfig" .. Version .. "_Pausemenu", "Barotrauma.GUI", "TogglePauseMenu", {}, function(instance, ptable)
        if not GUI.GUI.PauseMenuOpen then return end
        local PMframe = GUI.GUI.PauseMenu
        local PMInner = PMframe.GetChild(Int32(1))
        local PMbuttonContainer = PMInner.GetChild(Int32(0))
        --local textblocks = {}
        
        for config in rawconfig.Configs do
            local button = GUI.Button(
                GUI.RectTransform(Vector2(1, 0.1), PMbuttonContainer.RectTransform),
                config.Label or config.Name,
                GUI.Alignment.Center,
                "GUIButtonSmall"
            )

            button.OnClicked = function()
                config:OpenMenu()
                if Game.IsMultiplayer then
                    rawconfig.util.RequestConfig(config)
                end
            end
            config.PauseMenuButton = button
        end

        --GUI.TextBlock.AutoScaleAndNormalize(textblocks)

        local PMSizeY = 0
        for child in PMbuttonContainer.Children do
            PMSizeY = PMSizeY + child.Rect.Height + PMbuttonContainer.AbsoluteSpacing
        end
        PMSizeY = math.floor(PMSizeY / PMbuttonContainer.RectTransform.RelativeSize.Y)
        PMInner.RectTransform.MinSize = Point(PMInner.RectTransform.MinSize.X, math.max(PMSizeY, PMInner.RectTransform.MinSize.X));
    end, Hook.HookMethodType.After)
end


--Allows indexing util and gui table values from config table itself
--Makes possible stuff like Config:Set(key, value) without needing to touch underlying util
--This also allows overriding any gui/util function by adding your own implementation to Config as __index meta is only used for unspecified keys
metatable = {
    __index = function(self, key)
        return rawconfig.util[key] or rawconfig.gui[key]
    end,
}


---Add a button to the bottom of pause menu for your config menu
---@param string how your button would be labeled. Supports localization tags.
---@param function(button) function called when button is pressed with Barotrauma.GUIButton passed as argument
function rawconfig.addConfig(config)
    config.Label = config.Label and TextManager.ContainsTag(config.Label) and TextManager.Get(config.Label) or Label
    config.EnableGUI = config.EnableGUI or true
    config.CanBeReset = config.CanBeReset or false
    config.FilePath = config.FilePath or rawconfig.util.DirectoryPath .. "/" .. config.Name .. ".json"

    config.PauseMenuButton = nil


    for entry in config.Entries do
        entry.value = entry.default
        entry.name = TextManager.ContainsTag(entry.name) and TextManager.Get(entry.name) or entry.name
        entry.description = TextManager.ContainsTag(entry.description) and TextManager.Get(entry.description) or entry.description
        if entry.enforcment == rawconfig.Enforcment.Optional then
            entry.enforced = entry.enforced or false
        else
            entry.enforced = entry.enforcment == rawconfig.Enforcment.Server 
        end
    end

    setmetatable(config, metatable)

    rawconfig.Configs[config.Name] = config 
    return rawconfig.Configs[config.Name]
end


function rawconfig.util.RequestConfig(config)
    if Game.IsMultiplayer then
        local msg = Networking.Start("rawconfig.ConfigRequest")
        msg.WriteString(config.Name)
        Networking.Send(msg)
    end
end


function rawconfig.util.LoadConfig(config)
    if not File.Exists(config.FilePath) then
        return
    end

    local readConfig = json.parse(File.Read(config.FilePath))

    for key, entry in pairs(readConfig) do
        if config.Entries[key] then
            config.Entries[key].value = entry.value
            if entry.enforced ~= nil and config.Entries[key].enforcment == rawconfig.Enforcment.Optional then
                config.Entries[key].enforced = entry.enforced
            end
        end
    end

    if Game.IsMultiplayer and CLIENT then
        rawconfig.util.RequestConfig(config)
    end
end


function rawconfig.util.SaveConfig(config, preserveUnusedKeys)
    --prevent both owner client and server saving config at the same time and potentially erroring from file access
    if Game.IsMultiplayer and CLIENT and Game.Client.MyClient.IsOwner then
        return
    end

    preserveUnusedKeys = preserveUnusedKeys or true

    local tableToSave = {}
    if preserveUnusedKeys and File.Exists(config.FilePath) then
        tableToSave = json.parse(File.Read(config.FilePath))
    end
    
    for key, entry in pairs(config.Entries) do
        tableToSave[key] = {}
        --Only save clientside keys when in mp
        if Game.IsMultiplayer and CLIENT then
            if not entry.enforced then
                tableToSave[key].value = entry.value
            end
        else
            tableToSave[key].value = entry.value
            if entry.enforcment == rawconfig.Enforcment.Optional then
                tableToSave[key].enforced = entry.enforced
            end
        end
    end

    File.CreateDirectory(config.DirectoryPath)

    --Apparently access error can still happen if player hosts dedicated and joins it on same pc.
    --Haven't found how to check file being in use properly so just delay to avoid conflict
    if CLIENT then
        File.Write(config.FilePath, json.serialize(tableToSave))
    else
        Timer.Wait(function()
            File.Write(config.FilePath, json.serialize(tableToSave))
        end, 100)
    end
    
end


function rawconfig.util.ResetConfig(config)
    for key, entry in pairs(config.Entries) do
        config.Entries[key].value = entry.default
    end
end


function rawconfig.util.SendConfig(config, reciverClient)
    local tableToSend = {}
    for key, entry in pairs(config.Entries) do
        tableToSend[key] = {}
        tableToSend[key].value = entry.value
        tableToSend[key].enforced = entry.enforced
    end

    local msg = Networking.Start("rawconfig.ConfigUpdate")
    msg.WriteString(config.Name)
    msg.WriteString(json.serialize(tableToSend))
    if SERVER then
        Networking.Send(msg, reciverClient and reciverClient.Connection or nil)
    else
        Networking.Send(msg)
    end
end


function rawconfig.util.ReceiveConfig(msg)
    local RecivedTable = {}
    local targetConfig = rawconfig.Configs[msg.ReadString()]
    RecivedTable = json.parse(msg.ReadString())

    for key, entry in pairs(RecivedTable) do
        if entry.enforced then
            targetConfig.Entries[key].value = entry.value
        end
        if entry.enforced ~= nil and targetConfig.Entries[key].enforcment == rawconfig.Enforcment.Optional then
            targetConfig.Entries[key].enforced = entry.enforced
        end
    end

    return targetConfig
end


if CLIENT then
    Networking.Receive("rawconfig.ConfigUpdate", function(msg)
        config = rawconfig.util.ReceiveConfig(msg)
        if config.Frame then
            config:UpdateMenu()
        end
    end)
end


if SERVER then
    Networking.Receive("rawconfig.ConfigUpdate", function(msg, sender)
        if not rawconfig.util.ClientHasAccess(sender) then
            return
        end
        config = rawconfig.util.ReceiveConfig(msg)
        config:SaveConfig()
    end)

    Networking.Receive("rawconfig.ConfigRequest", function(msg, sender)
        if not sender then
            return
        end
        local targetConfig = rawconfig.Configs[msg.ReadString()]
        if targetConfig then targetConfig:SendConfig(sender) end
    end)
end



function rawconfig.util.Get(config, key, default)
    if config.Entries[key] ~= nil then
        return config.Entries[key].value
    end
    return default
end


function rawconfig.util.Set(config, key, value)
    if config.Entries[key] ~= nil then
        config.Entries[key].value = value
    end
end

function rawconfig.util.ClearBuffer()
    rawconfig.util.Buffer = {}
end


function rawconfig.util.DumpBuffer(config)
    for key, entry in pairs(rawconfig.util.Buffer) do
        if config.Entries[key] ~= nil then
            for datakey, value in pairs(entry) do
                config.Entries[key][datakey] = value
            end
        end
    end
end


function rawconfig.util.ClientHasAccess(client)
    return client.HasPermission(ClientPermissions.ManageSettings)
end


rawconfig.gui = {
    CloseButton = nil,
    SaveButton = nil,
    ResetButton = nil,
    PauseMenuButton = function(config) return config.PauseMenuButton end,
    Frame = nil,
    ListContainer = nil,
    ControlGroup = nil,
}

---Creates empty box and returns a GUI.Frame to attach other guis into
---@param Barotrauma.RectTransform
---@param Vector2
---@param bool show or hide Reset button
function rawconfig.gui.OpenMenu(config, parent, size)
    local menuFrame = GUI.Frame(GUI.RectTransform(size or Vector2(0.3, 0.6), parent or GUI.GUI.PauseMenu.RectTransform, GUI.Anchor.Center))
    local menuList = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.9), menuFrame.RectTransform, GUI.Anchor.TopCenter))
    menuList.Padding = Vector4(10,15,10,10)
    menuList.UpdateDimensions()
    local menuControlGroup = GUI.LayoutGroup(GUI.RectTransform(Vector2(0.9, 0.1), menuFrame.RectTransform, GUI.Anchor.BottomCenter), true, GUI.Anchor.BottomLeft)
    menuControlGroup.RectTransform.AbsoluteOffset = Point(0, 7)
    menuControlGroup.Stretch = true
    menuControlGroup.AbsoluteSpacing = 7
    rawconfig.gui.SaveButton = config:CreateSaveButton(menuControlGroup)
    rawconfig.gui.CloseButton = config:CreateCloseButton(menuControlGroup)

    rawconfig.gui.Frame = menuFrame
    rawconfig.gui.ListContainer = menuList
    rawconfig.gui.ControlGroup = menuControlGroup
    
    if config.CanBeReset then
        --rawconfig.ResetButton(menuFrame)
    end

    menuControlGroup.Recalculate()

    config:PopulateMenu()

    return menuFrame
end


---Adds save button
function rawconfig.gui.CreateSaveButton(config, parent)
    local button = GUI.Button(
        GUI.RectTransform(Vector2(0.33, 0.05), parent.RectTransform, GUI.Anchor.BottomCenter),
        "Save",
        GUI.Alignment.Center,
        "GUIButton"
    )

    button.OnClicked = function()
        rawconfig.util.DumpBuffer(config)
        rawconfig.util.ClearBuffer()
        if Game.IsMultiplayer and Game.Client.HasPermission(ClientPermissions.ManageSettings) then
            config:SendConfig()
        end
        config:SaveConfig()
        config:CloseMenu()
    end

    return button
end


---Adds close button
function rawconfig.gui.CreateCloseButton(config, parent)
    local button = GUI.Button(
        GUI.RectTransform(Vector2(0.33, 0.05), parent.RectTransform, GUI.Anchor.BottomCenter),
        "Discard",
        GUI.Alignment.Center,
        "GUIButton"
    )

    button.OnClicked = function()
        config:CloseMenu()
    end

    return button
end


function rawconfig.gui.CloseMenu(config)
    config.Frame.RectTransform.Parent = nil

    rawconfig.gui.CloseButton = nil
    rawconfig.gui.SaveButton = nil
    rawconfig.gui.ResetButton = nil
    rawconfig.gui.Frame = nil
    rawconfig.gui.ListContainer = nil
    rawconfig.gui.ControlGroup = nil

    for key, entry in pairs(config.Entries) do
        entry.gui = nil
    end
end

---@param Barotrauma.RectTransform
function rawconfig.gui.PopulateMenu(config)
    for key, entry in pairs(config.Entries) do
        local EntryGroup = GUI.LayoutGroup(GUI.RectTransform(Vector2(0.98, 0.08), config.ListContainer.Content.RectTransform, GUI.Anchor.TopCenter), true, GUI.Anchor.CenterLeft)
        --EntryGroup.RectTransform.AbsoluteOffset = Point(0,100)
        --EntryGroup.AbsoluteSpacing = 5
        --EntryGroup.Stretch = true

        local Lock = config:CreateLock(EntryGroup, key, entry)
        if entry.type == "bool" then
            config:CreateTickBox(EntryGroup, key, entry)
        elseif entry.type == "float" then
        end

        entry.gui = EntryGroup
    end
end


---@param Barotrauma.RectTransform
function rawconfig.gui.CreateLock(config, parent, key, entry)
    local rect = GUI.RectTransform(Vector2(0.05, 1), parent.RectTransform)
    local toggle = GUI.TickBox(rect, "", nil, "GUILockToggle")

    if Game.IsSingleplayer or entry.enforcment == rawconfig.Enforcment.Client then
        toggle.Selected = false
        toggle.Visible = false
        return toggle
    end

    toggle.Selected = entry.enforced
    toggle.Enabled = entry.enforcment == rawconfig.Enforcment.Optional and rawconfig.util.ClientHasAccess(Game.Client)


    if toggle.Selected and not toggle.Enabled then
        toggle.Box.DisabledColor = Color(255,106,106,255)
    end

    if entry.description then
        toggle.ToolTip = toggle.Selected and LockedStr or UnlockedStr
    end

    toggle.OnSelected = function()
        toggle.ToolTip = toggle.Selected and LockedStr or UnlockedStr
        rawconfig.util.Buffer[key].enforced = toggle.Selected
    end

    return toggle
end

---@param Barotrauma.RectTransform
function rawconfig.gui.CreateTickBox(config, parent, key, entry)
    -- toggle
    local rect = GUI.RectTransform(Vector2(0.8, 1), parent.RectTransform)
    local toggle = GUI.TickBox(rect, entry.name)
    if entry.description then
        toggle.ToolTip = entry.description
    end

    toggle.Selected = config:Get(key, entry.default or false)

    toggle.Enabled = Game.IsSingleplayer or not entry.enforced or rawconfig.util.ClientHasAccess(Game.Client)

    toggle.OnSelected = function()
        if not rawconfig.util.Buffer[key] then rawconfig.util.Buffer[key] = {} end
        rawconfig.util.Buffer[key].value = toggle.State == GUI.Component.ComponentState.Selected
    end

    return toggle
end


---@param Barotrauma.RectTransform
function rawconfig.gui.UpdateMenu(config)
    for key, entry in pairs(config.Entries) do
        if entry.type == "bool" then
            local lock = entry.gui.GetChild(Int32(0))
            local tickbox = entry.gui.GetChild(Int32(1))

            tickbox.Selected = entry.value
            tickbox.Enabled = Game.IsSingleplayer or not entry.enforced or rawconfig.util.ClientHasAccess(Game.Client)
            lock.Selected = entry.enforced
            if lock.Selected and not lock.Enabled then
                lock.Box.DisabledColor = Color(255,106,106,255)
            end

        elseif entry.type == "float" then
        end
    end
end


--[[
testcfg = {
    Name = "testcfg", --Internal name, used for rawconfig.Configs.Name
    Label = "pausemenuquitverification", --String displayed in menus, can be localization tag
    Entries = {
        TST_tickbox = {
            name = "pausemenuquitverification",
            default = false,
            type = "bool",
            description = "pausemenuquitverification",
            enforcment = rawconfig.Enforcment.Client,
        },
        TST_field = {
            name = "Test name2, can also be a localization tag",
            default = false,
            type = "bool",
            description = "Whatever whatever 2, can also be a localization tag",
            --enforced = true,
            enforcment = rawconfig.Enforcment.Optional,
        },

    },
}


rawconfig.addConfig(testcfg)
rawconfig.Configs.testcfg:LoadConfig()
]]


return rawconfig
















