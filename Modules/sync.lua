local addonName, bsloot = ...
local moduleName = addonName.."_sync"
local bsloot_sync = bsloot:NewModule(moduleName, "AceEvent-3.0")

bsloot_sync.queueTimerFrequency = 10
bsloot_sync.syncQueue = {first = 0, last = -1}
bsloot_sync.scheduled = {}
SyncEvents = SyncEvents or {}
bsloot_sync.maxSyncResponseWaitTimeMins = 10

InboundSyncQueue = InboundSyncQueue or {first = 0, last = -1}
bsloot_sync.enabled = false
bsloot_sync.syncOnlyCritical = true
function bsloot_sync:OnEnable()
  bsloot_sync.enabled = false or bsloot.db.char.syncEnabled
  bsloot_sync.syncOnlyCritical = false or bsloot.db.char.syncOnlyCritical
  bsloot_sync.queueTimerFrequency = 10 -- configurable??
  bsloot_sync:startInboundQueueTimer()
  bsloot_sync:syncAll()
end

function bsloot_sync:isCriticalType(eventType) 
--   return eventType == nil or string.find(eventType, "ItemVal_") == 1 or string.find(eventType, "CharRole_") == 1 
return true
end

function bsloot_sync:SetEnabled(flag)
  if(flag and not bsloot_sync.enabled) then
    bsloot_sync.enabled = flag
    bsloot_sync:syncAll()
  else
    bsloot_sync.enabled = flag
    bsloot_sync.syncQueue = {first = 0, last = -1}
  end
end

function bsloot_sync:IsEnabled()
  return bsloot_sync.enabled
  -- return false
end
function bsloot_sync:IsSyncOnlyCritical()
  return bsloot_sync.syncOnlyCritical
end
function bsloot_sync:SetSyncOnlyCritical(flag)
  bsloot_sync.syncOnlyCritical = flag
end
function bsloot_sync:SetSyncQueueFrequency(frequencyInSeconds)
  bsloot_sync.queueTimerFrequency = frequencyInSeconds
end

function bsloot_sync:startInboundQueueTimer()

  if(bsloot_sync:IsEnabled()) then
    bsloot:debugPrint("Processing inbound sync queue", {logicOp="AND", values={bsloot.statics.LOGS.DEV, bsloot.statics.LOGS.SYNC}})
    local success, numReadOrErr = pcall(function()
      return bsloot_sync:readInboundQueue()
    end)
    if(success) then
      if(numReadOrErr > 0) then
        bsloot_sync:startInboundQueueTimer()
      else
        C_Timer.After(bsloot_sync.queueTimerFrequency, bsloot_sync.startInboundQueueTimer)
      end
    else
      bsloot:debugPrint("Encountered error while reading inbound queue, ignoring record: "..bsloot:tableToString(numReadOrErr), bsloot.statics.LOGS.SYNC)
      C_Timer.After(bsloot_sync.queueTimerFrequency, bsloot_sync.startInboundQueueTimer)
    end
  else
    bsloot:debugPrint("NOT Processing inbound sync queue", {logicOp="AND", values={bsloot.statics.LOGS.DEV, bsloot.statics.LOGS.SYNC}})
  end
end

function bsloot_sync:syncAllOut(requester)
  if(bsloot_sync:IsEnabled()) then
    local _, _, rankIndex = GetGuildInfo("player")
    if(rankIndex <= bsloot.syncMinGuildRank) then
      bsloot_sync:sendAllData(requester)
    else
      bsloot:debugPrint("skipping broadcast, too low rank", bsloot.statics.LOGS.SYNC)
    end
  end
end

