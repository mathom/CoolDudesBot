function join_channel()
    local cool_dudes = piepan.channels("Cool Dudes Only")
    piepan.me:moveTo(cool_dudes)
end

function piepan.onConnect()
    join_channel()
end

function piepan.onMessage(msg)
    if msg.user == nil then
        return
    end
    local command, rest = msg.text:match('^!(%w+) ?(.*)$')
    if command == nil then
        return
    end

    local args = {}
    for word in rest:gmatch("[%w%p]+") do table.insert(args, word) end

    if commands['c_' .. command] then
        -- join_channel()
        commands['c_' .. command](msg.user, args)
    end
end

commands = {}

commands.h_help='Print this help message.'
function commands.c_help(user, args)
    local names = {}
    for name, _ in pairs(commands) do
        if name:sub(0,2) == 'c_' then
            local base = name:match('c_(.+)')
            local help = commands['h_' .. base]
            table.insert(names, '<b>!' .. base .. '</b> ' .. help)
        end
    end

    table.sort(names)
    user:send('Available commands:<br/>' .. table.concat(names, '<br/>'))
end

commands.h_stop='Stop playing sound.'
function commands.c_stop(user, args)
    piepan.Audio:stop()
end

commands.h_echo='Repeat what you just said.'
function commands.c_echo(user, args)
    user:send(table.concat(args, ' '))
end

commands.h_play='Play a supported soundfile. See !playlist.'
function commands.c_play(user, args)
    local volume = 1.0

    if args[2] ~= nil then
        volume = tonumber(args[2])
    end

    local filename = 'sounds/' .. args[1] .. '.ogg'
    play_soundfile(filename, volume, user)
end

function play_soundfile(file, volume, user)
    if piepan.Audio:isPlaying() then
        piepan.Audio:stop()
    end

    local success = piepan.me.channel:play({filename=file, volume=volume})

    if not success then
        user:send("I couldn't play that sound, sorry.")
    end
end

commands.h_say='Speak your message aloud.'
function commands.c_say(user, args)
    local cargs = ''
    local mode = 'espeak'
    local pitch_flag = ' -p '
    local speed_flag = ' -s '

    if args[1] == 'c64' then
        mode = 'sam'
        pitch_flag = ' -pitch '
        speed_flag = ' -speed '
        table.remove(args, 1)
    end

    local sargs = args[1]
    local pitch = sargs:match('p(%d+)')
    if pitch ~= nil then
        cargs = cargs .. pitch_flag .. pitch
    end
    local speed = sargs:match('s(%d+)')
    if speed ~= nil then
        cargs = cargs .. speed_flag .. speed
    end
    local variant = sargs:match('v\'(.+)\'')
    if variant ~= nil then
        cargs = cargs .. ' -v ' .. variant
    end
    local throat = sargs:match('t(%d+)')
    if variant ~= nil then
        cargs = cargs .. ' -throat ' .. throat
    end
    local mouth = sargs:match('m(%d+)')
    if variant ~= nil then
        cargs = cargs .. ' -mouth ' .. mouth
    end

    if cargs ~= '' then
        table.remove(args, 1)
    end

    local input = '/tmp/say.wav'
    os.remove(input)
    local message = table.concat(args, ' '):gsub('[^a-zA-Z0-9,\'-!. ]','\\%1')
    print('User ' .. user.name .. ' is saying ' .. message)
    if mode == 'espeak' then
        command = 'espeak ' .. cargs .. ' -w ' .. input .. ' "' .. message .. '"'
    elseif mode == 'sam' then
        command = 'sam ' .. cargs .. ' -wav ' .. input .. ' "' .. message .. '"'
    end
    rval, rtype = os.execute(command)

    if rtype ~= 'exit' or not rval then
        user:send('Error speaking!')
        return
    end

    local out = '/tmp/say.ogg'
    os.remove(out)
    command = 'avconv -i ' .. input .. ' -ac 1 -ar 48000 -codec:a libvorbis ' .. out
    rval, rtype = os.execute(command)

    if rtype ~= 'exit' or not rval then
        user:send('Error converting audio!')
        return
    end

    play_soundfile(out, 1.0, user)
end

commands.h_8ball='Ask the magic 8 Ball a question. Add "speak" to read aloud.'
function commands.c_8ball(user, args)
   local responses = {"As I see it, yes","It is certain","It is decidedly so","Most likely","Outlook good","Signs point to yes","Without a doubt","Yes","Yes definitely","You may rely on it","Reply hazy, try again","Ask again later","Better not tell you now","Cannot predict now","Concentrate and ask again","Don't count on it","My reply is no","My sources say no","Outlook not so good","Very doubtful"}
   local answer = responses[math.random(#responses)]

   if args[1] == 'speak' then
       commands.c_say(user, {answer})
   end
   user.channel:send(answer)
end

commands.h_fortune='Read your fortune for the day. Add "speak" to read aloud.'
function commands.c_fortune(user, args)
    local fortune = io.popen('fortune')
    local answer = fortune:read('*all')

   if args[1] == 'speak' then
       commands.c_say(user, {answer})
   end
   user.channel:send(answer)
end

commands.h_playlist='List files available to !play.'
function commands.c_playlist(user, args)
    local ls = io.popen('ls -sh1 sounds')

    local files = {}
    local file = ls:read()
    while file ~= nil do
        local size, name = file:match('([^.]+) ([^.]+)')
        table.insert(files, '<b>' .. name .. '</b> - ' .. size)
        file = ls:read()
    end

    user:send('Sound files:<br/>' .. table.concat(files, '<br/>'))
end

commands.h_ytplay='Download and play the audio from Youtube (supply video ID only).'
function commands.c_ytplay(user, args)
    local volume = 1.0

    if args[2] ~= nil then
        volume = tonumber(args[2])
    end

    local output = download_youtube(args[1], user)

    if output == nil then
        return
    end

    play_soundfile(output, volume, user)
end

function download_youtube(hash, user)
    print('User ' .. user.name .. ' is downloading ' .. hash)
    local yt = '/tmp/ytdl'
    os.remove(yt .. '.m4a')
    local command = 'youtube-dl --socket-timeout 15 -x https://www.youtube.com/watch?v=' .. hash .. ' -o "' .. yt .. '.%(ext)s"'
    local rval, rtype = os.execute(command)

    if rtype ~= 'exit' or not rval then
        user:send('Error downloading!')
        return
    end

    yt = yt .. '.m4a'

    local out = '/tmp/ytconv.ogg'
    os.remove(out)
    command = 'avconv -i ' .. yt .. ' -ac 1 -ar 48000 -codec:a libvorbis ' .. out
    rval, rtype = os.execute(command)

    if rtype ~= 'exit' or not rval then
        user:send('Error converting audio!')
        return
    end

    return out
end

commands.h_ytsave='Download and save a Youtube (video ID) with a name.'
function commands.c_ytsave(user, args)
    local output = download_youtube(args[1], user)

    if output == nil then
        return
    end

    local name = args[2]:match('(%w+)')

    os.rename(output, 'sounds/' .. name .. '.ogg')
    user:send('Saved new sound to ' .. name)
end
