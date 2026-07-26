local Players=game:GetService("Players")
local LocalPlayer=Players.LocalPlayer
local TextChatService=game:GetService("TextChatService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")

local cloneCounts={}
local MAX_CLONES=2
local bannedUsers={}
local whitelistedUsers={}
local trustedUsers={}
local coOwners={}
local mods={}
local silentMode=false
local silentDebounce=false
local freeCmdsDisabled=false
local debugMode=false
local VOTE_DURATION=10
local VOTES_NEEDED=1
local activeVote=nil
local BAN_FILE="ArkenBans.txt"
local WHITELIST_FILE="ArkenWhitelist.txt"
local COOWNER_FILE="ArkenCoOwners.txt"
local MOD_FILE="ArkenMods.txt"
local TRUST_FILE="ArkenTrust.txt"

local shutdownPending = false
local shutdownCancelled = false

-- 🔥 12 blocks per second
local GRIEFER_BLOCK_LIMIT = 12
local GRIEFER_BLOCK_WINDOW = 1
local GRIEFER_DELETE_LIMIT = 12
local GRIEFER_DELETE_WINDOW = 1

local blockPlacements = {}
local blockDeletions = {}
local flaggedGriefers = {}

-- ================== SAVE/LOAD FUNCTIONS ==================
local function saveBans()
    local t={}
    for id,_ in pairs(bannedUsers)do table.insert(t,tostring(id))end
    writefile(BAN_FILE,table.concat(t,"\n"))
end
local function loadBans()
    local ok,data=pcall(readfile,BAN_FILE)
    if ok and data and #data>0 then
        for idStr in data:gmatch("[^\r\n]+")do
            local id=tonumber(idStr)
            if id then bannedUsers[id]=true end
        end
        local count=0
        for _ in pairs(bannedUsers)do count=count+1 end
        print("[BANS] Loaded "..count.." bans from file.")
    else print("[BANS] No existing bans found.") end
end
loadBans()

local function saveWhitelist()
    local t={}
    for id,_ in pairs(whitelistedUsers)do table.insert(t,tostring(id))end
    writefile(WHITELIST_FILE,table.concat(t,"\n"))
end
local function loadWhitelist()
    local ok,data=pcall(readfile,WHITELIST_FILE)
    if ok and data and #data>0 then
        for idStr in data:gmatch("[^\r\n]+")do
            local id=tonumber(idStr)
            if id then whitelistedUsers[id]=true end
        end
        local count=0
        for _ in pairs(whitelistedUsers)do count=count+1 end
        print("[WHITELIST] Loaded "..count.." whitelisted players.")
    else print("[WHITELIST] No whitelist found.") end
end
loadWhitelist()

local function saveTrusted()
    local t={}
    for id,_ in pairs(trustedUsers)do table.insert(t,tostring(id))end
    writefile(TRUST_FILE,table.concat(t,"\n"))
end
local function loadTrusted()
    local ok,data=pcall(readfile,TRUST_FILE)
    if ok and data and #data>0 then
        for idStr in data:gmatch("[^\r\n]+")do
            local id=tonumber(idStr)
            if id then trustedUsers[id]=true end
        end
        local count=0
        for _ in pairs(trustedUsers)do count=count+1 end
        print("[TRUST] Loaded "..count.." trusted players.")
    else print("[TRUST] No trusted players found.") end
end
loadTrusted()

local function saveCoOwners()
    local t={}
    for id,_ in pairs(coOwners)do table.insert(t,tostring(id))end
    writefile(COOWNER_FILE,table.concat(t,"\n"))
end
local function loadCoOwners()
    local ok,data=pcall(readfile,COOWNER_FILE)
    if ok and data and #data>0 then
        for idStr in data:gmatch("[^\r\n]+")do
            local id=tonumber(idStr)
            if id then coOwners[id]=true end
        end
        local count=0
        for _ in pairs(coOwners)do count=count+1 end
        print("[CO-OWNER] Loaded "..count.." co-owners.")
    else print("[CO-OWNER] No co-owners found.") end
