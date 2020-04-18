local addonName, bsloot = ...
local moduleName = addonName.."_io"
local bsloot_io = bsloot:NewModule(moduleName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local Dump = LibStub("LibTextDump-1.0")
local Parse = LibStub("LibParse")

local temp_data = {}

function bsloot_io:OnEnable()
  self._iostandings = Dump:New(L["Export Standings"],250,290)
  self._ioloot = Dump:New(L["Export Loot"],500,320)
  self._iologs = Dump:New(L["Export Logs"],450,320)
  local bslootexport,_,_,_,reason = GetAddOnInfo("BSLoot_Export")
  if not (reason == "ADDON_MISSING" or reason == "ADDON_DISABLED") then
    local loaded, finished = IsAddOnLoaded("BSLoot_Export")
    if loaded then
      BSLootExport = BSLootExport or {}
      self._fileexport = BSLootExport
      bsloot:debugPrint(L["BSLoot will be saving to file in `\\WTF\\Account\\<ACCOUNT>\\SavedVariables\\BSLoot_Export.lua`"], 2)
    end
  end
end

function bsloot_io:Standings()
  local keys
  self._iostandings:Clear()
  local members = bsloot:buildRosterTable()
  self._iostandings:AddLine(string.format("%s;%s;%s;%s",L["Name"],L["ep"],L["gp"],L["pr"]))
  if self._fileexport then
    table.wipe(temp_data)
    keys = {L["Name"],L["ep"],L["gp"],L["pr"]}
  end
  for k,v in pairs(members) do
    local ep = bsloot:get_ep(v.name,v.onote) or 0
    if ep > 0 then
      local gp = bsloot:get_gp(v.name,v.onote) or bsloot.VARS.basegp
      local pr = ep/gp
      self._iostandings:AddLine(string.format("%s;%s;%s;%.4g",v.name,ep,gp,pr))
      if self._fileexport then
        local entry = {}
        entry[L["Name"]] = v.name
        entry[L["ep"]] = ep
        entry[L["gp"]] = gp
        entry[L["pr"]] = tonumber(string.format("%.4g",pr))
        table.insert(temp_data, entry)
      end
    end
  end
  self._iostandings:Display()
  self:export("Standings", temp_data, keys, ";")
end

function bsloot_io:Loot(loot_indices)
  local keys
  self._ioloot:Clear()
  self._ioloot:AddLine(string.format("%s;%s;%s;%s",L["Time"],L["Item"],L["Looter"],L["GP Action"]))
  if self._fileexport then
    table.wipe(temp_data)
    keys = {L["Time"],L["Item"],L["Looter"],L["GP Action"]}
  end
  for i,data in ipairs(bsloot.db.char.loot) do
    local time = data[loot_indices.time]
    local item = data[loot_indices.item]
    local itemColor, itemString, itemName, itemID = bsloot:getItemData(item)
    local looter = data[loot_indices.player]
    local action = data[loot_indices.action]
    if action == bsloot.VARS.msgp or action == bsloot.VARS.osgp or action == bsloot.VARS.bankde then
      self._ioloot:AddLine(string.format("%s;%s;%s;%s",time,itemName,looter,action))
      if self._fileexport then
        local entry = {}
        entry[L["Time"]] = time
        entry[L["Item"]] = itemName
        entry[L["Looter"]] = looter
        entry[L["GP Action"]] = action
        table.insert(temp_data, entry)
      end
    end
  end
  self._ioloot:Display()
  self:export("Loot", temp_data, keys, ";")
end

function bsloot_io:Logs()
  local keys
  self._iologs:Clear()
  self._iologs:AddLine(string.format("%s;%s",L["Time"],L["Action"]))
  if self._fileexport then
    table.wipe(temp_data)
    keys = {L["Time"],L["Action"]}
  end
  for i,data in ipairs(bsloot.db.char.logs) do
    self._iologs:AddLine(string.format("%s;%s",data[1],data[2]))
    if self._fileexport then
      local entry = {}
      entry[L["Time"]] = data[1]
      entry[L["Action"]] = data[2]
      table.insert(temp_data, entry)
    end
  end
  self._iologs:Display()
  self:export("Logs", temp_data, ";")
end

function bsloot_io:export(context,data,keys,sep)
  if not self._fileexport then return end
  if context == "Standings" then
    table.sort(data, function(a,b)
      return a[L["pr"]] > b[L["pr"]]
    end)
  end
  self._fileexport[context] = {}
  self._fileexport[context].JSON = Parse:JSONEncode(data)
  self._fileexport[context].CSV = Parse:CSVEncode(keys, data, sep)
end

function bsloot_io:StandingsImport()
  if not IsGuildLeader() then return end
end
