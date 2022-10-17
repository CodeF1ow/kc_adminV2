local users_cache = {}
local jobs = {}
local MySQL_Ready = false

ESX = exports['es_extended']:getSharedObject()

function loadJobs ()
    if string.lower(Config.CheckJobType) == "sql" then
        local jobs_name_sql = MySQL.query.await("SELECT * FROM jobs")
        local jobs_grades_sql = MySQL.query.await("SELECT * FROM job_grades")

        for job in pairs(jobs_name_sql) do
            local grades = {}
            
            local job_name = jobs_name_sql[job]["name"]

            for grade in pairs(jobs_grades_sql) do
                local grade_job_name = jobs_grades_sql[grade]["job_name"]
                local grade_job = jobs_grades_sql[grade]["grade"]

                if grade_job_name == job_name then
                    table.insert(grades, grade_job)
                end
            end

            table.insert(jobs, {["job"] = job_name, ["grades"] = grades})
        end
    end
end

ESX.RegisterServerCallback('kc_adminV2:soyadmin', function(playerId, cb)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if xPlayer.getGroup() == 'admin' then
        cb(true)
    else
        cb(false)
    end
end)

function getTime ()
    return os.time(os.date("!*t"))
end

function array2string(array)
    string = ""
    for a in pairs(array) do
        string = string .. " " .. tostring(array[a])
    end

    return string
end

function dateFromTimestamp (timestamp)
    return os.date("%Y-%m-%d %H:%M:%S", timestamp)
end

function ArrayLength (table)
    local count = 0
    for _ in pairs(table) do
        count = count + 1
    end
    return count

end

function inArray (target, table)
    for a,b in ipairs(table) do
        if target == b then
            return true
        end
    end

    return false

end

function getIdentifier (id)
    local identifier

    for k,v in ipairs(GetPlayerIdentifiers(id)) do
        if string.match(v, 'license:') then
            identifier = v
            break
        end
    end

    return identifier
end

function getIpAddress(id)
    return GetPlayerEndpoint(id)
end

function getName(id)
    local name = GetPlayerName(id)
    return name
end

function getGroup (id) 
    if id == Groups.Server then
        return id
    end

    local xPlayer_steamid = getIdentifier(id)
    local group = nil

    for a, b in pairs(users_cache) do
        if a == player_steamid then
            group = b
            break
        end
    end 

    if group ~= nil then
        return group
    end

    local mysql_query = MySQL.query.await("SELECT * FROM users WHERE identifier=@identifier", {["@identifier"] = player_steamid})
    local user_query = mysql_query[1]

    if user_query == nil then
        return "user"
    else 
        group = user_query["group"]
    end

    if group == nil then
        return "user"
    end

    users_cache[player_steamid] = group

    return group
end

function isBan (identifier)
    
    local isban_mysql = MySQL.query.await("SELECT * FROM kc_bans WHERE identifier = @identifier", {["@identifier"] = identifier})

    if not MySQL_Ready then
        return {true, Lang.MySQL}
    end

    if ArrayLength(isban_mysql) == 0 then
        return {false}
    end

    for ban in pairs(isban_mysql) do
        local mysql_reason = isban_mysql[ban]["reason"]
        local mysql_admin_name = isban_mysql[ban]["admin_name"]
        local mysql_time = isban_mysql[ban]["time"]

        if mysql_time == "permanent" then
            local reason = string.format(Lang.PermaBan, mysql_reason, mysql_admin_name)
            return {true, reason}
        else
            mysql_time = tonumber(mysql_time)
            if getTime() < mysql_time then
                local date_time = dateFromTimestamp(mysql_time)
                local reason = string.format(Lang.BannedFor, mysql_reason, date_time, mysql_admin_name)
                return {true, reason}
            end
        end

    end
    return {false}
end

function lowerGroup (local_group, target_group)
    local local_group_level = Groups.Levels[local_group]
    local target_group_level = Groups.Levels[target_group]

    if local_group_level == target_group_level then
        return false
    end

    if local_group_level <= target_group_level then
        return true
    end

    return false

end

function checkJob (job, grade)
    if string.lower(Config.CheckJobType) == "sql" then
        for i in pairs(jobs) do
            if jobs[i]["job"] == job then
                if inArray(tonumber(grade), jobs[i]["grades"]) then
                    return true
                end
            end
        end
        return false
    elseif string.lower(Config.CheckJobType) == "esx" then
        return ESX.DoesJobExist(job, grade)
    end

    return true