end
loadCoOwners()

local function saveMods()
    local t={}
    for id,_ in pairs(mods)do table.insert(t,tostring(id))end
    writefile(MOD_FILE,table.concat(t,"\n"))
end
local function loadMods()
    local ok,data=pcall(readfile,MOD_FILE)
    if ok and data and #data>0 then
        for idStr in data:gmatch("[^\r\n]+")do
            local id=tonumber(idStr)
            if id then mods[id]=true end
        end
        local count=0
        for _ in pairs(mods)do count=count+1 end
        print("[MOD] Loaded "..count.." mods.")
    else print("[MOD] No mods found.") end
end
loadMods()

-- Chat sender
local function sendChatMessage(msg,useSilent)
    local prefix=(silentMode and useSilent) and ";" or ""
    local finalMsg=prefix..msg
    if TextChatService.ChatVersion==Enum.ChatVersion.TextChatService then
        local ch=TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if ch then ch:SendAsync(finalMsg) return end
    end
    local sayEvent=ReplicatedStorage:FindFirstChild("SayMessageRequest",true)
    if sayEvent and sayEvent:IsA("RemoteEvent")then sayEvent:FireServer(finalMsg,"All") return end
    for _,rem in ipairs(ReplicatedStorage:GetDescendants())do
        if rem:IsA("RemoteEvent")and string.find(string.lower(rem.Name),"chat")then
            pcall(function()rem:FireServer(finalMsg,"All")end) return
        end
    end
end

-- 🔥 Send startup message in chat
sendChatMessage("Loading TCO bot | Credits to Echo", false)

local function sendCommandSequence(cmds, delaySec)
    for i,msg in ipairs(cmds)do
        sendChatMessage(msg,false)
        if i<#cmds then wait(delaySec) end
    end
end

-- Username cleaning: underscore → dot
local function getCleanUsername(name)
    return string.gsub(name,"_",".")
end

-- Arkenstone helpers
local function isHoldingArkenstone()
    local char=LocalPlayer.Character
    return char and char:FindFirstChild("The Arkenstone")~=nil
end
local function forceEquipArkenstone()
    local char=LocalPlayer.Character
    if not char then return false end
    if char:FindFirstChild("The Arkenstone")then return true end
    for _,obj in ipairs(char:GetChildren())do
        if obj:IsA("Tool")then obj.Parent=LocalPlayer.Backpack end
    end
    local bp=LocalPlayer:FindFirstChild("Backpack")
    if bp then
        local ark=bp:FindFirstChild("The Arkenstone")
        if ark then ark.Parent=char; return true end
    end
    return false
end

-- Player search
local function findPlayerByFragment(frag)
    local lower=string.lower(frag)
    for _,p in ipairs(Players:GetPlayers())do
        if string.find(string.lower(p.DisplayName),lower)or string.find(string.lower(getCleanUsername(p.Name)),lower)then
            return p
        end
    end
    return nil
end

-- ============ RANK SYSTEM ============
local function getRankLevel(player)
    if player.Name=="Noob1Noob667" then return 3 end
    if coOwners[player.UserId] then return 2 end
    if mods[player.UserId] then return 1 end
    return 0
end

local function canTarget(sender, target)
    return getRankLevel(sender) > getRankLevel(target)
end

-- Full punish (0.7s delay)
local function executePunish(sender, target)
    if not canTarget(sender, target) then return end
    local clean=getCleanUsername(target.Name)
    sendCommandSequence({";goto Noob1Noob667",";bring "..clean,";freeze "..clean,";jail "..clean,";myopic "..clean,";clearinv "..clean,";noclip "..clean}, 0.7)
    sendChatMessage("⚡ Punished "..target.DisplayName.."!",false)
end

-- Ban punish (0.7s delay)
local function executePunishBan(sender, target)
    if not canTarget(sender, target) then return end
    local clean=getCleanUsername(target.Name)
    sendCommandSequence({";freeze "..clean,";jail "..clean,";myopic "..clean,";clearinv "..clean,";noclip "..clean}, 0.7)
