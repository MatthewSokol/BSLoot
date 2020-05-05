local addonName, bsloot = ...
local moduleName = addonName.."_browser"
local bsloot_browser = bsloot:NewModule(moduleName, "AceEvent-3.0")
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
local slotfilterOptions = {["ANY"]=C:White(L["Any"]), ["_AUTO_ROLL"]=C:Green(L["AutoRoll"]), ["_AUTO_PASS"]=C:Yellow(L["AutoPass"]), ["_NO_AUTO"]=C:Yellow(L["No Auto Roll/Pass"]), }
local locsorted = {"_AUTO_ROLL", "_AUTO_PASS", "_NO_AUTO", "ANY","INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CHEST", "INVTYPE_ROBE", "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_CLOAK", "INVTYPE_WEAPON", "INVTYPE_SHIELD", "INVTYPE_2HWEAPON", "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_HOLDABLE", "INVTYPE_RANGED", "INVTYPE_THROWN", "INVTYPE_RANGEDRIGHT", "INVTYPE_RELIC"}

local questionblue = CreateAtlasMarkup("QuestRepeatableTurnin")

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

local favmap = bsloot._favmap
local menu_close = function()
  if bsloot_browser._ddmenu then
    bsloot_browser._ddmenu:Release()
  end
end
local favorite_options = {
  type = "group",
  name = L["BSLoot options"],
  desc = L["BSLoot options"],
  handler = bsloot_browser,
  args = { 
    ["1"] = {
      type = "execute",
      name = L["Add AutoRoll"],
      desc = L["Add AutoRoll"],
      order = 1,
      func = function(info)
        autoRollItems[bsloot_browser._selected]=1
        autoPassItems[bsloot_browser._selected]=nil
        bsloot_browser:Refresh()
        C_Timer.After(0.2, menu_close)
      end,
    },
    ["0"] = {
      type = "execute",
      name = L["Remove AutoRoll/AutoPass"],
      desc = L["Remove AutoRoll/AutoPass"],
      order = 2,
      func = function(info)
        autoRollItems[bsloot_browser._selected]=nil
        autoPassItems[bsloot_browser._selected]=nil
        bsloot_browser:Refresh()
        C_Timer.After(0.2, menu_close)
      end,
    },
    ["-1"] = {
      type = "execute",
      name = L["Add AutoPass"],
      desc = L["Add AutoPass"],
      order = 3,
      func = function(info)

        autoRollItems[bsloot_browser._selected]=nil
        autoPassItems[bsloot_browser._selected]=1
        bsloot_browser:Refresh()
        C_Timer.After(0.2, menu_close)
      end,
    },
    ["cancel"] = {
      type = "execute",
      name = _G.CANCEL,
      desc = _G.CANCEL,
      order = 4,
      func = function(info)
        C_Timer.After(0.2, menu_close)
      end,
    }
  }  
}
local item_interact = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
  if not realrow then return false end
  local itemId = GetItemInfoInstant(data[realrow].cols[1].value)
  if itemId then
    bsloot_browser._selected = tonumber(itemId)
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
    elseif button == "RightButton" then
      if bsloot_browser._selected then
        bsloot_browser._ddmenu = LDD:OpenAce3Menu(favorite_options)
        bsloot_browser._ddmenu:SetPoint("CENTER", cellFrame, "CENTER", 0,0)
        return true
      end      
    end
  end
  return false
end
local item_onenter = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
  if not realrow then return false end
  local itemId = GetItemInfoInstant(data[realrow].cols[1].value)
  if itemId then
    GameTooltip:SetOwner(rowFrame,"ANCHOR_TOP")
    GameTooltip:SetItemByID(itemId)
    GameTooltip:Show()
  end
end
local item_onleave = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
  if not realrow then return false end
  if GameTooltip:IsOwned(rowFrame) then
    GameTooltip_Hide()
  end
end