end

function getJob (id)
    local identifier = getIdentifier(id)

    local job_sql = MySQL.query.await("SELECT job, job_grade FROM users WHERE identifier = @identifier", {["@identifier"] = identifier})

    if ArrayLength(job_sql) <= 0 then
        return nil
    end

    return job_sql[1]

end

function defaultJob (id)
    local identifier = getIdentifier(id)

    print("^1" .. Lang.FixJob .. identifier .. "^0.")

    MySQL.execute_async("UPDATE users SET job = @job, job_grade = @grade WHERE identifier = @identifier", {["@job"] = Config.DefaultJob[1], ["@grade"] = Config.DefaultJob[2], ["@identifier"] = identifier}, function (rows)
        if rows ~= 1 then
            print("^1No se pudo cambiar el trabajo de " .. identifier .. "^0.")
        end
    end)

end

-- Server functions --

-- ESX thread --

Citizen.CreateThread(function ()
    while true do
        if ESX == nil then
            ESX = exports['es_extended']:getSharedObject()
        end
        Citizen.Wait(1000)
    end
end)

-- ESX thread --

-- Server Events --

RegisterServerEvent("kc_adminV2:global_message")
AddEventHandler("kc_adminV2:global_message", function (security_code, message)
    TriggerClientEvent("kc_adminV2:send_message", -1, message)
end)

RegisterServerEvent("kc_adminV2:remote_group")
AddEventHandler("kc_adminV2:remote_group", function (id, callback)
    local group = getGroup(id)
    callback(group)
end)

AddEventHandler("playerConnecting", function (user, setKickReason, deferrals)
    local Source = source

    deferrals.defer()

    deferrals.update("Revisando baneos...")

    local identifier = getIdentifier(Source)
    local bans = isBan(identifier)

    if bans[1] then
        deferrals.done(bans[2])
        CancelEvent()
        return
    end

    local job = getJob(Source)

    if job ~= nil then

        local job_name = job["job"]
        local grade = job["job_grade"]

        if string.lower(Config.CheckJobType) == "sql" then
    
            if not checkJob(job_name, grade) then
                defaultJob(Source)
            end
    
        elseif string.lower(Config.CheckJobType) == "esx" then
            if ESX.DoesJobExist(job_name, grade) then
                defaultJob(Source)
            end
        end

    end

    deferrals.done()

end)

RegisterServerEvent("kc_adminV2:get_bans")
AddEventHandler("kc_adminV2:get_bans", function (days, name)
    local Source = source
    local xPlayer = ESX.GetPlayerFromId(Source)

    if not xPlayer.getGroup() == 'admin' then
        TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.InsufficientPrivileges, "danger")
        TriggerClientEvent("kc_adminV2:send_message", Source, "^1" .. Lang.InsufficientPrivileges)
        CancelEvent()
        return
    end

    local filter = {false, false}

    name = string.lower(name)

    if days ~= '' then
        days = days * 24 * 60 * 60
        filter[1] = true
    end

    if name ~= '' then
        filter[2] = true
    end

    local bans = MySQL.query.await("SELECT * FROM kc_bans", {})

    local filtered_bans = {}

    for ban in pairs(bans) do
        local ban_obj = bans[ban]

        local user = ban_obj["name"]
        local admin_name = ban_obj["admin_name"]
        local reason = ban_obj["reason"]
        local time = ban_obj["time"]
        local date = ban_obj["date"]

        if filter[1] then
            if math.floor(getTime() - days) < tonumber(date) then
                table.insert(filtered_bans, ban_obj)
            end
        end

        if filter[2] then
            local low_name = string.lower(user)

            if string.find(low_name, name) ~= nil then
                table.insert(filtered_bans, ban_obj)
            end
        end

        if filter[1] == false and filter[2] == false then
            table.insert(filtered_bans, ban_obj)
        end

    end

    filtered_bans = json.encode(filtered_bans)

    TriggerClientEvent("kc_adminV2:recv_bans", Source, filtered_bans)
end)