end

-- Auto‑join punish (freeze only)
local function executeAutoPunish(target)
    local clean=getCleanUsername(target.Name)
    sendChatMessage(";freeze "..clean,false)
end

-- Ban list display
local function showBanList(serverOnly)
    local total=0
    for _ in pairs(bannedUsers)do total=total+1 end
    if serverOnly then
        local names={}
        for id,_ in pairs(bannedUsers)do
            local p=Players:GetPlayerByUserId(id)
            if p then table.insert(names,p.DisplayName) end
        end
        if #names==0 then sendChatMessage("No banned players in server.",false)
        else sendChatMessage("📜 Banlist: "..table.concat(names,", "),false) end
    else
        if total==0 then sendChatMessage("No bans found.",false)
        else sendChatMessage("📜 Banned players: "..total,false) end
    end
end

-- Grief vote
local function startGriefVote(sender, target)
    if not canTarget(sender, target) then return end
    if activeVote then return end
    activeVote={target=target,yes={},no={},startTime=os.time()}
    sendChatMessage("🗳️ Vote: Did "..target.DisplayName.." grief? Say yes or no! ("..VOTE_DURATION.."s)",false)
    wait(VOTE_DURATION)
    if not activeVote then return end
    local yes,no=0,0
    for _ in pairs(activeVote.yes)do yes=yes+1 end
    for _ in pairs(activeVote.no)do no=no+1 end
    if yes>=VOTES_NEEDED and yes>no then
        sendChatMessage("✅ Vote passed. Punishing "..activeVote.target.DisplayName.."!",false)
        executePunish(sender, activeVote.target)
    else
        sendChatMessage("❌ Vote failed. ("..yes.." yes / "..no.." no)",false)
    end
    activeVote=nil
end

local function handleVote(voter,voteType)
    if not activeVote then return end
    if activeVote.yes[voter.UserId]or activeVote.no[voter.UserId]then return end
    if voteType=="yes"then activeVote.yes[voter.UserId]=true
    else activeVote.no[voter.UserId]=true end
end

-- ============ SHUTDOWN (OWNER ONLY, WITH CANCEL) ============
local function shutdown(minutes)
    if shutdownPending then
        shutdownCancelled = true
    end
    local delaySeconds = minutes and tonumber(minutes) and tonumber(minutes)*60 or 0
    local function doShutdown()
        local clean = getCleanUsername(LocalPlayer.Name)
        sendChatMessage(";tospawn", false)
        wait(5)
        sendChatMessage("clone " .. clean, false)
        wait(1)
        LocalPlayer:Kick("Shutdown by bot")
    end
    if delaySeconds > 0 then
        shutdownPending = true
        shutdownCancelled = false
        sendChatMessage("⏳ Shutting down in "..minutes.." minutes...", false)
        spawn(function()
            wait(delaySeconds)
            if not shutdownCancelled then
                shutdownPending = false
                doShutdown()
            else
                shutdownPending = false
            end
        end)
    else
        doShutdown()
    end
end

-- ============ GRIEFER DETECTION (12 blocks/s, expanded tool list + fallback) ============
local function cleanTimestamps(timestamps, window)
    local now = os.time()
    local cleaned = {}
    for _, t in ipairs(timestamps) do
        if now - t <= window then
            table.insert(cleaned, t)
        end
    end
    return cleaned
end

local function checkLimit(userId, trackingTable, limit, window)
    if not trackingTable[userId] then
        trackingTable[userId] = {times={}}
    end
    local now = os.time()
    local times = trackingTable[userId].times
    table.insert(times, now)
    trackingTable[userId].times = cleanTimestamps(times, window)
    return #trackingTable[userId].times >= limit
end