bsloot_sync.offerBatchSize = 100
function bsloot_sync:offerSyncEvents(toPlayer)
  
  local guildRaid, raid, group, guildGroup = bsloot:isInGuildRaid()
  if(guildRaid) then
    bsloot:debugPrint("Skipping sync offer request to keep outbound comms cleared during guild raid", {logicOp="OR", values={bsloot.statics.LOGS.COMM, bsloot.statics.LOGS.SYNC}})
    return
  end
  if(bsloot_sync:IsEnabled()) then
    
    local _, _, rankIndex = GetGuildInfo("player")
    if(rankIndex <= bsloot.syncMinGuildRank) then
      local myProfile = bsloot_sync:getDataProfile()
      local dataProfileStr = myProfile.mostRecent .. "|" .. myProfile.numEvents
      if(toPlayer and toPlayer ~= nil) then
        bsloot:broadcastSync("syncOffer "..dataProfileStr, "WHISPER", toPlayer)
      else
        bsloot:broadcastSync("syncOffer "..dataProfileStr)
      end
    end
  end
end

function bsloot_sync:sendAllData(toPlayer)
  for eventId, eventData in pairs(SyncEvents) do
    local eventIdStr = eventId .. ":" .. eventData.type
    local qRec = bsloot_sync:buildOutboundQrec("outbound", eventIdStr, toPlayer)
    bsloot_sync:processEventDataRequest(qRec)
  end
end

function bsloot_sync:syncRecentEvent(eventId)
  if(bsloot_sync:IsEnabled()) then
    
    local _, _, rankIndex = GetGuildInfo("player")
    if(rankIndex <= bsloot.syncMinGuildRank) then
      local eventData = SyncEvents[eventId]
      if(eventData and eventData ~= nil) then
        local eventIdStr = eventId .. ":" .. eventData.type
        local qRec = bsloot_sync:buildOutboundQrec("outbound", eventIdStr)
        bsloot_sync:processEventDataRequest(qRec, true)
      else
        bsloot:errorPrint("Recent Sync Event not found: "..eventId, bsloot.statics.LOGS.SYNC)
      end
    end
  end
end

function bsloot_sync:checkSyncOffer(dataProfileStr, sender)
 -- bsloot:debugPrint("checkSyncOffer("..bsloot:tableToString(events)..", "..sender..")", {logicOp="AND", values={bsloot.statics.LOGS.DEV, bsloot.statics.LOGS.SYNC}})
  if(bsloot_sync:IsEnabled()) then
    local qDepth = bsloot:getQDepth(InboundSyncQueue)
    if(qDepth > 0) then
      bsloot:debugPrint("Waiting on offer from "..sender.." because you still have inbound events not saved", bsloot.statics.LOGS.SYNC)
      C_Timer.After(3, function() 
        bsloot_sync:checkSyncOffer(dataProfileStr, sender) 
      end)
      return
    end
    local dataProfile = bsloot:split(dataProfileStr, "|")
    local mostRecentOffered = tonumber(dataProfile[1])
    local numOffered = tonumber(dataProfile[2])
    
    local myProfile = bsloot_sync:getDataProfile()
    if(mostRecentOffered > myProfile.mostRecent) then
      bsloot_sync:requestAllData(myProfile.mostRecent, sender)
    elseif(numOffered > myProfile.numEvents) then
      local numMissing = numOffered - myProfile.numEvents
      bsloot:warnPrint("Negotiating eventId from "..sender.." because they have "..numMissing.." you do not. These are not most recent a full data rebuild may be necessary", bsloot.statics.LOGS.SYNC)
      bsloot_sync:requestAllIds(sender)
    end
  end
end

function bsloot_sync:getDataProfile()
  local dataProfile = {}
  dataProfile.numEvents =  bsloot:tablelength(SyncEvents)
  _, dataProfile.mostRecent = bsloot_sync.getMostRecentEvent()
  return dataProfile
end

function bsloot_sync.getMostRecentEvent()
  local mostRecentTs = 0
  local mostRecentEvent = ""
  for eventId, event in pairs(SyncEvents) do
    if(event.epochSeconds >= mostRecentTs) then
      mostRecentTs = event.epochSeconds
      mostRecentEvent = eventId
    end
  end
  return SyncEvents[mostRecentEvent], mostRecentTs
end