function bsloot_browser:OnEnable()
  local container = GUI:Create("Window")
  container:SetTitle(L["BSLoot Browser"])
  container:SetWidth(940)
  container:SetHeight(290)
  container:EnableResize(false)
  container:SetLayout("List")
  container:Hide()
  self._container = container
  local headers = {
    {["name"]=C:Orange(_G.ITEMS),["width"]=150,["comparesort"]=st_sorter_itemName}, --name
    {["name"]=C:Orange(L["Item Type"]),["width"]=80}, --type
    {["name"]=C:Orange(L["Base GP"]),["width"]=80}, --ms_gp
    {["name"]=C:Orange(L["Raid"]),["width"]=60,}, --raid
    {["name"]=C:Orange(L["AutoRoll/AutoPass"]),["width"]=60}, -- auto roll/pass
    {["name"]=C:Orange(L["Roll Type"]),["width"]=60,["sort"]=ST.SORT_DSC}, -- rollType
    {["name"]=C:Orange(L["Roll Mods"]),["width"]=80}, -- rollMods
    {["name"]=C:Orange(L["EffPR"]),["width"]=60}, -- effectivePR
    {["name"]=C:Orange(L["Your GP"]),["width"]=60}, -- personalGp
  }
  self._browser_table = ST:CreateST(headers,15,nil,colorHighlight,container.frame) -- cols, numRows, rowHeight, highlight, parent
  self._browser_table:EnableSelection(true)
  self._browser_table:RegisterEvents({
    ["OnClick"] = item_interact,
    ["OnEnter"] = item_onenter,
    ["OnLeave"] = item_onleave,
  })
  self._browser_table.frame:SetPoint("BOTTOMRIGHT",self._container.frame,"BOTTOMRIGHT", -10, 10)
  container:SetCallback("OnShow", function() bsloot_browser._browser_table:Show() end)
  container:SetCallback("OnClose", function() bsloot_browser._browser_table:Hide() end)
  
  local filterslots = GUI:Create("Dropdown")
  filterslots:SetList(slotfilterOptions)
  filterslots:SetValue("_AUTO_ROLL")
  filterslots:SetCallback("OnValueChanged", function(obj, event, choice)
    bsloot_browser:Refresh()
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
    bsloot_browser:Refresh()
  end)
  filterRaid:SetLabel(L["Filter by Raid"])
  filterRaid:SetWidth(150)
  filterRaid:SetMultiselect(true)
  self._container._filterRaid = filterRaid
  container:AddChild(filterRaid)

  local reloadDataButton = GUI:Create("Button")
  reloadDataButton:SetText(L["Reload Data"])
  reloadDataButton:SetAutoWidth(true)
  reloadDataButton:SetCallback("OnClick",function()
    bsloot_browser:ReInit()
  end)
  container:AddChild(reloadDataButton)

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

function bsloot_browser:Toggle()
  if self._container.frame:IsShown() then
    self._container:Hide()
  else
    self._container:Show()
  end
  self:Refresh()
end

function bsloot_browser:Hide()
  if self._container.frame:IsShown() then
    self._container:Hide()
  end
  self:Refresh()
end

function bsloot_browser:Show()
  if not self._container.frame:IsShown() then
    self._container:Show()
  end
  self:Refresh()
end

bsloot_browser.colors = {}
bsloot_browser.colors.red = {r=1.0,g=0,b=0,a=1.0}
bsloot_browser.colors.yellow = {r=1.0,g=1.0,b=0,a=1.0}
bsloot_browser.colors.green = {r=0,g=1.0,b=0,a=1.0}
function bsloot_browser:populate(data,link,subtype,baseGp,raid,autoRoll, autoPass, personalGp)
  
  local epGpSummary = bsloot:getEpGpSummary(bsloot._playerName)
  local rollType, rollMods, effectivePr = bsloot:getRollType(bsloot._playerName, link, epGpSummary.PR, epGpSummary.isMain)
  local autoCol = {["value"]=autoString}
  if(autoRoll and not autoPass) then
    autoCol.value = "AutoRoll"
    autoCol.color = bsloot_browser.colors.green
  elseif(autoPass and not autoRoll) then
    autoCol.value = "AutoPass"
    autoCol.color = bsloot_browser.colors.yellow
  elseif(autoPass or autoRoll) then
    autoCol.value = "Confused"
    autoCol.color = bsloot_browser.colors.red
  end
  table.insert(data,{["cols"]={
    {["value"]=link},
    {["value"]=subtype},
    {["value"]=baseGp},
    {["value"]=raid},
    autoCol,
    {["value"]=rollType},
    {["value"]=rollMods},
    {["value"]=effectivePr},
    {["value"]=personalGp},
  }})
