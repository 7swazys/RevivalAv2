run(function()
    local SoundChanger
    local List
    local soundlist = {}
    local old, target, key

    SoundChanger = vape.Categories.Legit:CreateModule({
        Name = 'SoundChanger',
        Function = function(callback)
            if callback then
                if type(bedwars.AudioManager) == 'table' and type(bedwars.AudioManager.playAudio) == 'function' then
                    target, key = bedwars.AudioManager, 'playAudio'
                elseif type(bedwars.SoundManager) == 'table' and type(bedwars.SoundManager.playSound) == 'function' then
                    target, key = bedwars.SoundManager, 'playSound'
                else
                    notif('SoundChanger', 'The game sound player was not found', 5, 'warning')
                    return
                end
                local original = target[key]
                old = original
                local wrapper
                wrapper = function(self, id, ...)
                    if SoundChanger.Enabled and soundlist[id] then
                        id = soundlist[id]
                    end
                    return original(self, id, ...)
                end
                target[key] = wrapper
                SoundChanger:Clean(function()
                    if target and target[key] == wrapper then
                        target[key] = original
                    end
                    old, target, key = nil, nil, nil
                end)
            end
        end,
        Tooltip = 'Changes in-game sounds to custom ones'
    })
    List = SoundChanger:CreateTextList({
        Name = 'Sounds',
        Placeholder = '(DAMAGE_1/ben.mp3)',
        Function = function()
            table.clear(soundlist)
            for _, entry in List.ListEnabled do
                local split = entry:split('/')
                local id = bedwars.SoundList[split[1]]
                if id and #split > 1 then
                    soundlist[id] = split[2]:find('rbxasset') and split[2] or isfile(split[2]) and assetfunction(split[2]) or ''
                end
            end
        end
    })
end)