function bsloot_sync:receiveInboundEvent(eventData, sender)
  
  if(bsloot_sync:IsEnabled()) then
    bsloot_sync:enqueue("inbound", eventData, sender)
    bsloot_sync.lastInboundEventSec, _ = bsloot:getServerTime()
    bsloot_sync.awaitingResponse = false
  end
end


function bsloot_sync:processInboundEvent(qRec)
  if(bsloot_sync:IsEnabled()) then
    local eventData = qRec.data
    local header = qRec.header
    local eventId = header.eventId
    local eventType = header.type
    local eventTs = header.epochSeconds
    local creator = header.creator
    local eventVersion = header.eventVersion
    if(not bsloot_sync.syncOnlyCritical or bsloot_sync:isCriticalType(eventType)) then

      --bsloot:debugPrint("receiveInboundEvent("..bsloot:tableToString(eventData)..", "..sender..")", {logicOp="AND", values={bsloot.statics.LOGS.DEV, bsloot.statics.LOGS.SYNC}})

      if(not SyncEvents[eventId] or SyncEvents[eventId] == nil) then --skips events we already have
        bsloot:receiveEvent(eventType, eventData, eventId, eventVersion, eventTs, creator)
      end
    end
  end
end

function bsloot_sync:enqueue(type, eventData, requester)
   --TODO remove if testing shows no need to q outbout
  if(bsloot_sync:IsEnabled()) then
    if(type == "inbound") then
      local qRec = {}
      qRec.sender = requester
      qRec.eventData = eventData
      bsloot:qAdd(InboundSyncQueue, qRec)
      -- end
    elseif(type == "outbound") then
      
      local qRec = bsloot_sync:buildOutboundQrec(type, eventData, requester)
      
      -- if(not bsloot_sync.syncOnlyCritical or bsloot_sync:isCriticalType(qRec.eventType)) then
        local addedAt = nil
        addedAt = bsloot:qAdd(bsloot_sync.syncQueue, qRec)
        
      -- end
    end
  end
end
function bsloot_sync:buildOutboundQrec(type, eventIdStr, toPlayer)
  
  local qRec = {}
  qRec.type = type
  qRec.data = eventData
  qRec.requesters = {}
  if(toPlayer and toPlayer ~= nil) then
    table.insert(qRec.requesters, toPlayer)
  end
  local eventIdArray = bsloot:split(eventIdStr, ":")
  qRec.eventId = eventIdArray[1]
  qRec.eventType = eventIdArray[2]
  return qRec
end
function bsloot_sync:parseInboundMetadata(type, eventData, requester)
  local qRec = {}
  qRec.type = type
  qRec.data = eventData
  local dataArray = bsloot:split(eventData, "\n")
  local headerArray = bsloot:split(dataArray[1], "|")
  local startData = string.find(eventData, "\n")
  qRec.data = strsub(eventData, startData+1)
  local header = {}
  header.senderVersion = headerArray[1]
  header.eventId = headerArray[2]
  header.type = headerArray[3]
  header.epochSeconds = tonumber(headerArray[4])
  header.eventVersion = headerArray[5]
  header.creator = headerArray[6]
  qRec.header = header
  qRec.eventId = headerArray[2]
  qRec.eventType = headerArray[3]
  return qRec
end
function bsloot_sync:receiveIdResponse(eventIds, sender)
  local guildRaid, raid, group, guildGroup = bsloot:isInGuildRaid()
  if(guildRaid) then
    bsloot:debugPrint("Ignoring sync ID Offer to keep outbound comms cleared during guild raid", {logicOp="OR", values={bsloot.statics.LOGS.COMM, bsloot.statics.LOGS.SYNC}})
    return
  end
  local idArray = bsloot:split(eventIds, "|")
  for _, id in ipairs(idArray) do
    if(not SyncEvents[id] or SyncEvents[id] == nil) then
      bsloot:broadcastSync("syncGet "..id, sender)
    end
  end
end

