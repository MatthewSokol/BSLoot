local addonName, bsloot = ...
local moduleName = addonName.."_rosterdetails"
local bsloot_rosterdetails = bsloot:NewModule(moduleName)
local ST = LibStub("ScrollingTable")
local C = LibStub("LibCrayon-3.0")
local LD = LibStub("LibDialog-1.0")
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

function bsloot_rosterdetails:OnEnable()
  bsloot_rosterdetails:setupRosterWindow()
  bsloot_rosterdetails:setupRoleSetterWindow()
end

function bsloot_rosterdetails:setupRosterWindow()

  local container = GUI:Create("Window")
  container:SetTitle(L["BSLoot Roster"])
  container:SetWidth(640)
  container:SetHeight(290)
  container:EnableResize(false)
  container:SetLayout("List")
  container:Hide()
  self._container = container
  local headers = {
    {["name"]=C:Orange(_G.NAME),["width"]=100}, --name
    {["name"]=C:Orange(L["Class"]),["width"]=60,["sortnext"]=1}, --Class
    {["name"]=C:Orange(L["Role"]:upper()),["width"]=75}, --Role
    {["name"]=C:Orange(L["PR"]:upper()),["width"]=75,["comparesort"]=st_sorter_numeric}, --pr
    {["name"]=C:Orange(L["isMain"]),["width"]=40}, --isMain
  }
  self._rosterdetails_table = ST:CreateST(headers,15,nil,colorHighlight,container.frame) -- cols, numRows, rowHeight, highlight, parent
  self._rosterdetails_table.frame:SetPoint("BOTTOMRIGHT",self._container.frame,"BOTTOMRIGHT", -10, 10)
  self._rosterdetails_table:EnableSelection(true)
  container:SetCallback("OnShow", function() bsloot_rosterdetails._rosterdetails_table:Show() end)
  container:SetCallback("OnClose", function() bsloot_rosterdetails._rosterdetails_table:Hide() end)
  
  local raid_only = GUI:Create("CheckBox")
  raid_only:SetLabel(L["Raid Only"])
  raid_only:SetValue(bsloot.db.char.raidonly)
  raid_only:SetCallback("OnValueChanged", function(widget,callback,value)
    bsloot.db.char.raidonly = value
    bsloot_rosterdetails:Refresh()
  end)
  container:AddChild(raid_only)
  self._widgetraid_only = raid_only

  local updateRoleButton = GUI:Create("Button")
  updateRoleButton:SetAutoWidth(true)
  updateRoleButton:SetText(L["Update Character Raid Role"])
  updateRoleButton:SetCallback("OnClick",function()

    local selected = self._rosterdetails_table:GetSelection()
    if(selected and selected ~= nil and selected > 0) then
      local selectedRow = self._rosterdetails_table:GetRow(selected)
      bsloot:debugPrint("Selected row: "..bsloot:tableToString(selectedRow), 7)
      bsloot_rosterdetails.selectedName = selectedRow.cols[1].value
      bsloot_rosterdetails.selectedClass = selectedRow.cols[2].value
      bsloot_rosterdetails.selectedRole = selectedRow.cols[3].value
      bsloot_rosterdetails:populateRoleSetter(bsloot_rosterdetails.selectedName, bsloot_rosterdetails.selectedClass, bsloot_rosterdetails.selectedRole)
    else
      bsloot:debugPrint("Select a player", 1)
    end
  end)
  if(bsloot:isAdmin()) then
    container:AddChild(updateRoleButton)
  else
    updateRoleButton:SetDisabled(true)
  end
  self._updateRoleButton = updateRoleButton

  bsloot:make_escable(container,"add")
end

function bsloot_rosterdetails:setupRoleSetterWindow()

  local container = GUI:Create("Window")
  container:SetTitle(L["BSLoot Role"])
  container:SetWidth(300)
  container:SetHeight(180)
  container:EnableResize(false)
  container:SetLayout("List")
  container:Hide()
  self._container_rolesetter = container
  
  self._roleLabel = GUI:Create("Label")
  self._roleLabel:SetText("No player selected")
  self._container_rolesetter:AddChild(self._roleLabel)
  
  self._roleDD = GUI:Create("Dropdown")
  self._roleDD:SetLabel("Role")
  self._roleDD:SetText("No role selected")
  self._roleDD:SetList({})
  self._container_rolesetter:AddChild(self._roleDD)
  
  self._mainCharInput = GUI:Create("EditBox")
  self._mainCharInput:SetLabel("Main Character")
  self._mainCharInput:SetText("")
  self._container_rolesetter:AddChild(self._mainCharInput)

  local commitRoleButton = GUI:Create("Button")
  commitRoleButton:SetAutoWidth(true)
  commitRoleButton:SetText(L["Ok"])
  commitRoleButton:SetCallback("OnClick",function()
    local newRole = self._roleDD:GetValue()
    bsloot:saveSingleCharacter(bsloot_rosterdetails.selectedName, bsloot_rosterdetails.selectedClass, newRole, bsloot_rosterdetails._mainCharInput:GetText())
    bsloot_rosterdetails:resetRoleSetter()
    bsloot_rosterdetails:Refresh()
  end)
  if(not bsloot:isAdmin()) then
    commitRoleButton:SetDisabled(true)
  end
  container:AddChild(commitRoleButton)
  self._commitRoleButton = commitRoleButton

  bsloot:make_escable(container,"add")
