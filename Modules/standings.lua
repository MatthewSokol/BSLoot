local addonName, bsloot = ...
local moduleName = addonName.."_standings"
local bsloot_standings = bsloot:NewModule(moduleName)
local ST = LibStub("ScrollingTable")
local C = LibStub("LibCrayon-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local GUI = LibStub("AceGUI-3.0")
local LW = LibStub("LibWindow-1.1")

local data = { }
local colorHighlight = {r=0, g=0, b=0, a=.9}
local currentSort = 2
local function st_sorter_numeric(st,rowa,rowb,col)
  local cella = st.data[rowa].cols[col].value
  local cellb = st.data[rowb].cols[col].value
  local sort = st.cols[col].sort or st.cols[col].defaultsort
  if bsloot.db.char.classgroup then
    local classa = st.data[rowa].cols[5].value
    local classb = st.data[rowb].cols[5].value
    if classa == classb then
      if cella == cellb then
        local sortnext = st.cols[col].sortnext
        if sortnext then
          return st.data[rowa].cols[sortnext].value < st.data[rowb].cols[sortnext].value
        end
      else
        return tonumber(cella) > tonumber(cellb)
      end      
    else
      if sort == ST.SORT_DSC then
        return classa < classb
      else
        return classa > classb
      end
    end
  else
    if cella == cellb then
      local sortnext = st.cols[col].sortnext
      if sortnext then
        return st.data[rowa].cols[sortnext].value < st.data[rowb].cols[sortnext].value
      end
    else
      if sort == ST.SORT_DSC then
        return tonumber(cella) > tonumber(cellb)
      else
        return tonumber(cella) < tonumber(cellb)
      end
    end
  end
end

function bsloot_standings:OnEnable()
  local container = GUI:Create("Window")
  container:SetTitle(L["BSLoot standings"])
  container:SetWidth(580)
  container:SetHeight(290)
  container:EnableResize(false)
  container:SetLayout("List")
  container:Hide()
  self._container = container
  local headers = {
    {["name"]=C:Orange(_G.NAME),["width"]=100}, --name
    {["name"]=C:Orange(L["pr"]:upper()),["width"]=60,["comparesort"]=st_sorter_numeric,["sortnext"]=1,["sort"]=ST.SORT_DSC}, --pr
    {["name"]=C:Orange(L["ep"]:upper()),["width"]=75,["comparesort"]=st_sorter_numeric}, --ep
    {["name"]=C:Orange(L["gp"]:upper()),["width"]=75,["comparesort"]=st_sorter_numeric}, --gp
    {["name"]=C:Orange(L["Class"]),["width"]=50}, --class
    {["name"]=C:Orange(L["isMain"]),["width"]=40}, --isMain
  }
  self._standings_table = ST:CreateST(headers,15,nil,colorHighlight,container.frame) -- cols, numRows, rowHeight, highlight, parent
  self._standings_table.frame:SetPoint("BOTTOMRIGHT",self._container.frame,"BOTTOMRIGHT", -10, 10)
  self._standings_table:EnableSelection(true)
  container:SetCallback("OnShow", function() bsloot_standings._standings_table:Show() end)
  container:SetCallback("OnClose", function() bsloot_standings._standings_table:Hide() end)
  
  local raid_only = GUI:Create("CheckBox")
  raid_only:SetLabel(L["Raid Only"])
  raid_only:SetValue(bsloot.db.char.raidonly)
  raid_only:SetCallback("OnValueChanged", function(widget,callback,value)
    bsloot.db.char.raidonly = value
    bsloot_standings:Refresh()
  end)
  container:AddChild(raid_only)
  self._widgetraid_only = raid_only

  local clearCacheButton = GUI:Create("Button")
  clearCacheButton:SetAutoWidth(true)
  clearCacheButton:SetText(L["Recalculate"])
  clearCacheButton:SetCallback("OnClick",function()
      EPGPCache = {}
      bsloot_standings:Refresh()
  end)
  container:AddChild(clearCacheButton)
  self._clearCacheButton = clearCacheButton

  bsloot:make_escable(container,"add")
end

function bsloot_standings:Toggle()
  if self._container.frame:IsShown() then
    self._container:Hide()
  else
    self._container:Show()
  end
  self:Refresh()
end
function bsloot_standings:Hide()
  if self._container.frame:IsShown() then
    self._container:Hide()
  end
  self:Refresh()
end
function bsloot_standings:Show()
  if not self._container.frame:IsShown() then
    self._container:Show()
  end
  self:Refresh()
end

function bsloot_standings:Refresh()
--need to get the set of players somehow
--if raid only use CURRENT calcs (alt penalties etc)
  table.wipe(data)

  local standingsRecords = bsloot:getStandings(self._widgetraid_only:GetValue())
  for k,v in ipairs(standingsRecords) do
    local name = v.charName
    local isMain = v.isMain

    local ep = v.EP
    local gp = v.GP
    local pr = v.PR
    
    local eClass, class, hexclass = bsloot:getClassData(v.class)
    local color = RAID_CLASS_COLORS[eClass]
    table.insert(data,{["cols"]={
      {["value"]=name,["color"]=color},
      {["value"]=string.format("%.4f", pr),["color"]={r=1.0,g=215/255,b=0,a=1.0}},
      {["value"]=string.format("%.4f", ep)},
      {["value"]=string.format("%.4f", gp)},
      {["value"]=eClass,["color"]=color},
      {["value"]=bsloot:tableToString(isMain)},
    }})
  end
  self._standings_table:SetData(data)  
  if self._standings_table and self._standings_table.showing then
    self._standings_table:SortData()
  end
end