function bsloot_sync:receiveEventDataRequest(eventId, sender)
  if(bsloot_sync:IsEnabled()) then
    --bsloot:debugPrint("processEventDataRequest("..bsloot:tableToString(eventId)..", "..sender..")", {logicOp="AND", values={bsloot.statics.LOGS.DEV, bsloot.statics.LOGS.SYNC}})
    local qRec = bsloot_sync:buildOutboundQrec("outbound", eventId)
    qRec.requesters = {}
    table.insert(qRec.requesters, sender)
    bsloot_sync:processEventDataRequest(qRec)
  end
end
function bsloot_sync:receiveDataSinceRequest(since, sender)
  since = tonumber(since)
  for eventId, event in pairs(SyncEvents) do
    if(event.epochSeconds > since) then
      local qRec = bsloot_sync:buildOutboundQrec("outbound", eventId)
      qRec.requesters = {}
      table.insert(qRec.requesters, sender)
      bsloot_sync:processEventDataRequest(qRec)
    end
  end
end

function bsloot_sync:processEventDataRequest(qRec, sendEvenInRaid)
  local guildRaid, raid, group, guildGroup = bsloot:isInGuildRaid()
  if(guildRaid and (not sendEvenInRaid or sendEvenInRaid == nil)) then
    bsloot:debugPrint("Ignoring sync request to keep outbound comms cleared during guild raid", {logicOp="OR", values={bsloot.statics.LOGS.COMM, bsloot.statics.LOGS.SYNC}})
    return
  end
  if(bsloot_sync:IsEnabled()) then
    local eventId = qRec.eventId
    local requesters = qRec.requesters
    local eventType = qRec.eventType
    if(not bsloot_sync.syncOnlyCritical or bsloot_sync:isCriticalType(eventType)) then
      local event = SyncEvents[eventId]
      if(event and event ~= nil) then
        local eventData = bsloot._versionString .. "|" .. eventId .. "|" .. event.type .. "|" .. event.epochSeconds .. "|" .. event.version .. "|" .. bsloot:getEventCreator(event) .. "\n" .. event.dataString
        if(qRec.requesters and qRec.requesters ~= nil and bsloot:tablelength(qRec.requesters) > 0) then
          for _, c in ipairs(qRec.requesters) do
            bsloot:broadcastSync("syncGive "..eventData, c)
          end
        else
          bsloot:broadcastSync("syncGive "..eventData)
        end
      else
        bsloot:warnPrint("Requested Event not found: "..eventId, bsloot.statics.LOGS.SYNC)
      end
    end
  end
end
-- Helper functions

function bsloot_sync:readInboundQueue()
  local readFromQueue = 0
  local qDepth = bsloot:getQDepth(InboundSyncQueue)
  while(qDepth > 0) do
    local qRec = bsloot:qPop(InboundSyncQueue)
    bsloot:debugPrint("Reading inbound sync queue (qdepth="..qDepth.."): " .. bsloot:tableToString(qRec), bsloot.statics.LOGS.SYNC)
    if(qRec and qRec ~= nil) then
      local sender = qRec.sender
      local eventData = qRec.eventData
      local inbound = bsloot_sync:parseInboundMetadata("inbound", eventData, sender)
      
      --TODO remove, or adjust to allow minor variance; if adjusting apply elsewhere
      if(bsloot_sync:checkVersion(inbound.header, sender)) then
        bsloot_sync:processInboundEvent(inbound)
      else
        bsloot:debugPrint("Rejecting inbound sync from "..sender .. " they are on version: "..inbound.header.senderVersion, bsloot.statics.LOGS.SYNC)
      end
      readFromQueue = readFromQueue + 1
    end
    qDepth = bsloot:getQDepth(InboundSyncQueue)
  end
  return readFromQueue
end

function bsloot_sync:syncAll()
  
  if(bsloot_sync:IsEnabled()) then
    bsloot_sync:offerSyncEvents()
    local profile = bsloot_sync:getDataProfile()
    bsloot_sync:getAllData(profile.mostRecent)
  end