RegisterServerEvent("kc_adminV2:set_job")
AddEventHandler("kc_adminV2:set_job", function (target_id, job_name, job_grade)
    local Source = source
    local xPlayer = ESX.GetPlayerFromId(Source)

    if not Player.getGroup() == 'admin' then
        TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.InsufficientPrivileges, "danger")
        TriggerClientEvent("kc_adminV2:send_message", Source, "^1" .. Lang.InsufficientPrivileges)
        CancelEvent()
        return
    end

    if ESX ~= nil then
        local xPlayer = ESX.GetPlayerFromId(target_id)

        if xPlayer ~= nil then
            
            if Config.CheckJobExist then
                if ESX.DoesJobExist(job_name, job_grade) then
                    xPlayer.setJob(job_name, job_grade)
                    TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Success, Lang.Job .. job_name, "success")
                else
                    TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.JobFail, "danger")
                end
            else
                xPlayer.setJob(job_name, job_grade)
                TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Success, Lang.Job .. job_name, "success")
            end
        else
            TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.ESX, "danger")
        end
    else
        TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.ESX, "danger")
    end
end)

RegisterServerEvent("kc_adminV2:set_money")
AddEventHandler("kc_adminV2:set_money", function (target_id, money_amount, money_type)
    local Source = source
    local xPlayer = ESX.GetPlayerFromId(Source)

    if not xPlayer.getGroup() == 'admin' then
        TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.InsufficientPrivileges, "danger")
        TriggerClientEvent("kc_adminV2:send_message", Source, "^1" .. Lang.InsufficientPrivileges)
        CancelEvent()
        return
    end

    if ESX ~= nil then
        local xPlayer = ESX.GetPlayerFromId(target_id)
        if xPlayer ~= nil then
            if money_type == "money" then
                xPlayer.setMoney(money_amount)
                TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Success, Lang.Money .. money_type, "success")
            else
                xPlayer.setAccountMoney(money_type, money_amount)
                TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Success, Lang.Money .. money_type, "success")
            end
        else
            TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.ESX, "danger")
        end
    else
        TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.ESX, "danger")
    end
end)

RegisterServerEvent("kc_adminV2:check_jail")
AddEventHandler("kc_adminV2:check_jail", function()
    local Source = source

    Citizen.Wait(2000)

    local identifier = getIdentifier(Source)

    local mysql_jails = MySQL.query.await("SELECT * FROM kc_jails WHERE identifier = @identifier", {["@identifier"] = identifier})

    if ArrayLength(mysql_jails) ~= 0 then
        local time = mysql_jails[1]["time_s"]
        local id = mysql_jails[1]["id"]
        local result = MySQL.execute_async("UPDATE users SET time = @time WHERE id = @id", {["@time"] = getTime() + time, ["@id"] = id})
        time = tonumber(time)
        TriggerClientEvent("kc_adminV2:jail_player", Source, time)
    end
end)

RegisterServerEvent("kc_adminV2:unjail")
AddEventHandler("kc_adminV2:unjail", function (target_id, force)
    local Source = source
    local xPlayer = ESX.GetPlayerFromId(Source)

    local identifier = getIdentifier(target_id)

    if force then
        if xPlayer.getGroup() == 'admin' then
            MySQL.execute_async("DELETE FROM kc_jails WHERE identifier = @identifier", {["@identifier"] = identifier}, function (rows)
                if rows == 1 then
                    TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Success, Lang.UnJail, "success")
                    TriggerClientEvent("kc_adminV2:unjail_player", target_id)
                else
                    TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.UnJailError, "danger")
                end
            end)
            CancelEvent()
            return
        end
    end

    local jail_time_sql = MySQL.query.await("SELECT time FROM kc_jails WHERE identifier = @identifier", {["@identifier"] = identifier})


    if jail_time_sql[1] == nil then
        CancelEvent()
        return
    end 

    local jail_time = jail_time_sql[1]["time"]

    jail_time = tonumber(jail_time)

    if getTime() >= jail_time then
        local unjail_sql = MySQL.execute_async("DELETE FROM kc_jails WHERE identifier = @identifier", {["@identifier"] = identifier})
        TriggerClientEvent("kc_adminV2:unjail_player", target_id)
    end
end)

