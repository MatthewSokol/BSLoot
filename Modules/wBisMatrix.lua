local addonName, bsloot = ...
local moduleName = addonName.."_bismatrix"
local bsloot_bismatrix = bsloot:NewModule(moduleName, "AceEvent-3.0")
local ST = LibStub("ScrollingTable")
local LDD = LibStub("LibDropdown-1.0")
local C = LibStub("LibCrayon-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local GUI = LibStub("AceGUI-3.0")
local Item = Item
local data, subdata = { }, { }
local colorHighlight = {r=0, g=0, b=0, a=.9}
local autoRollItems
local autoPassItems 
local activeRaidFilters = { }
local slotfilterOptions = {["ANY"]=C:White(L["Any"]),}
local locsorted = {"ANY","INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CHEST", "INVTYPE_ROBE", "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_CLOAK", "INVTYPE_WEAPON", "INVTYPE_SHIELD", "INVTYPE_2HWEAPON", "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_HOLDABLE", "INVTYPE_RANGED", "INVTYPE_THROWN", "INVTYPE_RANGEDRIGHT", "INVTYPE_RELIC"}

local questionblue = CreateAtlasMarkup("QuestRepeatableTurnin")

local function st_sorter_numeric(st,rowa,rowb,col)

end

local item_interact = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
  if not realrow then return false end
  local itemID = GetItemInfoInstant(data[realrow].cols[1].value)
  if itemID then
    bsloot_bismatrix._selected = tonumber(itemID)
    local link = data[realrow].cols[1].value
    if button == "LeftButton" then
      if IsModifiedClick("DRESSUP") then
        return DressUpItemLink(link)
      elseif IsModifiedClick("CHATLINK") then
        if ( ChatEdit_InsertLink(link) ) then
          return true
        end
      else
        return false
      end 
    end
  end
  return false
end
local item_onenter = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
  if not realrow then return false end
  local itemID = GetItemInfoInstant(data[realrow].cols[1].value)
  if itemID then
    GameTooltip:SetOwner(rowFrame,"ANCHOR_TOP")
    GameTooltip:SetItemByID(itemID)
    GameTooltip:Show()
  end
end
local item_onleave = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
  if not realrow then return false end
  if GameTooltip:IsOwned(rowFrame) then
    GameTooltip_Hide()
  end
end

local function st_sorter_itemName(st,rowa,rowb,col)
  local cella = st.data[rowa].cols[col].value
  local cellb = st.data[rowb].cols[col].value
  local sort = st.cols[col].sort or st.cols[col].defaultsort
  
  if cella == cellb then
    local sortnext = st.cols[col].sortnext
    if sortnext then
      return st.data[rowa].cols[sortnext].value < st.data[rowb].cols[sortnext].value
    end
  else
    local itemNameA = GetItemInfo(cella)
    local itemNameB = GetItemInfo(cellb)
    if sort == ST.SORT_DSC then
      return itemNameA > itemNameB
    else
      return itemNameA < itemNameB
    end
  end
end

function bsloot_bismatrix:OnEnable()
  local container = GUI:Create("Window")
  container:SetTitle(L["BSLoot Browser"])
  container:SetWidth(1700)
  container:SetHeight(300)
  container:EnableResize(false)
  container:SetLayout("List")
  container:Hide()
  local BASE_COL_WIDTH = 75
  self._container = container
  local headers = {
    {["name"]=C:Orange(_G.ITEMS),["width"]=150,["comparesort"]=st_sorter_itemName,["sort"]=ST.SORT_ASC}, --name
    {["name"]=C:Orange(L["Base GP"]),["width"]=80}, --base_gp
    {["name"]=C:Orange(L["Raid"]),["width"]=45,}, --raid
    {["name"]=C:Orange(L["Warrior Tank"]),["width"]=BASE_COL_WIDTH}, -- 
    {["name"]=C:Orange(L["Warrior OT"]),["width"]=BASE_COL_WIDTH},
    {["name"]=C:Orange(L["Warrior MDPS"]),["width"]=BASE_COL_WIDTH},
    {["name"]=C:Orange(L["Hunter RDPS"]),["width"]=BASE_COL_WIDTH}, 
    {["name"]=C:Orange(L["Shaman Healer"]),["width"]=BASE_COL_WIDTH+10}, 
    {["name"]=C:Orange(L["Shaman MDPS"]),["width"]=BASE_COL_WIDTH+5}, 
    {["name"]=C:Orange(L["Shaman RDPS"]),["width"]=BASE_COL_WIDTH}, 
    {["name"]=C:Orange(L["Druid Tank"]),["width"]=BASE_COL_WIDTH}, 
    {["name"]=C:Orange(L["Druid MDPS"]),["width"]=BASE_COL_WIDTH}, 
    {["name"]=C:Orange(L["Druid Healer"]),["width"]=BASE_COL_WIDTH}, 
    {["name"]=C:Orange(L["Druid RDPS"]),["width"]=BASE_COL_WIDTH}, 
    {["name"]=C:Orange(L["Rogue MDPS"]),["width"]=BASE_COL_WIDTH}, 
    {["name"]=C:Orange(L["Priest Healer"]),["width"]=BASE_COL_WIDTH}, 
    {["name"]=C:Orange(L["Priest RDPS"]),["width"]=BASE_COL_WIDTH}, 
    {["name"]=C:Orange(L["Warlock RDPS"]),["width"]=BASE_COL_WIDTH}, 
    {["name"]=C:Orange(L["Mage RDPS"]),["width"]=BASE_COL_WIDTH}, 
  }
  self._bismatrix_table = ST:CreateST(headers,15,nil,colorHighlight,container.frame) -- cols, numRows, rowHeight, highlight, parent
  self._bismatrix_table:EnableSelection(true)
  self._bismatrix_table:RegisterEvents({
    ["OnClick"] = item_interact,
    ["OnEnter"] = item_onenter,
    ["OnLeave"] = item_onleave,
  })
  self._bismatrix_table.frame:SetPoint("BOTTOMRIGHT",self._container.frame,"BOTTOMRIGHT", -10, 10)
  container:SetCallback("OnShow", function() bsloot_bismatrix._bismatrix_table:Show() end)
  container:SetCallback("OnClose", function() bsloot_bismatrix._bismatrix_table:Hide() end)
  
  local filterslots = GUI:Create("Dropdown")
  filterslots:SetList(slotfilterOptions)
  filterslots:SetValue("_AUTO_ROLL")
  filterslots:SetCallback("OnValueChanged", function(obj, event, choice)
    bsloot_bismatrix:Refresh()
  end)
  filterslots:SetLabel(L["Filter by Slot"])
  filterslots:SetWidth(150)
  self._container._filterslots = filterslots
  container:AddChild(filterslots)

  local filterRaid = GUI:Create("Dropdown")
  filterRaid:SetList(
    {["MC"]="MC",["BWL"]="BWL", ["Onyxia"]="Onyxia",["ZG"]="ZG",["AQ20"]="AQ20",["AQ40"]="AQ40",["Naxxramas"]="Naxxramas",["World"]="World Bosses",["Unknown"]="Unknown Raid"},
    {"MC","Onyxia","BWL","ZG","AQ20","AQ40","Naxxramas","World", "Unknown"}
  )

  filterRaid:SetCallback("OnValueChanged", function(obj, event, choice, checked)
    bsloot_bismatrix:Refresh()
  end)
  filterRaid:SetLabel(L["Filter by Raid"])
  filterRaid:SetWidth(150)
  filterRaid:SetMultiselect(true)
  self._container._filterRaid = filterRaid
  container:AddChild(filterRaid)


  local help = GUI:Create("Label")
  help:SetWidth(150)
  help:SetText("\n\n"..string.format("%s%s",questionblue,L["Right-click a row to add or remove a Favorite"]))
  help:SetColor(1,1,0)
  help:SetJustifyV("TOP")
  help:SetJustifyH("CENTER")
  self._container._help = help
  container:AddChild(help)

  bsloot:make_escable(container,"add")
  self:RegisterMessage(addonName.."_INIT_DONE","CoreInit")
end

function bsloot_bismatrix:Toggle()
  if self._container.frame:IsShown() then
    self._container:Hide()
  else
    self._container:Show()
  end
  self:Refresh()
end

function bsloot_bismatrix:Hide()
  if self._container.frame:IsShown() then
    self._container:Hide()
  end
  self:Refresh()
end

function bsloot_bismatrix:Show()
  if not self._container.frame:IsShown() then
    self._container:Show()
  end
  self:Refresh()
end

function bsloot_bismatrix:populate(subdata, link,baseGp,raid,bisThrough)
  
  table.insert(subdata,{["cols"]={
    {["value"]=link},
    {["value"]=baseGp},
    {["value"]=raid},
    {["value"]=bsloot_bismatrix:getFromBisThrough(bisThrough,"Warrior","Tank")},
    {["value"]=bsloot_bismatrix:getFromBisThrough(bisThrough,"Warrior","OT")},
    {["value"]=bsloot_bismatrix:getFromBisThrough(bisThrough,"Warrior","MDPS")},
    {["value"]=bsloot_bismatrix:getFromBisThrough(bisThrough,"Hunter","RDPS")},
    {["value"]=bsloot_bismatrix:getFromBisThrough(bisThrough,"Shaman","Healer")},
    {["value"]=bsloot_bismatrix:getFromBisThrough(bisThrough,"Shaman","MDPS")},
    {["value"]=bsloot_bismatrix:getFromBisThrough(bisThrough,"Shaman","RDPS")},
    {["value"]=bsloot_bismatrix:getFromBisThrough(bisThrough,"Druid","Tank")},
    {["value"]=bsloot_bismatrix:getFromBisThrough(bisThrough,"Druid","MDPS")},
    {["value"]=bsloot_bismatrix:getFromBisThrough(bisThrough,"Druid","Healer")},
    {["value"]=bsloot_bismatrix:getFromBisThrough(bisThrough,"Druid","RDPS")},
    {["value"]=bsloot_bismatrix:getFromBisThrough(bisThrough,"Rogue","MDPS")},
    {["value"]=bsloot_bismatrix:getFromBisThrough(bisThrough,"Priest","Healer")},
    {["value"]=bsloot_bismatrix:getFromBisThrough(bisThrough,"Priest","RDPS")},
    {["value"]=bsloot_bismatrix:getFromBisThrough(bisThrough,"Warlock","RDPS")},
    {["value"]=bsloot_bismatrix:getFromBisThrough(bisThrough,"Mage","RDPS")},
  }})
end

function  bsloot_bismatrix:getFromBisThrough(bisThrough, class, spec)
  if(bisThrough and bisThrough ~= nil and class and class ~= nil and spec and spec ~= nil and bisThrough[class] and bisThrough[class] ~= nil) then
    return bisThrough[class][spec]
  end
end

function bsloot_bismatrix:Refresh()
  local slotvalue = self._container._filterslots:GetValue() or "_AUTO_ROLL" --Slot values are multiselect nos
  for i, widget in self._container._filterRaid.pullout:IterateItems() do
    if widget.GetValue and widget.userdata.value then
      activeRaidFilters[widget.userdata.value] = widget:GetValue()
    end
  end
  table.wipe(subdata)
  if slotvalue == "ANY" then
    for _, subset in pairs(data) do
      bsloot_bismatrix:populate_subset(subset, activeRaidFilters, subdata)
    end
  else
    bsloot_bismatrix:populate_subset(data[slotvalue], activeRaidFilters, subdata)
  end
  self._bismatrix_table:SetData(subdata)  
  if self._bismatrix_table and self._bismatrix_table.showing then
    self._bismatrix_table:SortData()
  end
end

function bsloot_bismatrix:populate_subset(subset, activeRaidFilters, subdata)
  
  for _, info in pairs(subset) do
    local id,basePrice,raid = info[1],info[2],info[3]
    if activeRaidFilters[raid] then
      
      bsloot:doWithItemInfo(id, function(itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
        itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
        isCraftingReagent, itemId) 
      
        local entryId = bsloot:buildEpGpEventReasonKey(bsloot.statics.eventType.BIS_MATRIX, bsloot.statics.EPGP.LOOT, itemId)
        bsloot_bismatrix:populate(subdata, itemLink,basePrice,raid, BisMatrix[entryId].bisThrough)
        
      end)

    end
  end
end

function bsloot_bismatrix:CoreInit()
  if not self._initDone then
    autoRollItems = bsloot.db.char.autoRollItems
    autoPassItems = bsloot.db.char.autoPassItems
    
    bsloot_bismatrix:ReInit()

    self._container._filterslots:SetList(slotfilterOptions,locsorted)
    self._container._filterslots:SetValue("ANY")
    self._initDone = true
  end
end

function bsloot_bismatrix:ReInit()
  data = {}
  locsorted = {"ANY", "Unknown", "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CHEST", "INVTYPE_ROBE", "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_CLOAK", "INVTYPE_WEAPON", "INVTYPE_SHIELD", "INVTYPE_2HWEAPON", "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_HOLDABLE", "INVTYPE_RANGED", "INVTYPE_THROWN", "INVTYPE_RANGEDRIGHT", "INVTYPE_RELIC"}

  local count = 0
  for key,info in pairs(ItemGPCost) do
    local raid = info.raid
    if(not raid or raid == nil) then raid = "Unknown" end
    local itemID, itemType, itemSubType, itemEquipLoc, icon, itemClassID, itemSubClassID = GetItemInfoInstant(info.link)
    pcall(function()
      local _, basePrice = bsloot_prices:GetPrice(itemID,bsloot._playerName)
      if not itemEquipLoc or itemEquipLoc == nil or itemEquipLoc == "" then itemEquipLoc = "Unknown" end
      if itemEquipLoc == "INVTYPE_ROBE" then itemEquipLoc = "INVTYPE_CHEST" end
      data[itemEquipLoc] = data[itemEquipLoc] or {}
      table.insert(data[itemEquipLoc],{itemID,basePrice,raid})
      local equipLocDesc = _G[itemEquipLoc]
      if itemEquipLoc == "INVTYPE_SHIELD" then equipLocDesc = _G["SHIELDSLOT"] end
      if itemEquipLoc == "MISC" then equipLocDesc = L["Miscellaneous"] end
      if itemEquipLoc == "Unknown" then equipLocDesc = L["Unknown"] end
      if itemEquipLoc == "INVTYPE_RANGEDRIGHT" then equipLocDesc = _G["INVTYPE_RANGED"].."2" end
      slotfilterOptions[itemEquipLoc] = equipLocDesc
      count = count+1
    end)
  end
  bsloot:debugPrint("Loaded "..count.." items into the bis matrix browser", bsloot.statics.LOGS.LOOT)
  for i=#(locsorted),1,-1 do
    local loc = locsorted[i]
    if loc ~= "_AUTO_ROLL" and loc ~= "_AUTO_PASS" and loc ~= "ANY" and slotfilterOptions[loc]==nil then
      table.remove(locsorted,i)
    end
  end
end
