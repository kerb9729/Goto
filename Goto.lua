local Goto = ZO_Object:Subclass()
local Goto = Goto:New()

Goto.addonName = "Goto"
Goto.defaults = {}
Goto.memberdata = {}
Goto.groupUnitTags = {}

ZO_CreateStringId("GOTO_NAME", "Goto")

local GOTO_PANE = nil
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

local function getGuildMemberInfo(tabletopopulate)
    local numGuilds = GetNumGuilds()
    local punitAlliance = GetUnitAlliance("player")
    local punitName = GetUnitName("player")
    local prawUnitName = GetRawUnitName("player")
    local guildnum

    for guildnum = 1, numGuilds do
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
                mi.guildnames = {GetGuildName(guildID),}
                --d("mi.guildnames:"  .. for _,v in pairs(mi.guildnames) do print(string.format("%s\n", v) end )
                -- Don't display user, other factions, or players in Cyrodiil
                if mi.chname ~= prawUnitName and tabletopopulate[mi.unitname] == nil and mi.zone ~= "Cyrodiil" and mi.alliance == punitAlliance then
                    tabletopopulate[mi.unitname] = mi
                elseif mi.chname ~= prawUnitName and mi.zone ~= "Cyrodiil" and mi.alliance == punitAlliance then
                    -- Already got this player's data from a different guild
                    table.insert(tabletopopulate[mi.unitname].guildnames, mi.guildnames)
                end
            end
        end
    end

    -- Todo - friends

    -- This should catch group members that aren't in a guild the player is in
    for idx = 1, GetGroupSize() do
        local mi = {}
        local groupUnitTag = GetGroupUnitTagByIndex(idx)
        mi.unitname = GetUnitName(groupUnitTag)
        if tabletopopulate[mi.unitname] == nil and groupUnitTag ~= nil and IsUnitOnline(groupUnitTag) and mi.unitname ~= punitName then
            mi.zone = GetUnitZone(groupUnitTag)
            mi.class = GetUnitClass(groupUnitTag)
            mi.level = GetUnitLevel(groupUnitTag)
            mi.vr = GetUnitVeteranRank(groupUnitTag)
            --mi.guildnames = {"Grouped with player", }

            tabletopopulate[mi.unitname] = mi
        end
    end
end

local function populateScrollList(listdata)
    -- local displayed = {}
    local scrollData = ZO_ScrollList_GetDataList(GOTO_PANE.ScrollList)

    ZO_ClearNumericallyIndexedTable(scrollData)

    for _, player in pairs(listdata) do
        local guildlist = nil
        local idx

        if player.name ~= nil then
            for idx = 1, #player.guildnames do
                if guildlist ~= nil then
                    guildlist = string.format("%s\n%s", player.guildnames[idx], guildlist)
                else
                    guildlist = player.guildnames[idx]
                end
            end

            table.insert(scrollData, ZO_ScrollList_CreateDataEntry(GOTO_SCROLLLIST_DATA,
                {
                    playerName = player.unitname,
                    zoneName = player.zone,
                    playerClass = player.class,
                    playerLevel = player.level,
                    playerVr = player.vr,
                    playeratName = player.name,
                    playerGuilds = guildlist,
                }
            )
            )
        else
            table.insert(scrollData, ZO_ScrollList_CreateDataEntry(GOTO_SCROLLLIST_DATA,
                {
                    playerName = player.unitname,
                    zoneName = player.zone,
                    playerClass = player.class,
                    playerLevel = player.level,
                    playerVr = player.vr,
                    playeratName = player.unitname,
                    playerGuilds = "Grouped with player",
                }
            )
            )
        end
    end

    ZO_ScrollList_Commit(GOTO_PANE.ScrollList)
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
    GOTO_PANE.Headers.Name:SetDimensions(115,32)
    GOTO_PANE.Headers.Name:SetAnchor( TOPLEFT, GOTO_PANE.Headers, TOPLEFT, 8, 0 )
    ZO_SortHeader_Initialize(GOTO_PANE.Headers.Name, "Name", "playerName", ZO_SORT_ORDER_UP, TEXT_ALIGN_LEFT, "ZoFontGameLargeBold")
    ZO_SortHeader_SetTooltip(GOTO_PANE.Headers.Name, "Sort on player name")

    GOTO_PANE.Headers.Location = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)Location",GOTO_PANE.Headers,"ZO_SortHeader")
    GOTO_PANE.Headers.Location:SetDimensions(150,32)
    GOTO_PANE.Headers.Location:SetAnchor( LEFT, GOTO_PANE.Headers.Name, RIGHT, 18, 0 )
    ZO_SortHeader_Initialize(GOTO_PANE.Headers.Location, "Zone", "zoneName", ZO_SORT_ORDER_UP, TEXT_ALIGN_LEFT, "ZoFontGameLargeBold")
    ZO_SortHeader_SetTooltip(GOTO_PANE.Headers.Location, "Sort on zone")

    local sortHeaders = ZO_SortHeaderGroup:New(GOTO_PANE:GetNamedChild("Headers"), SHOW_ARROWS)
    sortHeaders:RegisterCallback(
        ZO_SortHeaderGroup.HEADER_CLICKED,
        function(key, order)
            table.sort(
                ZO_ScrollList_GetDataList(GOTO_PANE.ScrollList),
                function(entry1, entry2)
                    return ZO_TableOrderingFunction(entry1.data, entry2.data, key, GOTO_SCROLLLIST_SORT_KEYS, order)
                end)

            ZO_ScrollList_Commit(GOTO_PANE.ScrollList)
        end)
    sortHeaders:AddHeadersFromContainer()

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