local function announceGriefer(player, reason)
    if getRankLevel(player) >= 3 then return end
    if whitelistedUsers[player.UserId] then return end
    if trustedUsers[player.UserId] then return end
    if flaggedGriefers[player.UserId] then return end
    
    flaggedGriefers[player.UserId] = true
    sendChatMessage("⚠️ Griefer detected: "..player.DisplayName.." ("..reason..")", false)
    
    delay(30, function()
        flaggedGriefers[player.UserId] = nil
    end)
end

local function findActiveBuilder(nearPosition)
    local keywords = {
        "build", "tool", "paint", "hammer", "delete", "remove", "erase",
        "destroy", "clear", "del", "nuke", "trash", "explode", "bomb",
        "wand", "staff", "gun", "edit"
    }
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char then
                for _, obj in ipairs(char:GetChildren()) do
                    if obj:IsA("Tool") then
                        local name = string.lower(obj.Name)
                        for _, kw in ipairs(keywords) do
                            if string.find(name, kw) then
                                return player
                            end
                        end
                    end
                end
            end
        end
    end
    if nearPosition then
        local closestPlayer = nil
        local closestDist = math.huge
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local char = player.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    local dist = (char.HumanoidRootPart.Position - nearPosition).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closestPlayer = player
                    end
                end
            end
        end
        return closestPlayer
    end
    return nil
end

Workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("BasePart") then
        local creator = nil
        pcall(function()
            local cid = obj:GetAttribute("Creator") or obj:GetAttribute("Owner") or obj:GetAttribute("Placer") or obj:GetAttribute("UserId")
            if cid then creator = Players:GetPlayerByUserId(tonumber(cid)) end
        end)
        if not creator then
            creator = findActiveBuilder(obj.Position)
        end
        if creator then
            if checkLimit(creator.UserId, blockPlacements, GRIEFER_BLOCK_LIMIT, GRIEFER_BLOCK_WINDOW) then
                announceGriefer(creator, "block spam")
            end
        end
    end
end)

Workspace.DescendantRemoving:Connect(function(obj)
    if obj:IsA("BasePart") then
        local deleter = findActiveBuilder(obj.Position)
        if deleter then
            if checkLimit(deleter.UserId, blockDeletions, GRIEFER_DELETE_LIMIT, GRIEFER_DELETE_WINDOW) then
                announceGriefer(deleter, "block deletion")
            end
        end
    end
end)

-- ============ AUTO-PUNISH BANNED ============
local function autoPunishBanned(player)
    if bannedUsers[player.UserId] then
        wait(1)
        executeAutoPunish(player)
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        autoPunishBanned(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        autoPunishBanned(player)
        if whitelistedUsers[player.UserId] then
            wait(1)
            sendChatMessage("enlighten "..getCleanUsername(player.Name), true)
        end
    end
end)

-- ============ STATS (2 messages, 0.8s delay) ============
local function sendStats()
    local banCount = 0
    for _ in pairs(bannedUsers) do banCount = banCount + 1 end
    local whitelistCount = 0
    for _ in pairs(whitelistedUsers) do whitelistCount = whitelistCount + 1 end
    local trustedCount = 0
    for _ in pairs(trustedUsers) do trustedCount = trustedCount + 1 end
    local coOwnerCount = 0
    for _ in pairs(coOwners) do coOwnerCount = coOwnerCount + 1 end
    local modCount = 0
    for _ in pairs(mods) do modCount = modCount + 1 end

    local msg1 = "Bans " .. banCount .. " Whitelist " .. whitelistCount .. " Trusted " .. trustedCount .. " Co-owners " .. coOwnerCount .. " Mods " .. modCount
    local msg2 = "Silent " .. (silentMode and "on" or "off") .. " Free cmds " .. (freeCmdsDisabled and "off" or "on") .. " Debug " .. (debugMode and "on" or "off") .. " Griefer " .. GRIEFER_BLOCK_LIMIT .. "blocks/" .. GRIEFER_BLOCK_WINDOW .. "s"

    sendChatMessage(msg1, false)
    wait(0.8)
    sendChatMessage(msg2, false)
end