end

function bsloot_sync:getAllData(since)
  local rankSorted = {}
  local numGuildMembers = GetNumGuildMembers(true)
  for i = 1, numGuildMembers do
    local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName, 
    achievementPoints, achievementRank, isMobile, isSoREligible, standingID = GetGuildRosterInfo(i)
    local member_name = Ambiguate(name,"short")
    if(level > bsloot.VARS.minlevel) then
      if(online and member_name ~= bsloot._playerName) then 
        if(not rankSorted[rankIndex] or rankSorted[rankIndex] == nil) then
          rankSorted[rankIndex] = {}
        end
        table.insert(rankSorted[rankIndex], member_name)
      end
    end
  end

  local orderedSources = {}
  for rankIndex = 1, bsloot.syncMinGuildRank do
    if(rankSorted[rankIndex] and rankSorted[rankIndex] ~= nil) then
      table.sort(rankSorted[rankIndex])
      for _, c in ipairs(rankSorted[rankIndex]) do
        table.insert(orderedSources, c)
      end
    end
  end

  bsloot_sync:checkWithNextSourceForNewData(orderedSources, 1)
  
end

function bsloot_sync:checkWithNextSourceForNewData(orderedSources, index, startedWaiting)
  local qDepth = bsloot:getQDepth(InboundSyncQueue)
  if(qDepth > 0) then
    bsloot:debugPrint("Waiting to check from sources because you still have inbound events not saved", bsloot.statics.LOGS.SYNC)
    C_Timer.After(3, function() 
      bsloot_sync:checkWithNextSourceForNewData(orderedSources, index, startedWaiting)
    end)
  end
  if(index <= #orderedSources) then
    local source = orderedSources[index]
    local requested = true
    if(not startedWaiting or startedWaiting == nil) then
      bsloot_sync.lastInboundEventSec = 0
      local myProfile = bsloot_sync:getDataProfile()
      bsloot_sync.awaitingResponse = true
      local startSeconds, _ = bsloot:getServerTime()
      local waitingSeconds = 0
      requested = bsloot_sync:requestAllData(myProfile.mostRecent, source)
    end
    
    C_Timer.After(3, function()
      if(not requested) then
        bsloot:debugPrint("Event Source "..source.. " logged off, moving to next", bsloot.statics.LOGS.SYNC)
      end
      if(not startedWaiting or startedWaiting == nil) then
        startedWaiting, _ = bsloot:getServerTime()
      end
      local currentSeconds, _ = bsloot:getServerTime()
      waitingSeconds = currentSeconds - startedWaiting -- TODO if you are getting responses wait 15 seconds after the last one to ask next person
      if(bsloot_sync.lastInboundEventSec > 0) then
        waitingSeconds = currentSeconds - bsloot_sync.lastInboundEventSec
      end      
      if(requested and startedWaiting and bsloot_sync.awaitingResponse and waitingSeconds < bsloot_sync.maxTimeAwaitingResponse) then
        --keep waiting
        bsloot_sync:checkWithNextSourceForNewData(orderedSources, index, startedWaiting)
      else
        --move on
        bsloot_sync:checkWithNextSourceForNewData(orderedSources, index+1)
      end
    end)
  end
end

bsloot_sync.maxTimeAwaitingResponse = 5 --seconds
function bsloot_sync:requestAllData(since, from)
  local requested = false
  if(bsloot_sync:IsEnabled()) then
    
    local guildRaid, raid, group, guildGroup = bsloot:isInGuildRaid()
    if(guildRaid) then
      bsloot:debugPrint("Skipping sync to keep outbound comms cleared during guild raid", {logicOp="OR", values={bsloot.statics.LOGS.COMM, bsloot.statics.LOGS.SYNC}})
      return
    end
    local msg = "syncGetAll"
    if(since and since ~= nil) then
      msg = "syncGetSince "..since
    end

    if(from and from ~= nil) then
      requested = bsloot:broadcastSync(msg, from)
    else
      requested = bsloot:broadcastSync(msg)
    end
  end
  return requested
end
function bsloot_sync:requestAllIds(from)
  local requested = false
  if(bsloot_sync:IsEnabled()) then
    local guildRaid, raid, group, guildGroup = bsloot:isInGuildRaid()
    if(guildRaid) then
      bsloot:debugPrint("Skipping sync to keep outbound comms cleared during guild raid", {logicOp="OR", values={bsloot.statics.LOGS.COMM, bsloot.statics.LOGS.SYNC}})
      return
    end
    local msg = "syncGetIds"

    if(from and from ~= nil) then
      requested = bsloot:broadcastSync(msg, from)
    else
      requested = bsloot:broadcastSync(msg)
    end
  end
  return requested
end

function bsloot_sync:receiveIdRequest(sender)
  
  if(not bsloot_sync:IsEnabled() or not bsloot:isSourceOfTrue("sync")) then
    return
  end
  local guildRaid, raid, group, guildGroup = bsloot:isInGuildRaid()
  if(guildRaid) then
    bsloot:debugPrint("Ignoring sync request to keep outbound comms cleared during guild raid", {logicOp="OR", values={bsloot.statics.LOGS.COMM, bsloot.statics.LOGS.SYNC}})
    return
  end
  local _, _, rankIndex = GetGuildInfo("player")
  if(rankIndex <= bsloot.syncMinGuildRank) then
    local eventNum = 0
    local batch = ""
    local batchDiv = "syncIds "
    for eventId, _ in pairs(SyncEvents) do
      batch = batch .. batchDiv .. eventId
      batchDiv = "|"
      if(eventNum >= bsloot_sync.offerBatchSize) then 
        bsloot:broadcastSync(batch, sender)
        eventNum = 0
        batchDiv = "syncIds "
        batch = ""
      end
    end
    if(batch ~= "") then
      bsloot:broadcastSync(batch, sender)
      eventNum = 0
      batchDiv = "syncIds "
      batch = ""
    end
  end
end
function bsloot_sync:checkVersion(header, sender)
  
  local versionMismatch = bsloot._versionString ~= header.senderVersion
  if(versionMismatch) then
    bsloot:warnWrongVersion(sender, header.senderVersion)
  end
  return not versionMismatch
end

bsloot_sync.warnTimeLimitMinutes = 30
bsloot_sync.warnedPlayers = {}
function bsloot:warnWrongVersion(sender, version)
  epochSeconds, currTimeStamp = bsloot:getServerTime()
  local warn = false
  if( not bsloot_sync.warnedPlayers[sender] or bsloot_sync.warnedPlayers[sender] == nil) then
    bsloot_sync.warnedPlayers[sender] = {}
    bsloot_sync.warnedPlayers[sender].timestamp = currTimeStamp
    bsloot_sync.warnedPlayers[sender].version = version
    warn = true
  elseif (bsloot_sync.warnedPlayers[sender].version ~= version) then
    bsloot_sync.warnedPlayers[sender].timestamp = currTimeStamp
    bsloot_sync.warnedPlayers[sender].version = version
    warn = true
  elseif (bsloot_sync.warnedPlayers[sender].timestamp and bsloot_sync.warnedPlayers[sender].timestamp ~= nil and (bsloot_sync.warnedPlayers[sender].timestamp.epochMS + (bsloot_sync.warnTimeLimitMinutes * 60 * 1000)) < currTimeStamp.epochMS) then
    bsloot_sync.warnedPlayers[sender].timestamp = currTimeStamp
    bsloot_sync.warnedPlayers[sender].version = version
    warn = true
  end
  if(warn) then
    bsloot:debugPrint("Sync received from " ..sender.. " on version ".. version .. " while you are on "..bsloot._versionString.." one of you should update!", {logicOp="OR", values={bsloot.statics.LOGS.DEFAULT, bsloot.statics.LOGS.SYNC}})
  end
end