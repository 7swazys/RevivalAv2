run(function()
    local AutoToxic
    local GG, GGDelay
    local TrollTriggers
    local trollCooldown = 0
    local dead = false
    local Toggles, Actions, Lists, Emotes, Delays, said = {}, {}, {}, {}, {}, {}

    local function doSend(text, delay)
        if not text or text == '' then return end
        local wait = delay and delay.Value or 0
        local function push()
            if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
                textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(text)
            else
                replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(text, 'All')
            end
        end
        if wait > 0 then
            task.delay(wait, function() pcall(push) end)
        else
            pcall(push)
        end
    end

    local emoteTypes, emoteTrack = {}, nil
    local function emoteList()
        local list = {}
        for emoteType, v in bedwars.EmoteMeta do
            if emoteType ~= bedwars.EmoteType.NONE and v.name and not emoteTypes[v.name] then
                emoteTypes[v.name] = emoteType
                table.insert(list, v.name)
            end
        end
        table.sort(list)
        table.insert(list, 1, 'None')
        return list
    end
    local function playEmote(name)
        local emoteType = emoteTypes[name]
        local meta = emoteType and bedwars.EmoteMeta[emoteType]
        if not (meta and entitylib.isAlive) then return end
        local animation = meta.animation
        if not animation and meta.emoteDisplayType then
            local display = bedwars.EmoteDisplayMeta[meta.emoteDisplayType]
            animation = display and display.animation
        end
        if not animation then return end
        if emoteTrack then
            pcall(emoteTrack.Stop, emoteTrack)
        end
        local character, hum = lplr.Character, entitylib.character.Humanoid
        character:SetAttribute('PlayingEmote', emoteType)
        local track = hum:LoadAnimation(bedwars.GameAnimationUtil:getAnimation(animation.type))
        emoteTrack = track
        track:Play(nil, nil, animation.speed or 1)
        local function stop()
            if emoteTrack ~= track then return end
            emoteTrack = nil
            pcall(track.Stop, track)
            if character.Parent and character:GetAttribute('PlayingEmote') == emoteType then
                character:SetAttribute('PlayingEmote', nil)
            end
        end
        hum:GetPropertyChangedSignal('MoveDirection'):Once(stop)
        task.delay(6, stop)
    end

    local function emote(name)
        local choice = Emotes[name] and Emotes[name].Value
        if not choice or choice == 'None' then return end
        task.delay(Delays[name].Value, function()
            local deadline = tick() + 10
            while not entitylib.isAlive and tick() < deadline do
                task.wait(0.25)
            end
            pcall(playEmote, choice)
        end)
    end

    local function message(name, obj, default)
        local tab = Lists[name].ListEnabled
        local custommsg = #tab > 0 and tab[math.random(1, #tab)] or default
        if not custommsg then return end
        for _ = 1, #tab > 1 and 8 or 0 do
            if custommsg ~= said[name] then break end
            custommsg = tab[math.random(1, #tab)]
        end
        said[name] = custommsg
        doSend((custommsg:gsub('<obj>', obj or '')), Delays[name])
    end

    local function trigger(name, obj, default)
        if not Toggles[name].Enabled then return end
        local action = Actions[name].Value
        if action ~= 'Emote' then
            message(name, obj, default)
        end
        if action ~= 'Message' then
            emote(name)
        end
    end

    AutoToxic = vape.Categories.Utility:CreateModule({
        Name = 'AutoToxic',
        Function = function(callback)
            if callback then
                dead = false
                AutoToxic:Clean(entitylib.Events.LocalAdded:Connect(function()
                    dead = false
                end))

                AutoToxic:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
                    local breaker = bedTable.player
                    if bedTable.brokenBedTeam.id == lplr:GetAttribute('Team') then
                        trigger('BedDestroyed', breaker and (breaker.DisplayName or breaker.Name) or '', 'how dare you >:( | <obj>')
                    elseif breaker and breaker.UserId == lplr.UserId then
                        local team = bedwars.QueueMeta[store.queueType].teams[tonumber(bedTable.brokenBedTeam.id)]
                        trigger('BedBreak', team and team.displayName:lower() or 'white', 'nice bed lul | <obj>')
                    end
                end))
                AutoToxic:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
                    local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
                    local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
                    if not killed or not killer then return end
                    if killed == lplr then
                        if not dead and killer ~= lplr then
                            dead = true
                            trigger('Death', killer.DisplayName or killer.Name, 'my gaming chair subscription expired :( | <obj>')
                        end
                    elseif killer == lplr then
                        local name = killed.DisplayName or killed.Name
                        if deathTable.finalKill and Toggles.FinalKill.Enabled then
                            trigger('FinalKill', name, 'sit down | <obj>')
                        else
                            trigger('Kill', name, 'vxp on top | <obj>')
                        end
                    end
                end))
                AutoToxic:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winstuff)
                    if GG.Enabled then
                        doSend('gg', GGDelay)
                    end
                    local myTeam = bedwars.Store:getState().Game.myTeam
                    if myTeam and myTeam.id == winstuff.winningTeamId or lplr.Neutral then
                        trigger('Win', nil, 'yall garbage')
                    end
                end))

                local function handleIncoming(speakerName, text, speakerUserId)
                    if not Toggles.Troll.Enabled or not text or text == '' then return end
                    if speakerUserId and speakerUserId == lplr.UserId then return end
                    if speakerName and speakerName == lplr.Name then return end
                    if tick() < trollCooldown then return end
                    local lower = text:lower()
                    for _, phrase in TrollTriggers.ListEnabled do
                        if phrase ~= '' and lower:find(phrase:lower(), 1, true) then
                            trollCooldown = tick() + 6
                            task.spawn(trigger, 'Troll', speakerName, 'mad cause bad | <obj>')
                            break
                        end
                    end
                end

                if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
                    AutoToxic:Clean(textChatService.MessageReceived:Connect(function(msg)
                        local src = msg.TextSource
                        handleIncoming(src and src.Name, msg.Text, src and src.UserId)
                    end))
                else
                    pcall(function()
                        AutoToxic:Clean(replicatedStorage.DefaultChatSystemChatEvents.OnMessageDoneFiltering.OnClientEvent:Connect(function(data)
                            if type(data) == 'table' then
                                handleIncoming(data.FromSpeaker, data.Message, nil)
                            end
                        end))
                    end)
                end
            end
        end,
        Tooltip = 'Sends a message or plays an emote after a certain action'
    })

    local function refresh(key)
        local toggle, action = Toggles[key], Actions[key]
        local on = toggle and toggle.Enabled
        local value = action and action.Value or 'Message'
        if action then action.Object.Visible = on end
        if Lists[key] then Lists[key].Object.Visible = on and value ~= 'Emote' end
        if Emotes[key] then Emotes[key].Object.Visible = on and value ~= 'Message' end
        if Delays[key] then Delays[key].Object.Visible = on end
        if key == 'Troll' and TrollTriggers then TrollTriggers.Object.Visible = on end
    end

    local function event(key, label, tooltip, extra)
        Toggles[key] = AutoToxic:CreateToggle({
            Name = label..' ',
            Tooltip = tooltip,
            Function = function()
                refresh(key)
            end
        })
        if extra then extra() end
        Actions[key] = AutoToxic:CreateDropdown({
            Name = label..' Action',
            List = {'Message', 'Emote', 'Both'},
            Default = 'Message',
            Darker = true,
            Visible = false,
            Tooltip = 'Message - sends a random line from the list\nEmote - plays the chosen emote\nBoth - does both',
            Function = function()
                refresh(key)
            end
        })
        Emotes[key] = AutoToxic:CreateDropdown({
            Name = label..' Emote',
            List = emoteList(),
            Default = 'None',
            Darker = true,
            Visible = false,
            Tooltip = 'Emote to play when this happens'
        })
        Lists[key] = AutoToxic:CreateTextList({
            Name = key == 'Troll' and 'Troll Replies' or label,
            Tooltip = key == 'Troll' and 'Replies to send, <obj> is the accuser\'s name' or 'One of these is picked at random, <obj> is the other player or team',
            Default = key == 'Troll' and {'mad cause bad | <obj>', 'skill issue <obj>', 'cry about it <obj>', 'not my fault youre bad', 'imagine losing to a "hacker" lol'} or nil,
            Darker = true,
            Visible = false
        })
        Delays[key] = AutoToxic:CreateSlider({
            Name = label..' Delay',
            Min = key == 'Troll' and 0.5 or 0,
            Max = 10,
            Default = key == 'Troll' and 1.5 or 0,
            Decimal = 10,
            Suffix = 's',
            Darker = true,
            Visible = false,
            Tooltip = 'How long to wait before acting, 0 for instant'
        })
        refresh(key)
    end

    GG = AutoToxic:CreateToggle({
        Name = 'AutoGG',
        Default = true,
        Tooltip = 'Says gg when the match ends, won or lost',
        Function = function(callback)
            if GGDelay then GGDelay.Object.Visible = callback end
        end
    })
    GGDelay = AutoToxic:CreateSlider({
        Name = 'AutoGG Delay',
        Min = 0,
        Max = 10,
        Default = 0,
        Decimal = 10,
        Suffix = 's',
        Darker = true,
        Tooltip = 'How long to wait before saying gg, 0 for instant'
    })
    GGDelay.Object.Visible = GG.Enabled
    event('Kill', 'Kill', 'When you kill someone')
    event('FinalKill', 'Final Kill', 'When you kill someone whose bed is gone')
    event('BedBreak', 'Bed Break', 'When you break a bed')
    event('BedDestroyed', 'Bed Destroyed', 'When your own bed is destroyed')
    event('Win', 'Win', 'When your team wins the match')
    event('Death', 'Death', 'When someone kills you')
    event('Troll', 'Troll', 'Replies when someone calls you a hacker or cheater in chat', function()
        TrollTriggers = AutoToxic:CreateTextList({
            Name = 'Troll Triggers',
            Tooltip = 'Phrases that trigger a reply, matched anywhere in their message',
            Default = {'hacker', 'hacks', 'hacking', 'hax', 'cheater', 'cheating', 'cheat', 'exploiter', 'exploiting', 'aimbot'},
            Darker = true,
            Visible = false
        })
    end)
end)