RegisterServerEvent("kc_adminV2:jail")
AddEventHandler("kc_adminV2:jail", function (target_id, time)
    local Source = source
    local xPlayer = ESX.GetPlayerFromId(Source)

    if not xPlayer.getGroup() == 'admin' then
        TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.InsufficientPrivileges, "danger")
        TriggerClientEvent("kc_adminV2:send_message", Source, "^1" .. Lang.InsufficientPrivileges)
        CancelEvent()
        return
    end

    local user_name = getName(target_id)
    local identifier = getIdentifier(target_id)

    local admin_name = getName(Source)
    local admin_identifier = getIdentifier(Source)

    local time_m = tostring(time)
    local time = time * 60
    local timestamp = getTime() + time

    MySQL.execute_async("INSERT INTO kc_jails (identifier, name, admin_name, admin_identifier, time, time_s) VALUES (@identifier, @name, @admin_name, @admin_identifier, @timestamp, @time)", {["@identifier"] = identifier, ["@name"] = user_name, ["@admin_name"] = admin_name, ["@admin_identifier"] = admin_identifier, ["@timestamp"] = timestamp, ["@time"] = time}, function(rows)
        if rows == 1 then
            TriggerClientEvent("kc_adminV2:jail_player", target_id, time)
            TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Success, Lang.Jail, "success")
            TriggerEvent("kc_adminV2:global_message", Config.SecurityCode, string.format(Lang.Global.PlayerJailed, user_name, time_m))
        else
            TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.JailError, "danger")
        end
    end)

end)

RegisterServerEvent("kc_adminV2:freeze")
AddEventHandler("kc_adminV2:freeze", function (target_id)
    local Source = source
    local xPlayer = ESX.GetPlayerFromId(Source)

    if not xPlayer.getGroup() == 'admin' then
        TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.InsufficientPrivileges, "danger")
        TriggerClientEvent("kc_adminV2:send_message", Source, "^1" .. Lang.InsufficientPrivileges)
        CancelEvent()
        return
    end

    TriggerClientEvent("kc_adminV2:freeze_player", target_id)
    TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Success, Lang.Freeze, "success")
end)

RegisterServerEvent("kc_adminV2:revive")
AddEventHandler("kc_adminV2:revive", function (target_id)
    local Source = source
    local xPlayer = ESX.GetPlayerFromId(Source)

    if not xPlayer.getGroup() == 'admin' then
        TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.InsufficientPrivileges, "danger")
        TriggerClientEvent("kc_adminV2:send_message", Source, "^1" .. Lang.InsufficientPrivileges)
        CancelEvent()
        return
    end

    TriggerClientEvent("kc_adminV2:revive_player", target_id)
    TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Success, Lang.ReviveN, "success")
end)

RegisterServerEvent("kc_adminV2:slay")
AddEventHandler("kc_adminV2:slay", function (target_id)
    local Source = source
    local xPlayer = ESX.GetPlayerFromId(Source)
    
    if not xPlayer.getGroup() == 'admin' then
        TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.InsufficientPrivileges, "danger")
        TriggerClientEvent("kc_adminV2:send_message", Source, "^1" .. Lang.InsufficientPrivileges)
        CancelEvent()
        return
    end

    TriggerClientEvent("kc_adminV2:slay_player", target_id)
    TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Success, Lang.Slay, "success")
end)

RegisterServerEvent("kc_adminV2:visibility")
AddEventHandler("kc_adminV2:visibility", function (target_id)
    local Source = source
    local xPlayer = ESX.GetPlayerFromId(Source)

    if not xPlayer.getGroup() == 'admin' then
        TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.InsufficientPrivileges, "danger")
        TriggerClientEvent("kc_adminV2:send_message", Source, "^1" .. Lang.InsufficientPrivileges)
        CancelEvent()
        return
    end

    TriggerClientEvent("kc_adminV2:visibility_player", target_id)
    TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Success, Lang.Visibility, "success")
end)

RegisterServerEvent("kc_adminV2:noclip")
AddEventHandler("kc_adminV2:noclip", function (target_id)
    local Source = source
    local xPlayer = ESX.GetPlayerFromId(Source)

    if not xPlayer.getGroup() == 'admin' then
        TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.InsufficientPrivileges, "danger")
        TriggerClientEvent("kc_adminV2:send_message", Source, "^1" .. Lang.InsufficientPrivileges)
        CancelEvent()
        return
    end

    TriggerClientEvent("kc_adminV2:noclip_player", target_id)
    TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Success, Lang.Noclip, "success")
end)

