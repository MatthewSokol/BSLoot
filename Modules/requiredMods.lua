local addonName, bsloot = ...
local moduleName = addonName.."_requiredmods"
local bsloot_requiredmods = bsloot:NewModule(moduleName)
local ST = LibStub("ScrollingTable")
local C = LibStub("LibCrayon-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local GUI = LibStub("AceGUI-3.0")
local LW = LibStub("LibWindow-1.1")

local data = { }
local colorHighlight = {r=0, g=0, b=0, a=.9}

bsloot.requiredMods = {"BSLoot", "DBM", "buffOmat", "ThreatClassic2", "ClassicLootAssistant", "Decursive", "ItemRack", "Guild_Roster_Manager", }
--
bsloot.requiredModsExceptions = {}
bsloot.requiredModsExceptions["Warrior"] = {"buffOmat","Decursive","ItemRack", "Guild_Roster_Manager", }
bsloot.requiredModsExceptions["Hunter"] = {"buffOmat","Decursive","ItemRack", "Guild_Roster_Manager", }
bsloot.requiredModsExceptions["Shaman"] = {"buffOmat","ItemRack", "Guild_Roster_Manager", }
bsloot.requiredModsExceptions["Druid"] = {"ItemRack", "Guild_Roster_Manager", }
bsloot.requiredModsExceptions["Rogue"] = {"buffOmat","Decursive","ItemRack", "Guild_Roster_Manager", }
bsloot.requiredModsExceptions["Priest"] = {"ItemRack", "Guild_Roster_Manager", }
bsloot.requiredModsExceptions["Warlock"] = {"buffOmat","Decursive","ItemRack", "Guild_Roster_Manager", } 
bsloot.requiredModsExceptions["Mage"] = {"ItemRack", "Guild_Roster_Manager", } 

function bsloot_requiredmods:OnEnable()
  local width = 300
  local headers = {
    {["name"]=C:Orange(_G.NAME),["width"]=100}, --name
  }
  for _, mod in ipairs(bsloot.requiredMods) do
    table.insert(headers, {["name"]=C:Orange(mod),["width"]=100})
    width = width + 100
  end
  
  bsloot_requiredmods.roster = {}
  bsloot_requiredmods.responses = {}

  local container = GUI:Create("Window")
  container:SetTitle(L["Required Mods"])
  container:SetWidth(width)
  container:SetHeight(290)
  container:EnableResize(false)
  container:SetLayout("List")
  container:Hide()
  self._container = container
  self._requiredmods_table = ST:CreateST(headers,15,nil,colorHighlight,container.frame) -- cols, numRows, rowHeight, highlight, parent
  self._requiredmods_table.frame:SetPoint("BOTTOMRIGHT",self._container.frame,"BOTTOMRIGHT", -10, 10)
  container:SetCallback("OnShow", function() bsloot_requiredmods._requiredmods_table:Show() end)
  container:SetCallback("OnClose", function() bsloot_requiredmods._requiredmods_table:Hide() end)
  
  local getDataButton = GUI:Create("Button")
  getDataButton:SetText(L["Get Data"])
  getDataButton:SetAutoWidth(true)
  getDataButton:SetCallback("OnClick", function()
    bsloot_requiredmods.roster = {}
    bsloot_requiredmods.responses = {}
    bsloot:doCheckRequiredMods(bsloot.db.char.raidonly)
    bsloot_requiredmods:Refresh()
  end)
  container:AddChild(getDataButton)

  local raid_only = GUI:Create("CheckBox")
  raid_only:SetLabel(L["Raid Only"])
  raid_only:SetValue(bsloot.db.char.raidonly)
  raid_only:SetCallback("OnValueChanged", function(widget,callback,value)
    bsloot.db.char.raidonly = value
    bsloot_requiredmods:Refresh()
  end)
  container:AddChild(raid_only)
  self._widgetraid_only = raid_only

  bsloot:make_escable(container,"add")
    
end

function bsloot_requiredmods:Toggle()
  if self._container.frame:IsShown() then
    self._container:Hide()
  else
    self._container:Show()
  end
  self:Refresh()
end
function bsloot_requiredmods:Hide()
  if self._container.frame:IsShown() then
    self._container:Hide()
    bsloot_requiredmods.roster = {}
    bsloot_requiredmods.responses = {}
  end
  self:Refresh()
end
function bsloot_requiredmods:Show()
  if not self._container.frame:IsShown() then
    self._container:Show()
  end
  self:Refresh()
end
function bsloot_requiredmods:setRoster(roster)
  bsloot_requiredmods.roster = roster
  bsloot_requiredmods:Refresh()
end
function bsloot_requiredmods:addResponse(charName, response)
  bsloot_requiredmods.responses[charName] = response 
  bsloot_requiredmods:Refresh() 
end

bsloot_requiredmods.colors = {}
bsloot_requiredmods.colors.missingrequired = {r=1.0,g=0,b=0,a=1.0}
bsloot_requiredmods.colors.missingok = {r=1.0,g=1.0,b=0,a=1.0}
bsloot_requiredmods.colors.ok = {r=0,g=1.0,b=0,a=1.0}

function bsloot_requiredmods:Refresh()
  
  table.wipe(data)
  for k,v in pairs(bsloot_requiredmods.roster) do

    local name = v.name
    local eClass, class, hexclass = bsloot:getClassData(v.class)
    local classColor = RAID_CLASS_COLORS[eClass]
    local response = bsloot_requiredmods.responses[name]

    local colData = {["cols"]={
      {["value"]=v.name,["color"]=classColor},
    }}
    if(not response or response == nil) then
      for _, mod in ipairs(bsloot.requiredMods) do
        table.insert(colData.cols, {["value"]="?", ["color"]=bsloot_requiredmods.colors.missingrequired})
      end
    else
      for _, mod in ipairs(bsloot.requiredMods) do
        table.insert(colData.cols, bsloot_requiredmods:buildColEntry(class, response[mod], mod))
      end
    end
    table.insert(data,colData)
  end
  self._requiredmods_table:SetData(data)  
  if self._requiredmods_table and self._requiredmods_table.showing then
    self._requiredmods_table:SortData()
  end

end

function bsloot_requiredmods:buildColEntry(class, responseForMod, modName)
  local colEntry = {["value"]="?", ["color"]=bsloot_requiredmods.colors.missingrequired}
  local hasMod = false
  if(responseForMod and responseForMod ~= nil) then
    colEntry.value = strtrim(bsloot:tableToString(responseForMod.version), "\" \t\n\r") .. " (" .. strtrim(bsloot:tableToString(responseForMod.enabled), "\" \t\n\r") ..")"
    if(responseForMod.enabled == 2) then
      -- 0 - disabled
      -- 1 - enabled for some
      -- 2 - enabled
      hasMod = true
      colEntry.color = bsloot_requiredmods.colors.ok
    else
      hasMod = false
      colEntry.color = bsloot_requiredmods.colors.missingrequired
    end
  else
    hasMod = false
    colEntry.color = bsloot_requiredmods.colors.missingrequired
  end
  if(not hasMod and bsloot.requiredModsExceptions[class] and bsloot.requiredModsExceptions[class] ~= nil) then
    for _, ex in ipairs(bsloot.requiredModsExceptions[class]) do
      if (ex == modName) then
        colEntry.color = bsloot_requiredmods.colors.missingok
      else
        bsloot:debugPrint("Exception doesn't match: ".. ex .. "~="..modName, {logicOp="AND", values={bsloot.statics.LOGS.DEV, bsloot.statics.LOGS.MODS}})
      end
    end
  elseif(not bsloot.requiredModsExceptions[class] or bsloot.requiredModsExceptions[class] == nil) then
    bsloot:debugPrint("Class not found for exception: ".. class, bsloot.statics.LOGS.MODS)
  end
  return colEntry
end

function bsloot_requiredmods:getRequiredMods()
  return requiredMods
end
function bsloot_requiredmods:getRequiredModsStr()
  local modStr = ""
  local modStrDiv = ""
  for _, mod in ipairs(bsloot.requiredMods) do
    modStr = modStr .. modStrDiv .. mod
    modStrDiv = "|"
  end
  return modStr
end

