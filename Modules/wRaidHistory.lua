local addonName, bsloot = ...
local moduleName = addonName.."_raidhistory"
local bsloot_raidhistory = bsloot:NewModule(moduleName)
local ST = LibStub("ScrollingTable")
local C = LibStub("LibCrayon-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local GUI = LibStub("AceGUI-3.0")
local LW = LibStub("LibWindow-1.1")

local raid_data = { }
local raid_event_data = { }
local colorHighlight = {r=0, g=0, b=0, a=.9}
local currentSort = 2

function bsloot_raidhistory:OnEnable()
  local container = GUI:Create("Window")
  container:SetTitle(L["BSLoot Raid History"])
  local WINDOW_WIDTH = 1430
  local WINDOW_HEIGHT = 400
  container:SetWidth(WINDOW_WIDTH)
  container:SetHeight(WINDOW_HEIGHT)
  container:EnableResize(false)
  container:SetLayout("List")
  container:Hide()
  self._container = container
  local raid_headers = {
    {["name"]=C:Orange(L["Date/Time"]),["width"]=120,["sort"]=ST.SORT_DSC},
    {["name"]=C:Orange(L["Raid Name"]),["width"]=100,["sortnext"]=1,["sort"]=ST.SORT_DSC},
    {["name"]=C:Orange(L["Host/ML"]),["width"]=100},
    {["name"]=C:Orange(L["Raid Id"]),["width"]=250},
  }
  self._raidhistory_raid_table = ST:CreateST(raid_headers,15,nil,colorHighlight,container.frame) -- cols, numRows, rowHeight, highlight, parent
  self._raidhistory_raid_table.frame:SetPoint("BOTTOMLEFT",self._container.frame,"BOTTOMLEFT", 10, 10)
  self._raidhistory_raid_table:EnableSelection(true)
  self._raidhistory_raid_table:RegisterEvents({
    ["OnClick"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
        if not realrow then return false end
        self:RefreshRaidEventTable()
        self:RefreshRaidEventDetails()
    end,
  })
  container:SetCallback("OnShow", function() bsloot_raidhistory._raidhistory_raid_table:Show() end)
  container:SetCallback("OnClose", function() bsloot_raidhistory._raidhistory_raid_table:Hide() end)
  
  local event_headers = {
    {["name"]=C:Orange(L["Date/Time"]),["width"]=120,["sort"]=ST.SORT_ASC}, --timestamp
    {["name"]=C:Orange(L["Event Type"]),["width"]=80,["sortnext"]=1,["sort"]=ST.SORT_DSC}, --type
    {["name"]=C:Orange(L["SubType"]),["width"]=60}, --subtype
    {["name"]=C:Orange(L["Reason"]),["width"]=90}, --reason
    {["name"]=C:Orange(L["SubReason"]),["width"]=170}, --item/boss name
    {["name"]=C:Orange(L["Event Id"]),["width"]=250}, --id
    
  }
  self._raidhistory_raid_event_table = ST:CreateST(event_headers,15,nil,colorHighlight,container.frame) -- cols, numRows, rowHeight, highlight, parent
  self._raidhistory_raid_event_table.frame:SetPoint("BOTTOMRIGHT",self._container.frame,"BOTTOMRIGHT", -10, 10)
  self._raidhistory_raid_event_table:EnableSelection(true)
  self._raidhistory_raid_event_table:RegisterEvents({
    ["OnClick"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
        if not realrow then return false end
        self:RefreshRaidEventDetails()
    end,
  })
  container:SetCallback("OnShow", function() bsloot_raidhistory._raidhistory_raid_event_table:Show() end)
  container:SetCallback("OnClose", function() bsloot_raidhistory._raidhistory_raid_event_table:Hide() end)

  local eventDataBox = GUI:Create("MultiLineEditBox")
  eventDataBox:SetRelativeWidth(1)
  eventDataBox:SetHeight(260)
  eventDataBox:SetLabel(L["Event Details"])
  eventDataBox:SetDisabled(true)
  eventDataBox:DisableButton(true)
  container:AddChild(eventDataBox)
  self._eventDataBox = eventDataBox


  bsloot:make_escable(container,"add")
end



function bsloot_raidhistory:Toggle()
  if self._container.frame:IsShown() then
    self._container:Hide()
  else
    self._container:Show()
  end
  self:RefreshAll()
end
function bsloot_raidhistory:Hide()
  if self._container.frame:IsShown() then
    self._container:Hide()
  end
  self:RefreshAll()
end
function bsloot_raidhistory:Show()
  if not self._container.frame:IsShown() then
    self._container:Show()
  end
  self:RefreshAll()
end

function bsloot_raidhistory:RefreshAll()

  --Get selection before refresh
  self:RefreshRaidTable()

  self:RefreshRaidEventTable()

  self:RefreshRaidEventDetails()
end

function bsloot_raidhistory:RefreshRaidTable()

  local selectedRaid = self._raidhistory_raid_table:GetSelection()
  local selectedRaidRow = nil
  if(selectedRaid and selectedRaid ~= nil and selectedRaid > 0) then
    selectedRaidRow = self._raidhistory_raid_table:GetRow(selectedRaid)
  end

  table.wipe(raid_data)

  local loaded = 0
  for k,event in pairs(SyncEvents) do
    if(event.type == bsloot.statics.eventType.RAID) then
      local data = bsloot:getEventData(k, event.type)
      if(data.subType == bsloot.statics.eventSubType.RAID_START) then
        table.insert(raid_data,{["cols"]={
          {["value"]=bsloot:getDateTimeString(event.epochSeconds),},
          {["value"]=data.name,},
          {["value"]=bsloot:getEventCreator(event),},
          {["value"]=k,},
        }})
        loaded = loaded + 1
      end
    end
  end
  bsloot:debugPrint(string.format("Loaded %d raids", loaded), bsloot.statics.LOGS.EVENT)
  self._raidhistory_raid_table:SetData(raid_data)  
  if (selectedRaidRow and selectedRaidRow ~= nil) then
    self._raidhistory_raid_event_table:SetSelection(selectedRaidRow)
  end
  if self._raidhistory_raid_table and self._raidhistory_raid_table.showing then
    self._raidhistory_raid_table:SortData()
  end
end

function bsloot_raidhistory:RefreshRaidEventTable()
  
  local selectedRaid = self._raidhistory_raid_table:GetSelection()
  local selectedRaidId = nil
  local selectedRaidRow = nil
  if(selectedRaid and selectedRaid ~= nil and selectedRaid > 0) then
    selectedRaidRow = self._raidhistory_raid_table:GetRow(selectedRaid)
    selectedRaidId = selectedRaidRow.cols[4].value
  end

  local selectedRaidEvent = self._raidhistory_raid_event_table:GetSelection()
  local selectedRaidEventRow = nil
  if(selectedRaidEvent and selectedRaidEvent ~= nil) then
    selectedRaidEventRow = self._raidhistory_raid_event_table:GetRow(selectedRaidEvent)
  end

  table.wipe(raid_event_data)
  if(selectedRaidId and selectedRaidId ~= nil) then
    local raidEvents = bsloot:getRaidEvents(selectedRaidId)
    bsloot:debugPrint(string.format("Found %d events for raid %s", bsloot:tablelength(raidEvents), selectedRaidId), bsloot.statics.LOGS.EVENT)
    for k,event in pairs(raidEvents) do

      local data = bsloot:getEventData(k, event.type)
      local subReason = data.subReason -- boss's name, itemLink, etc

      if(data.reason == bsloot.statics.EPGP.LOOT) then
        bsloot:doWithItemInfo(subReason, function(itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
          itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
          isCraftingReagent, itemId)
          table.insert(raid_event_data,{["cols"]={
            {["value"]=bsloot:getDateTimeString(event.epochSeconds),},
            {["value"]=event.type,},
            {["value"]=data.subType,},
            {["value"]=data.reason,},
            {["value"]=itemLink,},
            {["value"]=k,},
        }})
      end)
      else
        table.insert(raid_event_data,{["cols"]={
            {["value"]=bsloot:getDateTimeString(event.epochSeconds),},
            {["value"]=event.type,},
            {["value"]=data.subType,},
            {["value"]=data.reason,},
            {["value"]=subReason,},
            {["value"]=k,},
        }})

      end
    end
  end
  self._raidhistory_raid_event_table:SetData(raid_event_data)  
  if (selectedRaidEventRow and selectedRaidEventRow ~= nil) then
    self._raidhistory_raid_event_table:SetSelection(selectedRaidEventRow)
  end
  if self._raidhistory_raid_event_table and self._raidhistory_raid_event_table.showing then
    self._raidhistory_raid_event_table:SortData()
  end
  
end

function bsloot_raidhistory:RefreshRaidEventDetails()
  
  local selectedRaidEvent = self._raidhistory_raid_event_table:GetSelection()
  local selectedRaidEventId = nil
  local selectedRaidEventRow = nil
  if(selectedRaidEvent and selectedRaidEvent ~= nil) then
    selectedRaidEventRow = self._raidhistory_raid_event_table:GetRow(selectedRaidEvent)
    if(selectedRaidEventRow and selectedRaidEventRow ~= nil) then
      selectedRaidEventId = selectedRaidEventRow.cols[6].value
    end
  end

  if(selectedRaidEventId and selectedRaidEventId ~= nil) then
    local eventString = bsloot:tableToString(SyncEvents[selectedRaidEventId])
    
    self._eventDataBox:SetText(eventString)
  else
    self._eventDataBox:SetText("")
  end
end