RegisterServerEvent("kc_adminV2:set_group")
AddEventHandler("kc_adminV2:set_group", function (mod_source, target_id, group)
    local Source = source
    local xPlayer = ESX.GetPlayerFromId(Source)

    if Source ~= "" then
        mod_source = Source
    end

    local local_group = getGroup(mod_source)
    local xPlayer_steamid = getIdentifier(target_id)

    if not Player.getGroup() == 'admin' then
        TriggerClientEvent("kc_adminV2:send_notify", mod_source, Lang.Error, Lang.InsufficientPrivileges, "danger")
        TriggerClientEvent("kc_adminV2:send_message", mod_source, "^1" .. Lang.InsufficientPrivileges)
        CancelEvent()
        return
    end

    local xPlayer = ESX.GetPlayerFromId(target_id)

    xPlayer.setGroup(group)
    Player.showNotification("Has dado el grupo de "..group.." a "..GetPlayerName(target_id))
    xPlayer.showNotification(GetPlayerName(Source).." te ha dado el grupo de "..group)
end)

RegisterServerEvent("kc_adminV2:return")
AddEventHandler("kc_adminV2:return", function (target_id)
    local Source = source
    local xPlayer = ESX.GetPlayerFromId(Source)

    local admin_name = getName(Source)

    if not xPlayer.getGroup() == 'admin' then
        TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.InsufficientPrivileges, "danger")
        TriggerClientEvent("kc_adminV2:send_message", Source, "^1" .. Lang.InsufficientPrivileges)
        CancelEvent()
        return
    end

    TriggerClientEvent("kc_adminV2:return_player", target_id)
    TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Success, Lang.Return, "success")
    TriggerClientEvent("kc_adminV2:send_message", target_id, "^2" .. admin_name .. "^0" .. Lang.ReturnPlayer)
end)

RegisterServerEvent("kc_adminV2:goto")
AddEventHandler("kc_adminV2:goto", function (target_id, target_coords)
    local Source = source
    local xPlayer = ESX.GetPlayerFromId(Source)

    local admin_name = getName(Source)
    local user_name = getName(target_id)

    if not xPlayer.getGroup() == 'admin' then
        TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.InsufficientPrivileges, "danger")
        TriggerClientEvent("kc_adminV2:send_message", Source, "^1" .. Lang.InsufficientPrivileges)
        CancelEvent()
        return
    end

    TriggerClientEvent("kc_adminV2:send_message", target_id, "^2" .. admin_name .. "^0" .. Lang.Goto)
    TriggerClientEvent("kc_adminV2:teleport_player", Source, target_coords)
    TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Success, Lang.GotoN .. user_name, "success")
end)

RegisterServerEvent("kc_adminV2:bring")
AddEventHandler("kc_adminV2:bring", function(admin_coords, target_id)
    local Source = source
    local xPlayer = ESX.GetPlayerFromId(Source)

    local admin_name = getName(Source)

    if not xPlayer.getGroup() == 'admin' then
        TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.InsufficientPrivileges, "danger")
        TriggerClientEvent("kc_adminV2:send_message", Source, "^1" .. Lang.InsufficientPrivileges)
        CancelEvent()
        return
    end

    TriggerClientEvent("kc_adminV2:teleport_player", target_id, admin_coords)
    TriggerClientEvent("kc_adminV2:send_message", target_id, Lang.Bringed .. "^2" .. admin_name)
end)

RegisterServerEvent("kc_adminV2:delete_ban")
AddEventHandler("kc_adminV2:delete_ban", function (ban_id)
    local Source = source
    local xPlayer = ESX.GetPlayerFromId(Source)

    --[[if not xPlayer.getGroup() == 'admin' then
        TriggerClientEvent("kc_adminV2:send_notify", mod_source, Lang.Error, Lang.InsufficientPrivileges, "danger")
        TriggerClientEvent("kc_adminV2:send_message", mod_source, "^1" .. Lang.InsufficientPrivileges)
        CancelEvent()
        return
    end--]]

    MySQL.execute_async("DELETE FROM kc_bans WHERE id=@id", {["@id"] = ban_id}, function (rows)
        if rows == 1 then
            TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Success, Lang.UnBan, "success")
        else
            TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.UnBanError, "danger")
        end
    end)
end)

