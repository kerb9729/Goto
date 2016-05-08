local Goto = ZO_Object:Subclass()
local Goto = Goto:New()

Goto.addonName = "Goto"
Goto.defaults = {}
Goto.playerdata = {}
Goto.groupUnitTags = {}

ZO_CreateStringId("GOTO_NAME", "Goto")

local GOTO_PANE = {}
local GOTO_SCROLLLIST_DATA = 1
local GOTO_SCROLLLIST_SORT_KEYS =
{
    ["playerName"] = { },
    ["zoneName"] = {  tiebreaker = "playerName" },
}

local function hook(baseFunc,newFunc)
    return function(...)
        return newFunc(baseFunc,...)
    end
end

local function getpunitUnlockedZones()
    local unlockedzones = {}
    local difficultylevel = GetPlayerDifficultyLevel()
    local zonename, _
    local punitlevel = GetUnitLevel("player")

    if punitlevel > 49 then
        difficultylevel = 2
    end

    for idx = 0, difficultylevel do
        for idy = 1, GetNumZonesForDifficultyLevel(idx) do
            zonename, _, _ = GetCadwellZoneInfo(idx, idy)
            unlockedzones[zonename] = 1
        end
    end
    if punitlevel > 49 then
        unlockedzones['Craglorn'] = 1
    end
    unlockedzones['Coldharbor'] = 1

    return unlockedzones
end

local function isInGroup(playerName)
    for idx = 1, GetGroupSize() do
        local groupUnitTag = GetGroupUnitTagByIndex(idx)
        local unitName = GetUnitName(groupUnitTag)
        if playerName == unitName then
                return true
        end
    end
    return false
end

local function getPlayerInfo(tabletopopulate)
    local punitAlliance = GetUnitAlliance("player")
    local punitName = GetUnitName("player")
    local prawUnitName = GetRawUnitName("player")
    local punitUnlockedZones = getpunitUnlockedZones()

    for guildnum = 1, GetNumGuilds() do
        local guildID = GetGuildId(guildnum)
        local numMembers = GetNumGuildMembers(guildID)
        local memberindex

        for memberindex = 1, numMembers do
            local mi = {} --mi == "member info"

            mi.name, mi.note, mi.rankindex, mi.status, mi.secsincelastseen =
                GetGuildMemberInfo(guildID,memberindex)
            if mi.status == 1 then -- only collect info for online players
                mi.hasCh, mi.chname, mi.zone, mi.class, mi.alliance, mi.level, mi.vr =
                    GetGuildMemberCharacterInfo(guildID, memberindex)
                mi.unitname = mi.chname:gsub("%^.*$", "") -- Strips all after ^
                if tabletopopulate[mi.unitname] ~= nil then
                    mi.guildnames = string.format("%s\n%s", tabletopopulate[mi.unitname].guildnames, GetGuildName(guildID))
                else
                    mi.guildnames = GetGuildName(guildID)
                end
                -- Don't display user, other factions, or players in Cyrodiil
                if mi.chname ~= prawUnitName and mi.zone ~= "Cyrodiil" and mi.alliance == punitAlliance and punitUnlockedZones[mi.zone] ~= nil then
                    tabletopopulate[mi.unitname] = mi
                end
            end
        end
    end

    -- This should catch group members that aren't in a guild the player is in
    for idx = 1, GetGroupSize() do
        local mi = {}
        local groupUnitTag = GetGroupUnitTagByIndex(idx)
        mi.unitname = GetUnitName(groupUnitTag)
        if mi.unitname ~= punitName and tabletopopulate[mi.unitname] == nil and groupUnitTag ~= nil
                and IsUnitOnline(groupUnitTag) then
            mi.zone = GetUnitZone(groupUnitTag)
            mi.class = GetUnitClassId(groupUnitTag)
            mi.level = GetUnitLevel(groupUnitTag)
            mi.vr = GetUnitVeteranRank(groupUnitTag)
            mi.guildnames = "Grouped"

            tabletopopulate[mi.unitname] = mi
        end
    end

    -- This should catch any friends that are not in a guild the player is in
    for findex = 1, GetNumFriends() do
        local mi = {} --mi == "member info"

        mi.name, mi.note, mi.status, mi.secsincelastseen = GetFriendInfo(findex)
        if mi.status == 1 then -- only collect info for online players
            mi.hasCh, mi.chname, mi.zone, mi.class, mi.alliance, mi.level, mi.vr =
                GetFriendCharacterInfo(findex)
            mi.unitname = mi.chname:gsub("%^.*$", "") -- Strips all after ^
            mi.guildnames = "Friend"

            -- Don't display user, other factions, or players in Cyrodiil
            if  tabletopopulate[mi.unitname] == nil and mi.zone ~= "Cyrodiil" and mi.alliance == punitAlliance  and punitUnlockedZones[mi.zone] ~= nil then
                tabletopopulate[mi.unitname] = mi
            end
        end
    end
end

