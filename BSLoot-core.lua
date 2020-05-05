local addonName, bsloot = ...
local addon = LibStub("AceAddon-3.0"):NewAddon(bsloot, addonName, "AceConsole-3.0", "AceHook-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceBucket-3.0", "AceComm-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local AC = LibStub("AceConfig-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
local ADBO = LibStub("AceDBOptions-3.0")
local LDBO = LibStub("LibDataBroker-1.1"):NewDataObject(addonName)
local LDI = LibStub("LibDBIcon-1.0")
local LDD = LibStub("LibDropdown-1.0")
local LD = LibStub("LibDialog-1.0")
local C = LibStub("LibCrayon-3.0")
local DF = LibStub("LibDeformat-3.0")
local G = LibStub("LibGratuity-3.0")
local T = LibStub("LibQTip-1.0")
local LT = LibStub("LibTouristClassic-1.0")
EPGPTable = {}
if EPGPTable == nil then
    EPGPTable = {};
end 
bsloot.syncMinGuildRank = 2 --higher = lower rank, 0 is GM, based on rankIndex not rankIndex  --TODO make "trustedRank" configurable
bsloot.test_mode_vars = 
--[[{
  channel = "RAID",
}]]
{
  channel = "GUILD",
}
bsloot.VARS = {
  basegp = 200,
  minep = 10000,
  -- baseaward_ep = 100,
  decay = 0.1,
  -- max = 1000,
  timeout = 60,
  minlevel = 55,
  maxloglines = 500,
  prefix = "BSLOOT1",
  pricesystem = "BSLootFixed-1.0",
  bop = C:Red(L["BoP"]),
  boe = C:Yellow(L["BoE"]),
  nobind = C:White(L["NoBind"]),
  msgp = L["Mainspec GP"],
  osgp = L["Offspec GP"],
  bankde = L["Bank-D/E"],
  unassigned = C:Red(L["Unassigned"]),
  prModPerBisPhase = 0.1,
  prModAlt = 0.75,
}
bsloot._playerName = Ambiguate(GetUnitName("player"), "short")
SyncEvents = SyncEvents or {}
EventsToProcessQueue = EventsToProcessQueue or {}
local raidStatus,lastRaidStatus
local lastUpdate = 0
local running_check
local partyUnit,raidUnit = {},{}
local hexClassColor, classToEnClass = {}, {}
local hexColorQuality = {}
local price_systems = {}
local special_frames = {}
local label = string.format("|cff33ff99%s|r",addonName)
local out_chat = string.format("%s: %%s",addonName)

bsloot.statics = {
  eventType = {
    SWITCH_MAIN = "SwitchMain",
    EPGP = "EPGP",
    CHAR_ROLE = "CharRole",
    GP_VAL = "GPVal",
    BIS_MATRIX = "BisMatrix",
    EP_VAL = "EPVal",
    RAID = "Raid",
  },
  eventSubType = {
    GP = "GP",
    EP = "EP",
    PARTIAL_UPDATE = "PARTIAL_UPDATE",
    FULL_UPDATE = "FULL_UPDATE",
    RAID_START = "Start",
    RAID_END = "End",
    BOSS_ATTEMPT = "BossAttempt",
  },
  EPGP = {
    LOOT = "LOOT",
    ADHOC = "ADHOC",
    BOSSKILL = "BOSSKILL",
    PROGRESSION = "PROGRESSION",
    BONUS = "BONUS",
    ON_TIME = "OnTime",
    IRONMAN = "Ironman",
  },
  LOGS = {
    DEFAULT = 1,
    LOOT = 2,
    SYNC = 4,
    COMM = 8,
    EPGP = 16,
    ROSTER = 32,
    EVENT = 64,
    MODS = 128,
    AUTODETECT = 256,
    BULK = 512,
    PRICE = 1024,
    FAVORITES = 2048,
    DEV = 4096,
  },
  channel = {
    RAID = "RAID",
    GUILD = "GUILD",
    WHISPER = "WHISPER",
  },
}
do
  for i=1,40 do
    raidUnit[i] = "raid"..i
  end
  for i=1,4 do
    partyUnit[i] = "party"..i
  end
end
do
  for i=0,5 do
    hexColorQuality[ITEM_QUALITY_COLORS[i].hex] = i
  end
end
do 
  for eClass, class in pairs(LOCALIZED_CLASS_NAMES_MALE) do
    hexClassColor[class] = RAID_CLASS_COLORS[eClass].colorStr:gsub("^(ff)","")
    classToEnClass[class] = eClass
  end
  for eClass, class in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
    hexClassColor[class] = RAID_CLASS_COLORS[eClass].colorStr:gsub("^(ff)","")
  end
end
do
  local star,star_off = CreateAtlasMarkup("tradeskills-star"),CreateAtlasMarkup("tradeskills-star-off")
  bsloot._favmap = {
    [1]=string.format("%s%s%s%s%s",star,star_off,star_off,star_off,star_off),
    [2]=string.format("%s%s%s%s%s",star,star,star_off,star_off,star_off),
    [3]=string.format("%s%s%s%s%s",star,star,star,star_off,star_off),
    [4]=string.format("%s%s%s%s%s",star,star,star,star,star_off),
    [5]=string.format("%s%s%s%s%s",star,star,star,star,star),
  }
end

local defaults = {
  profile = {
    announce = "GUILD",
    decay = bsloot.VARS.decay,
    minep = bsloot.VARS.minep,
    system = bsloot.VARS.pricesystem,    
    discount = 0.25,
    altpercent = 1.0,
    main = false,
    minimap = {
      hide = false,
    },
    logs = {
      verbosity = 1
    },
    guildcache = {},
    chat = {
      verboseRaidEp = false,
      presentItemToRollOn = {
        RAID = false,
        RAID_WARNING = true,
        GUILD = false,
        WIDEST = false,
      },
      bidResult = {
        RAID = true,
        RAID_WARNING = false,
        GUILD = false,
        WIDEST = false,
        WHISPER = true,
      },
      bidAck = {
        RAID = false,
        RAID_WARNING = false,
        GUILD = false,
        WIDEST = false,
        WHISPER = true,
      },
      bidDetails = {
        RAID = false,
        RAID_WARNING = false,
        GUILD = false,
        WIDEST = false,
        WHISPER = true,
      },
      passResult = {
        RAID = false,
        RAID_WARNING = false,
        GUILD = false,
        WIDEST = false,
        WHISPER = true,
      },
      passAck = {
        RAID = false,
        RAID_WARNING = false,
        GUILD = false,
        WIDEST = false,
        WHISPER = false,
      },
      autoPassResult = {
        RAID = false,
        RAID_WARNING = false,
        GUILD = false,
        WIDEST = false,
        WHISPER = true,
      },
      autoPassAck = {
        RAID = false,
        RAID_WARNING = false,
        GUILD = false,
        WIDEST = false,
        WHISPER = false,
      },
      autoRollAck = {
        RAID = false,
        RAID_WARNING = false,
        GUILD = false,
        WIDEST = false,
        WHISPER = false,
      },
      gpGrant = {
        RAID = false,
        RAID_WARNING = false,
        GUILD = true,
        WIDEST = false,
        WHISPER = true,
      },
      epGrant = {
        RAID = false,
        RAID_WARNING = false,
        GUILD = true,
        WIDEST = false,
        WHISPER = true,
      },
      raidEpGrant = {
        RAID = false,
        RAID_WARNING = true,
        GUILD = false,
        WIDEST = false,
      },
      lootResult = {
        RAID = false,
        RAID_WARNING = true,
        GUILD = false,
        WIDEST = false,
        WHISPER = true,
      },
      raidEvent = {
        RAID = false,
        RAID_WARNING = true,
        GUILD = false,
        WIDEST = false,
      },
    },
  },
  char = {
    raidonly = false,
    tooltip = true,
    classgroup = false,
    standby = false,
    ssOnAnnounce = false,
    bidpopup = false,
    rollWindowCloseOnNeed = false,
    rollWindowCloseOnPass = true,
    logs = {},
    loot = {},
    autoRollItems = {},
    autoPassItems = {},
  },
}
local admincmd = 
{type = "group", handler = bsloot, args = {
  standings = {
    type = "execute",
    name = L["Standings"],
    desc = L["Show Standings Table."],
    func = function()
      local standings = bsloot:GetModule(addonName.."_standings")
      if standings then
        standings:Show()
      end
    end,
    order = 2,
  },
  roster = {
    type = "execute",
    name = L["Roster"],
    desc = L["Show Guild roster Table"],
    func = function()
      local roster = bsloot:GetModule(addonName.."_rosterdetails")
      if roster then
        roster:Show()
      end
    end,
    order = 2,
  },
  bids = {
    type = "execute",
    name = L["Bids"],
    desc = L["Show Bids Window."],
    func = function()
      local lootBids = bsloot:GetModule(addonName.."_window_roll_present")
      if lootBids then
        lootBids:Show()
      end
    end,
    order = 2,
  },
  mods = {
    type = "execute",
    name = L["Required Mods"],
    desc = L["Query users for required mods"],
    func = function()
      bsloot_requiredmods:Show()
    end,
    order = 2,
  },
  browser = {
    type = "execute",
    name = L["Item Browser"],
    desc = L["Show Item Browser Table."],
    func = function()
      local browser = bsloot:GetModule(addonName.."_browser")
      if browser then
        browser:Show()
      end
    end,
    order = 3,      
  },    
  bis = {
    type = "execute",
    name = L["BiS Matrix Browser"],
    desc = L["Show BiS Matrix Browser Table."],
    func = function()
      local bisBrowser = bsloot:GetModule(addonName.."_bismatrix")
      if bisBrowser then
        bisBrowser:Show()
      end
    end,
    order = 3,      
  },    
    check = {
      type = "input",
      name = L["Check Guild for data"],
      desc = L["Check Guild for data."],
      set = function(info, arg)
        if(bsloot:isItemLink(arg)) then
              bsloot:presentItemToRollOn(arg)
        else
          bsloot:broadcast("check " .. arg, bsloot.statics.channel.RAID)
        end
      end,
      order = 11,
    },
    forceClear = {
      type = "execute",
      name = L["Force Clear everyone's Data"],
      desc = L["Force Clear everyone's Data"],
      func = function()
        bsloot:broadcast("forceClear", bsloot.statics.channel.GUILD)
      end,
      order = 7,
    },
    changeMain = {
      type = "input",
      name = L["Migrate a characters history to a new main"],
      desc = L["Migrate a characters history to a new main"],
      set = function(info, msg)
        local args = bsloot:split(msg)
        bsloot:changeMainChar(args[1], args[2], args[3], args[4])
      end,
      order = 7,
    },
    startRaid = {
      type = "input",
      name = L["Begin a Raid"],
      desc = L["Begin a Raid"],
      set = function(info, msg)
        bsloot:startRaid(msg)
      end,
      order = 10,
    },
    endRaid = {
      type = "input",
      name = L["End a Raid"],
      desc = L["End a Raid"],
      set = function(info, msg)
        bsloot:endRaid(msg)
      end,
      order = 10,
    },
    charge = {
      type = "input",
      name = L["Charge for item"],
      desc = L["Charge for an item outside of normal loot flow"],
      set = function(info, msg)
        local args = bsloot:split(msg)
        local characterName = args[1]
        local item = strsub(msg, string.len(characterName)+2)
        local itemId = GetItemInfoInstant(item)
        local gpValue = bsloot:chargeGpForItem(itemId, characterName)
        if(gpValue and gpValue ~= nil) then
          bsloot:doWithItemInfo(itemId, function(itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
            itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
            isCraftingReagent, itemId) 
            local notification = "Manual GP Charge for "..itemLink.."("..gpValue.." GP) to "..characterName
            bsloot:SendChat(notification, bsloot.db.profile.chat.gpGrant, characterName)
          end)
        else
          bsloot:warnPrint("GP was not charged", bsloot.statics.LOGS.EPGP)
        end
      end,
      order = 10,
    },
    refund = {
      type = "input",
      name = L["Refund an item"],
      desc = L["Refund an item outside of normal loot flow"],
      set = function(info, msg)
        local args = bsloot:split(msg)
        local characterName = args[1]
        local item = strsub(msg, string.len(characterName)+2)
        local itemId = GetItemInfoInstant(item)
        local gpValue = bsloot:refundGpForItem(itemId, characterName)
        if(gpValue and gpValue ~= nil) then
          bsloot:doWithItemInfo(itemId, function(itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
            itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
            isCraftingReagent, itemId) 
            local notification = "Manual GP Refund for "..itemLink.."("..gpValue.." GP) to "..characterName
            bsloot:SendChat(notification, bsloot.db.profile.chat.gpGrant, characterName)
          end)
        else
          bsloot:warnPrint("GP was not refunded", bsloot.statics.LOGS.EPGP)
        end
      end,
      order = 10,
    },
    sync = {
      type = "execute",
      name = L["Trigger Event Sync"],
      desc = L["Trigger Event Sync"],
      func = function()
        bsloot.sync:syncAll()
      end,
      order = 11,
    },
    syncAllFrom = {
      type = "input",
      name = L["Request all Event IDs from given player"],
      desc = L["Request all Event IDs from given player"],
      set = function(info, msg)
        local name, class, _ = bsloot:verifyGuildMember(msg, true)
        bsloot.sync:requestAllIds(name)
      end,
      order = 10,
    },
    events = {
      type = "execute",
      name = L["Show Event Browser"],
      desc = L["Show Event Browser"],
      func = function()
        local logs = bsloot:GetModule(addonName.."_logs")
        if(logs) then
          logs:Show()
        end
      end,
      order = 11,
    },
    raids = {
      type = "execute",
      name = L["Show Raid History"],
      desc = L["Show Raid History"],
      func = function()
        local logs = bsloot:GetModule(addonName.."_raidhistory")
        if(logs) then
          logs:Show()
        end
      end,
      order = 11,
    },
    uuid = {
      type = "execute",
      name = L["Generate and print a uuid"],
      desc = L["Generate and print a uuid"],
      func = function()
        local id = bsloot:uuid()
        bsloot:debugPrint("Your UUID is: "..id, bsloot.statics.LOGS.DEFAULT)
      end,
      order = 11,
    },
    bulkE = {
      type = "execute",
      name = L["Bulk Import Events"],
      desc = L["Bulk Import Events"],
      func = function()

        local iportCsv = bsloot:GetModule(addonName.."_window_bulk_events")
        if iportCsv then
          iportCsv:Show()
        end
      end,
      order = 12,
    },
    bulkI = {
      type = "execute",
      name = L["Bulk Import Items"],
      desc = L["Bulk Import Items"],
      func = function()

        local iportCsv = bsloot:GetModule(addonName.."_window_bulk_items")
        if iportCsv then
          iportCsv:Show()
        end
      end,
      order = 12,
    },
    bulkGP = {
      type = "execute",
      name = L["Bulk Import GP Values"],
      desc = L["Bulk Import GP Values"],
      func = function()

        local iportCsv = bsloot:GetModule(addonName.."_window_bulk_gp")
        if iportCsv then
          iportCsv:Show()
        end
      end,
      order = 12,
    },
    bulkEP = {
      type = "execute",
      name = L["Bulk Import EP Values"],
      desc = L["Bulk Import EP Values"],
      func = function()

        local iportCsv = bsloot:GetModule(addonName.."_window_bulk_ep")
        if iportCsv then
          iportCsv:Show()
        end
      end,
      order = 12,
    },
    bulkC = {
      type = "execute",
      name = L["Bulk Import Character Roles"],
      desc = L["Bulk Import Character Roles"],
      func = function()

        local iportCsv = bsloot:GetModule(addonName.."_window_bulk_chars")
        if iportCsv then
          iportCsv:Show()
        end
      end,
      order = 12,
    },
    
  }}
  local membercmd = {type = "group", handler = bsloot, args = {
  standings = {
    type = "execute",
    name = L["Standings"],
    desc = L["Show Standings Table."],
    func = function()
      local standings = bsloot:GetModule(addonName.."_standings")
      if standings then
        standings:Show()
      end
    end,
    order = 1,
  },
  bids = {
    type = "execute",
    name = L["Bids"],
    desc = L["Show Bids Window."],
    func = function()
      local lootBids = bsloot:GetModule(addonName.."_window_roll_present")
      if lootBids then
        lootBids:Show()
      end
    end,
    order = 2,
  },
    sync = {
      type = "execute",
      name = L["Trigger Event Sync"],
      desc = L["Trigger Event Sync"],
      func = function()
        bsloot.sync:syncAll()
      end,
      order = 11,
    },
    syncAllFrom = {
      type = "input",
      name = L["Request all Event IDs from given player"],
      desc = L["Request all Event IDs from given player"],
      set = function(info, msg)
        local name, class, _ = self:verifyGuildMember(msg, true)
        bsloot.sync:requestAllIds(name)
      end,
      order = 10,
    },
    events = {
      type = "execute",
      name = L["Show Event Browser"],
      desc = L["Show Event Browser"],
      func = function()
        local logs = bsloot:GetModule(addonName.."_logs")
        if(logs) then
          logs:Show()
        end
      end,
      order = 11,
    },
    raids = {
      type = "execute",
      name = L["Show Raid History"],
      desc = L["Show Raid History"],
      func = function()
        local logs = bsloot:GetModule(addonName.."_raidhistory")
        if(logs) then
          logs:Show()
        end
      end,
      order = 11,
    },
    browser = {
      type = "execute",
      name = L["Item Browser"],
      desc = L["Show Item Browser Table."],
      func = function()
        local browser = bsloot:GetModule(addonName.."_browser")
        if browser then
          browser:Show()
        end
      end,
      order = 5,      
    },  
  }}
bsloot.cmdtable = function() 
  if (bsloot:isAdmin()) then
    return admincmd
  else
    return membercmd
  end
end

function bsloot:options()
  if not (self._options) then
    self._options = {
      type = "group",
      name = "",
      desc = L["BSLoot options"],
      handler = bsloot,
      args = { }
    }
    self._options.args["sync"] = {
      type = "toggle",
      name = L["Enable Sync"],
      desc = L["Enable Syncing of Events"],
      order = 80,
      get = function() return not not bsloot.db.char.syncEnabled end,
      set = function(info, val) 
        bsloot.db.char.syncEnabled = not bsloot.db.char.syncEnabled
        bsloot.sync:SetEnabled(bsloot.db.char.syncEnabled)
      end,
    }
    self._options.args["rollWindow_closeOnPass"] = {
      type = "toggle",
      name = L["Close the roll window when you select pass"],
      desc = L["Close the roll window when you select pass(unless ML)"],
      order = 81,
      get = function() return not not bsloot.db.char.rollWindowCloseOnPass end,
      set = function(info, val) 
        bsloot.db.char.rollWindowCloseOnPass = not bsloot.db.char.rollWindowCloseOnPass
      end,
    }
    self._options.args["rollWindow_closeOnNeed"] = {
      type = "toggle",
      name = L["Close the roll window when you select need"],
      desc = L["Close the roll window when you select need(unless ML)"],
      order = 82,
      get = function() return not not bsloot.db.char.rollWindowCloseOnNeed end,
      set = function(info, val) 
        bsloot.db.char.rollWindowCloseOnNeed = not bsloot.db.char.rollWindowCloseOnNeed
      end,
    }
    self._options.args["tooltip"] = {
      type = "toggle",
      name = L["Tooltip Info"],
      desc = L["Add EPGP Information to Item Tooltips"],
      order = 83,
      get = function() return not not bsloot.db.char.tooltip end,
      set = function(info, val) 
        bsloot.db.char.tooltip = not bsloot.db.char.tooltip
        bsloot:tooltipHook(bsloot.db.char.tooltip)
      end,
    }  
    self._options.args["minimap"] = {
      type = "toggle",
      name = L["Hide from Minimap"],
      desc = L["Hide from Minimap"],
      order = 130,
      get = function() return bsloot.db.profile.minimap.hide end,
      set = function(info, val)
        bsloot.db.profile.minimap.hide = val
        if bsloot.db.profile.minimap.hide then
          LDI:Hide(addonName)
        else
          LDI:Show(addonName)
        end
      end
    }
    self._options.args["ssOnAnnounce"] = {
      type = "toggle",
      name = L["Screenshot Bids on Announce"],
      desc = L["Screenshot Bids when a winner is announced"],
      order = 131,
      get = function() return bsloot.db.char.ssOnAnnounce end,
      set = function(info, val)
        bsloot.db.char.ssOnAnnounce = val
      end
    }
    self._options.args["verbosity"] = {
      type = "input",
      name = L["Adjust log verbosity"],
      desc = L["Adjust log verbosity"],
      order = 1000,
      get = function() return bsloot.db.profile.logs.verbosity end,
      set = function(info, val)
        bsloot.db.profile.logs.verbosity = tonumber(val)
        
      end,
      pattern = "^(%d+)$",
      usage = L["Log verbosity should be an integer from 1 (quietest) to 10 (noisiest)"],
    }

    --[[
      Chat settings

    ]]
    self._options.args["header_chat"] = {
      type = "header",
      name = L["Chat Messages"],
      order = 2000,
    }
    self._options.args["chat_description"] = {
      type = "description",
      name = L["The below options are where you will broadcast messages when you are performing actions with BSLoot"],
      order = 2001,
    }
    self._options.args["verbose_raid_ep"] = {
      type = "toggle",
      name = L["Verbose Raid EP Message"],
      desc = L["List Characters individually for Raid EP"],
      order = 80,
      get = function() return not not bsloot.db.profile.chat.verboseRaidEp end,
      set = function(info, val) 
        bsloot.db.profile.chat.verboseRaidEp = not bsloot.db.profile.chat.verboseRaidEp
      end,
    }
    self._options.args["chat_presentItemToRollOn"] = {
      type = "multiselect",
      name = L["Item Presentation Messages"],
      desc = L["Item Presentation Messages"],
      order = 2002,
      values = {
        RAID = "Raid",
        RAID_WARNING = "Raid Warning",
        GUILD = "Guild",
        WIDEST = "Smart Select",
      },
      get = function(info, key) 
        return bsloot.db.profile.chat.presentItemToRollOn[key]
      end,
      set = function(info, key, val)
        bsloot.db.profile.chat.presentItemToRollOn[key] = val
      end,
    }
    self._options.args["chat_bidResult"] = {
      type = "multiselect",
      name = L["Bid Result Messages"],
      desc = L["Bid Result Messages"],
      order = 2002,
      values = {
        RAID = "Raid",
        RAID_WARNING = "Raid Warning",
        GUILD = "Guild",
        WIDEST = "Smart Select",
        WHISPER = "Whisper Bidder",
      },
      get = function(info, key) 
        return bsloot.db.profile.chat.bidResult[key] or false
      end,
      set = function(info, key, val)
        bsloot.db.profile.chat.bidResult[key] = val
      end,
    }
    self._options.args["chat_bidAck"] = {
      type = "multiselect",
      name = L["Bid Acknowledgement Messages"],
      desc = L["Bid Acknowledgement Messages"],
      order = 2002,
      values = {
        RAID = "Raid",
        RAID_WARNING = "Raid Warning",
        GUILD = "Guild",
        WIDEST = "Smart Select",
        WHISPER = "Whisper Bidder",
      },
      get = function(info, key) 
        return bsloot.db.profile.chat.bidAck[key] or false
      end,
      set = function(info, key, val)
        bsloot.db.profile.chat.bidAck[key] = val
      end,
    }
    self._options.args["chat_bidDetails"] = {
      type = "multiselect",
      name = L["Bid Details Messages"],
      desc = L["Bid Details Messages"],
      order = 2002,
      values = {
        RAID = "Raid",
        RAID_WARNING = "Raid Warning",
        GUILD = "Guild",
        WIDEST = "Smart Select",
        WHISPER = "Whisper Bidder",
      },
      get = function(info, key) 
        return bsloot.db.profile.chat.bidDetails[key] or false
      end,
      set = function(info, key, val)
        bsloot.db.profile.chat.bidDetails[key] = val
      end,
    }
    self._options.args["chat_passResult"] = {
      type = "multiselect",
      name = L["Pass Result Messages"],
      desc = L["Pass Result Messages"],
      order = 2002,
      values = {
        RAID = "Raid",
        RAID_WARNING = "Raid Warning",
        GUILD = "Guild",
        WIDEST = "Smart Select",
        WHISPER = "Whisper Player",
      },
      get = function(info, key) 
        return bsloot.db.profile.chat.passResult[key] or false
      end,
      set = function(info, key, val)
        bsloot.db.profile.chat.passResult[key] = val
      end,
    }
    self._options.args["chat_passAck"] = {
      type = "multiselect",
      name = L["Pass Acknowledgement Messages"],
      desc = L["Pass Acknowledgement Messages"],
      order = 2002,
      values = {
        RAID = "Raid",
        RAID_WARNING = "Raid Warning",
        GUILD = "Guild",
        WIDEST = "Smart Select",
        WHISPER = "Whisper Player",
      },
      get = function(info, key) 
        return bsloot.db.profile.chat.passAck[key] or false
      end,
      set = function(info, key, val)
        bsloot.db.profile.chat.passAck[key] = val
      end,
    }
    self._options.args["chat_autoPassResult"] = {
      type = "multiselect",
      name = L["AutoPass Result Messages"],
      desc = L["AutoPass Result Messages"],
      order = 2002,
      values = {
        RAID = "Raid",
        RAID_WARNING = "Raid Warning",
        GUILD = "Guild",
        WIDEST = "Smart Select",
        WHISPER = "Whisper Player",
      },
      get = function(info, key) 
        return bsloot.db.profile.chat.autoPassResult[key] or false
      end,
      set = function(info, key, val)
        bsloot.db.profile.chat.autoPassResult[key] = val
      end,
    }
    self._options.args["chat_autoPassAck"] = {
      type = "multiselect",
      name = L["AutoPass Acknowledgement Messages"],
      desc = L["AutoPass Acknowledgement Messages"],
      order = 2002,
      values = {
        RAID = "Raid",
        RAID_WARNING = "Raid Warning",
        GUILD = "Guild",
        WIDEST = "Smart Select",
        WHISPER = "Whisper Player",
      },
      get = function(info, key) 
        return bsloot.db.profile.chat.autoPassAck[key] or false
      end,
      set = function(info, key, val)
        bsloot.db.profile.chat.autoPassAck[key] = val
      end,
    }
    self._options.args["chat_autoRollAck"] = {
      type = "multiselect",
      name = L["AutoRoll Acknowledgement Messages"],
      desc = L["AutoRoll Acknowledgement Messages"],
      order = 2002,
      values = {
        RAID = "Raid",
        RAID_WARNING = "Raid Warning",
        GUILD = "Guild",
        WIDEST = "Smart Select",
        WHISPER = "Whisper Player",
      },
      get = function(info, key) 
        return bsloot.db.profile.chat.autoRollAck[key] or false
      end,
      set = function(info, key, val)
        bsloot.db.profile.chat.autoRollAck[key] = val
      end,
    }
    self._options.args["chat_gpGrant"] = {
      type = "multiselect",
      name = L["GP Grant Messages"],
      desc = L["GP Grant Messages"],
      order = 2002,
      values = {
        RAID = "Raid",
        RAID_WARNING = "Raid Warning",
        GUILD = "Guild",
        WIDEST = "Smart Select",
        WHISPER = "Whisper Player",
      },
      get = function(info, key) 
        return bsloot.db.profile.chat.gpGrant[key] or false
      end,
      set = function(info, key, val)
        bsloot.db.profile.chat.gpGrant[key] = val
      end,
    }
    self._options.args["chat_epGrant"] = {
      type = "multiselect",
      name = L["EP Grant Messages"],
      desc = L["EP Grant Messages"],
      order = 2002,
      values = {
        RAID = "Raid",
        RAID_WARNING = "Raid Warning",
        GUILD = "Guild",
        WIDEST = "Smart Select",
        WHISPER = "Whisper Player",
      },
      get = function(info, key) 
        return bsloot.db.profile.chat.epGrant[key] or false
      end,
      set = function(info, key, val)
        bsloot.db.profile.chat.epGrant[key] = val
      end,
    }
    self._options.args["chat_raidEpGrant"] = {
      type = "multiselect",
      name = L["Raid EP Grant Messages"],
      desc = L["Raid EP Grant Messages"],
      order = 2002,
      values = {
        RAID = "Raid",
        RAID_WARNING = "Raid Warning",
        GUILD = "Guild",
        WIDEST = "Smart Select",
      },
      get = function(info, key) 
        return bsloot.db.profile.chat.raidEpGrant[key] or false
      end,
      set = function(info, key, val)
        bsloot.db.profile.chat.raidEpGrant[key] = val
      end,
    }
    self._options.args["chat_lootResult"] = {
      type = "multiselect",
      name = L["Loot Results"],
      desc = L["Loot Results"],
      order = 2002,
      values = {
        RAID = "Raid",
        RAID_WARNING = "Raid Warning",
        GUILD = "Guild",
        WIDEST = "Smart Select",
        WHISPER = "Whisper Player",
      },
      get = function(info, key) 
        return bsloot.db.profile.chat.lootResult[key] or false
      end,
      set = function(info, key, val)
        bsloot.db.profile.chat.lootResult[key] = val
      end,
    }
    
    self._options.args["chat_raidEvent"] = {
      type = "multiselect",
      name = L["Raid Events"],
      desc = L["Raid Events"],
      order = 2002,
      values = {
        RAID = "Raid",
        RAID_WARNING = "Raid Warning",
        GUILD = "Guild",
        WIDEST = "Smart Select",
      },
      get = function(info, key) 
        return bsloot.db.profile.chat.raidEvent[key] or false
      end,
      set = function(info, key, val)
        bsloot.db.profile.chat.raidEvent[key] = val
      end,
    }
    
    --[[
      get (function|methodname) - getter function
set (function|methodname) - setter function
multiline (boolean|integer) - if true will be shown as a multiline editbox in dialog implementations (Integer = # of lines in editbox)
pattern (string) - optional validation pattern. (Use the validate field for more advanced checks!)
usage (string) - usage string (displayed if pattern mismatches and in console help messages)
    ]]
  end
  return self._options
end

function bsloot:ddoptions()
  if not self._ddoptions then
    self._ddoptions = {
      type = "group",
      name = L["BSLoot options"],
      desc = L["BSLoot options"],
      handler = bsloot,
      args = { }
    }
    self._ddoptions.args["ep_raid"] = {
      type = "execute",
      name = L["+EPs to Raid"],
      desc = L["Award EPs to all raid members."],
      order = 10,
      func = function(info)
        LD:Spawn(addonName.."DialogGroupPoints", {"ep", C:Green(L["Effort Points"]), _G.RAID, "0", "TBD"}) 
        self._ddmenu:Release()
      end,
    }
    self._ddoptions.args["ep"] = {
      type = "group",
      name = L["+EPs to Member"],
      desc = L["Account EPs for member."],
      order = 40,
      args = { }
    }
    self._ddoptions.args["gp"] = {
      type = "group",
      name = L["+GPs to Member"],
      desc = L["Account GPs for member."],
      order = 50,
      args = { }
    }      
  end
  local members = bsloot:buildRosterTable()
  self:debugPrint(string.format(L["Scanning %d members for EP/GP data. (%s)"],#(members),(bsloot.db.char.raidonly and "Raid" or "Full")), bsloot.statics.LOGS.ROSTER)
  self._ddoptions.args["ep"].args = bsloot:buildClassMemberTable(members,"ep")
  self._ddoptions.args["gp"].args = bsloot:buildClassMemberTable(members,"gp")
  return self._ddoptions
end

function bsloot:buildClassMemberTable(roster,epgp)
  local desc,usage
  if epgp == "ep" then
    desc = L["Account EPs to %s."]
    usage = "<EP>"
  elseif epgp == "gp" then
    desc = L["Account GPs to %s."]
    usage = "<GP>"
  end
  local c = { }
  for i,member in ipairs(roster) do
    local class,name = member.class, member.name
    if (class) and (c[class] == nil) then
      c[class] = { }
      c[class].type = "group"
      c[class].name = C:Colorize(hexClassColor[class],class)
      c[class].desc = class .. " members"
      c[class].args = { }
    end
    if (name) and (c[class].args[name] == nil) then
      c[class].args[name] = { }
      c[class].args[name].type = "execute"
      c[class].args[name].name = name
      c[class].args[name].desc = string.format(desc,name)
      --c[class].args[name].usage = usage
      c[class].args[name].func = function(info)
        local what = epgp == "ep" and C:Green(L["Effort Points"]) or C:Red(L["Gear Points"])
        LD:Spawn(addonName.."DialogMemberPoints", {epgp, what, name, "0", "TBD"})
        self._ddmenu:Release()
      end
    end
  end
  return c
end

function bsloot:buildRosterTable()
  local g, r = { }, { }
  local numGuildMembers = GetNumGuildMembers(true)
  
  for i = 1, numGuildMembers do
    local member_name,_,_,level,class,_,note,officernote,_,_ = GetGuildRosterInfo(i)
    member_name = Ambiguate(member_name,"short") --:gsub("(\-.+)","")
    if member_name and level and (member_name ~= UNKNOWNOBJECT) and (level > 0) then
      self.db.profile.guildcache[member_name] = level
    end
    local mainChar, isMain = self:getMainChar(member_name)
    local level = tonumber(level)
    local is_raid_level = level and level >= bsloot.VARS.minlevel
    
    if is_raid_level then
      table.insert(g,{["name"]=member_name,["class"]=class,["onote"]=officernote})
    end  
  end
  return g
end

function bsloot.OnLDBClick(obj,button)
  local is_admin = bsloot:isAdmin()
  local logs = bsloot:GetModule(addonName.."_logs")
  local raidHistory = bsloot:GetModule(addonName.."_raidhistory")
  local browser = bsloot:GetModule(addonName.."_browser")
  -- local standby = bsloot:GetModule(addonName.."_standby")
  local loot = bsloot:GetModule(addonName.."_loot")
  local bids = bsloot:GetModule(addonName.."_window_roll_present")
  local standings = bsloot:GetModule(addonName.."_standings")
    if button == "LeftButton" then
      if IsControlKeyDown() and IsShiftKeyDown() then
        -- logs
        if logs then
          logs:Show()
        end
      elseif IsAltKeyDown() and IsShiftKeyDown() then
        -- browser
        if browser then
          browser:Show()
        end
      -- elseif IsControlKeyDown() then
      --   -- standby
      --   -- if standby then
      --   --   standby:Show()
      --   -- end
      elseif IsShiftKeyDown() then
        if raidHistory then
          raidHistory:Show()
        end
      elseif IsAltKeyDown() then
        -- bids
        if bids then
          bids:Show(obj)
        end
      else
        if standings then
          standings:Show()
        end      
      end
    elseif button == "RightButton" then
      if is_admin then
        bsloot:OpenRosterActions(obj)
      end
    elseif button == "MiddleButton" then
      InterfaceOptionsFrame_OpenToCategory(bsloot.blizzoptions)
      InterfaceOptionsFrame_OpenToCategory(bsloot.blizzoptions)
    end
end

function bsloot.OnLDBTooltipShow(tooltip)
  tooltip = tooltip or GameTooltip
  tooltip:SetText(label)
  tooltip:AddLine(" ")
  local hint = L["|cffff7f00Click|r to view Standings."]
  tooltip:AddLine(hint)
  tooltip:AddLine(" ")
  hint = L["|cffff7f00Alt+Click|r to view Bids."]
  tooltip:AddLine(hint)
  hint = L["|cffff7f00Shift+Alt+Click|r to view Loot Browser."]
  tooltip:AddLine(hint)
  hint = L["|cffff7f00Shift+Click|r to view Raid History."]
  tooltip:AddLine(hint)
  tooltip:AddLine(" ")
  hint = L["|cffff7f00Middle Click|r for %s"]:format(L["Options"])
  tooltip:AddLine(hint)
  hint = L["|cffff7f00Ctrl+Shift+Click|r to view Logs."]
  tooltip:AddLine(hint)
  if bsloot:isAdmin() then
    -- hint = L["|cffff7f00Ctrl+Click|r to view Standby."]
    -- tooltip:AddLine(hint)
    hint = L["|cffff7f00Right Click|r for %s."]:format(L["Admin Actions"])
    tooltip:AddLine(hint)
  else
  end
end

function bsloot:OnInitialize() -- 1. ADDON_LOADED
  -- guild specific stuff should go in profile named after guild
  -- player specific in char
  self._versionString = GetAddOnMetadata(addonName,"Version")
  self._websiteString = GetAddOnMetadata(addonName,"X-Website")
  self._labelfull = string.format("%s %s",label,self._versionString)
  self.db = LibStub("AceDB-3.0"):New("BSLootDB", defaults)
  self:options()
  self._options.args.profile = ADBO:GetOptionsTable(self.db)
  self._options.args.profile.guiHidden = true
  self._options.args.profile.cmdHidden = true
  AC:RegisterOptionsTable(addonName.."_cmd", self.cmdtable, {"bsl", "bsloot"})
  AC:RegisterOptionsTable(addonName, self._options)
  self.blizzoptions = ACD:AddToBlizOptions(addonName)
  self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
  LDBO.type = "launcher"
  LDBO.text = addonName
  LDBO.label = string.format("%s %s",addonName,self._versionString)
  LDBO.icon = "Interface\\PetitionFrame\\GuildCharter-Icon"
  LDBO.OnClick = bsloot.OnLDBClick
  LDBO.OnTooltipShow = bsloot.OnLDBTooltipShow
  LDI:Register(addonName, LDBO, bsloot.db.profile.minimap)
  bsloot:debugPrint("Welcome to BSLoot " .. self._playerName, bsloot.statics.LOGS.DEFAULT)
end

function bsloot:OnEnable() -- 2. PLAYER_LOGIN
  if not IsInGuild() then
    bsloot:Disable()
    bsloot:RegisterEvent("PLAYER_GUILD_UPDATE")
    return
  end
  if IsInGuild() then
    local guildname = GetGuildInfo("player")
    if not guildname then
      GuildRoster()
    end
    self._playerLevel = UnitLevel("player")
    if self._playerLevel and self._playerLevel < MAX_PLAYER_LEVEL then
      self:RegisterEvent("PLAYER_LEVEL_UP")
    end
    -- NOTE this is what triggers the deferredInit which handles pretty much all init stuff
    self._bucketGuildRoster = self:RegisterBucketEvent("GUILD_ROSTER_UPDATE",3.0)
    
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(frame, event, message)
    
      if( event == "CHAT_MSG_SYSTEM") then	
        if message:match(string.format(ERR_CHAT_PLAYER_NOT_FOUND_S, "(.+)")) then
          return true
        end	
        -- if message:match(string.format(ERR_NOT_IN_RAID, "(.+)")) then
        --   return true
        -- end
      end		
      return false
    end)
    self:RegisterEvent("CHAT_MSG_WHISPER")
  end
end
-- NOTE this is what triggers the deferredInit which handles pretty much all init stuff
function bsloot:GUILD_ROSTER_UPDATE()
  if GuildFrame and GuildFrame:IsShown() or InCombatLockdown() then
    return
  end
  local guildname = GetGuildInfo("player")
  if guildname then
    self:deferredInit(guildname)
  end
  if not self._initdone then return end
end

function bsloot:OnDisable() -- ADHOC 

end

function bsloot:RefreshConfig()

end

function bsloot:deferredInit(guildname)
  self._guildName = guildname
  self:guildBranding()
  if self._initdone then return end
  
  bsloot_prices = bsloot:GetModule(addonName.."_prices")
  bsloot_requiredmods = bsloot:GetModule(addonName.."_requiredmods")
  local realmname = GetRealmName()
  if realmname then
    
    local baseline = bsloot:GetModule(addonName.."_baseline")
    baseline:trigger()

    local profilekey = guildname.." - "..realmname
    local panelHeader = self:isAdmin() and string.format("%s %s",self._labelfull,L["Admin Options"]) or string.format("%s %s",self._labelfull,L["Member Options"])
    self._options.name = panelHeader
    self.db:SetProfile(profilekey)
    bsloot:backFillDbDefaults()
    self:tooltipHook(bsloot.db.char.tooltip)
    -- comms
    self:RegisterComm(bsloot.VARS.prefix)
    bsloot.sync = bsloot.sync or bsloot:GetModule(addonName.."_sync")
    self:RegisterComm(bsloot.VARS.prefix.."_sync")
    
    
    LD:Register(addonName.."DialogMemberPoints", self:templateCache("DialogMemberPoints"))
    LD:Register(addonName.."DialogGroupPoints", self:templateCache("DialogGroupPoints"))

    -- version check
    self:parseVersion(bsloot._versionString)
    local major_ver = self._version.major
    local addonMsg = string.format("VERSION;%s;%d",bsloot._versionString,major_ver)
    self:broadcast(addonMsg, bsloot.statics.channel.GUILD)

    if(not IsInGroup() and not IsInRaid()) then
      bsloot:ProcessQueuedEvents()
    end

    -- group status change
    self:RegisterEvent("GROUP_JOINED","groupRosterChange")
    self:RegisterEvent("GROUP_LEFT","groupRosterChange")
    self:RegisterEvent("PLAYER_ENTERING_WORLD","groupRosterChange")
    self._bucketRaidRoster = self:RegisterBucketEvent("RAID_ROSTER_UPDATE",3.0)
    self:RegisterBucketEvent("GROUP_ROSTER_UPDATE", 10,"groupRosterChange")
    
    self:RegisterEvent("BOSS_KILL", "BOSS_KILL")
    self:RegisterEvent("ENCOUNTER_END", "ENCOUNTER_END")
    DBM:RegisterCallback("DBM_Kill", self.DBM_Kill)
    DBM:RegisterCallback("DBM_Wipe", self.DBM_Wipe)

    -- handle unnamed frames Esc
    self:RawHook("CloseSpecialWindows",true)

    self._initdone = true
    self:SendMessage(addonName.."_INIT_DONE")

  end
end

function bsloot:backFillDbDefaults()
  local success, err = pcall(function()
    if(bsloot.db.char.syncEnabled == nil) then
    end
    if(bsloot.db.char.rollWindowCloseOnPass == nil) then
      bsloot.db.char.rollWindowCloseOnPass = defaults.char.rollWindowCloseOnPass
    end
    if(bsloot.db.char.rollWindowCloseOnNeed == nil) then
      bsloot.db.char.rollWindowCloseOnNeed = defaults.char.rollWindowCloseOnNeed
    end
    if(bsloot.db.char.tooltip == nil) then
      bsloot.db.char.tooltip = defaults.char.tooltip
    end
    if(bsloot.db.profile.minimap == nil) then
      bsloot.db.profile.minimap = {}
      bsloot.db.profile.minimap.hide = defaults.profile.minimap.hide
    end
    if(bsloot.db.char.ssOnAnnounce == nil) then
      bsloot.db.char.ssOnAnnounce = defaults.char.ssOnAnnounce
    end
    if(bsloot.db.profile.logs == nil) then
      bsloot.db.profile.logs = {}
      bsloot.db.profile.logs.verbosity = defaults.profile.logs.verbosity
    end
    if(bsloot.db.profile.chat.verboseRaidEp == nil) then
      bsloot.db.profile.chat.verboseRaidEp = defaults.profile.chat.verboseRaidEp
    end
    if(bsloot.db.profile.chat.presentItemToRollOn == nil) then
      bsloot.db.profile.chat.presentItemToRollOn = {}
      for k, v in pairs(defaults.profile.chat.presentItemToRollOn) do
        bsloot.db.profile.chat.presentItemToRollOn[k] = v
      end
    end
    if(bsloot.db.profile.chat.bidResult == nil) then
      bsloot.db.profile.chat.bidResult = {}
      for k, v in pairs(defaults.profile.chat.bidResult) do
        bsloot.db.profile.chat.bidResult[k] = v
      end
    end
    if(bsloot.db.profile.chat.bidAck == nil) then
      bsloot.db.profile.chat.bidAck = {}
      for k, v in pairs(defaults.profile.chat.bidAck) do
        bsloot.db.profile.chat.bidAck[k] = v
      end
    end
    if(bsloot.db.profile.chat.bidDetails == nil) then
      bsloot.db.profile.chat.bidDetails = {}
      for k, v in pairs(defaults.profile.chat.bidDetails) do
        bsloot.db.profile.chat.bidDetails[k] = v
      end
    end
    if(bsloot.db.profile.chat.passResult == nil) then
      bsloot.db.profile.chat.passResult = {}
      for k, v in pairs(defaults.profile.chat.passResult) do
        bsloot.db.profile.chat.passResult[k] = v
      end
    end
    if(bsloot.db.profile.chat.passAck == nil) then
      bsloot.db.profile.chat.passAck = {}
      for k, v in pairs(defaults.profile.chat.passAck) do
        bsloot.db.profile.chat.passAck[k] = v
      end
    end
    if(bsloot.db.profile.chat.autoPassResult == nil) then
      bsloot.db.profile.chat.autoPassResult = {}
      for k, v in pairs(defaults.profile.chat.autoPassResult) do
        bsloot.db.profile.chat.autoPassResult[k] = v
      end
    end
    if(bsloot.db.profile.chat.autoPassAck == nil) then
      bsloot.db.profile.chat.autoPassAck = {}
      for k, v in pairs(defaults.profile.chat.autoPassAck) do
        bsloot.db.profile.chat.autoPassAck[k] = v
      end
    end
    if(bsloot.db.profile.chat.autoRollAck == nil) then
      bsloot.db.profile.chat.autoRollAck = {}
      for k, v in pairs(defaults.profile.chat.autoRollAck) do
        bsloot.db.profile.chat.autoRollAck[k] = v
      end
    end
    if(bsloot.db.profile.chat.gpGrant == nil) then
      bsloot.db.profile.chat.gpGrant = {}
      for k, v in pairs(defaults.profile.chat.gpGrant) do
        bsloot.db.profile.chat.gpGrant[k] = v
      end
    end
    if(bsloot.db.profile.chat.epGrant == nil) then
      bsloot.db.profile.chat.epGrant = {}
      for k, v in pairs(defaults.profile.chat.epGrant) do
        bsloot.db.profile.chat.epGrant[k] = v
      end
    end
    if(bsloot.db.profile.chat.raidEpGrant == nil) then
      bsloot.db.profile.chat.raidEpGrant = {}
      for k, v in pairs(defaults.profile.chat.raidEpGrant) do
        bsloot.db.profile.chat.raidEpGrant[k] = v
      end
    end
    if(bsloot.db.profile.chat.lootResult == nil) then
      bsloot.db.profile.chat.lootResult = {}
      for k, v in pairs(defaults.profile.chat.lootResult) do
        bsloot.db.profile.chat.lootResult[k] = v
      end
    end
    if(bsloot.db.profile.chat.raidEvent == nil) then
      bsloot.db.profile.chat.raidEvent = {}
      for k, v in pairs(defaults.profile.chat.raidEvent) do
        bsloot.db.profile.chat.raidEvent[k] = v
      end
    end

  end)
  if(not success) then
    bsloot:warnPrint(string.format("Failed to backfill default values for Options due to %s", bsloot:tableToString(err)), bsloot.statics.LOGS.DEFAULT)
  end
end

function bsloot:groupRosterChange(event, arg1, arg2)
  bsloot:debugPrint("GroupRosterChange: "..bsloot:tableToString(event) .. "; "..bsloot:tableToString(arg1) .. "; "..bsloot:tableToString(arg2) .. "; ", {logicOp="AND", values={bsloot.statics.LOGS.DEV, bsloot.statics.LOGS.ROSTER}})
  if(IsInGroup() or IsInRaid()) then
    bsloot:scanForMissingRoles()
  else
    bsloot:playerLeftGroup()
  end
end

function bsloot:playerLeftGroup()
  bsloot:ProcessQueuedEvents()
end

function bsloot:scanForMissingRoles() 

  if IsInRaid() and (UnitIsGroupAssistant("player") or UnitIsGroupLeader("player")) then 
    bsloot:debugPrint("Scanning for missing roles", bsloot.statics.LOGS.ROSTER)
    for raidIndex=1,40 do
      name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(raidIndex)
      if(name ~= nil) then
        if( not CharRoleDB[name]  or CharRoleDB[name] == nil) then
          bsloot:debugPrint("Missing role for: ".. name, bsloot.statics.LOGS.ROSTER)
        end
      end
    end
  end
end

function bsloot:tooltipHook(status)
  if status then
    -- tooltip
    if not self:IsHooked(GameTooltip, "OnTooltipSetItem") then
      self:HookScript(GameTooltip, "OnTooltipSetItem", "AddTipInfo")
    end
    if not self:IsHooked(ItemRefTooltip, "OnTooltipSetItem") then
      self:HookScript(ItemRefTooltip, "OnTooltipSetItem", "AddTipInfo")
    end    
  else
    -- tooltip
    if self:IsHooked(GameTooltip, "OnTooltipSetItem") then
      self:Unhook(GameTooltip, "OnTooltipSetItem")
    end
    if self:IsHooked(ItemRefTooltip, "OnTooltipSetItem") then
      self:Unhook(ItemRefTooltip, "OnTooltipSetItem")
    end    
  end
end

function bsloot:AddTipInfo(tooltip,...)
  local name, link = tooltip:GetItem()
  if name and link and strtrim(name) ~= "" and strtrim(link, "[] \t\r\n") ~= "" then
    local epgpSummary = bsloot:getEpGpSummary(bsloot._playerName)
    local rollType, rollMods, effectivePr = bsloot:getRollType(bsloot._playerName, link, epgpSummary.PR, epgpSummary.isMain)
    local price, basePrice = bsloot_prices:GetPrice(link, bsloot._playerName)
    if not price then return end
    local textRight = string.format(L["your gp:|cff32cd32%d|r base gp:|cff32cd32%d|r"],price, basePrice)
    tooltip:AddDoubleLine(label, textRight)
    local textRight2 = string.format(L["rollMods:|cff32cd32%s|r = your PR:|cff32cd32%.02f|r"],rollMods, effectivePr)
    tooltip:AddDoubleLine(" ", textRight2)
    local itemId = GetItemInfoInstant(link)
    local autoRoll = bsloot.db.char.autoRollItems[itemId]
    if(autoRoll) then
      tooltip:AddDoubleLine(" ", C:Green(L["AutoRoll"]))
    end
    local autoPass = bsloot.db.char.autoPassItems[itemId]
    if(autoPass) then
      tooltip:AddDoubleLine(" ", C:Yellow(L["AutoPass"]))
    end
  end
end

function bsloot:guildBranding()
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetWidth(64)
  f:SetHeight(64)
  f:SetPoint("CENTER",UIParent,"CENTER",0,0)

  local tabardBackgroundUpper, tabardBackgroundLower, tabardEmblemUpper, tabardEmblemLower, tabardBorderUpper, tabardBorderLower = GetGuildTabardFileNames()
  if ( not tabardEmblemUpper ) then
    tabardBackgroundUpper = "Textures\\GuildEmblems\\Background_49_TU_U"
    tabardBackgroundLower = "Textures\\GuildEmblems\\Background_49_TL_U"
  end

  f.bgUL = f:CreateTexture(nil, "BACKGROUND")
  f.bgUL:SetWidth(32)
  f.bgUL:SetHeight(32)
  f.bgUL:SetPoint("TOPLEFT",f,"TOPLEFT",0,0)
  f.bgUL:SetTexCoord(0.5,1,0,1)
  f.bgUR = f:CreateTexture(nil, "BACKGROUND")
  f.bgUR:SetWidth(32)
  f.bgUR:SetHeight(32)
  f.bgUR:SetPoint("LEFT", f.bgUL, "RIGHT", 0, 0)
  f.bgUR:SetTexCoord(1,0.5,0,1)
  f.bgBL = f:CreateTexture(nil, "BACKGROUND")
  f.bgBL:SetWidth(32)
  f.bgBL:SetHeight(32)
  f.bgBL:SetPoint("TOP", f.bgUL, "BOTTOM", 0, 0)
  f.bgBL:SetTexCoord(0.5,1,0,1)
  f.bgBR = f:CreateTexture(nil, "BACKGROUND")
  f.bgBR:SetWidth(32)
  f.bgBR:SetHeight(32)
  f.bgBR:SetPoint("LEFT", f.bgBL, "RIGHT", 0,0)
  f.bgBR:SetTexCoord(1,0.5,0,1)

  f.bdUL = f:CreateTexture(nil, "BORDER")
  f.bdUL:SetWidth(32)
  f.bdUL:SetHeight(32)
  f.bdUL:SetPoint("TOPLEFT", f.bgUL, "TOPLEFT", 0,0)
  f.bdUL:SetTexCoord(0.5,1,0,1)
  f.bdUR = f:CreateTexture(nil, "BORDER")
  f.bdUR:SetWidth(32)
  f.bdUR:SetHeight(32)
  f.bdUR:SetPoint("LEFT", f.bdUL, "RIGHT", 0,0)
  f.bdUR:SetTexCoord(1,0.5,0,1)
  f.bdBL = f:CreateTexture(nil, "BORDER")
  f.bdBL:SetWidth(32)
  f.bdBL:SetHeight(32)
  f.bdBL:SetPoint("TOP", f.bdUL, "BOTTOM", 0,0)
  f.bdBL:SetTexCoord(0.5,1,0,1)
  f.bdBR = f:CreateTexture(nil, "BORDER")
  f.bdBR:SetWidth(32)
  f.bdBR:SetHeight(32)
  f.bdBR:SetPoint("LEFT", f.bdBL, "RIGHT", 0,0)
  f.bdBR:SetTexCoord(1,0.5,0,1)

  f.emUL = f:CreateTexture(nil, "BORDER")
  f.emUL:SetWidth(32)
  f.emUL:SetHeight(32)
  f.emUL:SetPoint("TOPLEFT", f.bgUL, "TOPLEFT", 0,0)
  f.emUL:SetTexCoord(0.5,1,0,1)
  f.emUR = f:CreateTexture(nil, "BORDER")
  f.emUR:SetWidth(32)
  f.emUR:SetHeight(32)
  f.emUR:SetPoint("LEFT", f.bdUL, "RIGHT", 0,0)
  f.emUR:SetTexCoord(1,0.5,0,1)
  f.emBL = f:CreateTexture(nil, "BORDER")
  f.emBL:SetWidth(32)
  f.emBL:SetHeight(32)
  f.emBL:SetPoint("TOP", f.emUL, "BOTTOM", 0,0)
  f.emBL:SetTexCoord(0.5,1,0,1)
  f.emBR = f:CreateTexture(nil, "BORDER")
  f.emBR:SetWidth(32)
  f.emBR:SetHeight(32)
  f.emBR:SetPoint("LEFT", f.emBL, "RIGHT", 0,0)
  f.emBR:SetTexCoord(1,0.5,0,1)

  f.bgUL:SetTexture(tabardBackgroundUpper)
  f.bgUR:SetTexture(tabardBackgroundUpper)
  f.bgBL:SetTexture(tabardBackgroundLower)
  f.bgBR:SetTexture(tabardBackgroundLower)

  f.emUL:SetTexture(tabardEmblemUpper)
  f.emUR:SetTexture(tabardEmblemUpper)
  f.emBL:SetTexture(tabardEmblemLower)
  f.emBR:SetTexture(tabardEmblemLower)

  f.bdUL:SetTexture(tabardBorderUpper)
  f.bdUR:SetTexture(tabardBorderUpper)
  f.bdBL:SetTexture(tabardBorderLower)
  f.bdBR:SetTexture(tabardBorderLower)
  
  f.mask = f:CreateMaskTexture()
  f.mask:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  f.mask:SetSize(48,48)
  f.mask:SetPoint("CENTER", f, "CENTER", 0,0)
  f.bgUL:AddMaskTexture(f.mask)
  f.bgUR:AddMaskTexture(f.mask)
  f.bgBL:AddMaskTexture(f.mask)
  f.bgBR:AddMaskTexture(f.mask)
  f.bdUL:AddMaskTexture(f.mask)
  f.bdUR:AddMaskTexture(f.mask)
  f.bdBL:AddMaskTexture(f.mask)
  f.bdBR:AddMaskTexture(f.mask)

  f:SetScript("OnEnter",function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(bsloot._guildName)
    GameTooltip:AddLine(string.format(INSPECT_GUILD_NUM_MEMBERS,bsloot:table_count(bsloot.db.profile.guildcache)),1,1,1)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave",function(self)
    if GameTooltip:IsOwned(self) then
      GameTooltip_Hide()
    end
  end)
  self._guildLogo = f
  self._guildLogo:SetParent(self.blizzoptions)
  self._guildLogo:ClearAllPoints()
  self._guildLogo:SetPoint("TOPRIGHT", self.blizzoptions, "TOPRIGHT", 0,0)
  --self._guildLogo:SetIgnoreParentAlpha(true)
end

function bsloot:split(inputstr, sep)
    if sep == nil then
            sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            table.insert(t, str)
    end
    return t
end

function bsloot:isItemLink(msg)
    return (msg and msg ~= nill and string.match(msg, "item:(%d+)") ~= nil)
end

function bsloot:resetAllStoredData(preserveSettings)
  if (not preserveSettings or preserveSettings == nil) then
    BSLootDB = {}
  end
  bsloot:purgeNonEventData()
  SyncEvents = {}
  InboundSyncQueue = {first = 0, last = -1}
  Baseline = nil
end

function bsloot:purgeNonEventData()
  EPGPTable = {}
  ItemGPCost = {}
  EPValues = {}
  EventsToProcessQueue = {}
  BossKillCounter = {}
  BisMatrix = {}
  RaidHistory = {}
  EPGPCache = {}
  CharRoleDB = {}
end

function bsloot:OnCommReceived(prefix, msg, distro, sender)
  bsloot:debugPrint("Comm received(" ..distro .."): \"" .. msg .. "\" from: " .. sender, bsloot.statics.LOGS.COMM)
  local sender = Ambiguate(sender, "short")
  if prefix == bsloot.VARS.prefix then
    
    if(string.find(msg, "check ") == 1) then
      if(bsloot:isSourceOfTrue("loot", sender)) then
        bsloot:respondToCheck(msg, sender)
      else
        bsloot:untrustedMessage(msg, sender)
      end
      
    elseif(string.find(msg, "requiredMods") == 1) then
      if(bsloot:isSourceOfTrue("requiredMods", sender)) then
        local args = bsloot:split(msg)
        bsloot:checkRequiredMods(args[2], sender)
      else
        bsloot:untrustedMessage(msg, sender)
      end
    elseif(string.find(msg, "haveMods") == 1) then
      local args = bsloot:split(msg)
      bsloot:receiveModCheckFrom(args[2], sender)
    elseif(string.find(msg, "clearLoot") == 1) then
      if(bsloot:isSourceOfTrue("loot", sender)) then
        bsloot:clearItemWindow()
      else
        bsloot:untrustedMessage(msg, sender)
      end
    elseif(string.find(msg, "itemWinner") == 1) then
      if(bsloot:isSourceOfTrue("loot", sender)) then
        local args = bsloot:split(msg)
        bsloot:handleWinnerNotification(args[2], args[3])
      else
        bsloot:untrustedMessage(msg, sender)
      end 
    elseif(string.find(msg, "requestItemWindowRefresh") == 1) then
      if(bsloot:isSourceOfTrue("loot")) then
        bsloot:sendItemWindowRefresh(sender)
      end  
    elseif(string.find(msg, "forceClear") == 1) then
      if(bsloot:isSourceOfTrue("forceData", sender)) then
        bsloot:resetAllStoredData()
      else
        bsloot:untrustedMessage(msg, sender)
      end
    elseif(string.find(msg, "!") == 1) then
      if(bsloot:isSourceOfTrue("roll", sender)) then
        bsloot:processRelay(msg, sender)
      else
        bsloot:untrustedMessage(msg, sender)
      end
    elseif(string.find(msg, "#") == 1) then
      if(bsloot:isSourceOfTrue("loot", sender)) then
        bsloot:processRelayResponse(msg, sender)
      else
        bsloot:untrustedMessage(msg, sender)
      end
    end
    
  elseif prefix == bsloot.VARS.prefix.."_sync" then
    
    if sender == self._playerName then return end -- don't care for our own message
    
    bsloot:debugPrint("Sync Comm received(" ..distro .."): \"" .. msg .. "\" from: " .. sender, bsloot.statics.LOGS.SYNC)
    if(bsloot.sync:IsEnabled()) then
      if(string.find(msg, "syncOffer ") == 1) then
        if(bsloot:isSourceOfTrue("sync", sender)) then
          bsloot.sync:checkSyncOffer(strsub(msg, 11), sender)
        end
        
      elseif(string.find(msg, "syncGetIds") == 1) then
        bsloot.sync:receiveIdRequest(sender)
      elseif(string.find(msg, "syncIds ") == 1) then
        bsloot.sync:receiveIdResponse(strsub(msg, 9), sender)
      elseif(string.find(msg, "syncGet ") == 1) then
        bsloot.sync:receiveEventDataRequest(strsub(msg, 9), sender)
      elseif(string.find(msg, "syncGetSince ") == 1) then
        bsloot.sync:receiveDataSinceRequest(strsub(msg, 14), sender)
      elseif(string.find(msg, "syncGetAll") == 1) then
        bsloot.sync:syncAllOut(sender)
      elseif(string.find(msg, "syncGive ") == 1) then
        if(bsloot:isSourceOfTrue("sync", sender)) then
          bsloot.sync:receiveInboundEvent(strsub(msg, 10), sender)
        end
      end
    end
  end

end
function bsloot:sendItemWindowRefresh(sendTo)
  
  local rollWindow = bsloot:GetModule(addonName.."_window_roll_present")
  if rollWindow then
    local item, rolls, passes = rollWindow:GetBasiccData()
    if(item and item ~= nil) then
      
      local itemID = GetItemInfoInstant(item)
      bsloot:warnPrint("Sending item refresh to "..sendTo.." for "..item.." with "..bsloot:tablelength(rolls) .." rolls and "..bsloot:tablelength(passes) .." passes")
      bsloot:broadcast("check " .. item, bsloot.statics.channel.WHISPER, sendTo)
      for char, roll in pairs(rolls) do
        bsloot:buildAndSendRoll(itemID, char, roll.ep, roll.gp, roll.pr, roll.modifier, roll.effectivePr, sendTo)
      end
      for char, _ in pairs(passes) do
        bsloot:buildAndSendPass(char, sendTo)
      end
    else
      bsloot:debugPrint("Attempt to refresh item windo for "..sendTo..", but you are not presenting an item", bsloot.statics.LOGS.LOOT)
    end
  else
    bsloot:errorPrint("Unable to refresh item window for "..sendTo, bsloot.statics.LOGS.LOOT)
  end
end

function bsloot:debugPrint(msg,verbosityOfMessage)
  if(bsloot:checkVerbosity(verbosityOfMessage)) then
    if not self._debugchat then
      for i=1,NUM_CHAT_WINDOWS do
        local tab = _G["ChatFrame"..i.."Tab"]
        local cf = _G["ChatFrame"..i]
        local tabName = tab:GetText()
        if tab ~= nil and (tabName:lower() == "debug") then
          self._debugchat = cf
          ChatFrame_RemoveAllMessageGroups(self._debugchat)
          ChatFrame_RemoveAllChannels(self._debugchat)
          self._debugchat:SetMaxLines(1024)
          break
        end
      end
    end  
    if self._debugchat then
      self:Print(self._debugchat,msg)
    else
      self:Print(msg)
    end
  end
end
function bsloot:errorPrint(msg,verbosityOfMessage)
    self:Print(C:Red(msg))
end
function bsloot:removePrint(msg)
  if(
    bsloot._playerName == "Murach" or bsloot._playerName == "Icce" or bsloot._playerName == "Bsbank"
    -- or bsloot._playerName == "Sariel" or bsloot._playerName == "Mokurei"
  ) then
    self:Print(C:Purple(msg))
  end
end
function bsloot:warnPrint(msg,verbosityOfMessage)
  self:Print(C:Yellow(msg))
end

function bsloot:checkVerbosity(verbosityOfMessage)
  if(not verbosityOfMessage or verbosityOfMessage == nil) then
    return true
  end
  local shouldPrint = true
  if(type(verbosityOfMessage) == "number") then
    shouldPrint = bit.band(bsloot.db.profile.logs.verbosity, verbosityOfMessage) == verbosityOfMessage
  elseif(type(verbosityOfMessage) == "table") then
    local logicOp = verbosityOfMessage.logicOp -- NOT is not supported (yet?)
    if(logicType == "OR") then
      shouldPrint = false
    end
    for _, verbosity in ipairs(verbosityOfMessage.values) do
      if(logicOp == "OR") then
        shouldPrint = shouldPrint or bsloot:checkVerbosity(verbosity)
      elseif(logicOp == "AND") then
        shouldPrint = shouldPrint and bsloot:checkVerbosity(verbosity)
      else
        bsloot:warnPrint("Unhandled logic operator: "..tableToString(logicOp), bsloot.statics.LOGS.DEV)
      end
    end
  else
    bsloot:warnPrint("Unhandled verbosity type: "..type(verbosityOfMessage), bsloot.statics.LOGS.DEV)
  end 
  return shouldPrint
end
function bsloot:parseVersion(version,otherVersion)
  if not bsloot._version then bsloot._version = {} end
  for major,minor,patch in string.gmatch(version,"(%d+)[^%d]?(%d*)[^%d]?(%d*)") do
    bsloot._version.major = tonumber(major)
    bsloot._version.minor = tonumber(minor)
    bsloot._version.patch = tonumber(patch)
  end
  if (otherVersion) then
    if not bsloot._otherversion then bsloot._otherversion = {} end
    for major,minor,patch in string.gmatch(otherVersion,"(%d+)[^%d]?(%d*)[^%d]?(%d*)") do
      bsloot._otherversion.major = tonumber(major)
      bsloot._otherversion.minor = tonumber(minor)
      bsloot._otherversion.patch = tonumber(patch)      
    end
    if (bsloot._otherversion.major ~= nil and bsloot._version.major ~= nil) then
      if (bsloot._otherversion.major < bsloot._version.major) then -- we are newer
        return
      elseif (bsloot._otherversion.major > bsloot._version.major) then -- they are newer
        return true, "major"        
      else -- tied on major, go minor
        if (bsloot._otherversion.minor ~= nil and bsloot._version.minor ~= nil) then
          if (bsloot._otherversion.minor < bsloot._version.minor) then -- we are newer
            return
          elseif (bsloot._otherversion.minor > bsloot._version.minor) then -- they are newer
            return true, "minor"
          else -- tied on minor, go patch
            if (bsloot._otherversion.patch ~= nil and bsloot._version.patch ~= nil) then
              if (bsloot._otherversion.patch < bsloot._version.patch) then -- we are newer
                return
              elseif (bsloot._otherversion.patch > bsloot._version.patch) then -- they are newwer
                return true, "patch"
              end
            elseif (bsloot._otherversion.patch ~= nil and bsloot._version.patch == nil) then -- they are newer
              return true, "patch"
            end
          end    
        elseif (bsloot._otherversion.minor ~= nil and bsloot._version.minor == nil) then -- they are newer
          return true, "minor"
        end
      end
    end
  end
end


function bsloot:CloseSpecialWindows()
  local found = securecall(self.hooks["CloseSpecialWindows"])
  for key,object in pairs(special_frames) do
    object:Hide()
  end
  return found
end

function bsloot:make_escable(object,operation)
  if type(object) == "string" then
    local found
    for i,f in ipairs(UISpecialFrames) do
      if f==object then
        found = i
      end
    end
    if not found and operation=="add" then
      table.insert(UISpecialFrames,object)
    elseif found and operation=="remove" then
      table.remove(UISpecialFrames,found)
    end    
  elseif type(object) == "table" then
    if object.Hide then
      local key = tostring(object):gsub("table: ","")
      if operation == "add" then
        special_frames[key] = object
      else
        special_frames[key] = nil
      end
    end
  end
end

function bsloot:OpenRosterActions(obj)
  if not self._ddoptions then
    self:ddoptions()
  end
  self._ddmenu = LDD:OpenAce3Menu(self._ddoptions)
  local scale, x, y = UIParent:GetEffectiveScale(), GetCursorPosition()
  local half_width, half_height = GetScreenWidth()*scale/2, GetScreenHeight()*scale/2
  local prefix,postfix,anchor
  if x >= half_width then 
    postfix = "RIGHT"
  else
    postfix = "LEFT"
  end
  if y >= half_height then
    prefix = "TOP"
  else
    prefix = "BOTTOM"
  end
  anchor = prefix..postfix
  self._ddmenu:SetClampedToScreen(true)
  self._ddmenu:SetClampRectInsets(-25, 200, 25, -150)
  self._ddmenu:SetPoint(anchor, UIParent, "BOTTOMLEFT", x/scale, y/scale)
end

function bsloot:PLAYER_GUILD_UPDATE(...)
  local unitid = ...
  if unitid and UnitIsUnit(unitid,"player") then
    if IsInGuild() then
      self:Enable()
    end
  end
end

function bsloot:PLAYER_LEVEL_UP(event,...)
  local level = ...
  self._playerLevel = level
  if self._playerLevel == MAX_PLAYER_LEVEL then
    self:UnregisterEvent("PLAYER_LEVEL_UP")
  end
  if self._playerLevel and self._playerLevel >= bsloot.VARS.minlevel then
    self:testMain()
  end
end

function bsloot:isAdmin()
  return IsInGuild() and (CanEditOfficerNote())
end

function bsloot:lootMaster()
  if not IsInRaid() then return end
  local method, partyidx, raididx = GetLootMethod()
  return (method == "master") and (partyidx == 0)
end

function bsloot:raidLeader()
  return IsInRaid() and UnitIsGroupLeader("player")
end

function bsloot:raidAssistant()
  return IsInRaid() and UnitIsGroupAssistant("player")
end

function bsloot:inRaid(name)
  local rid = UnitInRaid(name)
  return IsInRaid() and rid and (rid >= 0)
end

function bsloot:GroupStatus()
  if IsInRaid() and GetNumGroupMembers() > 0 then
    return "RAID"
  elseif UnitExists("party1") then
    return "PARTY"
  else
    return "SOLO"
  end
end

local raidZones = {
  [(GetRealZoneText(249))] = "T1.5", -- Onyxia's Lair
  [(GetRealZoneText(409))] = "T1",   -- Molten Core
  [(GetRealZoneText(469))] = "T2",   -- Blackwing Lair
  [(GetRealZoneText(531))] = "T2.5", -- Ahn'Qiraj Temple
  [(GetRealZoneText(533))] = "T3",   -- Naxxramas
}


-------------------------------------------
--// UTILITY
-------------------------------------------
function bsloot:num_round(i)
  return math.floor(i+0.5)
end

function bsloot:table_count(t)
  local count = 0
  for k,v in pairs(t) do
    count = count+1
  end
  return count
end

function bsloot:getServerTime(minusDays)
  local epochSeconds = GetServerTime()
  if(minusDays and minusDays ~= nil) then
    epochSeconds = epochSeconds - minusDays * 24 * 60 * 60
  end
  local timestamp = bsloot:getTimestampFromEpochSec(epochSeconds)
  return epochSeconds, timestamp
end
function bsloot:getTsBefore(epochSeconds, secondsBefore)
  local seconds = epochSeconds - secondsBefore
  local before = bsloot:getTimestampFromEpochSec(seconds)
  return before
end
function bsloot:getTimestampFromEpochSec(epochSeconds)
  local ts = C_DateAndTime.GetDateFromEpoch(epochSeconds * 1000000)
  ts.epochMS = epochSeconds * 1000
  return ts
end

function bsloot:getRaidTimeFromDateString(dateString)
  --assume yyyy-mm-dd or yyyymmdd
  local year = 0
  local month = 0
  local day = 0 
  if(string.find(dateString, "-")) then
    year = tonumber(strsub(dateString, 1, 4))
    month = tonumber(strsub(dateString, 6, 7))
    day = tonumber(strsub(dateString, 9))
  else
    year = tonumber(strsub(dateString, 1, 4))
    month = tonumber(strsub(dateString, 5, 6))
    day = tonumber(strsub(dateString, 7))
  end
  local epochSeconds = time({day=day,month=month,year=year,hour=19,min=0,sec=0})

  local startTimestamp = bsloot:getTimestampFromEpochSec(epochSeconds)
  local latestSameDayRaid = epochSeconds - (60 * 60)
  local sameDayRaidFound = false
  for eventId, e in pairs(SyncEvents) do
    if(e.type == bsloot.statics.eventType.RAID) then
      local eventData = bsloot:getEventData(eventId, e.type)
      if(eventData ~= nil) then
        if(eventData.subType == bsloot.statics.eventSubType.RAID_START) then
          local raidStartTimestamp = bsloot:getTimestampFromEpochSec(e.epochSeconds)
          if(bsloot:isSameDay(startTimestamp, raidStartTimestamp)) then
            sameDayRaidFound = true
            latestSameDayRaid = math.max(latestSameDayRaid, e.epochSeconds)
          end
        end
      end
    end
  end
  epochSeconds = latestSameDayRaid + (60 * 60)
  local eventTimestamp = bsloot:getTimestampFromEpochSec(epochSeconds)
  local startEpochSec, endEpochSec = (epochSeconds-(60*5)), (epochSeconds+(60*5))
  if(sameDayRaidFound) then
    startEpochSec = startEpochSec + (60*5)
    endEpochSec = endEpochSec + (60*5)
  end
  startTimestamp = bsloot:getTimestampFromEpochSec(startEpochSec)
  local endTimestamp = bsloot:getTimestampFromEpochSec(endEpochSec)
  return startTimestamp, eventTimestamp, endTimestamp
end

function bsloot:isSameDay(ts1, ts2)
  return ts1.year == ts2.year and ts1.month == ts2.month and ts1.day == ts2.day
end

function bsloot:getClassData(class) -- CLASS, class, classColor
  local eClass = classToEnClass[class]
  local lClass = LOCALIZED_CLASS_NAMES_MALE[class] or LOCALIZED_CLASS_NAMES_FEMALE[class]
  if eClass then
    return eClass, class, hexClassColor[class]
  elseif lClass then
    return class, lClass, hexClassColor[lClass]
  end
end

function bsloot:getItemData(itemLink) -- itemcolor, itemstring, itemname, itemid
  local link_found, _, itemColor, itemString, itemName = string.find(itemLink, "^(|c%x+)|H(.+)|h(%[.+%])")
  if link_found then
    local itemID = GetItemInfoInstant(itemString)
    return itemColor, itemString, itemName, itemID
  else
    return
  end
end

function bsloot:getItemQualityData(quality) -- id, name, qualityColor
  -- WARNING: itemlink parsed color does NOT match the one returned by the ITEM_QUALITY_COLORS table
  local id, hex = tonumber(quality), type(quality) == "string"
  if id and id >=0 and id <= 5 then
    return id, _G["ITEM_QUALITY"..id.."_DESC"], ITEM_QUALITY_COLORS[id].hex
  elseif hex then
    id = hexColorQuality[quality]
    if id then
      return id, _G["ITEM_QUALITY"..id.."_DESC"], quality
    end
  end
end

-- local fullName, rank, rankIndex, level, class, zone, note, officernote, online, isAway, classFileName, achievementPoints, achievementRank, isMobile, canSoR, repStanding, GUID = GetGuildRosterInfo(index)
function bsloot:verifyGuildMember(name)
  for i=1,GetNumGuildMembers(true) do
    local g_name, g_rank, g_rankIndex, g_level, g_class, g_zone, g_note, g_officernote, g_online, g_status, g_eclass, _, _, g_mobile, g_sor, _, g_GUID = GetGuildRosterInfo(i)
    g_name = Ambiguate(g_name,"short") --:gsub("(\-.+)","")
    if (string.lower(name) == string.lower(g_name)) then
      return g_name, g_class, g_rankIndex, g_officernote
    end
  end
  if (name and name ~= "") then
    bsloot:debugPrint(string.format(L["%s not found in the guild or not raid level!"],name), bsloot.statics.LOGS.ROSTER)
  end
  return
end

--BEGIN "OB message routing" handling

function bsloot:broadcastSync(dataToSend, toPlayer)
  local sent = false
  if(not toPlayer or toPlayer == nil) then
    bsloot:debugPrint("Sending sync msg: ".. dataToSend, bsloot.statics.LOGS.SYNC)
    bsloot:SendCommMessage(bsloot.VARS.prefix.."_sync",dataToSend,"GUILD")
    sent = true
  else
    if(bsloot:isGuildMemberOnline(toPlayer)) then
      bsloot:debugPrint("Sending sync msg to "..toPlayer..": ".. dataToSend, bsloot.statics.LOGS.SYNC)
      bsloot:SendCommMessage(bsloot.VARS.prefix.."_sync",dataToSend,"WHISPER", toPlayer)
      sent = true
    end
  end
  return sent
end

function bsloot:broadcast(dataToSend, target, subtarget)
  bsloot:debugPrint(string.format("Sending \"%s\" to %s (%s)", dataToSend, (target or "default"), (subtarget or "")), {logicOp="AND", values={bsloot.statics.LOGS.DEV, bsloot.statics.LOGS.COMM}})
  
  local sent = false
  if(target == "GUILD" or target == nil) then
    bsloot:SendCommMessage(bsloot.VARS.prefix,dataToSend,"GUILD")
    sent = true
  elseif (target == "RAID" and bsloot:GroupStatus()=="RAID") then
    bsloot:SendCommMessage(bsloot.VARS.prefix,dataToSend,"RAID")
    sent = true
  elseif (target == "PARTY" or (target == "RAID" and not bsloot:GroupStatus()=="RAID")) then
    bsloot:SendCommMessage(bsloot.VARS.prefix,dataToSend,"PARTY")
    sent = true
  elseif (target == "OFFICER") then
    bsloot:SendCommMessage(bsloot.VARS.prefix,dataToSend,"OFFICER")
    sent = true
  elseif (target == "INSTANCE_CHAT") then
    bsloot:SendCommMessage(bsloot.VARS.prefix,dataToSend,"INSTANCE_CHAT")
    sent = true
  elseif (target == "CHANNEL") then
    bsloot:SendCommMessage(bsloot.VARS.prefix,dataToSend,"CHANNEL", subtarget)
    sent = true
  elseif (target == "YELL") then
    bsloot:SendCommMessage(bsloot.VARS.prefix,dataToSend,"YELL")
    sent = true
  elseif (target == "SAY") then
    bsloot:SendCommMessage(bsloot.VARS.prefix,dataToSend,"SAY")
    sent = true
  elseif (target == "WHISPER") then
    if(bsloot:isGuildMemberOnline(subtarget)) then
      bsloot:SendCommMessage(bsloot.VARS.prefix,dataToSend,"WHISPER", subtarget)
      sent = true
    end
  else 
    if(bsloot:isGuildMemberOnline(target)) then
      bsloot:SendCommMessage(bsloot.VARS.prefix,dataToSend,"WHISPER", target)
      sent = true
    end
  end
  return sent
end
--END "OB message routing" handling
function bsloot:presentItemToRollOn(item)
  
  if(bsloot:isSourceOfTrue("loot") ) then
    bsloot:broadcast("check " .. item, bsloot.statics.channel.RAID)
    local raidMsg = string.format(L["Presenting item for roll %s. Use mod or whisper !need or !pass"],item)
    
    local rollWindow = bsloot:GetModule(addonName.."_window_roll_present")
    if rollWindow then
      rollWindow.announced = false
    end
    bsloot:SendChat(raidMsg, bsloot.db.profile.chat.presentItemToRollOn)
  end
end

function bsloot:SendChat(msg, settings, inReplyTo)
  if(settings.RAID) then
    SendChatMessage(msg, "RAID", "Common")
  end
  if(settings.RAID_WARNING) then
    if (self:raidLeader() or self:raidAssistant()) then
      SendChatMessage(msg, "RAID_WARNING", "Common")
    else
      SendChatMessage(msg, "RAID", "Common")
    end
  end
  if(settings.GUILD) then
    SendChatMessage(msg, "GUILD", "Common")
  end
  if(settings.WIDEST) then
    bsloot:widestAudience(msg, inReplyTo)
  end
  if(settings.WHISPER and inReplyTo and inReplyTo ~= nil) then
    if(type(inReplyTo) == "string") then
      if(strtrim(inReplyTo) ~= "") then
        SendChatMessage(msg, "WHISPER", "Common", strtrim(inReplyTo))
      end
    elseif(type(inReplyTo) == "table") then
      for _, v in pairs(inReplyTo) do
        if(strtrim(v) ~= "") then
          SendChatMessage(msg, "WHISPER", "Common", strtrim(v))
        end
        --TODO test array??
      end
    end

  end
  
end

function bsloot:widestAudience(msg, replyTo)
  local groupstatus = self:GroupStatus()
  local channel = nil
  if(groupstatus == "RAID") then
    if (self:raidLeader() or self:raidAssistant()) then
      channel = "RAID_WARNING"
    else
      channel = "RAID"
    end    
  elseif(groupstatus == "PARTY") then
    channel = "PARTY"
  elseif(replyTo and replyTo ~= nil) then
    channel = "WHISPER"
  else
    channel = "GUILD"
  end
  if channel then
    if(channel ~= "WHISPER") then
      SendChatMessage(msg, channel, "Common")
    else
      SendChatMessage(msg, channel, "Common", replyTo)
    end
  end
end

--BEGIN "bid action"
function bsloot:doBid(bidder, item)
  if( not bsloot:isSourceOfTrue("loot")) then
    bsloot:warnPrint("Not currently source of truth for loot, cannot trigger bid for "..bidder, bsloot.statics.LOGS.LOOT)
  end
  if(not item or item == nil) then
    
    local rollWindow = bsloot:GetModule(addonName.."_window_roll_present")
    if rollWindow then
      item, _ = rollWindow:getCurrentItem()
      if(item and item ~= nil) then
        bsloot:debugPrint("No item provided for roll, using current from roll window: "..item, bsloot.statics.LOGS.LOOT)
      end
    end
  end
  
  if(item and item ~= nil) then
    bsloot:doWithItemInfo(item, 
      function(itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
        itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
        isCraftingReagent, itemId)

        local summary = bsloot:getEpGpSummary(bidder)
        local mainChar, isMain = bsloot:getMainChar(bidder)
        bsloot:debugPrint("MainChar for bidder "..bidder.." is "..bsloot:tableToString(mainChar).." and isMain="..bsloot:tableToString(isMain), bsloot.statics.LOGS.LOOT)
        local rollType, rollMods, effectivePr = bsloot:getRollType(bidder, itemId, summary.PR, isMain)
        bsloot:debugPrint("EPGP summary: "..bsloot:tableToString(summary), bsloot.statics.LOGS.EPGP)
        bsloot:publicAckBid(bidder, itemLink, effectivePr)

        local rollNotification = bsloot:buildAndSendRoll(item, bidder, summary.EP, summary.GP, summary.PR, rollMods, effectivePr)
        local raidMsg = "Roll Processed for "..bidder.." with effective PR of <"..effectivePr..">"
        bsloot:SendChat(raidMsg, bsloot.db.profile.chat.bidResult, bidder)
        bsloot:SendChat("Triggered: "..rollNotification, bsloot.db.profile.chat.bidDetails, bidder)
      end)
  else
    bsloot:warnPrint("No item to bid on for "..bidder, bsloot.statics.LOGS.LOOT)
  end
end

function bsloot:buildAndSendRoll(item, bidder, ep, gp, pr, rollMods, effectivePr, onlyTo)
  --format "#roll itemId name rollType ep gp pr modifier effectivePr"
  local rollNotification = "#roll "..item.." "..bidder.." "..ep.." "..gp.." "..pr.." " .. (rollMods or "??") .. " " .. effectivePr
  bsloot:sendRoll(rollNotification, onlyTo)
  return rollNotification
end

function bsloot:sendRoll(rollNotification, onlyTo)
  if(onlyTo and onlyTo ~= nil) then
    return bsloot:broadcast(rollNotification, bsloot.statics.channel.WHISPER, onlyTo)
  else
    return bsloot:broadcast(rollNotification, bsloot.statics.channel.RAID)
  end
end

function bsloot:doPass(bidder)

  if( not bsloot:isSourceOfTrue("loot")) then
    bsloot:warnPrint("Not currently source of truth for loot, cannot trigger pass for "..bidder, bsloot.statics.LOGS.LOOT)
  end


  local rollNotification = bsloot:buildAndSendPass(bidder)
  bsloot:SendChat("Triggered: "..rollNotification, bsloot.db.profile.chat.passAck, bidder)
  local raidMsg = "Pass received for "..bidder
  
  bsloot:SendChat(raidMsg, bsloot.db.profile.chat.passResult)
end

function bsloot:buildAndSendPass(bidder, onlyTo)
  local rollNotification = "#pass "..bidder
  
  bsloot:sendRoll(rollNotification, onlyTo)
  return rollNotification
end

function bsloot:publicAckBid(bidder, itemLink, effectivePr)
  local message = "ACK: Bid from "..bidder.." for "..itemLink.." effectivePr: "..effectivePr
  bsloot:SendChat(message, bsloot.db.profile.chat.bidAck, bidder)
end
--END "bid action"

-- BEGIN Relay Handling

function bsloot:processRelay(msg, sender)
    args = bsloot:split(msg)
    if(args[1]=="!pass") then
      bsloot:doPass(sender)
    elseif(args[1]=="!autopass") then
      local rollNotification = "#pass "..sender
      bsloot:SendChat("Triggering Autopass: "..rollNotification, bsloot.db.profile.chat.autoPassAck, sender)
      bsloot:broadcast(rollNotification, bsloot.statics.channel.RAID)
      local raidMsg = "AutoPass received for "..sender
      bsloot:SendChat(raidMsg, bsloot.db.profile.chat.autoPassResult, sender)
    elseif(args[1]=="!autoroll") then
      local raidMsg = "AutoRoll received for "..sender
      bsloot:SendChat(raidMsg, bsloot.db.profile.chat.autoRollAck, sender)
      bsloot:doBid(sender, args[2])
    elseif(args[1] == "!need") then
      bsloot:doBid(sender, args[2])
    end
end
function bsloot:handleWinnerNotification(winner, item)
  if(winner == bsloot._playerName) then
    bsloot:debugPrint("I won! I won a "..item, bsloot.statics.LOGS.LOOT)
    bsloot.db.char.autoRollItems[tonumber(item)] = nil
  end
end

function bsloot:processRelayResponse(msg, sender)
    args = bsloot:split(msg)
    if(args[1]=="#roll") then
        bsloot:debugPrint("Processing "..args[2].."'s roll", bsloot.statics.LOGS.LOOT)
        local rollWindow = bsloot:GetModule(addonName.."_window_roll_present")
        if rollWindow then
            --assume "#roll itemId name rollType ep gp pr modifier effectivePr"
            rollWindow:updateRolls(args[2], args[3], args[4], args[5], args[6], args[7], args[8])
        end
    elseif(args[1]=="#pass") then
        local rollWindow = bsloot:GetModule(addonName.."_window_roll_present")
        if rollWindow then
            bsloot:debugPrint("Processing "..args[2].."'s pass", bsloot.statics.LOGS.LOOT)
            rollWindow:updatePass(args[2])
        end
    end
end

ItemGPCost = ItemGPCost or {}
EPValues = EPValues or {}
BisMatrix = BisMatrix or {}
CharRoleDB = CharRoleDB or {}
RaidHistory = RaidHistory or {}
BossKillCounter = BossKillCounter or {}

function bsloot:changeMainChar(fromChar, toChar, gpVal, epPenalty)
  
  --save/broadcase event
  local eventData, eventType = bsloot:buildEventChangeMainChar(fromChar, toChar, amount, bsloot.statics.EPGP.LOOT, subReason)
  bsloot:recordEvent(eventType, eventData)
  
  if(gpVal and gpVal ~= nil) then
    if(type(gpVal) ~= "number") then
      gpVal = tonumber(gpVal)
    end
    if(gpVal ~= 0 and gpVal ~= nil) then
      if(gpVal < 0) then
        gpVal = gpVal * -1
      end
      bsloot:gpToPlayer(fromChar, gpVal, "ChangingMain", toChar)
    end
  end
  if(epPenalty and epPenalty ~= nil) then
    if(type(epPenalty) ~= "number") then
      epPenalty = tonumber(epPenalty)
    end
    if(epPenalty ~= 0 and epPenalty ~= nil) then
      if(epPenalty > 0) then
        epPenalty = epPenalty * -1
      end
      bsloot:epToPlayer(fromChar, epPenalty, "ChangingMain", toChar)
    end
  end
end

function bsloot:saveSingleCharacter(name, class, role, mainChar)
  local eventData, eventType = bsloot:buildEventSaveCharacter(name, class, role, mainChar)
  bsloot:recordEvent(eventType, eventData)
end

-- END Relay handling

function bsloot:getPlayerInfoFromRaid(playerName)
  local target = bsloot:sanitizeCharName(playerName)
  local class = nil
  for raidIndex=1,40 do
    name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(raidIndex);
    if(name ~= nil and bsloot:sanitizeCharName(name) == target) then
      return class
    end
  end
end

function bsloot:getPlayerInfoFromGuild(playerName)
  
  local target = bsloot:sanitizeCharName(playerName)
  local class = nil
  local numGuildMembers = GetNumGuildMembers(true)
  
  for i = 1, numGuildMembers do
    local member_name,_,_,level,class,_,note,officernote,_,_ = GetGuildRosterInfo(i)
    if(name ~= nil and bsloot:sanitizeCharName(name) == target) then
      return class
    end
  end
end
bsloot.defaultRaidRole = {}
bsloot.defaultRaidRole["Warrior"] = "MDPS"
bsloot.defaultRaidRole["Hunter"] = "RDPS"
bsloot.defaultRaidRole["Shaman"] = "Healer"
bsloot.defaultRaidRole["Druid"] = "Healer"
bsloot.defaultRaidRole["Rogue"] = "MDPS"
bsloot.defaultRaidRole["Priest"] = "Healer"
bsloot.defaultRaidRole["Warlock"] = "RDPS"
bsloot.defaultRaidRole["Mage"] = "RDPS"

function bsloot:getRole(bidder, class, bidderDetails)
  
  local bidderDetails = CharRoleDB[bidder]
  local role = nil
  if(bidderDetails and bidderDetails ~= nil) then
    if(not class or class == nil) then
      class = bsloot:camelCase(bidderDetails.class)
    end
    role = bidderDetails.role
  else
    class = bsloot:getPlayerInfoFromRaid(bidder)
    if(not class or class == nil) then
      class = bsloot:getPlayerInfoFromGuild(bidder)
    end
    if(class and class ~= nil) then
      role = bsloot.defaultRaidRole[class]
    end
    if(not class or class == nil) then
      class = "Unknown"
    end
    if(not role or role == nil) then
      role = "MDPS"
    end
    bsloot:debugPrint("Using default class/role detection for "..bidder.." class="..class.." role="..role, bsloot.statics.LOGS.ROSTER)
  end
  return role, class
end

function bsloot:getRollType(bidder, item, basePr, isMain)
    osType = -1
    memeType = -2
    notequippable = -3
    local rollType = -3
    local rollMods = ""
    local effectivePr = -10000000
    local itemId = GetItemInfoInstant(item)
    local key = bsloot:buildEpGpEventReasonKey(bsloot.statics.eventType.GP_VAL, bsloot.statics.EPGP.LOOT, itemId)
    local altMod = 0
    if(isMain ~= nil and not isMain) then
      altMod = bsloot.VARS.prModAlt
    end
    local currentCompletedPhase = 2 --TODO settings? hardcode? event?
    
    local pctMod = 0
    local rollModsAffix = ""
    if(BisMatrix[key] and BisMatrix[key] ~= nil) then
      local itemDetails = BisMatrix[key]
      local role, class = bsloot:getRole(bidder)
      local ms = itemDetails.bisThrough[class][role]
      local bestForClass = -5
      for _, val in pairs(itemDetails.bisThrough[class]) do
        if(val > bestForClass) then
          bestForClass = val
        end
      end
      
      if(ms < 0 or not ms or ms == nil or (ms == 0 and ms < bestForClass)) then
        local _, maxPr = bsloot:getStandings()
        if(ms<currentCompletedPhase and bestForClass>ms and bestForClass >= 0) then
         --use OS
         rollType = osType
         if(basePr and basePr ~= nil and isMain ~= nil) then
          local flatmod = -1.6 * maxPr
          rollModsAffix =  ""..flatmod
          pctMod =  ((ms * bsloot.VARS.prModPerBisPhase) - (altMod))
          effectivePr = basePr + flatmod + (basePr * pctMod)
         end
        elseif (bestForClass == -1) then
          --use meme
          rollType = memeType
          if(basePr and basePr ~= nil and isMain ~= nil) then
            pctMod =  0
            local flatmod = -10 * maxPr
            rollModsAffix =  ""..flatmod
            effectivePr = basePr + flatmod
          end
        end 

      else
        --use ms
        rollType = ms
        if(basePr and basePr ~= nil and isMain ~= nil) then
          pctMod =  ((ms * bsloot.VARS.prModPerBisPhase) - (altMod))
          effectivePr = basePr + (basePr * pctMod)
        end
      end
      if (pctMod > 0) then
        rollMods = "+"..(pctMod * 100 ).."%"
      elseif (pctMod < 0) then
        rollMods = ""..(pctMod * 100 ).."%"
      end
      if(rollModsAffix ~= "") then
        rollMods = rollMods .. rollModsAffix
      end
      if (rollMods == "") then
        rollMods = "N/A"
      end
      return rollType, rollMods, effectivePr
    end
    --[[

if not basePr, isMain only care about 
MS vs osType = -1
    memeType = -2
    notequippable = -3

      local mods = rollType * bsloot.VARS.prModPerBisPhase 
  if(not summary.isMain) then
    mods = mods - bsloot.VARS.prModAlt
  end
  effectivePr = summary.PR + (mods * summary.PR)
    ]]
    bsloot:debugPrint("Item not found in DB, defaulting to no mod: "..item, {logicOp="AND", values={bsloot.statics.LOGS.LOOT, bsloot.statics.LOGS.PRICE}})
    return 0, "N/A", basePr
end

function bsloot:getMainChar(charName)
  local isMain = false
  charName = bsloot:sanitizeCharName(charName)
  if(CharRoleDB[charName] and CharRoleDB[charName] ~= nil and CharRoleDB[charName].mainChar and CharRoleDB[charName].mainChar ~= nil and CharRoleDB[charName].mainChar ~= "") then
    local mainChar = CharRoleDB[charName].mainChar
    isMain = charName == mainChar
    return mainChar, isMain
  else
    isMain = true
    if(bsloot:isAdmin()) then
      bsloot:debugPrint("No Role Data or mainChar for " .. charName .. ", set their role/main using /bsl roster. They are currently treated as a main", bsloot.statics.LOGS.ROSTER)
    else
      bsloot:debugPrint("No Role Data or mainChar for " .. charName .. ", talk to an officer to set their role. They are currently treated as a main", bsloot.statics.LOGS.ROSTER)
    end
  end
  return charName, isMain
end

function bsloot:sanitizeCharName(charName) 
  return Ambiguate(charName, "short")
end

function bsloot:getEpGpSummary(charName)
    
    local summary = {}
    summary.mainChar, summary.isMain = bsloot:getMainChar(Ambiguate(charName, "short"))
    summary.charName = Ambiguate(charName, "short")
    local cachedEntry = bsloot:getFromCache(summary.mainChar)
    summary.EP = cachedEntry.EP
    summary.GP = cachedEntry.GP
    if(not summary.GP or summary.GP == nil) then
      summary.GP = bsloot.VARS.basegp
    end
    summary.PR = bsloot:calcPr(summary.EP, summary.GP)
    return summary
end
function bsloot:calcPr(ep, gp)
  local pr = ep / gp
  if(ep < bsloot.VARS.minep) then
    pr = 0
  end
  return pr
end
function bsloot:getFromCache(mainChar, forceRefresh)
  if(not EPGPCache or EPGPCache == nil) then
    EPGPCache = {}
  end
  if(not EPGPCache[mainChar] or EPGPCache[mainChar] == nil) then
    mainChar = bsloot:getMainChar(mainChar)
  end
  local cachedEntry = EPGPCache[mainChar]
  local _, timestamp = bsloot:getServerTime()
  local nowMS = timestamp.epochMS
  if(not cachedEntry or cachedEntry == nil 
    or not cachedEntry.expiration or cachedEntry.expiration == nil or cachedEntry.expiration < nowMS 
    or forceRefresh) then
    cachedEntry = bsloot:refreshCache(mainChar)
  end
  return cachedEntry
end

EPGPCache = EPGPCache or {}

function bsloot:updateCache(event, playerName, weeklyKey)
  local thisWeeklyKey = bsloot:getWeeklyKey()
  if(not EPGPCache[playerName] or EPGPCache[playerName] == nil) then
    EPGPCache[playerName] = {}
    EPGPCache[playerName].GP = bsloot.VARS.basegp
  end
  local cachedEntry = bsloot:getFromCache(playerName)
  if(weeklyKey == thisWeeklyKey) then
    if(not cachedEntry[event.type] or cachedEntry[event.type] == nil) then
      cachedEntry[event.type] = 0
    end
    cachedEntry[event.type] = cachedEntry[event.type] + event.amount
  else
    bsloot:refreshCache(playerName)
  end
  return cachedEntry
end

function bsloot:refreshCache(mainChar)
  local _, timestamp = bsloot:getServerTime()
  local nowMS = timestamp.epochMS
  local cachedEntry = {}
  cachedEntry.expiration = nowMS + (14 * 60 * 60 * 1000)
  cachedEntry.EP = 0
  cachedEntry.GP = bsloot.VARS.basegp
  
  local thisWeeklyKey = bsloot:getWeeklyKey()
  if(not EPGPTable[mainChar] or EPGPTable[mainChar] == nil) then
    mainChar = bsloot:getMainChar(mainChar)
  end

  for _, weeklyKey in ipairs(bsloot:getAllWeeklyKeys(mainChar)) do
  
    if(EPGPTable[mainChar][weeklyKey] and EPGPTable[mainChar][weeklyKey] ~= nil) then
      local values = EPGPTable[mainChar][weeklyKey]
      values.Total = {}
      values.Total.EP = 0
      values.Total.GP = 0
      if(values.EP and values.EP ~= nil) then
        for _, ep in ipairs(values.EP) do
          values.Total.EP = values.Total.EP + ep.amount
        end
      end
      if(values.GP and values.GP ~= nil) then
        for _, gp in ipairs(values.GP) do
          values.Total.GP = values.Total.GP + gp.amount
        end
      end
      local weeksEP = values.Total.EP or 0
      local weeksGP = values.Total.GP or 0
      cachedEntry.EP = cachedEntry.EP + weeksEP
      cachedEntry.GP = cachedEntry.GP + weeksGP
    end
    if(weeklyKey ~= thisWeeklyKey) then
      cachedEntry.EP = cachedEntry.EP - cachedEntry.EP * bsloot.VARS.decay
      cachedEntry.GP = cachedEntry.GP - cachedEntry.GP * bsloot.VARS.decay
      if(cachedEntry.GP < bsloot.VARS.basegp) then
        cachedEntry.GP = bsloot.VARS.basegp
      end
    end
  end
  EPGPCache[mainChar] = cachedEntry
  return cachedEntry
end

function bsloot:getAllWeeklyKeys(mainChar)

  local allWeeks = {}
  if(not EPGPTable[mainChar] or EPGPTable[mainChar] == nil) then
    mainChar = bsloot:getMainChar(mainChar)
  end

  if(EPGPTable[mainChar] and EPGPTable[mainChar] ~= nil) then
    --build list of weeks to count
    local toCount = {}
    local counter = 0
    for key, _ in pairs(EPGPTable[mainChar]) do
      toCount[key] = 1
      counter = counter + 1
    end

    local minusDays = 0
    while(counter > 0) do
      local event = {}
      _, event.timestamp = bsloot:getServerTime(minusDays)
      local key = bsloot:getWeeklyKey(event)
      if(toCount[key] and toCount[key] == 1) then
        toCount[key] = nil
        counter = counter - 1
      else
        bsloot:debugPrint("Key "..key.." not found in "..bsloot:tableToString(toCount), bsloot.statics.LOGS.EPGP)
      end
      
      table.insert(allWeeks, key)
      minusDays = minusDays + 7
    end
    table.sort(allWeeks)
  else
    bsloot:debugPrint("No history for "..mainChar, bsloot.statics.LOGS.EPGP)
  end
  return allWeeks
end

function bsloot:doCheckRequiredMods(onlyRaid) 
  local roster = bsloot:getRoster(onlyRaid, (not onlyRaid))
  bsloot_requiredmods:setRoster(roster)
  local channel = bsloot.statics.channel.GUILD
  if(onlyRaid) then
    channel = bsloot.statics.channel.RAID
  end
  bsloot:debugPrint("sending ".."requiredMods " .. bsloot_requiredmods:getRequiredModsStr(), bsloot.statics.LOGS.MODS)
  bsloot:broadcast("requiredMods " .. bsloot_requiredmods:getRequiredModsStr(), channel)  
end

function bsloot:checkRequiredMods(requiredModsStr, replyTo)
    local requiredMods = {}
    requiredMods = bsloot:split(requiredModsStr, "|")
    local numMods = GetNumAddOns()
    
    output = {}
    for i=1,numMods do
        name, title, notes, loadable, reason, security, newVersion = GetAddOnInfo(i)
        version = GetAddOnMetadata(i, "Version") 
        enabled = GetAddOnEnableState(bsloot._playerName, i)
        if(name == nil) then
            name = "nil"
        end
        for _,rMod in ipairs(requiredMods) do
          if(output[rMod] == nil or output[rMod] == "NOT FOUND") then
            output[rMod] = "NOT FOUND"
                if(string.match(name, rMod)) then
                  output[rMod] = {}
                  output[rMod].enabled = -1
                  if(title == nil) then
                      title = "nil"
                  end
                  if(notes == nil) then
                      notes = "nil"
                  end
                  if(enabled == nil) then
                      enabled = "nil"
                  end
                  if(version == nil) then
                    version = GetAddOnMetadata(i, "version") 
                    if(version == nil) then
                      if(name == "ClassicLootAssistant") then
                        if(CLA_VERSION and CLA_VERSION ~= nil) then
                          version = CLA_VERSION
                        end
                      elseif(name == "ItemRack") then
                        if(ItemRack and ItemRack ~= nil) then
                          version = ItemRack.Version
                        end
                      end
                      if(version == nil) then
                        version = "nil"
                      end
                    end
                  end
                  output[rMod].version = version
                  output[rMod].enabled = enabled
                  line = i .. ": " .. name .. " (" .. title .. ") " .. version .. " enabled: " .. enabled
                  bsloot:debugPrint(line, {logicOp="AND", values={bsloot.statics.LOGS.DEV, bsloot.statics.LOGS.MODS}})
                end
            end
        end
    end
    outputStr = ""
    outputStrDiv = ""
    for _,rMod in ipairs(requiredMods) do
      if(output[rMod] == nil or output[rMod] == "NOT FOUND") then
        output[rMod] = {}
        output[rMod].enabled = -1
      end
      outputStr = outputStr .. outputStrDiv .. rMod .. "`" .. bsloot:tableToString(output[rMod].version) .. "`" .. bsloot:tableToString(output[rMod].enabled) 
      outputStrDiv = "|"
    end
    
    bsloot:debugPrint("sending ".."haveMods=\"" .. outputStr .."\"", bsloot.statics.LOGS.MODS)
    return bsloot:broadcast("haveMods " .. outputStr, bsloot.statics.channel.WHISPER, replyTo)
end

function bsloot:receiveModCheckFrom(haveModStr, from)
  bsloot:debugPrint("receiving ".."haveModStr=\"" .. haveModStr .."\"", bsloot.statics.LOGS.MODS)
  parsedResponse = {}
  local modArray = bsloot:split(haveModStr, "|")
  for _, entry in ipairs(modArray) do
    local entryArray = bsloot:split(entry, "`")
    local modName = entryArray[1]
    
    parsedResponse[modName] = {}
    parsedResponse[modName].version = strtrim(entryArray[2], "\" \t\n\r")
    parsedResponse[modName].enabled = tonumber(strtrim(entryArray[3], "\" \t\n\r"))
    parsedResponse[modName].modName = strtrim(modName, "\" \t\n\r")
  end
  bsloot_requiredmods:addResponse(from, parsedResponse)
end

--BEGIN "check" handling
function bsloot:respondToCheck(msg, sender)
    bsloot:broadcast("ACK " .. msg, bsloot.statics.channel.WHISPER, sender)
    args = bsloot:split(msg)
  
    for i, val in ipairs(args) do
      bsloot:debugPrint("args["..i.."]="..val, {logicOp="AND", values={bsloot.statics.LOGS.DEV, bsloot.statics.LOGS.COMM}})
    end
    local checkType = args[2]
    if(checkType == "slot") then
      bsloot:respondGearSlotCheck(sender, args[3])
    elseif(bsloot:isItemLink(args[2])) then
      local item = strsub(msg, 7);
      bsloot:debugPrint("Presenting "..item, bsloot.statics.LOGS.LOOT)
      local itemid = GetItemInfoInstant(item)
      
      local success, rollType = pcall(function() 
        return bsloot:getRollType(bsloot._playerName, itemid) 
      end)
      local autoActionTaken = false
      
      if(bsloot.db.char.autoPassItems[itemid] and bsloot.db.char.autoPassItems[itemid]==1) then
        --Auto pass
        bsloot:broadcast("!autopass "..itemid, bsloot.statics.channel.WHISPER, sender)
        autoActionTaken = true
      end
      if(bsloot.db.char.autoRollItems[itemid] and bsloot.db.char.autoRollItems[itemid]==1) then
        --Auto roll
        bsloot:broadcast("!autoroll "..itemid, bsloot.statics.channel.WHISPER, sender)
        autoActionTaken = true
      end
      local showWindow =  (not autoActionTaken) or bsloot:isSourceOfTrue("loot")
      bsloot:presentItemWindow(sender, itemid, rollType, showWindow)
    else
      bsloot:broadcast("Unknown check " .. checkType, bsloot.statics.channel.WHISPER, sender)
    end
  end
  function bsloot:respondGearSlotCheck(sender, slot)
      item = GetInventoryItemLink("player", GetInventorySlotInfo(slot))
      bsloot:broadcast("Wearing " .. item .. " in " .. slot, bsloot.statics.channel.WHISPER, sender)
  end

function bsloot:presentItemWindow(sender, item, rollType, shouldShow)
    
    local rollWindow = bsloot:GetModule(addonName.."_window_roll_present")
    if rollWindow then
        rollWindow:presentItem(sender, item, bsloot:getRaidRoster(), rollType, shouldShow)
        bsloot:broadcast("Thinking", bsloot.statics.channel.WHISPER, sender)
    else
        bsloot:broadcast("Failed to display loot window HALP", bsloot.statics.channel.WHISPER, sender)
    end
end

function bsloot:clearItemWindow()
    
    local rollWindow = bsloot:GetModule(addonName.."_window_roll_present")
    if rollWindow then
        rollWindow:Clear(bsloot.db.char.ssOnAnnounce)
    else
        bsloot:broadcast("Failed to clear loot window HALP", bsloot.statics.channel.WHISPER, sender)
    end
end

function bsloot:tableToString(t, depth, maxDepth)
    local out = ""
    local div = ""
    if(not depth or depth == nil) then
      depth = 0
    end
    if(not maxDepth or maxDepth == nil) then
      maxDepth = 4
    end
    if(depth > maxDepth) then
      return "..."
    end
    if (t == nil) then
      out = "nil"
    elseif type ( t ) == "table" then
        out = out .. "{"
        for k, v in pairs(t) do
            out = out .. div .. "\"" .. bsloot:tableToString(k) .. "\": "
            out = out .. bsloot:tableToString(v, depth+1)
            div = ", "
        end
        out = out .. "}"
    elseif type ( t ) == "array" then
        out = out .. "["
        for k, v in ipairs(t) do
            out = out .. div .. "\"" .. k .. "\": "
            out = out .. bsloot:tableToString(v, depth+1)
            div = ", "
        end
        out = out .. "]"
    elseif type ( t ) == "string" or type ( t ) == "number" then
        out = out .. "\"" .. t .. "\""
      elseif  type ( t ) == "boolean" then
        out = out .. (t and "true" or "false")
    else
        out = out .. tostring(out)
    end
    return out
end

function bsloot:epToPlayer(charName, amount, reason, subReason)
  bsloot:singleCharEpGpStore(charName, "EP", amount, reason, subReason)
  bsloot:SendChat("EP grant for " .. reason ..":" .. subReason .. " to "..charName.." completed (".. amount.." EP)", bsloot.db.profile.chat.epGrant, charName)
end
function bsloot:gpToPlayer(charName, amount, reason, subReason)
  bsloot:singleCharEpGpStore(charName, "GP", amount, reason, subReason)
  bsloot:SendChat("GP grant for " .. reason ..":" .. subReason .. " to "..charName.." completed (".. amount.." GP)", bsloot.db.profile.chat.gpGrant, charName)
end


function bsloot:singleCharEpGpStore(charName, eventType, amount, reason, subReason)
  local characters = {}
  table.insert(characters, charName)
  local eventData, eventType = bsloot:buildEventSaveEpGpEvent(characters, eventType, amount, reason, subReason)
  bsloot:recordEvent(eventType, eventData)
end

function bsloot:getWeeklyKeyFromTimestamp(timestamp)
  
  bsloot:debugPrint("timestamp: " .. bsloot:tableToString(timestamp), bsloot.statics.LOGS.EPGP)
  local adjustByDays = 0
  if(timestamp.weekDay >= 3) then
    adjustByDays = (3 - timestamp.weekDay)
  else
    adjustByDays = (3 - timestamp.weekDay) - 7
  end
  bsloot:debugPrint("adding " .. adjustByDays.." days", bsloot.statics.LOGS.EPGP)
  local weekStartMs = timestamp.epochMS + (24 * 60 * 60 * 1000 * adjustByDays)
  local dateOfWeekStart = bsloot:getTimestampFromEpochSec(weekStartMs / 1000)
  local year = dateOfWeekStart.year
  local month = dateOfWeekStart.month
  local day = dateOfWeekStart.day
  return ""..year .. "-" .. bsloot:toTwoDigitStr(month) .. "-" .. bsloot:toTwoDigitStr(day)
end
function bsloot:getWeeklyKeyFromSeconds(seconds)
  
  local timestamp = bsloot:getTimestampFromEpochSec(seconds)
  return bsloot:getWeeklyKeyFromTimestamp(timestamp)
end

function bsloot:getWeeklyKey(event)
  local timestamp = nil
  if(event and event ~= nil and event.timestamp and event.timestamp ~= nil) then
    timestamp = event.timestamp
  else
    _, timestamp = bsloot:getServerTime()
    if(event and event ~= nil) then
      event.timestamp = timestamp
    end
  end
  return bsloot:getWeeklyKeyFromTimestamp(timestamp)
end

function bsloot:toTwoDigitStr(num)
  local numVal = num
  if( type(num) == "number") then
    numVal = tonumber(num)
  end
  local modulod = numVal - math.floor(numVal/100)*100
  local str = ""..modulod
  if(modulod < 10) then
    str = "0" .. str
  end
  return str
end

function bsloot:buildEpGpEvent(characterName, type, amount, reason, timestamp)
    local event = {}
    event.characterName = characterName
    event.type = type:upper()
    event.amount = amount
    event.reason = reason
    event.giver = bsloot._playerName
    if(timestamp and timestamp ~= nil) then
      event.timestamp = timestamp
      event.epochSeconds = timestamp.epochMS / 1000
    else
      event.epochSeconds, event.timestamp = bsloot:getServerTime()
    end
    return event
end
  --END "check" handling

function bsloot:CHAT_MSG_WHISPER(event, msg, sender, language, arg4, simpleSender, status, messageId, unknown, arg9, arg10, chatLineId, senderGuid)
  --bsloot:debugPrint("Processing WHISPER message: "..msg..", "..sender..", "..language..", "..arg4..", "..arg5..", "..status..", "..messageId..", "..unknown..", "..arg9..", "..arg10..", "..chatLineId..", "..senderGuid,{logicOp="AND", values={bsloot.statics.LOGS.DEV, bsloot.statics.LOGS.COMM}})
  local ackTo = {}
  ackTo.channel = "WHISPER"
  ackTo.target = sender
  bsloot:processChatQuery(msg, sender, ackTo)
end
function bsloot:GROUP_ROSTER_UPDATED(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
end
function bsloot:RAID_ROSTER_UPDATE(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
  if(IsInGroup() or IsInRaid()) then
    bsloot:scanForMissingRoles()
  else
    bsloot:playerLeftGroup()
  end
  arg0 = arg0 or ""
  arg1 = arg1 or ""
  arg2 = arg2 or ""
  arg3 = arg3 or ""
  arg4 = arg4 or ""
  arg5 = arg5 or ""
  arg6 = arg6 or ""
  arg7 = arg7 or ""
  arg8 = arg8 or ""
  arg9 = arg9 or ""

end
function bsloot:GROUP_ROSTER_UPDATE(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)

end

function bsloot:BOSS_KILL(encounterId, encounterName)

end
function bsloot:ENCOUNTER_END(encounterID, encounterName, difficultyID, groupSize, success)

end
function bsloot:COMBAT_LOG_EVENT_UNFILTERED(unknown, sourceGUID, sourceName, sourceFlags, sourceFlags2, destGUID, destName, destFlags, destFlags2)

end

function bsloot:DBM_Kill(mod, arg2)
  
  bsloot:removePrint("DBM_Kill detected")
  if(mod.combatInfo and mod.combatInfo ~= nil) then
    for k, v in pairs(mod.combatInfo) do
      bsloot:removePrint("mod.combatInfo."..k .. " exists as a "..type(v))
    end
  end
  bsloot:removePrint("mod="..bsloot:tableToString(mod))
  local guildRaid, raid, group, guildGroup = bsloot:isInGuildRaid()
  
  if(not guildRaid) then
    bsloot:debugPrint("Skipping kill detection due to: not in a guild raid", {logicOp="AND", values={bsloot.statics.LOGS.DEV, bsloot.statics.LOGS.AUTODETECT}})
    return
  end
  if(mod and mod ~= nil) then
    if(mod.combatInfo and mod.combatInfo ~= nil) then
      if(bsloot:isSourceOfTrue("loot")) then
        local bossName = mod.combatInfo.name
        bsloot:removePrint("DBM_Kill name: " .. bsloot:tableToString(bossName), bsloot.statics.LOGS.AUTODETECT)
        local characters = bsloot:getCharactersFromDBMevent(mod)
        if(not characters or characters == nil or bsloot:tablelength(characters) == 0) then
          characters = bsloot:getRaidMembers(true, true)
        end

        local eventData, eventType = bsloot:buildEventSaveRaidBossAttempt(characters, bsloot:getCurrentRaidId(), bossName)
        bsloot:recordEvent(eventType, eventData)

        local ep, progressionEp, reason = bsloot:getEpForEncounter(mod.combatInfo)
        bsloot:debugPrint("Auto EP: " .. ep .. " for "..reason, {logicOp="AND", values={bsloot.statics.LOGS.EPGP, bsloot.statics.LOGS.AUTODETECT}})
        
        bsloot:epToRaid(ep, bsloot.statics.EPGP.BOSSKILL, bossName, true, characters)
        if(progressionEp > 0) then
          bsloot:epToRaid(progressionEp, bsloot.statics.EPGP.PROGRESSION, reason, true, characters)
        end

      end
    else
      bsloot:removePrint("DBM_Kill with mod but not combat info?", bsloot.statics.LOGS.AUTODETECT)
    end
  else
    bsloot:removePrint("DBM_Kill with no mod?", bsloot.statics.LOGS.AUTODETECT)
  end
end
function bsloot:getCharactersFromDBMevent(mod)

end

function bsloot:DBM_Wipe(mod, arg2)
  bsloot:removePrint("DBM_Wipe detected")
  local guildRaid, raid, group, guildGroup = bsloot:isInGuildRaid()
  
  if(mod.combatInfo and mod.combatInfo ~= nil) then
    for k, v in pairs(mod.combatInfo) do
      bsloot:removePrint("mod.combatInfo."..k .. " exists as a "..type(v))
    end
  end
  if(not guildRaid) then
    bsloot:debugPrint("Skipping wipe detection due to: not in a guild raid", {logicOp="AND", values={bsloot.statics.LOGS.DEV, bsloot.statics.LOGS.AUTODETECT}})
    return
  end
  if(mod and mod ~= nil) then
    if(mod.combatInfo and mod.combatInfo ~= nil) then
      if(bsloot:isSourceOfTrue("loot")) then
        bsloot:removePrint("DBM_Wipe name: " .. bsloot:tableToString(mod.combatInfo.name), bsloot.statics.LOGS.AUTODETECT)
        
        local characters = bsloot:getCharactersFromDBMevent(mod)
        if(not characters or characters == nil or bsloot:tablelength(characters) == 0) then
          characters = bsloot:getRaidMembers(true, true)
        end
        local eventData, eventType = bsloot:buildEventSaveRaidBossAttempt(characters, bsloot:getCurrentRaidId(), bossName)
        bsloot:recordEvent(eventType, eventData)
        
        local killEp, progressionEp, reason = bsloot:getEpForEncounter(mod.combatInfo)
        if(progressionEp > 0) then
          bsloot:epToRaid(progressionEp, bsloot.statics.EPGP.PROGRESSION, "WIPE:"..(mod.combatInfo.name or "Unknown boss"), true, characters)
        end
      end
    else
      bsloot:removePrint("DBM_Wipe with mod but not combat info?", bsloot.statics.LOGS.AUTODETECT)
    end
  else
    bsloot:removePrint("DBM_Wipe with no mod?", bsloot.statics.LOGS.AUTODETECT)
  end
end
  
function bsloot:processChatQuery(msg, sender, ackTo)
  bsloot:debugPrint(msg.." from "..ackTo.channel..": "..sender, bsloot.statics.LOGS.COMM)
  sender = Ambiguate(sender, "short")
  if(msg == "!need") then
    bsloot:debugPrint("Roll from whisper: "..sender, bsloot.statics.LOGS.LOOT)
    bsloot:doBid(sender)
  elseif(msg == "!pass") then
    bsloot:debugPrint("Pass from whisper: "..sender, bsloot.statics.LOGS.LOOT)
    bsloot:doPass(sender)
  elseif(msg == "!bids") then
    bsloot:debugPrint("Bid table request from whisper: "..sender, bsloot.statics.LOGS.LOOT)
    local rollWindow = bsloot:GetModule(addonName.."_window_roll_present")
    if rollWindow then
      rollWindow:SendAsChat(sender)
    end
  end
end
--BEGIN Data source trustworthiness check

--return true if this data type is trusted from this source
function bsloot:isSourceOfTrue(dataType, dataSource)
  if(not dataSource or dataSource == nil) then
    dataSource = bsloot._playerName
  end
  local raid = IsInRaid()
  local party = raid or IsInGroup()
  local trusted = false
  if(dataType == "requiredMods") then
    --TODO only guild and raid admins
    return true
  elseif(dataType == "loot") then
    local lootmethod, masterlooterPartyID, masterlooterRaidID = GetLootMethod()
    if(raid) then
      for raidIndex=1,40 do
        name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(raidIndex);
        if(name ~= nil and name == dataSource) then
          local isRaidLead = rank == 2
          local isRaidAssist = rank >= 1
          if(lootmethod == "master") then
            trusted = isML
            return trusted
          end
        end
      end
    elseif(party) then
      if(lootmethod == "master") then
        UnitIsGroupLeader(dataSource)
      end
    end
  elseif (dataType == "sync") then
    local name, class, rank = self:verifyGuildMember(dataSource, true)
    local _, _, myRank = GetGuildInfo("player")
    
    if(rank <= bsloot.syncMinGuildRank or (myRank == nil or rank < myRank)) then
      trusted = true
    end
  elseif (dataType == "forceData") then
    trusted = dataSource == "Murach" or dataSource == "Icce" or dataSource == "Repairmanman"
  elseif (dataType == "roll") then
    trusted = true
  end
  
  -- bsloot:debugPrint((trusted and "trusted" or "untrusted").. "MESSAGE RECEIVED from "..sender..": \"" ..msg.."\"", {logicOp="AND", values={bsloot.statics.LOGS.DEV, bsloot.statics.LOGS.COMM}})
  return trusted
end

function bsloot:untrustedMessage(msg, sender)
  bsloot:debugPrint("UNTRUSTED MESSAGE RECEIVED from "..sender..": \"" ..msg.."\"", bsloot.statics.LOGS.COMM)
end
--END Data source trustworthiness check

function bsloot:getRaidRoster()
  local roster = {}
  for raidIndex=1,40 do
    name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(raidIndex);
    if(name ~= nil) then
      roster[name] = {}
      roster[name].name = name
      roster[name].rank = rank
      roster[name].subgroup = subgroup
      roster[name].level = level
      roster[name].class = class
      roster[name].fileName = fileName
      roster[name].zone = zone
      roster[name].online = online
      roster[name].isDead = isDead
      roster[name].role = role
      roster[name].isML = isML
    end
  end
  bsloot:debugPrint("Raid roster: "..bsloot:tableToString(roster), bsloot.statics.LOGS.ROSTER)
  return roster
end

--BEGIN Auto charge GP for item


function bsloot:chargeGpForItem(itemId, charName)
  if(bsloot:isSourceOfTrue("loot")) then
    local playerName, isMain = bsloot:getMainChar(charName)
    local rollType = bsloot:getRollType(charName, itemId)
    local gpValue = bsloot_prices:GetPrice(itemId, charName, rollType)
    bsloot:debugPrint("Adding "..gpValue.." GP automatically for "..itemId.." to player: "..playerName, bsloot.statics.LOGS.EPGP)
    local characters = {}
    table.insert(characters, charName)
    local eventData, eventType = bsloot:buildEventSaveEpGpEvent(characters, bsloot.statics.eventSubType.GP, gpValue, bsloot.statics.EPGP.LOOT, itemId)
    bsloot:recordEvent(eventType, eventData)
    return gpValue
  end
end
function bsloot:refundGpForItem(itemId, charName)
  if(bsloot:isSourceOfTrue("loot")) then
    local playerName, isMain = bsloot:getMainChar(charName)
    local rollType = bsloot:getRollType(charName, itemId)
    local gpValue = bsloot_prices:GetPrice(itemId, charName, rollType)
    gpValue = gpValue * -1
    bsloot:debugPrint("Refunding "..gpValue.." GP automatically for "..itemId.." to player: "..playerName, bsloot.statics.LOGS.EPGP)
    local characters = {}
    table.insert(characters, charName)
    local eventData, eventType = bsloot:buildEventSaveEpGpEvent(characters, bsloot.statics.eventSubType.GP, gpValue, bsloot.statics.EPGP.LOOT, itemId)
    bsloot:recordEvent(eventType, eventData)
    return gpValue
  end
end
--END Auto charge GP for item

--BEGIN Standings
function bsloot:getStandings(onlyRaid)
  local standings = {}
  local maxPr = -100000000
  if(onlyRaid) then
    for raidIndex=1,40 do
      name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(raidIndex);
      if(name ~= nil) then
        if(level > bsloot.VARS.minlevel) then
          local summary = bsloot:getEpGpSummary(name)
          summary.name = Ambiguate(name, "short")
          summary.class = class
          table.insert(standings, summary)
          if(summary.PR > maxPr) then
            maxPr = summary.PR
          end
        end
      end
    end
  else
    
    local numGuildMembers = GetNumGuildMembers(true)
    for i = 1, numGuildMembers do
        local member_name,_,_,level,class,_,note,officernote,_,_ = GetGuildRosterInfo(i)
        member_name = Ambiguate(member_name,"short")
        
        if(level > bsloot.VARS.minlevel) then
          local summary = bsloot:getEpGpSummary(member_name)
          summary.name = member_name
          summary.class = class
          table.insert(standings, summary)
          if(summary.PR > maxPr) then
            maxPr = summary.PR
          end
        end
    end
  end
  return standings, maxPr
end

function bsloot:getRoster(onlyRaid, onlyOnline)
  local roster = {}
  if(onlyRaid) then
    for raidIndex=1,40 do
      name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(raidIndex);
      if(name ~= nil) then
        if(level > bsloot.VARS.minlevel) then 
          if(not onlyOnline or onlyOnline == nil or online) then  
            table.insert(roster, bsloot:getRosterEntry(name, class))
          end
        end
      end
    end
  else
    
    local numGuildMembers = GetNumGuildMembers(true)
    for i = 1, numGuildMembers do
      local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName, 
      achievementPoints, achievementRank, isMobile, isSoREligible, standingID = GetGuildRosterInfo(i)
      local member_name = Ambiguate(name,"short")
      
      if(level > bsloot.VARS.minlevel) then
        if(not onlyOnline or onlyOnline == nil or online) then 
          table.insert(roster, bsloot:getRosterEntry(member_name, class))
        end
      end
    end
  end
  return roster
end

function bsloot:getRosterEntry(name, class)
  local rosterEntry = {}
  name = Ambiguate(name, "short")
  rosterEntry.name = name
  rosterEntry.class = class
  if(CharRoleDB[name] and CharRoleDB[name] ~= nil and CharRoleDB[name].role ~= nil) then
    rosterEntry.role = CharRoleDB[name].role
    rosterEntry.mainChar = CharRoleDB[name].mainChar
  else
    rosterEntry.role = role
  end
  local summary = bsloot:getEpGpSummary(name)
  rosterEntry.isMain = summary.isMain
  rosterEntry.pr = summary.PR
  return rosterEntry
end

--END Standings
function bsloot:templateCache(id)
  local key = addonName..id
  self._dialogTemplates = self._dialogTemplates or {}
  if self._dialogTemplates[key] then return self._dialogTemplates[key] end
  if not self._dialogTemplates[key] then
    if id == "DialogMemberPoints" then
      self._dialogTemplates[key] = {
        hide_on_escape = true,
        show_whlle_dead = true,
        text = L["You are assigning %s %s to %s."],
        on_show = function(self)
          local what = self.data[1]
          local amount
          if what == "ep" then
            amount = 0
          elseif what == "gp" then
            amount = 0
          end
          self.text:SetText(string.format(L["You are assigning %s %s to %s."],amount,self.data[2],self.data[3]))
        end,
        editboxes = {
          {
            on_enter_pressed = function(self)
              local who = self:GetParent().data[3]
              local why = self:GetParent().data[5]
              local what = self:GetParent().data[1]
              local amount = tonumber(data[4])
              if amount then
                if what == "ep" then
                  bsloot:epToPlayer(who, amount, bsloot.statics.EPGP.ADHOC, why)
                elseif what == "gp" then
                  bsloot:gpToPlayer(who, amount, bsloot.statics.EPGP.ADHOC, why)
                end
              end
              LD:Dismiss(addonName.."DialogMemberPoints")
            end,
            on_escape_pressed = function(self)
              self:ClearFocus()
            end,
            on_text_changed = function(self, userInput)
              local dialog_text = self:GetParent().text
              local data = self:GetParent().data
              data[4] = self:GetText()
              dialog_text:SetText(string.format(L["You are assigning %s %s to %s for %s."],data[4],data[2],data[3],data[5]))
            end,
            on_show = function(self)
              local amount
              local data = self:GetParent().data
              local what = data[1]
              amount = 0
              
              self:SetText(tostring(amount))
              self:SetFocus()
            end,
            text = 0,
          },
          {
            on_enter_pressed = function(self)
              local who = self:GetParent().data[3]
              local why = self:GetParent().data[5]
              local what = self:GetParent().data[1]
              local amount = tonumber(data[4])
              if amount then
                if what == "ep" then
                  bsloot:epToPlayer(who, amount, bsloot.statics.EPGP.ADHOC, why)
                elseif what == "gp" then
                  bsloot:gpToPlayer(who, amount, bsloot.statics.EPGP.ADHOC, why)
                end
              end
              LD:Dismiss(addonName.."DialogMemberPoints")
            end,
            on_escape_pressed = function(self)
              self:ClearFocus()
            end,
            on_text_changed = function(self, userInput)
              local dialog_text = self:GetParent().text
              local data = self:GetParent().data
              data[5] = self:GetText()
              dialog_text:SetText(string.format(L["You are assigning %s %s to %s for %s."],data[4],data[2],data[3],data[5]))
            end,
            on_show = function(self)
              local amount
              local data = self:GetParent().data
              
              self:SetText("TBD")
              self:SetFocus()
            end,
            text = "TBD",
          },
        },
        buttons = {
          {
            text = _G.ACCEPT,
            on_click = function(self, button, down)
              local data = self.data
              local what, who, amount, why = data[1],data[3],data[4],data[5]
              amount = tonumber(amount)
              if amount then
                if what == "ep" then
                  bsloot:epToPlayer(who, amount, bsloot.statics.EPGP.ADHOC, why)
                elseif what == "gp" then
                  bsloot:gpToPlayer(who, amount, bsloot.statics.EPGP.ADHOC, why)
                end
              end
              LD:Dismiss(addonName.."DialogMemberPoints")
            end,
          },
        },
      }
    elseif id == "DialogGroupPoints" then
      self._dialogTemplates[key] = {
        hide_on_escape = true,
        show_whlle_dead = true,
        text = L["You are assigning %s %s to %s for %s."],
        on_show = function(self)
          local amount = 0
          self.text:SetText(string.format(L["You are assigning %s %s to %s for %s."],amount,self.data[2],self.data[3],self.data[4]))
        end,
        editboxes = {
          {
            on_enter_pressed = function(self)
              local who = self:GetParent().data[3]
              local why = self:GetParent().data[5]
              local what = self:GetParent().data[1]
              local amount = tonumber(data[4])
              if amount then
                if who == _G.RAID then
                  bsloot:epToRaid(amount, bsloot.statics.EPGP.ADHOC, why, false)
                elseif who == L["Standby"] then
                  bsloot:award_standby_ep(amount)
                end
              end
              LD:Dismiss(addonName.."DialogGroupPoints")
            end,
            on_escape_pressed = function(self)
              self:ClearFocus()
            end,
            on_text_changed = function(self, userInput)
              local dialog_text = self:GetParent().text
              local data = self:GetParent().data
              data[4] = self:GetText()
              dialog_text:SetText(string.format(L["You are assigning %s %s to %s for %s."],data[4],data[2],data[3],data[5]))
            end,
            on_show = function(self)
              local amount = 0
              self:SetText(tostring(amount))
              self:SetFocus()
            end,
            text = tostring(0),
          },
          {
            on_enter_pressed = function(self)
              local who = self:GetParent().data[3]
              local why = self:GetParent().data[5]
              local what = self:GetParent().data[1]
              local amount = tonumber(data[4])
              if amount then
                if who == _G.RAID then
                  bsloot:epToRaid(amount, bsloot.statics.EPGP.ADHOC, why, false)
                elseif who == L["Standby"] then
                  bsloot:award_standby_ep(amount)
                end
              end
              LD:Dismiss(addonName.."DialogGroupPoints")
            end,
            on_escape_pressed = function(self)
              self:ClearFocus()
            end,
            on_text_changed = function(self, userInput)
              local dialog_text = self:GetParent().text
              local data = self:GetParent().data
              data[5] = self:GetText()
              dialog_text:SetText(string.format(L["You are assigning %s %s to %s for %s."],data[4],data[2],data[3],data[5]))
            end,
            on_show = function(self)
              self:SetText("TBD")
              self:SetFocus()
            end,
            text = "TBD",
          },
        },
        buttons = {
          {
            text = _G.ACCEPT,
            on_click = function(self, button, down)
              local data = self.data
              local what, who, amount, why = data[1],data[3],data[4],data[5]
              amount = tonumber(amount)
              if amount then
                if who == _G.RAID then
                  bsloot:epToRaid(amount, bsloot.statics.EPGP.ADHOC, why, false)
                elseif who == L["Standby"] then
                  bsloot:award_standby_ep(amount)
                end
              end
              LD:Dismiss(addonName.."DialogGroupPoints")
            end,
          },
        },
      }
    elseif id == "DialogItemPoints" then
      --TODO change heavily; this sets gp value for an item it looks like   
    end
  end
  return self._dialogTemplates[key]
end

function bsloot:epToRaid(ep, reason, subReason, inZoneOnly, characters, when) -- awards ep to raid members in zone
  if IsInRaid() and GetNumGroupMembers()>0 then
    local raidmembers = ""
    local raidmembersDiv = ""
    
    if(not characters or characters == nil) then
      characters = bsloot:getRaidMembers(inZoneOnly, true)
    end
    local eventData, eventType = bsloot:buildEventSaveEpGpEvent(characters, bsloot.statics.eventSubType.EP, ep, reason, subReason)
    bsloot:recordEvent(eventType, eventData, when)

    local epKey = bsloot:buildEpGpEventReasonKey(bsloot.statics.eventType.EP_VAL, reason, subReason)
    local recipient = "raid"
    if (bsloot.db.profile.chat.verboseRaidEp) then
      recipient = ""
      local charStringDiv = ""
      for _, c in ipairs(characters) do
        recipient = recipient .. charStringDiv .. c
        charStringDiv = ", "  
      end

    end
    local raidMsg = string.format(L["Giving %d EP to %s for %s"],ep, recipient, epKey)

    bsloot:SendChat(raidMsg, bsloot.db.profile.chat.raidEpGrant)
  else
    message("You must be in a raid, action skipped")
  end
end

function bsloot:getRaidMembers(inZoneOnly, includeDeadAsInZone)
  local characters = {}
  local myZone = GetRealZoneText()
  for i = 1, GetNumGroupMembers() do
    local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(i)
    local inZone = zone == myZone
    if(online) then
      if((not inZoneOnly or inZoneOnly == nil or inZone) or (includeDeadAsInZone and isDead)) then
        table.insert(characters, name)
      end
    end
  end
  return characters
end
function bsloot:recordEvent(eventType, eventData, timestamp)
  local eventId = bsloot:uuid()
  bsloot:debugPrint("Storing event to uuid: "..bsloot:tableToString(eventId), bsloot.statics.LOGS.EVENT)

  local event = {}
  event.type = eventType
  event.creator = bsloot._playerName
  if(not timestamp or timestamp == nil) then
    event.epochSeconds, _ = bsloot:getServerTime()
  else
    event.epochSeconds = timestamp.epochMS / 1000
  end
  local eventDataString = EventParsers[bsloot.latestParseVer][eventType].toString(eventData)
  event.dataString = eventDataString
  event.version = bsloot.latestParseVer
  SyncEvents[eventId] = event
  
  bsloot:doRecalcIfAppropriate(event, eventId)
  bsloot.sync:syncRecentEvent(eventId)

  return eventId
end

  EventParsers = {
    ["0.0.4"] = {
      [bsloot.statics.eventType.SWITCH_MAIN] = {
        ["toString"] = function(eventData)
          local gp = eventData.gpVal
          if(not gp or gp == nil) then
            gp = 0
          end 
          local ep = eventData.epPenalty
          if(not ep or ep == nil) then
            ep = 0
          end 
          return eventData.toChar .."|".. eventData.fromChar .. "|" .. gp .. "|" .. ep
        end,
        ["fromString"] = function(string)
          local arr = bsloot:split(string, "|")
          local eventData = {}
          eventData.toChar = arr[1]
          eventData.fromChar = arr[2]
          eventData.gpVal = tonumber(arr[3])
          eventData.epPenalty = tonumber(arr[4])
          return eventData
        end,
      },
      [bsloot.statics.eventType.EPGP] = {
        ["toString"] = function(eventData)
          local characters = ""
          local charDiv = ""
          for _, char in ipairs(eventData.characters) do
            characters = characters .. charDiv .. char
            charDiv = ","
          end
          return eventData.subType .. "|" .. eventData.reason .. "|" .. eventData.subReason .. "|" .. characters .. "|" .. eventData.amount
        end,
        ["fromString"] = function(string)
          local arr = bsloot:split(string, "|")
          local eventData = {}
          eventData.subType = arr[1] --EP vs GP
          eventData.reason = arr[2] -- bossKill, loot, progressionAttempt, etc
          eventData.subReason = arr[3] -- boss's name, itemLink, etc
          eventData.characters = bsloot:split(arr[4], ",")
          eventData.amount = tonumber(arr[5])
          return eventData
        end,
      },
      [bsloot.statics.eventType.CHAR_ROLE] = {
        ["toString"] = function(eventData)
          return eventData.name .. "|" .. eventData.class .. "|" .. eventData.role .. "|" .. eventData.mainChar
        end,
        ["fromString"] = function(string)
          local arr = bsloot:split(string, "|")
          local eventData = {}
          eventData.name = arr[1]
          eventData.class = arr[2]
          eventData.role = arr[3]
          eventData.mainChar = arr[4]
          return eventData
        end,
      },
      [bsloot.statics.eventType.GP_VAL] = {
        ["toString"] = function(eventData)
          return eventData.itemId .. "|" .. eventData.gp .. "|" .. (eventData.slot or " ") .. "|" .. (eventData.raid or " ") .. "|" .. (eventData.importedName or " ") .. "|" .. (eventData.importedSlot or " ") .. "|"
        end,
        ["fromString"] = function(string)
          local arr = bsloot:split(string, "|")
          local eventData = {}
          eventData.itemId = arr[1]
          eventData.gp = tonumber(arr[2])
          if(arr[3] and arr[3] ~= nil and arr[3] ~= " ") then
            eventData.slot = arr[3]
          end
          if(arr[4] and arr[4] ~= nil and arr[4] ~= " ") then
            eventData.raid = arr[4]
          end
          if(arr[5] and arr[5] ~= nil and arr[5] ~= " ") then
            eventData.importedName = arr[5]
          end
          if(arr[6] and arr[6] ~= nil and arr[6] ~= " ") then
            eventData.importedSlot = arr[6]
          end
          return eventData
        end,
      },
      [bsloot.statics.eventType.BIS_MATRIX] = {
        ["toString"] = function(eventData)
          local bisThroughStr = ""
          bisThroughStrDiv = ""
          for class, specList in pairs(eventData.bisThrough) do
            for spec, bisLevel in pairs(specList) do
              bisThroughStr = bisThroughStr .. bisThroughStrDiv .. class .. "." .. spec .. "." .. bisLevel
              bisThroughStrDiv = ","
            end
          end
          return eventData.itemId .. "|" .. bisThroughStr .. "|" .. eventData.subType
        end,
        ["fromString"] = function(string)
          local arr = bsloot:split(string, "|")
          local eventData = {}
          eventData.itemId = arr[1]
          eventData.bisThrough = {}
          local bisEntries = bsloot:split(arr[2], ",")
          for _, entry in ipairs(bisEntries) do
            local e = bsloot:split(entry, ".")
            if(not eventData.bisThrough[e[1]] or eventData.bisThrough[e[1]] == nil) then
              eventData.bisThrough[e[1]] = {}
            end
            eventData.bisThrough[e[1]][e[2]] = tonumber(e[3])
          end
          eventData.subType = arr[3]
          return eventData
        end,
      },
      [bsloot.statics.eventType.EP_VAL] = {
        ["toString"] = function(eventData)
          return eventData.epType .. "|" .. eventData.epReason .. "|" .. eventData.raid .. "|" .. eventData.ep
        end,
        ["fromString"] = function(string)
          local arr = bsloot:split(string, "|")
          local eventData = {}
          eventData.epType = arr[1]
          eventData.epReason = arr[2]
          eventData.raid = arr[3]
          eventData.ep = tonumber(arr[4])
          return eventData
        end,
      },
      [bsloot.statics.eventType.RAID] = {
        ["toString"] = function(eventData)
          local characters = ""
          local charDiv = ""
          for _, char in ipairs(eventData.characters) do
            characters = characters .. charDiv .. char
            charDiv = ","
          end
          local name = eventData.name or " "
          local raidLoc = eventData.raidLoc or " "
          local raidId = eventData.raidId or " "
          return eventData.subType .. "|" .. characters .. "|" .. name .. "|" .. raidLoc  .. "|" .. raidId 
        end,
        ["fromString"] = function(string)
          local arr = bsloot:split(string, "|")
          local eventData = {}
      
          eventData.subType = arr[1]
          eventData.characters = bsloot:split(arr[2], ",")
          if(arr[3] and arr[3] ~= nil and arr[3] ~= " ") then
            eventData.name = arr[3]
          end
          if(arr[4] and arr[4] ~= nil and arr[4] ~= " ") then
            eventData.raidLoc = arr[4]
          end
          if(arr[5] and arr[5] ~= nil and arr[5] ~= " ") then
            eventData.raidId = arr[5]
          end

          return eventData
        end,
      },
    },
  }
  bsloot.latestParseVer = "0.0.4"

  function bsloot:receiveEvent(eventType, eventDataString, eventId, eventVersion, epochSeconds, creator)
    if(not eventId or eventId == nil) then
      bsloot:errorPrint("Storing event to uuid: "..bsloot:tableToString(eventId), bsloot.statics.LOGS.SYNC)
      return
    end
    local event = {}
    event.type = eventType
    event.epochSeconds = epochSeconds
    event.dataString = eventDataString
    event.version = eventVersion
    event.creator = creator
    SyncEvents[eventId] = event
    
    bsloot:doRecalcIfAppropriate(event, eventId)
  end

  function bsloot:doRecalcIfAppropriate(event, eventId)
    local eventType = event.type
    local timestamp = bsloot:getTimestampFromEpochSec(event.epochSeconds)
    if(bsloot:isAppropriateTimeToRecalc(eventType, timestamp)) then
      
      local success, err = pcall(function() 
        return bsloot:doRecalc(eventType, eventId, timestamp)
      end)
      if(not success) then
        bsloot:warnPrint("Failed to recalc event, will retry sometime later ("..bsloot:tableToString(eventId)..") err="..bsloot:tableToString(err), bsloot.statics.LOGS.EVENT)
        bsloot:QueueForLaterRecalc(eventType, eventId, timestamp)
      end
    else
      bsloot:QueueForLaterRecalc(eventType, eventId, timestamp)
    end
  end

  function bsloot:ProcessQueuedEvents()
    while(#EventsToProcessQueue > 0) do
      local qRec = table.remove(EventsToProcessQueue)
      bsloot:doRecalc(qRec.eventType, qRec.eventId, qRec.timestamp)
    end
  end

  function bsloot:QueueForLaterRecalc(eventType, eventId, timestamp)
    local qRec = {}
    qRec.eventType = eventType
    qRec.eventId = eventId
    qRec.timestamp = timestamp
    table.insert(EventsToProcessQueue, qRec)
  end
  function bsloot:doRecalcEventId(eventId)
    return bsloot:doRecalcEvent(SyncEvents[eventId], eventId)
  end

  function bsloot:doRecalcEvent(event, eventId)
    local eventType = event.type
    local timestamp = bsloot:getTimestampFromEpochSec(event.epochSeconds)
    return bsloot:doRecalc(eventType, eventId, timestamp)
  end

  function bsloot:doRecalc(eventType, eventId, timestamp)
    if(eventType == bsloot.statics.eventType.SWITCH_MAIN) then
      bsloot:doRecalcSwitchMain(eventId)
    elseif(eventType == bsloot.statics.eventType.EPGP) then
      bsloot:doRecalcEPGP(eventId, timestamp)
    elseif(eventType == bsloot.statics.eventType.CHAR_ROLE) then
      bsloot:doRecalcCharRole(eventId)
    elseif(eventType == bsloot.statics.eventType.GP_VAL) then
      bsloot:doRecalcGPVal(eventId)
    elseif(eventType == bsloot.statics.eventType.BIS_MATRIX) then
      bsloot:doRecalcBisMatrix(eventId)
    elseif(eventType == bsloot.statics.eventType.EP_VAL) then
      bsloot:doRecalcEPVal(eventId)
    elseif(eventType == bsloot.statics.eventType.RAID) then
      bsloot:doRecalcRaid(eventId, timestamp)
    else
      bsloot:errorPrint("Unknown eventType: "..bsloot:tableToString(eventType), bsloot.statics.LOGS.EVENT)
    end

  end

  function bsloot:getEventData(eventId, eventType)
    local event = SyncEvents[eventId]
    local eventData = nil
    if(event ~= nil) then
      if(EventParsers ~= nil and EventParsers[event.version] ~= nil and EventParsers[event.version][event.type] ~= nil and EventParsers[event.version][event.type].fromString ~= nil) then
        eventData = EventParsers[event.version][event.type].fromString(event.dataString)
      else
        bsloot:warnPrint(string.format("Unable to find parser for version: %s and type %s, current feature may be using incomplete data", bsloot:tableToString(event.version), bsloot:tableToString(event.type)), bsloot.statics.LOGS.EVENT)
      end
    else
      bsloot:warnPrint(string.format("Unable to find event data for event: %s, current feature may be using incomplete data", bsloot:tableToString(eventId)), bsloot.statics.LOGS.EVENT)
    end
    return eventData
  end
  function bsloot:getAndStoreEventData(eventId, eventType)
    local event = SyncEvents[eventId]
    if(not event.data or event.data == nil) then
      event.data = bsloot:getEventData(eventId, eventType)
    end
    return event.data
  end

  function bsloot:doRecalcRaid(eventId, timestamp)

    eventData = bsloot:getEventData(eventId, bsloot.statics.eventType.RAID)
    if(eventData ~= nil) then
      local raidId = eventData.raidId or eventId
      local subType = eventData.subType
      local eventName = eventData.name
      local raidLoc = eventData.raidLoc
      local characters = eventData.characters
      
      if(not RaidHistory[raidId] or RaidHistory[raidId] == nil) then
        RaidHistory[raidId] = {}
        RaidHistory[raidId].startRoster = {}
        RaidHistory[raidId].endRoster = {}
        RaidHistory[raidId].name = ""
        RaidHistory[raidId].raidLoc = ""
      end

      if(subType == bsloot.statics.eventSubType.RAID_START) then
        RaidHistory[raidId].startRoster = characters
        if(eventName and eventName ~= nil) then
          RaidHistory[raidId].name = eventName
        end
        if(raidLoc and raidLoc ~= nil) then
          RaidHistory[raidId].raidLoc = raidLoc
        end
      elseif(subType == bsloot.statics.eventSubType.RAID_END) then
        RaidHistory[raidId].endRoster = characters
      elseif(subType == bsloot.statics.eventSubType.BOSS_ATTEMPT) then
        if(not RaidHistory[raidId].attempts or RaidHistory[raidId].attempts == nil) then
          RaidHistory[raidId].attempts = {}
        end
        local attempt = {}
        attempt.boss = eventName
        attempt.roster = characters
        attempt.time = timestamp.epochMS
        table.insert(RaidHistory[raidId].attempts, attempt)
      end
    end
  end

  function bsloot:doRecalcSwitchMain(eventId)
    eventData = bsloot:getEventData(eventId, bsloot.statics.eventType.SWITCH_MAIN)
    if(eventData ~= nil) then
      local toChar = eventData.toChar
      local fromChar = eventData.fromChar
      local gpVal = eventData.gpVal
      local epPenalty = eventData.epPenalty

      bsloot:doSwitchMain(fromChar, toChar)
    end
  end
  function bsloot:doSwitchMain(fromChar, toChar)
    if(not fromChar or fromChar == nil) then
      bsloot:errorPrint("fromChar must be provided when changing mains", bsloot.statics.LOGS.ROSTER)
      return
    end
    if( not toChar or toChar == nil) then
      bsloot:errorPrint("toChar must be provided when changing mains", bsloot.statics.LOGS.ROSTER)
      return
    end
    fromChar = strtrim(fromChar)
    if(fromChar == "") then
      bsloot:errorPrint("fromChar must be provided when changing mains", bsloot.statics.LOGS.ROSTER)
      return
    end
    toChar = strtrim(toChar)
    if(toChar == "") then
      bsloot:errorPrint("toChar must be provided when changing mains", bsloot.statics.LOGS.ROSTER)
      return
    end

    toChar = bsloot:sanitizeCharName(toChar)
    fromChar = bsloot:sanitizeCharName(fromChar)
    bsloot:warnPrint(string.format("Triggering Main Change from %s to %s", fromChar, toChar), bsloot.statics.LOGS.ROSTER)
    
    --Rename EPGP table entry
    if(EPGPTable[fromChar] and EPGPTable[fromChar] ~= nil) then
      EPGPTable[toChar] = EPGPTable[fromChar]
      EPGPTable[fromChar] = nil
    end
    --Update cache
    if(EPGPCache[fromChar] and EPGPCache[fromChar] ~= nil) then
      EPGPCache[toChar] = EPGPCache[fromChar]
      EPGPCache[fromChar] = nil
    end
    
    --CharRoleDB
    for charName, charData in pairs(CharRoleDB) do
      if(charData and charData ~= nil and charData.mainChar and charData.mainChar ~= nil and charData.mainChar == fromChar) then
        charData.mainChar = toChar
      end
    end
  end

  function bsloot:getEpGpEventAmount(subType, reasonKey, existingAmout)
    local amount = existingAmout or 0
    if(subType == bsloot.statics.eventSubType.EP and EPValues[reasonKey]) then
      amount = EPValues[reasonKey].ep or existingAmout or 0
    elseif(subType == bsloot.statics.eventSubType.GP and ItemGPCost[reasonKey]) then
      amount = ItemGPCost[reasonKey].gp or existingAmout or 0
    else
    end  
    return amount
  end

  function bsloot:getNewEpGpEventAmount(subType, reasonKey, existingPlayerAmout, oldValue)

    local amount = existingAmout
    if(subType == bsloot.statics.eventSubType.EP and EPValues[reasonKey]) then
      amount = EPValues[reasonKey].ep
    elseif(subType == bsloot.statics.eventSubType.GP and ItemGPCost[reasonKey]) then
      amount = ItemGPCost[reasonKey].gp
    else
    end  
    local modifier = existingPlayerAmout * oldValue
    
    return bsloot:num_round(amount * modifier)
  end

  function bsloot:doRecalcEPGP(eventId, timestamp)
    eventData = bsloot:getEventData(eventId, bsloot.statics.eventType.EPGP)
    if(eventData ~= nil) then
      local subType = eventData.subType --EP vs GP
      local reason = eventData.reason -- bossKill, loot, progressionAttempt, etc
      local subReason = eventData.subReason -- boss's name, itemLink, etc
      local reasonKey = bsloot:buildEpGpEventReasonKey(subType, reason, subReason)
      local characters = eventData.characters
      local amount = eventData.amount
      for _, charName in ipairs(characters) do
        local epgpEvent = bsloot:buildEpGpEvent(charName, subType, amount, reasonKey, timestamp)
        local playerName = bsloot:getMainChar(charName)
        if(epgpEvent == nil) then
          error("EPGP event required for storing event")
        end
        if(EPGPTable[playerName] == nil) then
            EPGPTable[playerName] = {}
        end

        local weeklyKey = bsloot:getWeeklyKey(epgpEvent)
        if(not EPGPTable[playerName][weeklyKey] or EPGPTable[playerName][weeklyKey] == nil) then
          EPGPTable[playerName][weeklyKey] = {}
          EPGPTable[playerName][weeklyKey].Total = {}
        end
        local weekTable = EPGPTable[playerName][weeklyKey]
        bsloot:debugPrint("inserting event: "..bsloot:tableToString(epgpEvent), bsloot.statics.LOGS.EPGP)
      
        if(not weekTable[epgpEvent.type] or weekTable[epgpEvent.type] == nil) then
          weekTable[epgpEvent.type] = {}
        end
          
        if(not weekTable.Total[epgpEvent.type] or weekTable.Total[epgpEvent.type] == nil) then
          weekTable.Total[epgpEvent.type] = 0
        end
        weekTable.Total[epgpEvent.type] = weekTable.Total[epgpEvent.type] + epgpEvent.amount
        local index = #weekTable[epgpEvent.type]+1
        weekTable[epgpEvent.type][index] = epgpEvent
        bsloot:updateCache(epgpEvent, playerName, weeklyKey)
      end
      if(eventData.reason == bsloot.statics.EPGP.BOSSKILL) then
        local killCount, isNew = bsloot:getNumKills(eventData.subReason)
        if(not isNew) then
          BossKillCounter[eventData.subReason] = BossKillCounter[eventData.subReason] + 1
        end
      end
    end
  end

  function bsloot:doRecalcCharRole(eventId)
    eventData = bsloot:getEventData(eventId, bsloot.statics.eventType.CHAR_ROLE)
    if(eventData ~= nil) then
      local name = eventData.name
      local class = eventData.class
      local role = eventData.role
      local mainChar = eventData.mainChar
      
      mainChar = bsloot:sanitizeCharName(mainChar)
      if(CharRoleDB[name] and CharRoleDB[name] ~= nil and CharRoleDB[name].mainChar and CharRoleDB[name].mainChar ~= nil and CharRoleDB[name].mainChar ~= "" and CharRoleDB[name].mainChar ~= mainChar) then
        bsloot:doSwitchMain(CharRoleDB[name].mainChar, mainChar)
      end
      CharRoleDB[name] = {}
      CharRoleDB[name].class = class
      CharRoleDB[name].role = role
      CharRoleDB[name].mainChar = mainChar
    end
  end

  function bsloot:doRecalcGPVal(eventId)
    eventData = bsloot:getEventData(eventId, bsloot.statics.eventType.GP_VAL)
    if(eventData ~= nil) then
      local itemId = eventData.itemId
      local gp = eventData.gp
      local slot = eventData.slot
      local raid = eventData.raid
      local importedName = eventData.importedName
      bsloot:doWithItemInfo(itemId, 
        function(itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
          itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
          isCraftingReagent, itemId)
          local entryId = bsloot:buildEpGpEventReasonKey(bsloot.statics.eventType.GP_VAL, bsloot.statics.EPGP.LOOT, itemId)
          local resolvedSlot = itemEquipLoc

          local priceChange = ItemGPCost[entryId] and ItemGPCost[entryId] ~= nil and ItemGPCost[entryId].gp ~= gp
          local oldValue = nil
          if(ItemGPCost[entryId]) then oldValue = ItemGPCost[entryId].gp end

          local itemEntry = {}
          itemEntry.gp = gp
          itemEntry.raid = raid
          itemEntry.importedName = importedName
          itemEntry.slot = resolvedSlot
          itemEntry.link = itemLink
          itemEntry.name = itemName
          if(not itemEquipLoc or itemEquipLoc == nil or strtrim(itemEquipLoc) == "") then
            itemEntry.slot = slot
          end
          if(ItemGPCost[entryId] )then
            bsloot:debugPrint("Entry: "..entryId, {logicOp="AND", values={bsloot.statics.LOGS.DEV, bsloot.statics.LOGS.BULK}})
          end
          ItemGPCost[entryId] = itemEntry
          
          --No longer retroactive
          -- if(priceChange) then
          --   bsloot:recalcItemReceivers(itemLink, itemEntry, oldValue)
          -- end
        end)
    end
  end

  function bsloot:recalcItemReceivers(itemLink, itemGpEntry, oldValue)
    local toUpdate = {}
    local itemId = GetItemInfoInstant(itemLink)
    local targetReason = bsloot:buildEpGpEventReasonKey(bsloot.statics.eventType.GP_VAL, bsloot.statics.EPGP.LOOT, itemId)
    
    for eventId, event in pairs(SyncEvents) do
      local eventData = bsloot:getEventData(eventId, event.type)
      
      if(eventData ~= nil) then
        if(event.type == bsloot.statics.eventType.EPGP and eventData.subType == bsloot.statics.eventSubType.GP and eventData.reason == bsloot.statics.EPGP.LOOT and eventData.subReason == itemLink) then
          for _, charName in iPairs(event.characters) do
            toUpdate[charName] = 1
            local mainChar = bsloot:getMainChar(charName)
            local weeklyKey = bsloot:getWeeklyKeyFromSeconds(event.epochSeconds)
            if(EPGPTable[mainChar] and EPGPTable[mainChar] ~= nil and EPGPTable[mainChar][weeklyKey] and EPGPTable[mainChar][weeklyKey] ~= nil and EPGPTable[mainChar][weeklyKey][eventData.subType] and EPGPTable[mainChar][weeklyKey][eventData.subType] ~= nil) then
              local scanThrough = EPGPTable[mainChar][weeklyKey][eventData.subType]
              for _, e in ipairs(scanThrough) do
                if(e.reason == targetReason) then
                  event.amount = bsloot:getNewEpGpEventAmount(e.type, e.reason, e.amount, oldValue)
                end
              end
            else
              bsloot:warnPrint("Can't adjust value perhaps events came in out of order. Suggest rebuilding from eventlog", bsloot.statics.LOGS.SYNC)
            end
          end
        end
      end
    end

    for charName,_ in pairs(toUpdate) do
      bsloot:recalcForCharacter(charName)
    end
  end

  function bsloot:recalcForCharacter(charName, weeklyKey)
    local mainChar = bsloot:getMainChar(charName)
    if(not weeklyKey or weeklyKey == nil) then
      for key, weekEvents in pairs(epgpForChar) do
        bsloot:doRecalcForCharacterWeek(key, weeklyKey)
      end 
    else
      bsloot:doRecalcForCharacterWeek(mainChar, weeklyKey)
    end
    bsloot:refreshCache(mainChar)
    --TODO implement (shallow vs deep?)
    --[[
      depth...
      0 add to cache only (if appropriate)
      1 recalculate only week changed and recalculate cache
      2 reread all EP/GP values for all weeks, recalculate weeks and recalculate cache
    ]]
  end
  function bsloot:doRecalcForCharacterWeek(mainChar, weeklyKey)
    
    if(EPGPTable[mainChar] and EPGPTable[mainChar] ~= nil and EPGPTable[mainChar][weeklyKey] and EPGPTable[mainChar][weeklyKey] ~= nil) then
      local weekEvents = EPGPTable[mainChar][weeklyKey]
      weekEvents.Total = {}
      weekEvents.Total.EP = 0
      weekEvents.Total.GP = 0
      
      if(weekEvents.EP and weekEvents.EP ~= nil) then
        for _, epEvent in ipairs(weekEvents.EP) do
          weekEvents.Total.EP = weekEvents.Total.EP + epEvent.amount
        end
      end
      if(weekEvents.GP and weekEvents.GP ~= nil) then
        for _, gpEvent in ipairs(weekEvents.GP) do
          weekEvents.Total.GP = weekEvents.Total.GP + gpEvent.amount
        end
      end
    end 
  end

  function bsloot:doRecalcBisMatrix(eventId)
    eventData = bsloot:getEventData(eventId, bsloot.statics.eventType.BIS_MATRIX)
    if(eventData ~= nil) then
      local itemId = eventData.itemId
      local bisThrough = eventData.bisThrough
      local updateType = eventData.subType -- PARTIAL_UPDATE or FULL_UPDATE 
      local entryId = bsloot:buildEpGpEventReasonKey(bsloot.statics.eventType.BIS_MATRIX, bsloot.statics.EPGP.LOOT, itemId)
      local itemEntry = {}
      bsloot:doWithItemInfo(itemId, 
        function(itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
          itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
          isCraftingReagent, itemId) 
      
          itemEntry.link = itemLink 
      end)
      

      if(updateType == bsloot.statics.eventSubType.FULL_UPDATE) then
        itemEntry.bisThrough = bisThrough
      elseif(updateType == bsloot.statics.eventSubType.PARTIAL_UPDATE) then
        -- partial update not supported
      else
      end

      --fill in default values
      itemEntry.bisThrough["Warrior"] = itemEntry.bisThrough["Warrior"] or {} 
      itemEntry.bisThrough["Warrior"]["Arms"] = itemEntry.bisThrough["Warrior"]["Arms"] or -5
      itemEntry.bisThrough["Warrior"]["Tank"] = itemEntry.bisThrough["Warrior"]["Tank"] or -5
      itemEntry.bisThrough["Warrior"]["OT"] = itemEntry.bisThrough["Warrior"]["OT"] or -5
      itemEntry.bisThrough["Warrior"]["FuryProt"] = itemEntry.bisThrough["Warrior"]["FuryProt"] or -5
      itemEntry.bisThrough["Warrior"]["Prot"] = itemEntry.bisThrough["Warrior"]["Prot"] or -5
      itemEntry.bisThrough["Warrior"]["MDPS"] = itemEntry.bisThrough["Warrior"]["MDPS"] or -5
      itemEntry.bisThrough["Warrior"]["1hFury"] = itemEntry.bisThrough["Warrior"]["1hFury"] or -5
      itemEntry.bisThrough["Warrior"]["2hFury"] = itemEntry.bisThrough["Warrior"]["2hFury"] or -5
      itemEntry.bisThrough["Paladin"] = itemEntry.bisThrough["Paladin"] or {} 
      itemEntry.bisThrough["Paladin"]["Tank"] = itemEntry.bisThrough["Paladin"]["Tank"] or -5
      itemEntry.bisThrough["Paladin"]["Healer"] = itemEntry.bisThrough["Paladin"]["Healer"] or -5
      itemEntry.bisThrough["Paladin"]["MDPS"] = itemEntry.bisThrough["Paladin"]["MDPS"] or -5
      itemEntry.bisThrough["Paladin"]["OT"] = itemEntry.bisThrough["Paladin"]["OT"] or -5
      itemEntry.bisThrough["Paladin"]["Prot"] = itemEntry.bisThrough["Paladin"]["Prot"] or -5
      itemEntry.bisThrough["Paladin"]["Ret"] = itemEntry.bisThrough["Paladin"]["Ret"] or -5
      itemEntry.bisThrough["Paladin"]["Holy"] = itemEntry.bisThrough["Paladin"]["Holy"] or -5
      itemEntry.bisThrough["Hunter"] = itemEntry.bisThrough["Hunter"] or {} 
      itemEntry.bisThrough["Hunter"]["BeastMastery"] = itemEntry.bisThrough["Hunter"]["BeastMastery"] or -5
      itemEntry.bisThrough["Hunter"]["Marksman"] = itemEntry.bisThrough["Hunter"]["Marksman"] or -5
      itemEntry.bisThrough["Hunter"]["RDPS"] = itemEntry.bisThrough["Hunter"]["RDPS"] or -5
      itemEntry.bisThrough["Hunter"]["Survival"] = itemEntry.bisThrough["Hunter"]["Survival"] or -5
      itemEntry.bisThrough["Shaman"] = itemEntry.bisThrough["Shaman"] or {} 
      itemEntry.bisThrough["Shaman"]["RDPS"] = itemEntry.bisThrough["Shaman"]["RDPS"] or -5
      itemEntry.bisThrough["Shaman"]["Elemental"] = itemEntry.bisThrough["Shaman"]["Elemental"] or -5
      itemEntry.bisThrough["Shaman"]["Healer"] = itemEntry.bisThrough["Shaman"]["Healer"] or -5
      itemEntry.bisThrough["Shaman"]["Resto"] = itemEntry.bisThrough["Shaman"]["Resto"] or -5
      itemEntry.bisThrough["Shaman"]["MDPS"] = itemEntry.bisThrough["Shaman"]["MDPS"] or -5
      itemEntry.bisThrough["Shaman"]["Hybrid"] = itemEntry.bisThrough["Shaman"]["Hybrid"] or -5
      itemEntry.bisThrough["Shaman"]["Enhancement"] = itemEntry.bisThrough["Shaman"]["Enhancement"] or -5
      itemEntry.bisThrough["Druid"] = itemEntry.bisThrough["Druid"] or {} 
      itemEntry.bisThrough["Druid"]["RDPS"] = itemEntry.bisThrough["Druid"]["RDPS"] or -5
      itemEntry.bisThrough["Druid"]["Tank"] = itemEntry.bisThrough["Druid"]["Tank"] or -5
      itemEntry.bisThrough["Druid"]["FeralDPS"] = itemEntry.bisThrough["Druid"]["FeralDPS"] or -5
      itemEntry.bisThrough["Druid"]["Healer"] = itemEntry.bisThrough["Druid"]["Healer"] or -5
      itemEntry.bisThrough["Druid"]["Resto"] = itemEntry.bisThrough["Druid"]["Resto"] or -5
      itemEntry.bisThrough["Druid"]["MDPS"] = itemEntry.bisThrough["Druid"]["MDPS"] or -5
      itemEntry.bisThrough["Druid"]["Balance"] = itemEntry.bisThrough["Druid"]["Balance"] or -5
      itemEntry.bisThrough["Druid"]["FeralTank"] = itemEntry.bisThrough["Druid"]["FeralTank"] or -5
      itemEntry.bisThrough["Rogue"] = itemEntry.bisThrough["Rogue"] or {} 
      itemEntry.bisThrough["Rogue"]["Mace"] = itemEntry.bisThrough["Rogue"]["Mace"] or -5
      itemEntry.bisThrough["Rogue"]["MDPS"] = itemEntry.bisThrough["Rogue"]["MDPS"] or -5
      itemEntry.bisThrough["Rogue"]["Sword"] = itemEntry.bisThrough["Rogue"]["Sword"] or -5
      itemEntry.bisThrough["Rogue"]["Dagger"] = itemEntry.bisThrough["Rogue"]["Dagger"] or -5
      itemEntry.bisThrough["Priest"] = itemEntry.bisThrough["Priest"] or {} 
      itemEntry.bisThrough["Priest"]["RDPS"] = itemEntry.bisThrough["Priest"]["RDPS"] or -5
      itemEntry.bisThrough["Priest"]["Holy"] = itemEntry.bisThrough["Priest"]["Holy"] or -5
      itemEntry.bisThrough["Priest"]["Healer"] = itemEntry.bisThrough["Priest"]["Healer"] or -5
      itemEntry.bisThrough["Priest"]["HolyShadowweave"] = itemEntry.bisThrough["Priest"]["HolyShadowweave"] or -5
      itemEntry.bisThrough["Priest"]["DiscHoly"] = itemEntry.bisThrough["Priest"]["DiscHoly"] or -5
      itemEntry.bisThrough["Priest"]["Shadow"] = itemEntry.bisThrough["Priest"]["Shadow"] or -5
      itemEntry.bisThrough["Warlock"] = itemEntry.bisThrough["Warlock"] or {} 
      itemEntry.bisThrough["Warlock"]["RDPS"] = itemEntry.bisThrough["Warlock"]["RDPS"] or -5
      itemEntry.bisThrough["Warlock"]["Destruction"] = itemEntry.bisThrough["Warlock"]["Destruction"] or -5
      itemEntry.bisThrough["Warlock"]["Demonology"] = itemEntry.bisThrough["Warlock"]["Demonology"] or -5
      itemEntry.bisThrough["Warlock"]["SMRuin"] = itemEntry.bisThrough["Warlock"]["SMRuin"] or -5
      itemEntry.bisThrough["Warlock"]["Affliction"] = itemEntry.bisThrough["Warlock"]["Affliction"] or -5
      itemEntry.bisThrough["Mage"] = itemEntry.bisThrough["Mage"] or {} 
      itemEntry.bisThrough["Mage"]["RDPS"] = itemEntry.bisThrough["Mage"]["RDPS"] or -5
      itemEntry.bisThrough["Mage"]["Elementalist"] = itemEntry.bisThrough["Mage"]["Elementalist"] or -5
      itemEntry.bisThrough["Mage"]["APFrost"] = itemEntry.bisThrough["Mage"]["APFrost"] or -5
      itemEntry.bisThrough["Mage"]["DeepFire"] = itemEntry.bisThrough["Mage"]["DeepFire"] or -5
      itemEntry.bisThrough["Mage"]["WintersChill"] = itemEntry.bisThrough["Mage"]["WintersChill"] or -5
      itemEntry.bisThrough["Mage"]["POMPyro"] = itemEntry.bisThrough["Mage"]["POMPyro"] or -5
      BisMatrix[entryId] = itemEntry
    end
  end
  function bsloot:doRecalcEPVal(eventId)
    eventData = bsloot:getEventData(eventId, bsloot.statics.eventType.EP_VAL)
    if(eventData ~= nil) then
      local epType = eventData.epType
      local epReason = eventData.epReason
      local raid = eventData.raid
      local ep = eventData.ep
      local entryId = bsloot:buildEpGpEventReasonKey(bsloot.statics.eventType.EP_VAL, epType, epReason)
      
      local priceChange = EPValues[entryId] and EPValues[entryId] ~= nil and EPValues[entryId].ep ~= ep
      local oldValue = nil
      if(EPValues[entryId]) then oldValue = EPValues[entryId].ep end

      local itemEntry = {}
      itemEntry.ep = ep
      itemEntry.epType = epType
      itemEntry.epReason = epReason
      itemEntry.raid = raid
      EPValues[entryId] = itemEntry
      
      --No longer retroactive
      -- if(priceChange) then
      --   bsloot:recalcEpReceivers(entryId, itemEntry, oldValue)
      -- end
    end
  end

  function bsloot:buildEpGpEventReasonKey(eventType, reason, subReason)
    return reason..":"..subReason
  end

  function bsloot:recalcEpReceivers(itemLink, epEntry, oldValue)
    local toUpdate = {}
    for eventId, event in pairs(SyncEvents) do
      
      if(event.type == bsloot.statics.eventType.EPGP and event.data.subType == bsloot.statics.eventSubType.EP and event.data.reason == epEntry.epType and event.data.subReason == epEntry.epReason) then
        for _, charName in ipairs(event.characters) do
          toUpdate[charName] = 1
          local mainChar = bsloot:getMainChar(charName)
          local weeklyKey = bsloot:getWeeklyKeyFromSeconds(event.epochSeconds)
          if(EPGPTable[mainChar] and EPGPTable[mainChar] ~= nil and EPGPTable[mainChar][weeklyKey] and EPGPTable[mainChar][weeklyKey] ~= nil and EPGPTable[mainChar][weeklyKey][eventData.subType] and EPGPTable[mainChar][weeklyKey][eventData.subType] ~= nil) then
            local scanThrough = EPGPTable[mainChar][weeklyKey][eventData.subType]
            for _, e in ipairs(scanThrough) do
              if(e.reason == targetReason) then
                event.amount = bsloot:getNewEpGpEventAmount(e.type, e.reason, e.amount, oldValue)
              end
            end
          else
            bsloot:warnPrint("Can't adjust value perhaps events came in out of order. Suggest rebuilding from eventlog", bsloot.statics.LOGS.SYNC)
          end
        end
      end
    end

    for charName,_ in pairs(toUpdate) do
      bsloot:recalcForCharacter(charName)
    end
  end

  function bsloot:isAppropriateTimeToRecalc(eventType, eventTimestamp)
    -- RaidStart/End
    -- SwitchMain : always recalc
    -- EPGP : check week against current; if not current week, historical recalc (don't do in raid unless forced)
    -- CharRoleDb : always recalc
    -- ItemValDB : defer if possible
    -- EPValDb : defer if possible
    local thisWeeklyKey = bsloot:getWeeklyKey()
    local eventWeeklyKey = bsloot:getWeeklyKeyFromTimestamp(eventTimestamp)
    
    local currentTimeSec, _ = bsloot:getServerTime()
    local isCurrentWeek = (eventWeeklyKey == thisWeeklyKey)
    local guildRaid, raid, group, guildGroup = bsloot:isInGuildRaid()
    local isVeryRecent = currentTimeSec-(eventTimestamp.epochMS/1000) < (2 * 60 * 60)
    
    --if guild group and last 2 hours, true
    --if non guild group and this week, true
    --else if not in grp
    return (guildRaid and isVeryRecent) or (group and isCurrentWeek) or not group
  end

  function bsloot:isInGuildRaid()
    local isRaid = IsInRaid() 
    local isGroup = IsInGroup() 
    local numGuild = 0
    local groupSize = GetNumGroupMembers()
    if(isRaid or isGroup) then
      
      local temp = {}
      for i=1,GetNumGuildMembers(true) do
        local g_name, g_rank, g_rankIndex, g_level, g_class, g_zone, g_note, g_officernote, g_online, g_status, g_eclass, _, _, g_mobile, g_sor, _, g_GUID = GetGuildRosterInfo(i)
        temp[string.lower(Ambiguate(g_name,"short"))] = true
      end
      for i = 1, groupSize do
        local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(i)
        if(temp[string.lower(Ambiguate(name,"short"))]) then
          numGuild = numGuild + 1
        end
      end
    end
    local guildPct = numGuild / groupSize
    local guildRaid = isRaid and groupSize > 10 and guildPct >= 0.5
    local guildGroup = isGroup and groupSize <= 11 and guildPct >= 1
    return guildRaid, isRaid, isGroup, guildGroup
  end

  --BEGIN bulk import
  function bsloot:importEvents(csvText)
    local lines = bsloot:split(csvText, "\n")
    local raidStartDateTime = nil
    local raidEndDateTime = nil
    local raidEventDateTime = nil
    local imported = 0
    local epEvents = {}
    local raidName = ""
    local raidNameDiv = ""
    local raidLoc = ""
    for lineNum, line in ipairs(lines) do
      local sLine = bsloot:split(line, "|")
      if(lineNum == 1) then
        local dateString = sLine[2]
        raidStartDateTime, raidEventDateTime, raidEndDateTime  = bsloot:getRaidTimeFromDateString(dateString)
        raidName = raidName .. raidNameDiv .. dateString
        raidNameDiv = " "
      elseif (lineNum == 2) then
        raidLoc = sLine[2]
        raidName = raidName .. raidNameDiv .. raidLoc
        raidNameDiv = " "
      elseif (lineNum > 3) then
        local charName = strtrim(sLine[1] or "")
        if(not raidStartDateTime or raidStartDateTime == nil) then
          message("raidStartDateTime not found, aborting import")
          return
        elseif(not raidEventDateTime or raidEventDateTime == nil) then
          message("raidEventDateTime not found, aborting import")
          return
        elseif(not raidEndDateTime or raidEndDateTime == nil) then
          message("raidEndDateTime not found, aborting import")
          return
        elseif (string.find(line, "|") ~= 1 and charName and charName ~= nil and charName ~= "") then
          local lineItemPlayerName = strtrim(sLine[1], "[] \t\n\r")
          local lineItemType = strtrim(sLine[2], "[] \t\n\r")
          local lineItemAmount = tonumber(strtrim(sLine[3], "[] \t\n\r"))
          local lineItemReason = strtrim(sLine[4], "\t\n\r")
          local lineItemNotes = ""
          if(sLine[5] and sLine[5] ~= nil) then
            lineItemNotes = strtrim(sLine[5], "\t\n\r") --can detect other 
          end
          charName = lineItemPlayerName
          local amount = lineItemAmount
          local reason = lineItemReason

          if(lineItemPlayerName:lower() == "bsbank" or lineItemNotes:lower() == "shard" ) then
            amount = 0
          end

          if(string.find(lineItemNotes:lower(), "on ") == 1) then
            charName = strsub(lineItemNotes, 4)
            local spaceInd = string.find(charName, " ")
            local parenInd = string.find(charName, "%(")
            if(parenInd ~= nil and spaceInd ~= nil) then
              charName = strsub(charName, 1, math.min(parenInd, spaceInd)-1)
            elseif(parenInd == nil and spaceInd == nil) then
              charName = strtrim(charName, " \t\n\r")
            elseif(parenInd == nil) then
              charName = strsub(charName, 1, spaceInd-1)
            else
              charName = strsub(charName, 1, parenInd-1)
            end
            bsloot:debugPrint("Alt detected: "..charName, bsloot.statics.LOGS.ROSTER)
          end
          if(string.find(lineItemNotes:lower(), "shard") ~= nil) then
            amount = 0
          end
          if(lineItemType == bsloot.statics.eventSubType.GP) then
            local success, err = pcall(function()
              local subReason = reason
              if(string.find(reason, "%[")) then
                reason = bsloot:buildEpGpEventReasonKey(bsloot.statics.eventType.EPGP, bsloot.statics.EPGP.LOOT, bsloot:findItemIdByImportedName(reason))
              end
              --Do for 1 char
              local characters = {}
              table.insert(characters, charName)
              local eventData, eventType = bsloot:buildEventSaveEpGpEvent(characters, lineItemType, amount, bsloot.statics.EPGP.LOOT, subReason)
              bsloot:recordEvent(eventType, eventData, raidEventDateTime)

            end)
            if(not success) then
              bsloot:warnPrint(string.format("Failed to import line: %s", line), bsloot.statics.LOGS.BULK)
            end
          else
            if(not epEvents[reason] or epEvents[reason] == nil) then
              epEvents[reason] = {}
            end
            if(not epEvents[reason][amount] or epEvents[reason][amount] == nil) then
              epEvents[reason][amount] = {}
            end
            local success, err = pcall(function() table.insert(epEvents[reason][amount], charName) end)
            if(not success) then
              bsloot:errorPrint(string.format("Failed loading events, somehow epEvent subtable is nil: %s.%s for %s", reason, amount, charName), bsloot.statics.LOGS.BULK)
              bsloot:debugPrint(string.format("epEvents[reason] = %s", bsloot:tableToString(epEvents[reason])), {logicOp="AND", values={bsloot.statics.LOGS.DEV, bsloot.statics.LOGS.BULK}})
              bsloot:debugPrint(string.format("epEvents[reason][amount] = %s", bsloot:tableToString(epEvents[reason][amount])), {logicOp="AND", values={bsloot.statics.LOGS.DEV, bsloot.statics.LOGS.BULK}})
              error(err)
            end
          end
                    
          imported = imported + 1
          
        else
          bsloot:debugPrint("Ignoring invalid line: "..line, bsloot.statics.LOGS.BULK)
        end
      end
    end

    local raidId = ""
    if(epEvents["bonus:OnTime"] and epEvents["bonus:OnTime"] ~= nil) then
      local epCategory = bsloot.statics.EPGP.BONUS
      local subReason = "OnTime"
      local reasonChars = {}
      for amount, characters in pairs(epEvents["bonus:OnTime"]) do
        for _, c in ipairs(characters) do
          reasonChars[c] = true
        end
        local eventData, eventType = bsloot:buildEventSaveEpGpEvent(characters, bsloot.statics.eventSubType.EP, amount, epCategory, subReason)
        bsloot:recordEvent(eventType, eventData, raidEventDateTime)
      end

      local eventData, eventType = bsloot:buildEventSaveRaidStartEvent(bsloot:trueOnlyMapToArray(reasonChars), raidLoc, raidName)
      raidId = bsloot:recordEvent(eventType, eventData, raidStartDateTime)
      
    end
    
    local raidEndChars = {}
    -- logically pick the last event. this is based on us doing ony AFTER MC whenever they are together
    local lastBossEvent = epEvents["bossKill:Onyxia"] or epEvents["progression:Onyxia"] 

                          or epEvents["bossKill:Ragnaros"] or epEvents["progression:Ragnaros"] 
                          or epEvents["bossKill:Majordomo Executus"] or epEvents["progression:Majordomo Executus"] 
                          or epEvents["bossKill:Golemagg the Incinerator"] or epEvents["progression:Golemagg the Incinerator"] 
                          or epEvents["bossKill:Sulfuron"] or epEvents["progression:Sulfuron"] 
                          or epEvents["bossKill:Shazzrah"] or epEvents["progression:Shazzrah"] 
                          or epEvents["bossKill:Baron Gedon"] or epEvents["progression:Baron Gedon"] 
                          or epEvents["bossKill:Garr"] or epEvents["progression:Garr"] 
                          or epEvents["bossKill:Gehennas"] or epEvents["progression:Gehennas"] 
                          or epEvents["bossKill:Magmadar"] or epEvents["progression:Magmadar"] 
                          or epEvents["bossKill:Lucifron"] or epEvents["progression:Lucifron"] 

                          or epEvents["bossKill:Nefarian"] or epEvents["progression:Nefarian"] 
                          or epEvents["bossKill:Chromaggus"] or epEvents["progression:Chromaggus"] 
                          or epEvents["bossKill:Flamegor"] or epEvents["progression:Flamegor"] 
                          or epEvents["bossKill:Ebonroc"] or epEvents["progression:Ebonroc"] 
                          or epEvents["bossKill:Firemaw"] or epEvents["progression:Firemaw"] 
                          or epEvents["bossKill:Broodlord Lashlayer"] or epEvents["progression:Broodlord Lashlayer"] 
                          or epEvents["bossKill:Vaelastrasz the Corrupt"] or epEvents["progression:Vaelastrasz the Corrupt"] 
                          or epEvents["bossKill:Razorgore the Untamed"] or epEvents["progression:Razorgore the Untamed"] 

                          or epEvents["bossKill:Hakkar"] or epEvents["progression:Hakkar"] 
                          or epEvents["bossKill:Jin'do the Hexxer"] or epEvents["progression:Jin'do the Hexxer"] 
                          or epEvents["bossKill:Bloodlord Mandokir"] or epEvents["progression:Bloodlord Mandokir"] 
                          or epEvents["bossKill:Gahz'ranka"] or epEvents["progression:Gahz'ranka"] 
                          or epEvents["bossKill:Wushoolay"] or epEvents["progression:Wushoolay"] 
                          or epEvents["bossKill:Renataki"] or epEvents["progression:Renataki"] 
                          or epEvents["bossKill:Hazza'rah"] or epEvents["progression:Hazza'rah"] 
                          or epEvents["bossKill:Gri'lek"] or epEvents["progression:Gri'lek"] 
                          or epEvents["bossKill:High Priestess Arlokk"] or epEvents["progression:High Priestess Arlokk"] 
                          or epEvents["bossKill:High Priest Thekal"] or epEvents["progression:High Priest Thekal"] 
                          or epEvents["bossKill:High Priestess Mar'li"] or epEvents["progression:High Priestess Mar'li"] 
                          or epEvents["bossKill:High Priestess Jeklik"] or epEvents["progression:High Priestess Jeklik"] 
                          or epEvents["bossKill:High Priest Venoxis"] or epEvents["progression:High Priest Venoxis"] 

                          or epEvents["bossKill:Ossirian the Unscarred"] or epEvents["progression:Ossirian the Unscarred"] 
                          or epEvents["bossKill:Ayamiss the Hunter"] or epEvents["progression:Ayamiss the Hunter"] 
                          or epEvents["bossKill:Buru the Gorger"] or epEvents["progression:Buru the Gorger"] 
                          or epEvents["bossKill:Moam"] or epEvents["progression:Moam"] 
                          or epEvents["bossKill:General Rajaxx"] or epEvents["progression:General Rajaxx"] 
                          or epEvents["bossKill:Kurinnaxx"] or epEvents["progression:Kurinnaxx"] 

                          or epEvents["bossKill:C'Thun"] or epEvents["progression:C'Thun"] 
                          or epEvents["bossKill:Twin Emperors"] or epEvents["progression:Twin Emperors"] 
                          or epEvents["bossKill:Ouro"] or epEvents["progression:Ouro"] 
                          or epEvents["bossKill:Viscidus"] or epEvents["progression:Viscidus"] 
                          or epEvents["bossKill:Silithid Royalty"] or epEvents["progression:Silithid Royalty"] 
                          or epEvents["bossKill:Princess Huhuran"] or epEvents["progression:Princess Huhuran"] 
                          or epEvents["bossKill:Fankriss the Unyielding"] or epEvents["progression:Fankriss the Unyielding"] 
                          or epEvents["bossKill:Battleguard Sartura"] or epEvents["progression:Battleguard Sartura"] 
                          or epEvents["bossKill:The Prophet Skeram"] or epEvents["progression:The Prophet Skeram"] 

                          or epEvents["bossKill:Kel'Thuzad"] or epEvents["progression:Kel'Thuzad"] 
                          or epEvents["bossKill:Sapphiron"] or epEvents["progression:Sapphiron"] 
                          or epEvents["bossKill:Thaddius"] or epEvents["progression:Thaddius"] 
                          or epEvents["bossKill:Gluth"] or epEvents["progression:Gluth"] 
                          or epEvents["bossKill:Grobbulus"] or epEvents["progression:Grobbulus"] 
                          or epEvents["bossKill:Patchwerk"] or epEvents["progression:Patchwerk"] 
                          or epEvents["bossKill:The Four Horsemen"] or epEvents["progression:The Four Horsemen"] 
                          or epEvents["bossKill:Gothik the Harvester"] or epEvents["progression:Gothik the Harvester"] 
                          or epEvents["bossKill:Instructor Razuvious"] or epEvents["progression:Instructor Razuvious"] 
                          or epEvents["bossKill:Loatheb"] or epEvents["progression:Loatheb"] 
                          or epEvents["bossKill:Heigan the Unclean"] or epEvents["progression:Heigan the Unclean"] 
                          or epEvents["bossKill:Noth the Plaguebringer"] or epEvents["progression:Noth the Plaguebringer"] 
                          or epEvents["bossKill:Maexxna"] or epEvents["progression:Maexxna"] 
                          or epEvents["bossKill:Grand Widow Faerlina"] or epEvents["progression:Grand Widow Faerlina"] 
                          or epEvents["bossKill:Anub'Rekhan"] or epEvents["progression:Anub'Rekhan"] 

                          or epEvents["bossKill:Azuregos"] or epEvents["progression:Azuregos"] 
                          or epEvents["bossKill:Doom Lord Kazzak"] or epEvents["progression:Doom Lord Kazzak"] 
                          or epEvents["bossKill:Emeriss"] or epEvents["progression:Emeriss"] 
                          or epEvents["bossKill:Lethon"] or epEvents["progression:Lethon"] 
                          or epEvents["bossKill:Taerar"] or epEvents["progression:Taerar"] 
                          or epEvents["bossKill:Ysondre"] or epEvents["progression:Ysondre"] 
                            -- if all else fails just use the on time bonus
                          or epEvents["bonus:OnTime"]
    if(lastBossEvent and lastBossEvent ~= nil) then 
      
      local reasonChars = {}
      for amount, characters in pairs(lastBossEvent) do

        for _, c in ipairs(characters) do
          reasonChars[c] = true
        end
      end
      local eventData, eventType = bsloot:buildEventSaveRaidEndEvent(bsloot:trueOnlyMapToArray(reasonChars), raidId)
      bsloot:recordEvent(eventType, eventData, raidEndDateTime)
    end
    for reason, amountMap in pairs(epEvents) do
      if(reason ~= "bonus:OnTime") then
        local epCategory = bsloot.statics.EPGP.BONUS
        local subReason = reason
        
        if(string.find(reason, ":") ~= nil) then
          local reasonArray = bsloot:split(reason, ":")
          epCategory = reasonArray[1]:upper()
          subReason = reasonArray[2]
        end
        
        local reasonChars = {}
        for amount, characters in pairs(amountMap) do
          local splitChars = {}
          for _, c in ipairs(characters) do
            reasonChars[c] = true
            if(not splitChars[c] or splitChars[c] == nil) then
              splitChars[c] = 0
            end
            splitChars[c] = splitChars[c] + 1
          end
          while(bsloot:tablelength(splitChars) > 0) do
            local count = 0
            local builtList = {}
            for char, charCount in pairs(splitChars) do
              if(count == bsloot:getRaidSize(raidLoc)) then
                break
              end
              count = count + 1
              table.insert(builtList, char)
              splitChars[char] = charCount - 1
              if(splitChars[char] <= 0) then
                splitChars[char] = nil
              end
            end 
            local eventData, eventType = bsloot:buildEventSaveEpGpEvent(builtList, bsloot.statics.eventSubType.EP, amount, epCategory, subReason)
            bsloot:recordEvent(eventType, eventData, raidEventDateTime)
          end
        end
        if((epCategory == bsloot.statics.EPGP.BOSSKILL and not epEvents["progression:"..subReason]) or (epCategory == bsloot.statics.EPGP.PROGRESSION)) then

          local eventData, eventType = bsloot:buildEventSaveRaidBossAttempt(bsloot:trueOnlyMapToArray(reasonChars), raidId, bossName)
          bsloot:recordEvent(eventType, eventData, raidEventDateTime)
        end
      end
    end            
    bsloot:debugPrint("Imported Events Total: " ..imported, bsloot.statics.LOGS.BULK)
  end
  

  function bsloot:camelCase(str)
    return string.gsub(str,"(%a)([%w_']*)",function(head,tail) 
      return string.format("%s%s",string.upper(head),string.lower(tail)) 
      end)
  end
  function bsloot:importItems(csvText, overwrite)
    local lines = bsloot:split(csvText, "\n")
    local total, found, missed = 0, 0, 0
    local gpImported, bisImported = 0, 0
    if(lines and lines ~= nil) then
      for lineNum, line in ipairs(lines) do
        local sLine = bsloot:split(line, "|")
        if (sLine and sLine ~= nil) then
          local tempItemName = strtrim(sLine[1] or "")
          if (string.find(line, "|") ~= 1 and tempItemName and tempItemName ~= nil and tempItemName ~= "") then
            local lineItemName = strtrim(sLine[1], " \t\n\r")
            local lineItemSlot = tonumber(strtrim(sLine[2], "[] \t\n\r"))
            local lineItemId = tonumber(strtrim(sLine[3], "[] \t\n\r"))
            local lineItemRaid = strtrim(sLine[4], "[] \t\n\r")
            local lineItembaseGp = tonumber(strtrim(sLine[5], "[] \t\n\r"))
            local lineItemGp = tonumber(strtrim(sLine[6], "[] \t\n\r"))
            
            total = total + 1
            bsloot:doWithItemInfo(lineItemId, 
              function(itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
                itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
                isCraftingReagent, itemId) 
                if(itemLink ~= nil) then
                  found = found + 1
                  local itemKey = bsloot:buildEpGpEventReasonKey(bsloot.statics.eventType.GP_VAL, bsloot.statics.EPGP.LOOT, itemId)
                  if(overwrite or not ItemGPCost[itemKey] or ItemGPCost[itemKey] == nil) then

                    if(itemEquipLoc == "") then
                      itemEquipLoc = " "
                    end
                    local eventData, eventType = bsloot:buildEventSaveItemGp(itemId, lineItemGp, itemEquipLoc, lineItemRaid, lineItemName, itemLink, lineItemSlot)
                    bsloot:recordEvent(eventType, eventData)
                    gpImported = gpImported + 1
                  else
                    bsloot:debugPrint("Processing "..itemLink.." from line: "..line, bsloot.statics.LOGS.BULK)
                  end
                  
                  itemKey = bsloot:buildEpGpEventReasonKey(bsloot.statics.eventType.BIS_MATRIX, bsloot.statics.EPGP.LOOT, itemId)
                  if(overwrite or not BisMatrix[itemKey] or BisMatrix[itemKey] == nil) then
                    
                    local prioWarriorTankProt = tonumber(strtrim(sLine[7], " \t\n\r"))
                    local prioWarriorOTFuryProt = tonumber(strtrim(sLine[8], " \t\n\r"))
                    local prioWarriorMDPS1hFury = tonumber(strtrim(sLine[9], "[] \t\n\r"))
                    local prioWarriorMDPS2hFury = tonumber(strtrim(sLine[10], "[] \t\n\r"))
                    local prioWarriorMDPSArms = tonumber(strtrim(sLine[11], "[] \t\n\r"))
                    local prioHunterRDPSBeastMastery = tonumber(strtrim(sLine[12], "[] \t\n\r"))
                    local prioHunterRDPSSurvival = tonumber(strtrim(sLine[13], "[] \t\n\r"))
                    local prioHunterRDPSMarksMan = tonumber(strtrim(sLine[14], "[] \t\n\r"))
                    local prioShamanHealerResto = tonumber(strtrim(sLine[15], "[] \t\n\r"))
                    local prioShamanMDPSEnhancement = tonumber(strtrim(sLine[16], "[] \t\n\r"))
                    local prioShamanRDPSElemental = tonumber(strtrim(sLine[17], "[] \t\n\r"))
                    local prioShamanRDPSHybrid = tonumber(strtrim(sLine[18], "[] \t\n\r"))
                    local prioDruidTankFeralTank = tonumber(strtrim(sLine[19], "[] \t\n\r"))
                    local prioDruidMDPSFeralDPS = tonumber(strtrim(sLine[20], "[] \t\n\r"))
                    local prioDruidHealerResto = tonumber(strtrim(sLine[21], "[] \t\n\r"))
                    local prioDruidRDPSBalance = tonumber(strtrim(sLine[22], "[] \t\n\r"))
                    local prioRogueMDPSSword = tonumber(strtrim(sLine[23], "[] \t\n\r"))
                    local prioRogueMDPSDagger = tonumber(strtrim(sLine[24], "[] \t\n\r"))
                    local prioRogueMDPSMace = tonumber(strtrim(sLine[25], "[] \t\n\r"))
                    local prioPriestHealerHoly = tonumber(strtrim(sLine[26], "[] \t\n\r"))
                    local prioPriestHealerDiscHoly = tonumber(strtrim(sLine[27], "[] \t\n\r"))
                    local prioPriestRDPSShadow = tonumber(strtrim(sLine[28], "[] \t\n\r"))
                    local prioPriestUtilityHolyShadowweave = tonumber(strtrim(sLine[29], "[] \t\n\r"))
                    local prioWarlockRDPSSMRuin = tonumber(strtrim(sLine[30], "[] \t\n\r"))
                    local prioWarlockRDPSDemo = tonumber(strtrim(sLine[31], "[] \t\n\r"))
                    local prioWarlockRDPSAffliction = tonumber(strtrim(sLine[32], "[] \t\n\r"))
                    local prioWarlockRDPSDestruction = tonumber(strtrim(sLine[33], "[] \t\n\r"))
                    local prioMageRDPSWC = tonumber(strtrim(sLine[34], "[] \t\n\r"))
                    local prioMageRDPSAPFrost = tonumber(strtrim(sLine[35], "[] \t\n\r"))
                    local prioMageRDPSElementalist = tonumber(strtrim(sLine[36], "[] \t\n\r"))
                    local prioMageRDPSPOMPyro = tonumber(strtrim(sLine[37], "[] \t\n\r"))
                    local prioMageRDPSDeepFire = tonumber(strtrim(sLine[38], "[] \t\n\r"))

                    local bisThrough = {}
                    bisThrough["Warrior"] = {}
                    bisThrough["Warrior"]["Tank"] = math.max(prioWarriorTankProt)
                    bisThrough["Warrior"]["OT"] = math.max(prioWarriorOTFuryProt)
                    bisThrough["Warrior"]["MDPS"] = math.max(prioWarriorMDPS1hFury, prioWarriorMDPS2hFury, prioWarriorMDPSArms)
                    bisThrough["Warrior"]["Prot"] = prioWarriorTankProt
                    bisThrough["Warrior"]["FuryProt"] = prioWarriorOTFuryProt
                    bisThrough["Warrior"]["1hFury"] = prioWarriorMDPS1hFury
                    bisThrough["Warrior"]["2hFury"] = prioWarriorMDPS2hFury
                    bisThrough["Warrior"]["Arms"] = prioWarriorMDPSArms
                    bisThrough["Hunter"] = {}
                    bisThrough["Hunter"]["RDPS"] = math.max(prioHunterRDPSBeastMastery, prioHunterRDPSSurvival, prioHunterRDPSMarksMan)
                    bisThrough["Hunter"]["BeastMastery"] = prioHunterRDPSBeastMastery
                    bisThrough["Hunter"]["Survival"] = prioHunterRDPSSurvival
                    bisThrough["Hunter"]["Marksman"] = prioHunterRDPSMarksMan
                    bisThrough["Shaman"] = {}
                    bisThrough["Shaman"]["Healer"] = math.max(prioShamanHealerResto)
                    bisThrough["Shaman"]["MDPS"] = math.max(prioShamanMDPSEnhancement)
                    bisThrough["Shaman"]["RDPS"] = math.max(prioShamanRDPSElemental, prioShamanRDPSHybrid)
                    bisThrough["Shaman"]["Resto"] = prioShamanHealerResto
                    bisThrough["Shaman"]["Enhancement"] = prioShamanMDPSEnhancement
                    bisThrough["Shaman"]["Elemental"] = prioShamanRDPSElemental
                    bisThrough["Shaman"]["Hybrid"] = prioShamanRDPSHybrid
                    bisThrough["Druid"] = {}
                    bisThrough["Druid"]["MDPS"] = math.max(prioDruidMDPSFeralDPS)
                    bisThrough["Druid"]["RDPS"] = math.max(prioDruidRDPSBalance)
                    bisThrough["Druid"]["Tank"] = math.max(prioDruidTankFeralTank)
                    bisThrough["Druid"]["Healer"] = math.max(prioDruidHealerResto)
                    bisThrough["Druid"]["FeralTank"] = prioDruidTankFeralTank
                    bisThrough["Druid"]["FeralDPS"] = prioDruidMDPSFeralDPS
                    bisThrough["Druid"]["Balance"] = prioDruidRDPSBalance
                    bisThrough["Druid"]["Resto"] = prioDruidHealerResto
                    bisThrough["Rogue"] = {}
                    bisThrough["Rogue"]["MDPS"] = math.max(prioRogueMDPSSword, prioRogueMDPSDagger, prioRogueMDPSMace)
                    bisThrough["Rogue"]["Sword"] = prioRogueMDPSSword
                    bisThrough["Rogue"]["Dagger"] = prioRogueMDPSDagger
                    bisThrough["Rogue"]["Mace"] = prioRogueMDPSMace
                    bisThrough["Priest"] = {}
                    bisThrough["Priest"]["Healer"] = math.max(prioPriestHealerHoly, prioPriestHealerDiscHoly)
                    bisThrough["Priest"]["RDPS"] = math.max(prioPriestRDPSShadow,prioPriestUtilityHolyShadowweave)
                    bisThrough["Priest"]["Holy"] = prioPriestHealerHoly
                    bisThrough["Priest"]["DiscHoly"] = prioPriestHealerDiscHoly
                    bisThrough["Priest"]["Shadow"] = prioPriestRDPSShadow
                    bisThrough["Priest"]["HolyShadowweave"] = prioPriestUtilityHolyShadowweave
                    bisThrough["Warlock"] = {}
                    bisThrough["Warlock"]["RDPS"] = math.max(prioWarlockRDPSSMRuin, prioWarlockRDPSDemo, prioWarlockRDPSAffliction, prioWarlockRDPSDestruction)
                    bisThrough["Warlock"]["SMRuin"] = prioWarlockRDPSSMRuin
                    bisThrough["Warlock"]["Demonology"] = prioWarlockRDPSDemo
                    bisThrough["Warlock"]["Affliction"] = prioWarlockRDPSAffliction
                    bisThrough["Warlock"]["Destruction"] = prioWarlockRDPSDestruction
                    bisThrough["Mage"] = {}
                    bisThrough["Mage"]["RDPS"] = math.max(prioMageRDPSWC, prioMageRDPSAPFrost, prioMageRDPSElementalist, prioMageRDPSPOMPyro, prioMageRDPSDeepFire)
                    bisThrough["Mage"]["WintersChill"] = prioMageRDPSWC
                    bisThrough["Mage"]["APFrost"] = prioMageRDPSAPFrost
                    bisThrough["Mage"]["Elementalist"] = prioMageRDPSElementalist
                    bisThrough["Mage"]["POMPyro"] = prioMageRDPSPOMPyro
                    bisThrough["Mage"]["DeepFire"] = prioMageRDPSDeepFire

                    local eventData, eventType = bsloot:buildEventSaveItemBisMatrix(lineItemId, bisThrough)
                    bsloot:recordEvent(eventType, eventData)
                    bisImported = bisImported + 1
                  else
                    bsloot:debugPrint("Processing "..itemLink.." from line: "..line, bsloot.statics.LOGS.BULK)
                  end
                else
                  missed = missed + 1
                  bsloot:debugPrint("Failed to find item: from line: "..line, bsloot.statics.LOGS.BULK)
                end
              end)
          else
            bsloot:debugPrint("Ignoring invalid line: "..line, bsloot.statics.LOGS.BULK)
          end
        end
      end
    end
    bsloot:debugPrint("Imported Item GPs Total: " ..gpImported, bsloot.statics.LOGS.BULK)
    bsloot:debugPrint("Imported Item BisMatrix Total: " ..bisImported, bsloot.statics.LOGS.BULK)
    bsloot:debugPrint("Total items processed: " ..total, bsloot.statics.LOGS.BULK)
    bsloot:debugPrint("Missed items: " ..missed, bsloot.statics.LOGS.BULK)
    bsloot:debugPrint("Found items: " ..found, bsloot.statics.LOGS.BULK)
    if(gpImported > 0 or bisImported > 0) then
      local browser = bsloot:GetModule(addonName.."_browser")
      if browser then
        browser:ReInit()
      end
    end

  end
  
  function bsloot:importGpValues(csvText, overwrite)
    local lines = bsloot:split(csvText, "\n")
    local total, found, missed = 0, 0, 0
    local imported = 0
    local newItems = 0
    if(lines and lines ~= nil) then
      for lineNum, line in ipairs(lines) do
        local sLine = bsloot:split(line, "|")
        if (sLine and sLine ~= nil) then
          local tempItemName = strtrim(sLine[1] or "")
          if (string.find(line, "|") ~= 1 and tempItemName and tempItemName ~= nil and tempItemName ~= "") then
            local lineItemName = strtrim(sLine[1], " \t\n\r")
            local lineItemSlot = tonumber(strtrim(sLine[2], "[] \t\n\r"))
            local lineItemId = tonumber(strtrim(sLine[3], "[] \t\n\r"))
            local lineItemRaid = strtrim(sLine[4], "[] \t\n\r")
            local lineItemGp = tonumber(strtrim(sLine[6], "[] \t\n\r"))
            
            total = total + 1
            bsloot:doWithItemInfo(lineItemId, 
              function(itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
                itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
                isCraftingReagent, itemId) 
                if(itemLink ~= nil) then
                  found = found + 1

                  local itemKey = bsloot:buildEpGpEventReasonKey(bsloot.statics.eventType.GP_VAL, bsloot.statics.EPGP.LOOT, lineItemId)
                  if(not ItemGPCost[itemKey] or ItemGPCost[itemKey] == nil) then
                    newItems = newItems + 1
                  end
                  
                  local eventData, eventType = bsloot:buildEventSaveItemGp(lineItemId, lineItemGp, itemEquipLoc, lineItemRaid, lineItemName, itemLink, lineItemSlot)
                  bsloot:recordEvent(eventType, eventData)

                  imported = imported + 1
                else
                  missed = missed + 1
                  bsloot:debugPrint("Failed to find item: from line: "..line, bsloot.statics.LOGS.BULK)
                end
              end)
          else
            bsloot:debugPrint("Ignoring invalid line: "..line, bsloot.statics.LOGS.BULK)
          end
        end
      end
    end
    bsloot:debugPrint("New Items Total: " ..newItems, bsloot.statics.LOGS.BULK)
    bsloot:debugPrint("Imported Items Total: " ..imported, bsloot.statics.LOGS.BULK)
    bsloot:debugPrint("Total items processed: " ..total, bsloot.statics.LOGS.BULK)
    bsloot:debugPrint("Missed items: " ..missed, bsloot.statics.LOGS.BULK)
    bsloot:debugPrint("Found items: " ..found, bsloot.statics.LOGS.BULK)
    if(imported > 0) then
      local browser = bsloot:GetModule(addonName.."_browser")
      if browser then
        browser:ReInit()
      end
    end
  end

  function bsloot:importEpValues(csvText, overwrite)
    local lines = bsloot:split(csvText, "\n")
    local total = 0
    local imported = 0
    local newItems = 0
    if(lines and lines ~= nil) then
      for lineNum, line in ipairs(lines) do
        local sLine = bsloot:split(line, "|")
        if (sLine and sLine ~= nil) then
          local tempItemName = strtrim(sLine[1] or "")
          if (string.find(line, "|") ~= 1 and tempItemName and tempItemName ~= nil and tempItemName ~= "") then
            local reasonName = strtrim(sLine[1], " \t\n\r")
            local epAmount = tonumber(strtrim(sLine[2], "[] \t\n\r"))
            local lineItemRaid = strtrim(sLine[3], "[] \t\n\r")
            local reasonArray = bsloot:split(reasonName, ":")
            local subType = reasonArray[1]:upper()
            local reason = reasonArray[2]
            total = total + 1

            local reasonKey = bsloot:buildEpGpEventReasonKey(bsloot.statics.eventType.EP_VAL, subType, reason)
            if(not EPValues[reasonKey] or EPValues[reasonKey] == nil) then
              newItems = newItems + 1
            end
            
            local eventData, eventType = bsloot:buildEventSaveItemEp(subType, reason, epAmount, lineItemRaid)
            bsloot:recordEvent(eventType, eventData)
            imported = imported + 1
            
          else
            bsloot:debugPrint("Ignoring invalid line: "..line, bsloot.statics.LOGS.BULK)
          end
        end
      end
    end
    bsloot:debugPrint("New EP Values: " ..newItems, bsloot.statics.LOGS.BULK)
    bsloot:debugPrint("Imported EP Values Total: " ..imported, bsloot.statics.LOGS.BULK)
    bsloot:debugPrint("Total EP Values processed: " ..total, bsloot.statics.LOGS.BULK)
  end

  function bsloot:importCharRoles(csvText, overwrite)
    local lines = bsloot:split(csvText, "\n")
    local imported = 0
    if(lines and lines ~= nil) then
      for lineNum, line in ipairs(lines) do
        local sLine = bsloot:split(line, "|")
        if (sLine and sLine ~= nil and lineNum > 1) then
          local charName = strtrim(sLine[1] or "")
          if (string.find(line, "|") ~= 1 and charName and charName ~= nil and charName ~= "") then
            local lineItemCharName = strtrim(sLine[1], "[] \t\n\r")
            local lineItemPlayerName = strtrim(sLine[2], "[] \t\n\r")
            local lineItemClass = strtrim(sLine[3], "[] \t\n\r")
            local lineItemRole = strtrim(sLine[4], "[] \t\n\r")
            if(overwrite or not CharRoleDB[lineItemCharName] or CharRoleDB[lineItemCharName] == nil) then
              
              local eventData, eventType = bsloot:buildEventSaveCharacter(lineItemCharName, lineItemClass, lineItemRole, lineItemPlayerName)
              bsloot:recordEvent(eventType, eventData)
              imported = imported + 1
            else
              bsloot:debugPrint("Skipping existing "..lineItemCharName.." from line: "..line, bsloot.statics.LOGS.BULK)
            end
            
          else
            bsloot:debugPrint("Ignoring invalid line: "..line, bsloot.statics.LOGS.BULK)
          end
        end
      end
      
    end
    bsloot:debugPrint("Imported CharRoles Total: " ..imported, bsloot.statics.LOGS.BULK)
  end

  --END bulk import

  --BEGIN auto EP
  function bsloot:getEpForEncounter(combatInfo) 
    -- bsloot:debugPrint("Detected DBM_Kill Event of: "..bsloot:tableToString(combatInfo), bsloot.statics.LOGS.AUTODETECT)
    local bossName = combatInfo.name;
    local epKey = bsloot:buildEpGpEventReasonKey(bsloot.statics.eventType.EP_VAL, bsloot.statics.EPGP.BOSSKILL, bossName)
    local epEntry = EPValues[epKey]
    local ep = 0
    if(epEntry and epEntry ~= nil) then
      ep = epEntry.ep
    else
      bsloot:warnPrint("No EP entry found for ".. epKey, bsloot.statics.LOGS.EPGP)
    end
    local progrssionEp = bsloot:getProgressionEp(bossName)
    return ep, progrssionEp, epKey
  end
  function bsloot:getProgressionEp(bossName)
    local progrssionEp = 0
    if(bsloot:getNumKills(bossName) < bsloot.MaxProgressionKills) then -- the < is assuming the kill count is checked PRIOR to recording the kill event, if after change to <=
      local progressionEpKey = bsloot:buildEpGpEventReasonKey(bsloot.statics.eventType.EP_VAL, bsloot.statics.EPGP.PROGRESSION, bossName)
      local epEntry = EPValues[progressionEpKey]
      if(epEntry and epEntry ~= nil) then
        progrssionEp = epEntry.ep
      else
        bsloot:warnPrint("No EP entry found for ".. progressionEpKey, bsloot.statics.LOGS.EPGP)
      end
    end
    return progrssionEp
  end
  bsloot.MaxProgressionKills = 3 -- number of kills to give progression EP for --TODO configurable?
  function bsloot:getNumKills(bossName)
    local isNew = false
    if(BossKillCounter[bossName] == nil or type(BossKillCounter[bossName]) ~= "number") then
      isNew = true
      BossKillCounter[bossName] = 0
      for eventId, event in pairs(SyncEvents) do
        if(event.type == bsloot.statics.eventType.EPGP) then
          local eventData = bsloot:getEventData(eventId, event.type)
          if(eventData.reason == bsloot.statics.EPGP.BOSSKILL and eventData.subReason == bossName) then
            BossKillCounter[bossName] = BossKillCounter[bossName] + 1
          end
        end
      end
    end
    return BossKillCounter[bossName], isNew
  end

  --END auto EP
  
  --BEGIN event creation
  function bsloot:uuid()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
  end
  
  function bsloot:buildEventChangeMainChar(fromChar, toChar, gpVal, epPenalty)
    local eventData = {}
    eventData.toChar = toChar
    eventData.fromChar = fromChar
    eventData.gpVal = gpVal
    eventData.epPenalty = epPenalty
    return eventData, bsloot.statics.eventType.SWITCH_MAIN
  end
  function bsloot:buildEventSaveCharacter(charName, class, role, mainChar)
    local eventData = {}
    eventData.name = charName
    eventData.class = class
    eventData.role = role
    eventData.mainChar = mainChar
    return eventData, bsloot.statics.eventType.CHAR_ROLE
  end
  function bsloot:buildEventSaveItemGp(itemId, gp, slot, raid, importedName, itemLink, importedSlot)
    local eventData = {}
    eventData.itemId = itemId
    eventData.gp = gp
    eventData.slot = slot
    eventData.raid = raid
    eventData.importedName = importedName
    eventData.importedSlot = importedSlot
    eventData.itemLink = itemLink
    return eventData, bsloot.statics.eventType.GP_VAL
  end
  function bsloot:buildEventSaveItemBisMatrix(itemId, bisThrough, subType)
    local eventData = {}
    eventData.itemId = itemId
    eventData.bisThrough = bisThrough
    eventData.subType = subType or bsloot.statics.eventSubType.FULL_UPDATE
    
    return eventData, bsloot.statics.eventType.BIS_MATRIX
  end
  function bsloot:buildEventSaveItemEp(subType, reason, epAmount, raid)
    local eventData = {}
    eventData.epType = subType
    eventData.epReason = reason
    eventData.ep = epAmount
    eventData.raid = raid
    
    return eventData, bsloot.statics.eventType.EP_VAL

  end
  function bsloot:buildEventSaveEpGpEvent(characters, type, amount, reason, subReason)
    local eventData = {}
    eventData.subType = type
    eventData.reason = reason
    eventData.subReason = subReason
    eventData.amount = amount
    eventData.characters = characters
    
    return eventData, bsloot.statics.eventType.EPGP
  end
  function bsloot:buildEventSaveRaidStartEvent(characters, raidLoc, name)
    local eventData = {}
    eventData.raidLoc = raidLoc
    eventData.name = name
    eventData.subType = bsloot.statics.eventSubType.RAID_START
    eventData.characters = characters
    
    return eventData, bsloot.statics.eventType.RAID
  end
  function bsloot:buildEventSaveRaidEndEvent(characters, raidId)
    local eventData = {}
    eventData.raidId = raidId
    eventData.subType = bsloot.statics.eventSubType.RAID_END
    eventData.characters = characters
    
    return eventData, bsloot.statics.eventType.RAID
  end

  function bsloot:buildEventSaveRaidBossAttempt(characters, raidId, bossName)
    local eventData = {}
    eventData.raidId = raidId
    eventData.subType = bsloot.statics.eventSubType.BOSS_ATTEMPT
    eventData.characters = characters
    eventData.name = bossName
    
    return eventData, bsloot.statics.eventType.RAID
  end

  function bsloot:rebuildDataFromEventLog()
    local eventIds = {}
    bsloot:warnPrint("Beginning full Data Reconstruction from Events", bsloot.statics.LOGS.EVENT)
    local count = 0
    for k, event in pairs(SyncEvents) do
      if(not eventIds[event.type] or eventIds[event.type] == nil) then
        eventIds[event.type] = {}
      end
      table.insert(eventIds[event.type], k)
      count = count + 1
    end
    for _, subset in pairs(eventIds) do
      table.sort(subset, function(a,b) 
        return SyncEvents[a].epochSeconds < SyncEvents[b].epochSeconds
      end)
    end
    bsloot:warnPrint(string.format("%d events sorted", count), bsloot.statics.LOGS.EVENT)
    bsloot:purgeNonEventData()
    bsloot:warnPrint("Non event data purged", bsloot.statics.LOGS.EVENT)

    local numRecalcd = 0
    local calculated = {}
    numRecalcd = numRecalcd + bsloot:processAllEventsOfType(eventIds[bsloot.statics.eventType.CHAR_ROLE])
    calculated[bsloot.statics.eventType.CHAR_ROLE] = true
    numRecalcd = numRecalcd + bsloot:processAllEventsOfType(eventIds[bsloot.statics.eventType.SWITCH_MAIN])
    calculated[bsloot.statics.eventType.SWITCH_MAIN] = true
    numRecalcd = numRecalcd + bsloot:processAllEventsOfType(eventIds[bsloot.statics.eventType.EP_VAL])
    calculated[bsloot.statics.eventType.EP_VAL] = true
    numRecalcd = numRecalcd + bsloot:processAllEventsOfType(eventIds[bsloot.statics.eventType.GP_VAL])
    calculated[bsloot.statics.eventType.GP_VAL] = true
   
    for type, events in pairs(eventIds) do
      if(not calculated[type] or calculated[type] == false) then
        numRecalcd = numRecalcd + bsloot:processAllEventsOfType(events)
        calculated[type] = true
      end
    end

    bsloot:correctForNonRealtimeDataLoad()

    bsloot:warnPrint(string.format("Completed full Data Reconstruction from %d Events", numRecalcd), bsloot.statics.LOGS.EVENT)

  end
  function bsloot:processAllEventsOfType(events, type)
    
    local numRecalcd = 0
    if(events and events ~= nil) then
      for _, eventId in ipairs(events) do
        local success, err = pcall(function()
          bsloot:doRecalcEventId(eventId)
          numRecalcd = numRecalcd + 1
        end)
        if(not success) then
          bsloot:warnPrint(string.format("Unable to include event in rebuild as it is corrupt: %s; err=\"%s\"", eventId, (err or "nil")), bsloot.statics.LOGS.EVENT)
        end
      end
    end
    return numRecalcd
  end
  function bsloot:correctForNonRealtimeDataLoad()
    --Boss kill counts are based on the events in history when the first one is seen. could fix this by using a different "getKillCount" method in the getProgressionEp function instead of correcting it at
    for bossName, count in pairs(BossKillCounter) do
      if(count > 1) then
        BossKillCounter[bossName] = count - 1
      end
    end

  end

  --END event creation

  --BEGIN raid event management
  function bsloot:startRaid(raidName, raidLoc, timestamp)
    --create event, include players in raid at start
    local currentRoster = {}
    for i = 1, GetNumGroupMembers() do
      local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(i)
      if(name ~= nil) then
        name = Ambiguate(name,"short")
        table.insert(currentRoster, name)
      end
    end
    --give EP for on time
    if(not raidLoc or raidLoc == nil) then
      raidLoc = GetZoneText()
    end
    
    local eventData, eventType = bsloot:buildEventSaveRaidStartEvent(currentRoster, raidLoc, raidName)
    bsloot:recordEvent(eventType, eventData)
    local raidMsg = string.format(L["Starting Raid: %s"],raidName)
    bsloot:SendChat(raidMsg, bsloot.db.profile.chat.raidEvent)
    local epKey = bsloot:buildEpGpEventReasonKey(bsloot.statics.eventType.EP_VAL, bsloot.statics.EPGP.BONUS, bsloot.statics.EPGP.ON_TIME)
    local ep = EPValues[epKey]
    if(ep ~= nil) then
      bsloot:epToRaid(ep.ep, bsloot.statics.EPGP.BONUS, bsloot.statics.EPGP.ON_TIME, false, currentRoster)
    else
      bsloot:errorPrint(string.format("No EP Value for key: \"%s\"", epKey), bsloot.statics.LOGS.EPGP)
    end
  end

  bsloot.minDurationForIronman = 120 --TODO configurable?

  function bsloot:endRaid(raidName, timestamp)
    --create event, include players in raid at end
    local currentRoster = {}
    for i = 1, GetNumGroupMembers() do
      local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(i)
      if(name ~= nil) then
        name = Ambiguate(name,"short")
        table.insert(currentRoster, name)
      end
    end
    local currentRaidId = bsloot:getCurrentRaidId()
    local eventData, eventType = bsloot:buildEventSaveRaidEndEvent(currentRoster, raidLoc, raidName)
    local raidEndId = bsloot:recordEvent(eventType, eventData)
    local raidMsg = string.format(L["Ending Raid: %s (raid event ID: %s)"],raidName, (currentRaidId or ""))
    bsloot:SendChat(raidMsg, bsloot.db.profile.chat.raidEvent)
    --give EP for Ironman
    local raidDuration = bsloot:getRaidDuration(currentRaidId, raidEndId)
    if(raidDuration >= bsloot.minDurationForIronman) then
      local ironmanRoster = bsloot:getIronmanRoster(currentRaidId, raidEndId)
      local epKey = bsloot:buildEpGpEventReasonKey(bsloot.statics.eventType.EP_VAL, bsloot.statics.EPGP.BONUS, bsloot.statics.EPGP.IRONMAN)
      local ep = EPValues[epKey]
      bsloot:epToRaid(ep.ep, bsloot.statics.EPGP.BONUS, bsloot.statics.EPGP.IRONMAN, false, ironmanRoster, bsloot:getTsBefore(SyncEvents[raidEndId].epochSeconds, 10000))
    end
  end
  function bsloot:getIronmanRoster(currentRaidId, raidEndId)
    local tempIronmanRoster = {}
    if(not raidEndId or raidEndId == nil) then
      _, raidEndId = bsloot:getRaidEndTime(raidId, raidEndId)
    end
    local startRaidEvent = bsloot:getEventData(currentRaidId, bsloot.statics.eventType.RAID)
    local startRoster = startRaidEvent.characters
    local startMap = bsloot:arrayToTrueOnlyMap(startRoster)
    local endRaidEvent = bsloot:getEventData(raidEndId, bsloot.statics.eventType.RAID)
    local endRoster = endRaidEvent.characters
    local endMap = bsloot:arrayToTrueOnlyMap(endRoster)
    for charName, _ in pairs(startMap) do
      if(startMap[charName] and endMap[charName] and startMap[charName] ~= nil and endMap[charName] ~= nil) then
        tempIronmanRoster[charName] = true
      end
    end

    local raidEvents = bsloot:getRaidEvents(currentRaidId, raidEndId)
    for eventId, event in ipairs(raidEvents) do
      local eventData = bsloot:getEventData(eventId, event.type)
      if(eventData.characters) then
        local tempArrayRoster = bsloot:arrayToTrueOnlyMap(eventData.characters)

        for charName, _ in pairs(tempIronmanRoster) do
          if(not tempArrayRoster[charName] or tempArrayRoster[charName] == nil) then
            tempIronmanRoster[charName] = nil
          end
        end
      end
    end

    return bsloot:trueOnlyMapToArray(tempIronmanRoster)
  end
  
  function bsloot:trueOnlyMapToArray(map)
    
    local arr = {}
    for k, _ in pairs(map) do
      if(map[k] and map[k] ~= nil) then
        table.insert(arr, k)
      end
    end
    return arr
  end
  function bsloot:arrayToTrueOnlyMap(arr)
    
    local map = {}
    for _, k in ipairs(arr) do
      map[k] = true
    end
    return map
  end
  
  function bsloot:arrayContains(arr, target)
    for _, v in ipairs(arr) do
        if v == target then
            return true
        end
    end
    return false
  end
  function bsloot:isInTimeWindow(beginTime, endTime, targetTime)
    return targetTime >= beginTime and targetTime <= endTime
  end
  function bsloot:isEventInTimeWindow(beginTime, endTime, eventId)
    return bsloot:isInTimeWindow(beginTime, endTime, SyncEvents[eventId].epochSeconds)
  end

  function bsloot:getRaidHighlights(raidId, raidEndId)

    local endTime, raidEndId = bsloot:getRaidEndTime(raidId, raidEndId)
    local attendees = {}
    local raidEvents = {}
    local isEnded = false
    local startTime = SyncEvents[raidId].epochSeconds
    raidEvents[raidId] = SyncEvents[raidId]
    eventData = bsloot:getEventData(raidId, bsloot.statics.eventType.RAID)
    for _, char in ipairs(eventData.characters) do
      attendees[char] = true
    end

    for eventId, event in pairs(SyncEvents) do
      if(bsloot:isInTimeWindow(startTime, endTime, event.epochSeconds) and eventId ~= raidId) then
        eventData = bsloot:getEventData(eventId, eventType)
        if(eventData ~= nil) then
          if(event.type == bsloot.statics.eventType.RAID) then
            if(eventData.raidId == raidId) then
              if(eventData.subType == bsloot.statics.eventSubType.RAID_END) then
                isEnded = true
              end
              raidEvents[eventId] = SyncEvents[eventId]
              for _, char in ipairs(eventData.characters) do
                attendees[char] = true
              end
            end
          end
        end
      end
    end
    return attendees, raidEvents, isEnded
  end

  function bsloot:getRaidEvents(raidId, raidEndId, includeMiscTypes)
    local endTime, raidEndId = bsloot:getRaidEndTime(raidId, raidEndId)
    local startTime = SyncEvents[raidId].epochSeconds
    local attendees = bsloot:getRaidAttendees(raidId, raidEndId)
    local raidEvents = {}
    local startTime = SyncEvents[raidId].epochSeconds

    for eventId, event in pairs(SyncEvents) do
      if(event.type ~= bsloot.statics.eventType.RAID and bsloot:isInTimeWindow(startTime, endTime, event.epochSeconds)) then
        local eventData = bsloot:getEventData(eventId, eventType)
        if(event.type == bsloot.statics.eventType.SWITCH_MAIN) then
          if((attendees[eventData.toChar] and attendees[eventData.toChar] ~= nil) or (attendees[eventData.fromChar] and attendees[eventData.fromChar] ~= nil)) then
            raidEvents[eventId] = SyncEvents[eventId]
          end
        elseif(event.type == bsloot.statics.eventType.EPGP) then
          for _, char in ipairs(eventData.characters) do
            if(attendees[char] and attendees[char] ~= nil) then
              raidEvents[eventId] = SyncEvents[eventId]
              break
            end
          end
        elseif(event.type == bsloot.statics.eventType.CHAR_ROLE) then
          if(attendees[eventData.name] and attendees[eventData.name] ~= nil) then
            raidEvents[eventId] = SyncEvents[eventId]
          end
        elseif(includeMiscTypes) then
          raidEvents[eventId] = SyncEvents[eventId]
        end
      end
    end

    --strawman get all events between start and end
    --better get all events between start and end by whoever started it
    --best get all events between start and end that happened to attendees
    return raidEvents
  end
  function bsloot:getRaidAttendees(raidId, raidEndId)

    local endTime, raidEndId = bsloot:getRaidEndTime(raidId, raidEndId)
    local attendees = {}
    local startTime = SyncEvents[raidId].epochSeconds

    for eventId, event in pairs(SyncEvents) do
      if(
        (event.type == bsloot.statics.eventType.EPGP or event.type == bsloot.statics.eventType.RAID)
        and bsloot:isInTimeWindow(startTime, endTime, event.epochSeconds) 
        and bsloot:getEventCreator(event) == bsloot:getEventCreator(SyncEvents[raidId])
      ) then
        local eventData = bsloot:getEventData(eventId, eventType)
        if(eventData ~= nil) then
          for _, char in ipairs(eventData.characters) do
            attendees[char] = true
          end
        end
      end
    end
    return attendees
  end

  bsloot.currentRaidId = "" -- TODO hmmm should i store this?
  function bsloot:getCurrentRaidId(asOfTimestamp) 
    if(not asOfTimestamp or asOfTimestamp == nil) then
      _, asOfTimestamp = bsloot:getServerTime()
    end
    local potentials = {}
    local recentTimeLength = 8 * 60 * 60 -- 8 hours
    local windowEnd = asOfTimestamp.epochMS / 1000
    local windowStart = windowEnd - recentTimeLength
    for eventId, event in pairs(SyncEvents) do
      if(event.type == bsloot.statics.eventType.RAID and bsloot:isInTimeWindow(windowStart, windowEnd, event.epochSeconds)) then
        local eventData = bsloot:getEventData(eventId, eventType)
        if(eventData ~= nil) then
          if(eventData.subType == bsloot.statics.eventSubType.RAID_START) then
            potentials[eventId] = SyncEvents[eventId].epochSeconds
          end
        end
      end
    end

    local mostRecentId = nil
    for raidId, raidStartTime in pairs(potentials) do

      local attendees, _, isEnded= bsloot:getRaidHighlights(raidId, raidEndId)
      if(not isEnded and attendees[bsloot._playerName]) then
        if(mostRecentId == nil or raidStartTime > potentials[mostRecentId]) then
          mostRecentId = raidId
        end
      end
    end
    --NOTE: an edge case exists where someone could hop over to help team B Ony (or other fast) mid raid and have this value mixed up
    return mostRecentId
  end
  
  function bsloot:getRaidEndTime(raidStartId, raidEndId, assumeOngoing)
    local endTime, _ = bsloot:getServerTime()
    if(not assumeOngoing or assumeOngoing == nil) then
      if(not raidEndId or raidEndId == nil) then
        for eventId, event in pairs(SyncEvents) do
          if(event.type == bsloot.statics.eventType.RAID) then
            local eventData = bsloot:getEventData(eventId, eventType)
            if(eventData ~= nil) then
              if(eventData.subType == bsloot.statics.eventSubType.RAID_END and eventData.raidId == raidStartId) then
                raidEndId = eventId
                break
              end
            end
          end
        end
      end
      if(raidEndId and raidEndId ~= nil) then
        endTime = SyncEvents[raidEndId].epochSeconds
      end
    end
    return endTime, raidEndId
  end
  function bsloot:getRaidDuration(raidStartId, raidEndId, assumeOngoing)
    local startTime = SyncEvents[raidStartId].epochSeconds
    local endTime = bsloot:getRaidEndTime(raidStartId, raidEndId, assumeOngoing)
    local durationTotalSeconds = endTime - startTime
    return durationTotalSeconds/60.0, durationTotalSeconds
  end
  --END raid event management

  -- BEGIN Item Info stuff
  function bsloot:doWithItemInfo(originalItem, func)
    local item = originalItem
    if(type(item) == "string") then
      item = strtrim(item, " \t\r\n")
      local itemAsNumber = tonumber(item)
      if(itemAsNumber ~= nil) then
        item = itemAsNumber
      end
    end
    local itemId, instanItemType, instanItemSubType, instanItemEquipLoc, instanIcon, instanItemClassID, instanItemSubClassID = GetItemInfoInstant(item)
    if(itemId == nil) then
      itemId = bsloot:findItemIdByImportedName(item)
      bsloot:debugPrint(string.format("Finding %s by id: %s", bsloot:tableToString(item), bsloot:tableToString(itemId)), {logicOp="AND", values={bsloot.statics.LOGS.DEV, bsloot.statics.LOGS.EVENT}})
    end
    local success, err = pcall(function()
      local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
      itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
      isCraftingReagent = GetItemInfo(itemId)
      if (itemLink) then
        func(itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
          itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
          isCraftingReagent, itemId)
      else
        local itemMixin = Item:CreateFromItemID(itemId)
        itemMixin:ContinueOnItemLoad(function()
          itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
          itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
          isCraftingReagent = GetItemInfo(itemId)
          func(itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
          itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
          isCraftingReagent, itemId)
        end)
      end
    end)
    if(not success) then
      bsloot:warnPrint(string.format("Failed to load item \"%s\" due to %s", originalItem, err), bsloot.statics.LOGS.DEV)
    end
  end
  function bsloot:tablelength(t)
    local count = 0
    for _ in pairs(t) do
      count = count + 1
    end
    return count
  end
  function bsloot:getQDepth(q)
    return q.last-q.first+1
  end
  function bsloot:isQEmpty(q)
    return q.first > q.last
  end
  function bsloot:qAdd(q, value)
    local last = q.last + 1
    q.last = last
    q[last] = value
    return last
  end
  function bsloot:qPop(q)
    local first = q.first
    if(first > q.last) then 
      return
    end
    local value = q[first]
    q[first] = nil
    q.first = first + 1
    if(bsloot:isQEmpty(q)) then
      bsloot:rsetQ(q)
    end
    return value
  end
  function bsloot:rsetQ(q)
    table.wipe(q)
    q.first = 0
    q.last = -1
  end
  function bsloot:isGuildMemberOnline(chackName)
    local isOnline = false
    chackName = Ambiguate(chackName,"short")
    local numGuildMembers = GetNumGuildMembers(true)
    for i = 1, numGuildMembers do
      local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName, 
      achievementPoints, achievementRank, isMobile, isSoREligible, standingID = GetGuildRosterInfo(i)
      local member_name = Ambiguate(name,"short")
      if(member_name == chackName) then 
        isOnline = online
        break
      end
    end
    return isOnline
  end

  function bsloot:getEventCreator(event)
    return event.creator or "Murach"
  end
  function bsloot:getDateTimeString(epochSeconds)
    return date("%Y.%m.%d %H:%M:%S", epochSeconds)
  end
  function bsloot:findItemIdByImportedName(itemName)
    for itemKey, item in pairs(ItemGPCost) do
      if(item.importedName and item.importedName ~= nil and item.importedName == itemName) then
        local itemId = GetItemInfoInstant(item.link)
        return itemId
      end
    
    end
  end

  function bsloot:getRaidSize(raidLoc)
    if(raidLoc == "ZG" or raidLoc == "AQ20") then
      return 20
    end
    return 40
  end
  -- END
  
  _G[addonName] = bsloot