RegisterServerEvent("kc_adminV2:kick")
AddEventHandler("kc_adminV2:kick", function (mod_source, target_id, reason)
    local Source = source
    local xPlayer = ESX.GetPlayerFromId(Source)
    local target_name = getName(target_id)

    --[[if not xPlayer.getGroup() == 'admin' then
        xPlayer.showNotification("~r~No tienes permisos suficientes~s~")
        CancelEvent()
        return
    end--]]

    DropPlayer(target_id, reason)
    xPlayer.showNotification("~g~Se ha expulsado correctamente del servidor a ~s~"..target_name)
end)

RegisterServerEvent("kc_adminV2:ban")
AddEventHandler("kc_adminV2:ban", function (mod_source, target_id, reason, time)
    local Source = source
    local xPlayer = ESX.GetPlayerFromId(Source)

    if Source ~= "" then
        mod_source = Source
    end

    --[[if not xPlayer.getGroup() == 'admin' then
        TriggerClientEvent("kc_adminV2:send_notify", mod_source, Lang.Error, Lang.InsufficientPrivileges, "danger")
        TriggerClientEvent("kc_adminV2:send_message", mod_source, "^1" .. Lang.InsufficientPrivileges)
        CancelEvent()
        return
    end--]]

    local user_name = getName(target_id)
    local user_identifier = getIdentifier(target_id)
    local user_ip = getIpAddress(target_id)
    local date = getTime()

    local admin_name
    local admin_identifier

    if mod_source == Groups.Server then
        admin_name = "Server"
        admin_identifier = "Server"
    else
        admin_name = getName(mod_source)
        admin_identifier = getIdentifier(mod_source)
    end

    local reason_

    if time == "permanent" then
        reason_ = string.format(Lang.PermaBan, reason, admin_name)
    else
        time = getTime() + time
        reason_ = string.format(Lang.BannedFor, reason, dateFromTimestamp(time), admin_name)
    end

    MySQL.execute_async("INSERT INTO kc_bans (identifier, reason, name, ip, admin_name, admin_identifier, time, date) VALUES(@identifier, @reason, @name, @ip, @admin_name, @admin_identifier, @time, @date)", {["@identifier"] = user_identifier, ["@reason"] = reason, ["@name"] = user_name, ["@ip"] = user_ip, ["@admin_name"] = admin_name, ["@admin_identifier"] = admin_identifier, ["@time"] = time, ["@date"] = date}, function(rows)
        if rows == 1 then
            if mod_source ~= Groups.Server then
                TriggerClientEvent("kc_adminV2:send_notify", mod_source, Lang.Success, Lang.BannedSuccessfully, "success")
            end
            TriggerClientEvent("kc_adminV2:send_message", target_id, "^1" .. Lang.Banned .. ".")
            Citizen.Wait(1000)
            TriggerEvent("kc_adminV2:kick", Groups.Server, target_id, Lang.Banned)

            TriggerEvent("kc_adminV2:global_message", -1, string.format(Lang.Global.PlayerBanned, user_name, reason))
        else
            if mod_source ~= Groups.Server then
                TriggerClientEvent("kc_adminV2:send_notify", mod_source, Lang.Error, Lang.BanError, "danger")
            end
        end
    end)
end)

RegisterServerEvent("kc_adminV2:reload_groups")
AddEventHandler("kc_adminV2:reload_groups", function ()
    users_cache = {}
    TriggerClientEvent("kc_adminV2:order_group", -1)
end)

RegisterServerEvent("kc_adminV2:request_group")
AddEventHandler("kc_adminV2:request_group", function ()
    local Source = source

    local group = getGroup(Source)
    local xPlayer = getIdentifier(Source)


    TriggerClientEvent("kc_adminV2:get_group", Source, group)
end)

RegisterServerEvent("kc_adminV2:delete_warn")
AddEventHandler("kc_adminV2:delete_warn", function (warn_id)
    local Source = source
    local xPlayer = ESX.GetPlayerFromId(Source)

    if not xPlayer.getGroup() == 'admin' then
        TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.InsufficientPrivileges, "danger")
        TriggerClientEvent("kc_adminV2:send_message", Source, "^1" .. Lang.InsufficientPrivileges)
    end

    MySQL.execute_async("DELETE FROM kc_warns WHERE id = @warn_id", {["warn_id"] = warn_id}, function(rows)
        if rows == 1 then
            TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Success, Lang.WarnDeleted .. getName(Source), "success")
        else
            TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.WarnDeletedError, "danger")
        end
    end)