local function populateScrollList(listdata)
    local scrollData = ZO_ScrollList_GetDataList(GOTO_PANE.ScrollList)

    ZO_ClearNumericallyIndexedTable(scrollData)

    for _, player in pairs(listdata) do
        if player.name ~= nil then -- was in guild or friends list
            table.insert(scrollData, ZO_ScrollList_CreateDataEntry(GOTO_SCROLLLIST_DATA,
                {
                    playerName = player.unitname,
                    zoneName = player.zone,
                    playerClass = player.class,
                    playerLevel = player.level,
                    playerVr = player.vr,
                    playeratName = player.name,
                    playerGuilds = player.guildnames,
                }
            )
            )
        else -- not in guild or friends list; no way to determine @name or guilds
            table.insert(scrollData, ZO_ScrollList_CreateDataEntry(GOTO_SCROLLLIST_DATA,
                {
                    playerName = player.unitname,
                    zoneName = player.zone,
                    playerClass = player.class,
                    playerLevel = player.level,
                    playerVr = player.vr,
                    playeratName = player.unitname,
                    playerGuilds = player.guildnames,
                }
            )
            )
        end
    end

    ZO_ScrollList_Commit(GOTO_PANE.ScrollList)
    GOTO_PANE.sortHeaders:SelectHeaderByKey("playerName")
end

local function createGotoPane()
    local x,y = ZO_WorldMapLocations:GetDimensions()
    local isValidAnchor, point, relativeTo, relativePoint, offsetX, offsetY = ZO_WorldMapLocations:GetAnchor()

    GOTO_PANE = WINDOW_MANAGER:CreateTopLevelWindow(nil)
    GOTO_PANE:SetMouseEnabled(true)
    GOTO_PANE:SetMovable( false )
    GOTO_PANE:SetClampedToScreen(true)
    GOTO_PANE:SetDimensions( x, y )
    GOTO_PANE:SetAnchor( point, relativeTo, relativePoint, offsetX, offsetY )
    GOTO_PANE:SetHidden( true )

    -- Create Sort Headers
    GOTO_PANE.Headers = WINDOW_MANAGER:CreateControl("$(parent)Headers",GOTO_PANE,nil)
    GOTO_PANE.Headers:SetAnchor( TOPLEFT, GOTO_PANE, TOPLEFT, 0, 0 )
    GOTO_PANE.Headers:SetHeight(32)

    GOTO_PANE.Headers.Name = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)Name",GOTO_PANE.Headers,"ZO_SortHeader")
    GOTO_PANE.Headers.Name:SetDimensions(150,32)
    GOTO_PANE.Headers.Name:SetAnchor( TOPLEFT, GOTO_PANE.Headers, TOPLEFT, 8, 0 )
    ZO_SortHeader_Initialize(GOTO_PANE.Headers.Name, "Name", "playerName", ZO_SORT_ORDER_UP, TEXT_ALIGN_LEFT, "ZoFontGameLargeBold")
    ZO_SortHeader_SetTooltip(GOTO_PANE.Headers.Name, "Sort on player name")

    GOTO_PANE.Headers.Location = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)Location",GOTO_PANE.Headers,"ZO_SortHeader")
    GOTO_PANE.Headers.Location:SetDimensions(150,32)
    GOTO_PANE.Headers.Location:SetAnchor( LEFT, GOTO_PANE.Headers.Name, RIGHT, 18, 0 )
    ZO_SortHeader_Initialize(GOTO_PANE.Headers.Location, "Zone", "zoneName", ZO_SORT_ORDER_UP, TEXT_ALIGN_LEFT, "ZoFontGameLargeBold")
    ZO_SortHeader_SetTooltip(GOTO_PANE.Headers.Location, "Sort on zone")

    GOTO_PANE.sortHeaders = ZO_SortHeaderGroup:New(GOTO_PANE:GetNamedChild("Headers"), SHOW_ARROWS)
    GOTO_PANE.sortHeaders:RegisterCallback(
        ZO_SortHeaderGroup.HEADER_CLICKED,
        function(key, order)
            table.sort(
                ZO_ScrollList_GetDataList(GOTO_PANE.ScrollList),
                function(entry1, entry2)
                    if isInGroup(entry1.data.playerName) then
                        if not isInGroup(entry2.data.playerName) then
                            return true -- 1 (group member) comes before 2 (non-member)
                        end
                    else
                        if isInGroup(entry2.data.playerName) then
                            return false -- 1 (non-member) comes after 2 (group member)
                        end
                    end
                    -- both members or both non-members, break the tie using the usual column sorting rules
                    return ZO_TableOrderingFunction(entry1.data, entry2.data, key, GOTO_SCROLLLIST_SORT_KEYS, order)
                end)
            ZO_ScrollList_Commit(GOTO_PANE.ScrollList)
        end)
    GOTO_PANE.sortHeaders:AddHeadersFromContainer()

    -- Create a scrollList
    GOTO_PANE.ScrollList = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)GotoScrollList", GOTO_PANE, "ZO_ScrollList")
    GOTO_PANE.ScrollList:SetDimensions(x, y-32)
    GOTO_PANE.ScrollList:SetAnchor(TOPLEFT, GOTO_PANE.Headers, BOTTOMLEFT, 0, 0)

    -- Add a datatype to the scrollList
    ZO_ScrollList_AddDataType(GOTO_PANE.ScrollList, GOTO_SCROLLLIST_DATA, "GotoRow", 23,
        function(control, data)

            local nameLabel = control:GetNamedChild("Name")
            local locationLabel = control:GetNamedChild("Location")

            local friendColor = ZO_ColorDef:New(0.3, 1, 0, 1)
            local groupColor = ZO_ColorDef:New(0.46, .73, .76, 1)
            local selectedColor = ZO_ColorDef:New(0.7, 0, 0, 1)

            local displayedlevel = nil

            nameLabel:SetText(data.playerName)

            if data.playerLevel < 50 then
                displayedlevel = data.playerLevel
            else
                displayedlevel = "VR" .. data.playerVr
            end

            nameLabel.tooltipText = string.format("%s\n%s %s\n%s",
                data.playeratName, displayedlevel, GetClassName(1, data.playerClass), data.playerGuilds)

            locationLabel:SetText(data.zoneName)

            if isInGroup(data.playerName) then
                ZO_SelectableLabel_SetNormalColor(nameLabel, groupColor)
                ZO_SelectableLabel_SetNormalColor(locationLabel, groupColor)

            elseif IsFriend(data.playerName) then
                ZO_SelectableLabel_SetNormalColor(nameLabel, friendColor)
                ZO_SelectableLabel_SetNormalColor(locationLabel, friendColor)

            else
                ZO_SelectableLabel_SetNormalColor(nameLabel, ZO_NORMAL_TEXT)
                ZO_SelectableLabel_SetNormalColor(locationLabel, ZO_NORMAL_TEXT)
            end
        end
    )

    local buttonData = {
        normal = "EsoUI/Art/mainmenu/menubar_journal_up.dds",
        pressed = "EsoUI/Art/mainmenu/menubar_journal_down.dds",
        highlight = "EsoUI/Art/mainmenu/menubar_journal_over.dds",
    }

    --
    -- Create a fragment from the window and add it to the modeBar of the WorldMap RightPane
    --
    local gotoFragment = ZO_FadeSceneFragment:New(GOTO_PANE)
    WORLD_MAP_INFO.modeBar:Add(GOTO_NAME, {gotoFragment}, buttonData)
