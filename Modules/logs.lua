local addonName, bsloot = ...
local moduleName = addonName.."_logs"
local bsloot_logs = bsloot:NewModule(moduleName)
local ST = LibStub("ScrollingTable")
local C = LibStub("LibCrayon-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local GUI = LibStub("AceGUI-3.0")
local LW = LibStub("LibWindow-1.1")

local data = { }
local colorHighlight = {r=0, g=0, b=0, a=.9}
local currentSort = 2

function bsloot_logs:OnEnable()
  local container = GUI:Create("Window")
  container:SetTitle(L["BSLoot Events"])
  local WINDOW_WIDTH = 680
  local WINDOW_HEIGHT = 400
  container:SetWidth(WINDOW_WIDTH)
  container:SetHeight(WINDOW_HEIGHT)
  container:EnableResize(false)
  container:SetLayout("List")
  container:Hide()
  self._container = container
  local headers = {
    {["name"]=C:Orange(L["Event Type"]),["width"]=100,["sort"]=ST.SORT_DSC}, --type
    {["name"]=C:Orange(L["Epoch Sec"]),["width"]=100,["comparesort"]=st_sorter_numeric,["sortnext"]=1,["sort"]=ST.SORT_DSC}, --timestamp
    {["name"]=C:Orange(L["Event Id"]),["width"]=250}, --id
  }
  self._logs_table = ST:CreateST(headers,15,nil,colorHighlight,container.frame) -- cols, numRows, rowHeight, highlight, parent
  self._logs_table.frame:SetPoint("TOPRIGHT",self._container.frame,"TOPRIGHT", -10, -40)
  self._logs_table:EnableSelection(true)
  self._logs_table:RegisterEvents({
    ["OnClick"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
        if not realrow then return false end
        local eventId = data[realrow].cols[3].value
        local event = SyncEvents[eventId]
        local eventString = bsloot:tableToString(event)
        self._eventDataBox:SetText(eventString)
        
        local timestamp = C_DateAndTime.GetDateFromEpoch(event.epochSeconds * 1000 * 1000)
        self._timestampLabel:SetText("Timestamp: " .. bsloot:tableToString(timestamp))
        return false
    end,
  })
  container:SetCallback("OnShow", function() bsloot_logs._logs_table:Show() end)
  container:SetCallback("OnClose", function() bsloot_logs._logs_table:Hide() end)
  
  local deepRecalcButton = GUI:Create("Button")
  deepRecalcButton:SetAutoWidth(true)
  deepRecalcButton:SetText(L["Rebuild from Event Log"])
  deepRecalcButton:SetCallback("OnClick",function()
    bsloot:rebuildDataFromEventLog()
    bsloot_logs:Refresh()
  end)
  
  container:AddChild(deepRecalcButton)
  self._deepRecalcButton = deepRecalcButton

  local timestampLabel = GUI:Create("Label")
  timestampLabel:SetText("Select an Event")
  timestampLabel:SetWidth(150)
  container:AddChild(timestampLabel)
  self._timestampLabel = timestampLabel

  local eventDataBox = GUI:Create("MultiLineEditBox")
  eventDataBox:SetWidth(WINDOW_WIDTH)
  eventDataBox:SetHeight(260)
  eventDataBox:SetLabel(L["Event Details"])
  eventDataBox:SetDisabled(true)
  eventDataBox:DisableButton(true)
  eventDataBox:SetPoint("BOTTOMRIGHT",self._container.frame,"BOTTOMRIGHT",-10,10)
  container:AddChild(eventDataBox)
  self._eventDataBox = eventDataBox


  bsloot:make_escable(container,"add")
end



function bsloot_logs:Toggle()
  if self._container.frame:IsShown() then
    self._container:Hide()
  else
    self._container:Show()
  end
  self:Refresh()
end
function bsloot_logs:Hide()
  if self._container.frame:IsShown() then
    self._container:Hide()
  end
  self:Refresh()
end
function bsloot_logs:Show()
  if not self._container.frame:IsShown() then
    self._container:Show()
  end
  self:Refresh()
end

function bsloot_logs:Refresh()
--need to get the set of players somehow
--if raid only use CURRENT calcs (alt penalties etc)
  table.wipe(data)

  for k,v in pairs(SyncEvents) do
    table.insert(data,{["cols"]={
        {["value"]=v.type,},
        {["value"]=v.epochSeconds,},
        {["value"]=k,},
    }})
  end
  self._logs_table:SetData(data)  
  if self._logs_table and self._logs_table.showing then
    self._logs_table:SortData()
  end
end