end)

RegisterServerEvent("kc_adminV2:warn")
AddEventHandler("kc_adminV2:warn", function (user_id, reason, date, table_id)
    local Source = source
    local xPlayer = ESX.GetPlayerFromId(Source)

    if not xPlayer.getGroup() == 'admin' then
        TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.InsufficientPrivileges, "danger")
        TriggerClientEvent("kc_adminV2:send_message", Source, "^1" .. Lang.InsufficientPrivileges)
        CancelEvent()
        return
    end

    local user_name = getName(user_id)
    local user_identifier = getIdentifier(user_id)

    local admin_name = getName(Source)
    local admin_identifier = getIdentifier(Source)

    MySQL.execute_async("INSERT INTO kc_warns (name, identifier, admin_name, admin_identifier, reason, timestamp) VALUES (@user_name, @user_identifier, @admin_name, @admin_identifier, @reason, @timestamp)", {["@user_name"] = user_name, ["@user_identifier"] = user_identifier, ["@admin_name"] = admin_name, ["@admin_identifier"] = admin_identifier, ["@reason"] = reason, ["@timestamp"] = date}, function(rows)
        if rows == 1 then
            TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Success, Lang.Warn .. user_name, "success")
            TriggerClientEvent("kc_adminV2:send_message", user_id, "^2" .. admin_name .. Lang.Warned .. "^0" .. reason .. ".")

            MySQL.query.await("SELECT id FROM kc_warns WHERE admin_identifier=@admin_identifier AND identifier=@identifier AND timestamp=@timestamp AND reason=@reason", {["@admin_identifier"] = admin_identifier, ["@identifier"] = user_identifier, ["@timestamp"] = date, ["@reason"] = reason}, function (result)
                if ArrayLength(result) ~= 0 then
                    TriggerClientEvent("kc_adminV2:fix_table", Source, table_id, result[1]["id"])
                end
                MySQL.query.await("SELECT id FROM kc_warns WHERE identifier=@identifier", {["@identifier"] = user_identifier}, function(result)

                    warn_count = ArrayLength(result)

                    if warn_count >= Config.WarnPerma then
                        TriggerEvent("kc_adminV2:perma_ban", Groups.Server, user_id, Lang.WarnAccumulation .. warn_count)
                        return
                    end

                    if warn_count == Config.WarnWeek then
                        TriggerEvent("kc_adminV2:ban", Groups.Server, user_id, Lang.WarnAccumulation .. warn_count ,1468800)
                        return
                    end

                    if warn_count == Config.WarnDays then
                        TriggerEvent("kc_adminV2:ban", Groups.Server, user_id, Lang.WarnAccumulation  .. warn_count, 259200)
                        return
                    end

                end)
            end)

        else
            TriggerClientEvent("kc_adminV2:send_notify", Source, Lang.Error, Lang.WarnError, "danger")
            TriggerClientEvent("kc_adminV2:remove_table", Source, table_id)
            CancelEvent()
            return
        end
    end)
end)

RegisterServerEvent("kc_adminV2:get_warns")
AddEventHandler("kc_adminV2:get_warns", function (id) 
    local Source = source
    local xPlayer = ESX.GetPlayerFromId(Source)

    if not xPlayer.getGroup() == 'admin' then
        TriggerClientEvent("kc_adminV2:send_message", Source, "^1" .. Lang.InsufficientPrivileges)
        CancelEvent()
        return
    end

    local identifier = getIdentifier(id)
    local result = MySQL.query.await("SELECT id, reason, admin_name, timestamp FROM kc_warns WHERE identifier=@identifier", {["@identifier"] = identifier})
    
    result_json = json.encode(result)

    TriggerClientEvent("kc_adminV2:recv_warn", Source, id, result_json)

end)

RegisterServerEvent("kc_adminV2:message_to_group")
AddEventHandler("kc_adminV2:message_to_group", function (message, group)
    local xPlayers = GetPlayers()
    
    for i in pairs(players) do
        local r_group = getGroup(players[i])

        if not lowerGroup(r_group, group) then
            TriggerClientEvent("kc_adminV2:send_raw_message", players[i], message)
        end
    end
end)

-- Server Events --

MySQL.ready(function()
    MySQL_Ready = true
    loadJobs()
end)