-- ============ MAIN CHAT HANDLER ============
local function onChat(sender,msg)
    if sender==LocalPlayer then return end
    local lower=msg:lower()
    local senderLevel = getRankLevel(sender)

    if debugMode then
        print("[CHAT] "..sender.Name..": "..msg)
    end

    if lower=="yes"then handleVote(sender,"yes") return
    elseif lower=="no"then handleVote(sender,"no") return end

    if whitelistedUsers[sender.UserId] and lower=="enlighten" then
        sendChatMessage("enlighten "..getCleanUsername(sender.Name), true)
        return
    end

    -- ========== ADMIN COMMANDS (MOD AND ABOVE) ==========
    if senderLevel >= 1 then
        if lower=="enlighten" then
            sendChatMessage("enlighten "..getCleanUsername(sender.Name), true)
            return
        end

        if msg:find("^!silent$") and not silentDebounce then
            silentDebounce = true
            silentMode = not silentMode
            sendChatMessage(silentMode and "🔇 Silent mode ON" or "🔊 Silent mode OFF",false)
            wait(0.5)
            silentDebounce = false
            return
        end

        if msg:find("^!stats$") then
            sendStats()
            return
        end

        if msg:find("^!banlist%s+server$")then showBanList(true) return end
        if msg:find("^!banlist$")then showBanList(false) return end

        local sayMsg = msg:match("^!say%s+(.+)")
        if sayMsg then
            sendChatMessage(sayMsg, false)
            return
        end

        if msg:find("^!force%s+yes$")then
            if activeVote then
                local target = activeVote.target
                if canTarget(sender, target) then
                    sendChatMessage("👑 "..sender.DisplayName.." forced YES. Punishing "..target.DisplayName.."!",false)
                    executePunish(sender, target)
                end
                activeVote=nil
            end
            return
        elseif msg:find("^!force%s+no$")then
            if activeVote then
                sendChatMessage("👑 "..sender.DisplayName.." forced NO. Vote cancelled.",false)
                activeVote=nil
            end
            return
        end
    end

    -- ========== CO-OWNER AND ABOVE ==========
    if senderLevel >= 2 then
        if msg:find("^!restartserver$") then
            sendCommandSequence({";delcubes a", ";maptide", ";delclones a"}, 1.0)
            return
        end

        local banTarget=msg:match("^!ban%s+(.+)")
        if banTarget then
            local target=findPlayerByFragment(banTarget)
            if target and canTarget(sender, target) then
                bannedUsers[target.UserId]=true
                saveBans()
                sendChatMessage("🔨 banned "..target.DisplayName,false)
                executePunishBan(sender, target)
            end
            return
        end
        local unbanTarget=msg:match("^!unban%s+(.+)")
        if unbanTarget then
            local target=findPlayerByFragment(unbanTarget)
            if target then
                bannedUsers[target.UserId]=nil
                saveBans()
                sendChatMessage("✅ unbanned "..target.DisplayName,false)
            end
            return
        end
    end

    -- ========== OWNER-ONLY COMMANDS ==========
    if senderLevel == 3 then
        if msg:find("^!shutdown stop$") then
            if shutdownPending then
                shutdownCancelled = true
                shutdownPending = false
                sendChatMessage("🛑 Shutdown cancelled.", false)
            else
                sendChatMessage("❌ No shutdown in progress.", false)
            end
            return
        end

        local shutArgs=msg:match("^!shutdown%s+(.+)")
        if msg:find("^!shutdown$")then shutdown(nil) return
        elseif shutArgs then
            local n=tonumber(shutArgs)
            if n then shutdown(n)
            else sendChatMessage("❌ Invalid format. Use !shutdown or !shutdown 10 (minutes)",false) end
            return
        end

        if msg:find("^!disablefree$") then
            freeCmdsDisabled = not freeCmdsDisabled
            sendChatMessage(freeCmdsDisabled and "🔒 Free item commands DISABLED" or "🔓 Free item commands ENABLED", fals