end
function bsloot_rosterdetails:resetRoleSetter() 
  self._roleLabel:SetText("No player selected")
  self._roleDD:SetText("No role selected")
  self._roleDD:SetList({})
  self._mainCharInput:SetText("")
  if self._container_rolesetter.frame:IsShown() then
    self._container_rolesetter:Hide()
  end
end
bsloot_rosterdetails.ClassRoles = {
  WARRIOR = {
    Tank = "Tank",
    OT = "OT",
    MDPS = "MDPS",
  },
  HUNTER = {
    RDPS = "RDPS",
  },
  SHAMAN = {
    MDPS = "MDPS",
    RDPS = "RDPS",
    Healer = "Healer",
  },
  DRUID = {
    Tank = "Tank",
    MDPS = "MDPS",
    RDPS = "RDPS",
    Healer = "Healer",
  },
  ROGUE = {
    MDPS = "MDPS",
  },
  PRIEST = {
    RDPS = "RDPS",
    Healer = "Healer",
  },
  WARLOCK = {
    RDPS = "RDPS",
  },
  MAGE = {
    RDPS = "RDPS",
  },

}
function bsloot_rosterdetails:populateRoleSetter(name, class, role)
  self._roleDD:SetList(bsloot_rosterdetails.ClassRoles[class])
  local roleStr = "ROLE MISSING"
  local mainChar = bsloot_rosterdetails:guessMain(name)
  if(CharRoleDB[name] and CharRoleDB[name] ~= nil) then
    if(CharRoleDB[name].role and CharRoleDB[name].role ~= nil) then
      role = CharRoleDB[name].role
    end
    if(CharRoleDB[name].mainChar and CharRoleDB[name].mainChar ~= nil) then
      mainChar = CharRoleDB[name].mainChar
    end
  end
  if(role and role ~= nil) then
    roleStr = role
    self._roleDD:SetValue(role)
    self._roleDD:SetText(role)
  end
  self._mainCharInput:SetText(mainChar)
  self._roleLabel:SetText("Current role info: " .. name .. ", " .. class .. ", " .. roleStr)

  if not self._container_rolesetter.frame:IsShown() then
    self._container_rolesetter:Show()
  end
end

function bsloot_rosterdetails:guessMain(name)
  
  local shortCharName = Ambiguate(name, "short")
  local guess = shortCharName
  if(GRM_GuildMemberHistory_Save) then
    local guildData = GRM_GuildMemberHistory_Save[ GRM_G.F ][ GRM_G.guildName ];
    for _ , player in pairs ( guildData ) do
        if type ( player ) == "table" then
          local shortName = Ambiguate(player.name, "short")
          if(shortName == shortCharName) then
            if(player.isMain) then
              guess = shortName
              return guess
            end
            for _,v in ipairs(player.alts) do
              local altName = Ambiguate(v[1], "short")
              if(v[5]) then
                guess = shortName
                return guess
              end
            end
            break
          end
        end
    end
  end
  return guess
end

function bsloot_rosterdetails:Toggle()
  if self._container.frame:IsShown() then
    self._container:Hide()
  else
    self._container:Show()
  end
  self:Refresh()
end
function bsloot_rosterdetails:Hide()
  if self._container.frame:IsShown() then
    self._container:Hide()
  end
  self:Refresh()
end
function bsloot_rosterdetails:Show()
  if not self._container.frame:IsShown() then
    self._container:Show()
  end
  self:Refresh()
end

function bsloot_rosterdetails:Refresh()
  
  table.wipe(data)

  local rosterRecords = bsloot:getRoster(self._widgetraid_only:GetValue())
  for k,v in ipairs(rosterRecords) do
    local name = v.name
    local isMain = v.isMain
    local pr = v.pr
    local role = v.role
    local eClass, class, hexclass = bsloot:getClassData(v.class)
    local color = RAID_CLASS_COLORS[eClass]

    local prStr = nil
    if(pr and pr ~= nil) then
      prStr = string.format("%.4f", pr)
    else
      -- pr = "nil"
    end
    table.insert(data,{["cols"]={
      {["value"]=name,["color"]=color},
      {["value"]=eClass,["color"]=color},
      {["value"]=role},
      {["value"]=prStr,["color"]={r=1.0,g=215/255,b=0,a=1.0}},
      {["value"]=bsloot:tableToString(isMain)},
    }})
  end
  self._rosterdetails_table:SetData(data)  
  if self._rosterdetails_table and self._rosterdetails_table.showing then
    self._rosterdetails_table:SortData()
  end
end