end


local function processSlashCommands(argslist)
    d("Under Construction")
    --[[
    local options = {}
    local searchResult = { string.match(argslist,"^(%S*)%s*(.-)$") }
    for i,v in pairs(searchResult) do
        if (v ~= nil and v ~= "") then
            options[i] = string.lower(v)
        end
    end
    if #options == 0 or options[1] == "help" then
        d("/j @name\tJump to shrine nearest @name")
        d("/j aliasname\tJump to shrine nearest character with alias \"aliasname\"")
        d("/j leader\tJump to party leader")
        d("/galias @name|\"character name\" aliasname")
        d("-- assign aliasname to either @name or \"character name\"")
    end
    --]]
end

function Goto:EVENT_ADD_ON_LOADED(eventCode, addonName, ...)
    if addonName == Goto.addonName then
        Goto.SavedVariables = ZO_SavedVars:New("Goto_SavedVariables", 2, nil, Goto.defaults)
        createGotoPane()

        SLASH_COMMANDS["/j"] = processSlashCommands
        SLASH_COMMANDS["/galias"] = processSlashCommands

        EVENT_MANAGER:UnregisterForEvent(Goto.addonName, EVENT_ADD_ON_LOADED)
    end
end


function Goto:EVENT_PLAYER_ACTIVATED(...)
    d("|cFF2222Goto|r addon loaded")
    EVENT_MANAGER:UnregisterForEvent(Goto.addonName, EVENT_PLAYER_ACTIVATED)
end


function Goto_OnInitialized()
    EVENT_MANAGER:RegisterForEvent(Goto.addonName, EVENT_ADD_ON_LOADED, function(...) Goto:EVENT_ADD_ON_LOADED(...) end )
    EVENT_MANAGER:RegisterForEvent(Goto.addonName, EVENT_PLAYER_ACTIVATED, function(...) Goto:EVENT_PLAYER_ACTIVATED(...) end)
    ZO_WorldMap.SetHidden = hook(ZO_WorldMap.SetHidden,function(base,self,value)
        base(self,value)
        if value == false then
            Goto.playerdata = {}
            getPlayerInfo(Goto.playerdata)
            populateScrollList(Goto.playerdata)
        end
    end)
end

function nameOnMouseUp(self, button, upInside)
    --d("MouseUp:" .. self:GetText() .. ":" .. tostring(button) .. ":" .. tostring(upInside) )
    local unitName = self:GetText()

    if button == 1 then -- left
        if IsFriend(unitName) then
            JumpToFriend(unitName)
        elseif isInGroup(unitName) then
            JumpToGroupMember(unitName)
        else
            JumpToGuildMember(unitName)
        end

    elseif button == 2 then -- right
        ZO_ScrollList_RefreshVisible(GOTO_PANE.ScrollList)

    else -- middle
        Goto.playerdata = {}
        getPlayerInfo(Goto.playerdata)
        populateScrollList(Goto.playerdata)
    end
end