end

function bsloot_browser:Refresh()
  local slotvalue = self._container._filterslots:GetValue() or "_AUTO_ROLL" --Slot values are multiselect nos
  for i, widget in self._container._filterRaid.pullout:IterateItems() do
    if widget.GetValue and widget.userdata.value then
      activeRaidFilters[widget.userdata.value] = widget:GetValue()
    end
  end
  table.wipe(subdata)
  if slotvalue == "_AUTO_ROLL" then
    for id, _ in pairs(autoRollItems) do
      local entryId = bsloot:buildEpGpEventReasonKey(bsloot.statics.eventType.GP_VAL, bsloot.statics.EPGP.LOOT, id)
      if(ItemGPCost[entryId] and ItemGPCost[entryId] ~= nil) then
        local slot = ItemGPCost[entryId].slot
        local raid = ItemGPCost[entryId].raid
        local price, basePrice = bsloot_prices:GetPrice(id,bsloot._playerName)
        
        local autoPass = autoPassItems[id]
        local autoRoll = autoRollItems[id]
        bsloot:doWithItemInfo(id, function(itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
          itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
          isCraftingReagent, itemId)
  
          bsloot_browser:populate(subdata,itemLink,itemSubType,basePrice,raid,autoRoll,autoPass,price)
        
        end)
        
      else
        bsloot:debugPrint("No entry for AutoRoll ItemId: "..id, bsloot.statics.LOGS.FAVORITES)
      end
    end
  elseif slotvalue == "_AUTO_PASS" then
    for id, _ in pairs(autoPassItems) do
      local entryId = bsloot:buildEpGpEventReasonKey(bsloot.statics.eventType.GP_VAL, bsloot.statics.EPGP.LOOT, id)
      if(ItemGPCost[entryId] and ItemGPCost[entryId] ~= nil) then
        local slot = ItemGPCost[entryId].slot
        local raid = ItemGPCost[entryId].raid
        local price, basePrice = bsloot_prices:GetPrice(id,bsloot._playerName)
        
        local autoPass = autoPassItems[id]
        local autoRoll = autoRollItems[id]
        bsloot:doWithItemInfo(id, function(itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
          itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
          isCraftingReagent, itemId)
  
          bsloot_browser:populate(subdata,itemLink,itemSubType,basePrice,raid,autoRoll,autoPass,price)
        
        end)
        
      else
        bsloot:debugPrint("No entry for AutoPass ItemId: "..id, bsloot.statics.LOGS.FAVORITES)
      end
    end
  elseif slotvalue == "_NO_AUTO" then
    for _, info in ipairs(data) do
      local id,price,basePrice,raid = info[1],info[2],info[3],info[4]
      if(activeRaidFilters[raid] and (not autoPassItems[id] or autoPassItems[id] == nil) and (not autoRollItems[id] or autoRollItems[id] == nil))then
        local autoPass = autoPassItems[id]
        local autoRoll = autoRollItems[id]
        bsloot:doWithItemInfo(id, function(itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
          itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
          isCraftingReagent, itemId)
  
          bsloot_browser:populate(subdata,itemLink,itemSubType,basePrice,raid,autoRoll,autoPass,price)
        
        end)
      end
    end
  elseif slotvalue == "ANY" then
    for _, subset in pairs(data) do
      bsloot_browser:populate_subset(subset, activeRaidFilters, subdata)
    end
  else
    bsloot_browser:populate_subset(data[slotvalue], activeRaidFilters, subdata)
  end
  self._browser_table:SetData(subdata)  
  if self._browser_table and self._browser_table.showing then
    self._browser_table:SortData()
  end
end

function bsloot_browser:populate_subset(subset, activeRaidFilters, subdata)
  
  for _, info in pairs(subset) do
    local id,price,basePrice,raid = info[1],info[2],info[3],info[4]
    if activeRaidFilters[raid] then
      local autoPass = autoPassItems[id]
      local autoRoll = autoRollItems[id]
      bsloot:doWithItemInfo(id, function(itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
        itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
        isCraftingReagent, itemId)

        bsloot_browser:populate(subdata,itemLink,itemSubType,basePrice,raid,autoRoll,autoPass,price)
      
      end)
    end
  end