function Goto:EVENT_ADD_ON_LOADED(eventCode, addonName, ...)
    if addonName == Goto.addonName then
        Goto.SavedVariables = ZO_SavedVars:New("Goto_SavedVariables", 2, nil, Goto.defaults)
        createGotoPane()

        --SLASH_COMMANDS["/goto"] = processSlashCommands

        --
        -- Unregister events we are not using anymore
        --
        EVENT_MANAGER:UnregisterForEvent(Goto.addonName, EVENT_ADD_ON_LOADED)
    end
end


function Goto:EVENT_PLAYER_ACTIVATED(...)
    d("|cFF2222Goto|r addon loaded")
    --
    -- Only once so unreg is from further events
    --
    EVENT_MANAGER:UnregisterForEvent(Goto.addonName, EVENT_PLAYER_ACTIVATED)
end


function Goto_OnInitialized()
    EVENT_MANAGER:RegisterForEvent(Goto.addonName, EVENT_ADD_ON_LOADED, function(...) Goto:EVENT_ADD_ON_LOADED(...) end )
    EVENT_MANAGER:RegisterForEvent(Goto.addonName, EVENT_PLAYER_ACTIVATED, function(...) Goto:EVENT_PLAYER_ACTIVATED(...) end)
    ZO_WorldMap.SetHidden = hook(ZO_WorldMap.SetHidden,function(base,self,value)
        base(self,value)
        if value == false then
            Goto.memberdata = {}
            getGuildMemberInfo(Goto.memberdata)
            populateScrollList(Goto.memberdata)
        end
    end)
end

function nameOnMouseUp(self, button, upInside)
    --d("MouseUp:" .. self:GetText() .. ":" .. tostring(button) .. ":" .. tostring(upInside) )
    local sButton = tostring(button)

    if sButton == "1" then -- left
        JumpToGuildMember(self:GetText())

    elseif sButton == "2" then -- right
        ZO_ScrollList_RefreshVisible(GOTO_PANE.ScrollList)

    else -- middle
        Goto.memberdata = {}
        getGuildMemberInfo(Goto.memberdata)
        populateScrollList(Goto.memberdata)
    end
end
--[[
EVENT_GROUP_MEMBER_JOINED (integer eventCode, string memberName)
EVENT_GROUP_MEMBER_LEFT (integer eventCode, string memberName, integer reason, bool wasLocalPlayer)

--]]