end

function bsloot_browser:CoreInit()
  if not self._initDone then
    autoRollItems = bsloot.db.char.autoRollItems
    autoPassItems = bsloot.db.char.autoPassItems
    bsloot_browser:cleanBadFavorites()
    bsloot_browser:ReInit()

    self._container._filterslots:SetList(slotfilterOptions,locsorted)
    self._container._filterslots:SetValue("ANY")
    self._initDone = true
  end
end

function bsloot_browser:cleanBadFavorites()
  for id, _ in pairs(autoRollItems) do
    if(tonumber(id) < 1000) then
      autoRollItems[id] = nil
    end
  end
  for id, _ in pairs(autoPassItems) do
    if(tonumber(id) < 1000) then
      autoPassItems[id] = nil
    end
  end
end

function bsloot_browser:ReInit()
  data = {}
  locsorted = {"ANY", "_AUTO_ROLL", "_AUTO_PASS", "_NO_AUTO", "Unknown", "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CHEST", "INVTYPE_ROBE", "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_CLOAK", "INVTYPE_WEAPON", "INVTYPE_SHIELD", "INVTYPE_2HWEAPON", "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_HOLDABLE", "INVTYPE_RANGED", "INVTYPE_THROWN", "INVTYPE_RANGEDRIGHT", "INVTYPE_RELIC"}

  local count = 0
  local epGpSummary = bsloot:getEpGpSummary(bsloot._playerName)

  for _,info in pairs(ItemGPCost) do
    local raid = info.raid
    if(not raid or raid == nil) then raid = "Unknown" end
    local itemId, itemType, itemSubType, itemEquipLoc, icon, itemClassID, itemSubClassID = GetItemInfoInstant(info.link)
    
    bsloot_browser:autoDetectAutoPass(info.link, itemId, epGpSummary)
    pcall(function()
      local price, basePrice = bsloot_prices:GetPrice(itemId,bsloot._playerName)
      if not itemEquipLoc or itemEquipLoc == nil or itemEquipLoc == "" then itemEquipLoc = "Unknown" end
      if itemEquipLoc == "INVTYPE_ROBE" then itemEquipLoc = "INVTYPE_CHEST" end
      data[itemEquipLoc] = data[itemEquipLoc] or {}
      table.insert(data[itemEquipLoc],{itemId,price,basePrice,raid})
      local equipLocDesc = _G[itemEquipLoc]
      if itemEquipLoc == "INVTYPE_SHIELD" then equipLocDesc = _G["SHIELDSLOT"] end
      if itemEquipLoc == "MISC" then equipLocDesc = L["Miscellaneous"] end
      if itemEquipLoc == "Unknown" then equipLocDesc = L["Unknown"] end
      if itemEquipLoc == "INVTYPE_RANGEDRIGHT" then equipLocDesc = _G["INVTYPE_RANGED"].."2" end
      slotfilterOptions[itemEquipLoc] = equipLocDesc
      count = count+1
    end)
  end
  bsloot:debugPrint("Loaded "..count.." items into the browser", bsloot.statics.LOGS.FAVORITES)
  for i=#(locsorted),1,-1 do
    local loc = locsorted[i]
    if loc ~= "_AUTO_ROLL" and loc ~= "_AUTO_PASS" and loc ~= "_NO_AUTO" and loc ~= "ANY" and slotfilterOptions[loc]==nil then
      table.remove(locsorted,i)
    end
  end
end

function bsloot_browser:autoDetectAutoPass(itemLink, itemId, epGpSummary)
  if(not autoPassItems[itemId] or autoPassItems[itemId] == nil or not autoRollItems[itemId] or autoRollItems[itemId] == nil) then
    local success, rollTypeOrErr = pcall(function()
      return bsloot:getRollType(bsloot._playerName, itemLink, epGpSummary.PR, epGpSummary.isMain)
    end)
    if(success) then
      if(rollTypeOrErr == -3) then
        autoPassItems[itemId]=1
      else 
      end
    end
  end
end
