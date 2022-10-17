local group = "user"
local loaded = false
local dead = false
local last_pos
local noclip = false
local visibility = true
local heading = 0
local noclip_pos
local info
local freeze = false
local jailed = false
local jail_time
local actual_jail
local jail_warn = 0
ESX = nil

local Keys = {
    ["ESC"] = 642, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57,
    ["~"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["-"] = 84, ["="] = 83, ["BACKSPACE"] = 177,
    ["TAB"] = 37, ["Q"] = 44, ["W"] = 64, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["["] = 39, ["]"] = 40, ["ENTER"] = 18,
    ["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182,
    ["LEFTSHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81,
    ["LEFTCTRL"] = 36, ["LEFTALT"] = 19, ["SPACE"] = 22, ["RIGHTCTRL"] = 70,
    ["HOME"] = 213, ["PAGEUP"] = 10, ["PAGEDOWN"] = 11, ["DELETE"] = 178,
    ["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173,
    ["NENTER"] = 201, ["N4"] = 108, ["N5"] = 60, ["N6"] = 107, ["N+"] = 96, ["N-"] = 97, ["N7"] = 117, ["N8"] = 61, ["N9"] = 118
}

Citizen.CreateThread(function()
    while ESX == nil do
        ESX = exports['es_extended']:getSharedObject()
        Citizen.Wait(0)
    end

    while ESX.GetPlayerData().job == nil do
        Citizen.Wait(100)
    end
end)

-- Client functions --

function inArray (target, table)

    for a,b in ipairs(table) do
        if target == b then
            return true
        end
    end

    return false

end

function ArrayLength (table)
    local count = 0
    for _ in pairs(table) do
        count = count + 1
    end
    return count
end

function SendMessage(msg)
    TriggerEvent("chatMessage", "^0[^5KC Admin^0]", {0, 0, 0}, " ^0" .. msg)
end

function getPlayers ()
    local pre_players = {}

	for i = 0,255 do
        if NetworkIsPlayerActive(i) then
            table.insert(pre_players, GetPlayerServerId(i))
		end
    end

    table.sort(pre_players)

    local players = {}

    for i=1, #pre_players, 1 do
        table.insert(players, {
            id = pre_players[i],
            name = GetPlayerName(GetPlayerFromServerId(pre_players[i]))
        })
    end

    return players
end

function OpenMenu ()
    menu_open = true
    SendNUIMessage({type = "open", players = getPlayers()})
    SetNuiFocus(true, true)
end

function CloseMenu ()
    menu_open = false
    SendNUIMessage({type = "close"})
    SetNuiFocus(false)
end

function RespawnPed (ped, coords, heading)
	SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false, true)
	NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
    SetPlayerInvincible(ped, false)
    SetEntityVisible(ped, true)
    TriggerServerEvent('esx:onPlayerSpawn')
    TriggerEvent('esx:onPlayerSpawn')
	TriggerEvent('playerSpawned', coords.x, coords.y, coords.z)
	ClearPedBloodDamage(ped)
end

function randomArray (array)
    local array_length = ArrayLength(array)
    random_int = math.random(array_length)
    return array[random_int]
end

function fixVector(coords_vector3)
    local x = coords_vector3.x
    local y = coords_vector3.y
    local z = coords_vector3.z

    x = math.floor(x)
    y = math.floor(y)
    z = math.floor(z)

    local fixed_coords = vector3(x, y, z)

    return fixed_coords

end

function drawTimeText(time, red, green, blue, alpha)
	SetTextFont(4)
	SetTextProportional(0)
	SetTextScale(0.0, 0.5)
	SetTextColour(red, green, blue, alpha)
	SetTextDropShadow(0, 0, 0, 0, 255)
	SetTextEdge(1, 0, 0, 0, 255)
	SetTextDropShadow()
	SetTextOutline()
	SetTextCentre(true)

    BeginTextCommandDisplayText("STRING")

    local text = string.format(Lang.JailedTime, tostring(time))

	AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.5, 0.5)
end

-- Client functions --

-- Main thread --

Citizen.CreateThread(function ()
    while true do

        Citizen.Wait(0)

        if IsControlJustPressed(1, Keys["HOME"]) then
            ESX.TriggerServerCallback('kc_adminV2:soyadmin', function(soyadmin)
                if soyadmin then
                    OpenMenu()
                end
            end)
        end
    end
end)

-- Main thread --

-- Group thread --

Citizen.CreateThread(function ()
    while true do

        TriggerServerEvent("kc_adminV2:request_group")

        Citizen.Wait(600000)

    end
end)

-- Group thread --

-- Noclip thread --

Citizen.CreateThread(function ()
    while true do
        Citizen.Wait(0)
        if noclip then
            SetEntityCoordsNoOffset(PlayerPedId(), noclip_pos.x, noclip_pos.y, noclip_pos.z, 0, 0, 0)

			if IsControlPressed(1, 34) then
				heading = heading + 1.5
				if(heading > 360)then
					heading = 0
				end

				SetEntityHeading(PlayerPedId(), heading)
			end

			if IsControlPressed(1, 9) then
				heading = heading - 1.5
				if(heading < 0)then
					heading = 360
				end

				SetEntityHeading(PlayerPedId(), heading)
			end

			if IsControlPressed(1, 8) then
				noclip_pos = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 1.0, 0.0)
			end

			if IsControlPressed(1, 32) then
				noclip_pos = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, -1.0, 0.0)
			end

			if IsControlPressed(1, 27) then
				noclip_pos = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 0.0, 1.0)
			end

			if IsControlPressed(1, 173) then
                noclip_pos = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 0.0, -1.0)
            end
		end
    end
end)

-- Noclip thread --

-- Jail threads --

Citizen.CreateThread(function ()
    while true do
        if jailed then
            local local_ped = PlayerPedId()
            local local_player = PlayerId()
            local player_coords = GetEntityCoords(local_ped)

            if GetDistanceBetweenCoords(player_coords, actual_jail.x, actual_jail.y, actual_jail.z, true) > Config.MaxJailDistance then
                SendMessage("^1" .. Lang.JailMaxDistance)
                if jail_warn >= Config.JailWarns then
                    SendMessage("^1" .. Lang.JailMaxWarns)
                    local time_add = Config.JailWarnsMinutes * 60
                    jail_time = jail_time + time_add
                end
                SetEntityCoords(local_ped, actual_jail.x, actual_jail.y, actual_jail.z)
                FreezeEntityPosition(local_ped, true)
                Citizen.Wait(1000)
                FreezeEntityPosition(local_ped, false)
                jail_warn = jail_warn + 1
            end

            if not GetPlayerInvincible(local_player) then
                SetPlayerInvincible(local_player, true)
            end
            if jail_time ~= nil then
                if jail_time <= 0 then
                    local player_server_id = GetPlayerServerId(PlayerId())

                    TriggerServerEvent("kc_adminV2:unjail", player_server_id, false)
                else
                    jail_time = jail_time - 1
                end
            end
            Citizen.Wait(1000)
        end
        Citizen.Wait(0)
    end
end)

Citizen.CreateThread(function ()
    while true do

        if jailed then
            drawTimeText(jail_time, 255, 255, 255, 200)
        end

        Citizen.Wait(1000)
    end
end)

-- Jail threads --

-- NUI Callbacks --

RegisterNUICallback("close", function (data)
    CloseMenu()
end)

RegisterNUICallback("msg", function (data)
    SendMessage(data.msg)
end)

RegisterNUICallback("remove_warn", function (data)
    TriggerServerEvent("kc_adminV2:delete_warn", data.id)
end)

RegisterNUICallback("warn", function (data)
    TriggerServerEvent("kc_adminV2:warn", data.id, data.reason, data.date, data.table_id)
end)

RegisterNUICallback("kick", function (data)
    TriggerServerEvent("kc_adminV2:kick", "", data.id, data.reason)
end)

RegisterNUICallback("ban", function (data)
    TriggerServerEvent("kc_adminV2:ban", "", data.id, data.reason, "permanent")
end)

RegisterNUICallback("bring", function (data)
    local admin_coords = GetEntityCoords(PlayerPedId())
    local target_id = data.id

    TriggerServerEvent("kc_adminV2:bring", admin_coords, target_id)

end)

RegisterNUICallback("bring_all", function (data)
    local admin_coords = GetEntityCoords(PlayerPedId())
    local target_id = data.id

    TriggerServerEvent("kc_adminV2:bring", admin_coords, -1)

end)

RegisterNUICallback("remove_ban", function(data)
	local target_id = data.id
    TriggerServerEvent("kc_adminV2:delete_ban", target_id)
end)

RegisterNUICallback("goto", function (data)
    local target_id = data.id
    local player_id = GetPlayerFromServerId(tonumber(target_id))
    local local_ped = GetPlayerPed(player_id)
    local target_coords = GetEntityCoords(local_ped)

    target_coords = fixVector(target_coords)

    TriggerServerEvent("kc_adminV2:goto", target_id, target_coords)
end)

RegisterNUICallback("return", function (data)
    TriggerServerEvent("kc_adminV2:return", data.id)
end)

RegisterNUICallback("noclip", function (data)

    local target_id = data.id
    TriggerServerEvent("kc_adminV2:noclip", target_id)

end)

RegisterNUICallback("visibility", function (data)

    local target_id = data.id
    TriggerServerEvent("kc_adminV2:visibility", target_id)

end)

RegisterNUICallback("slay", function (data)
    local target_id = data.id
    TriggerServerEvent("kc_adminV2:slay", target_id)
end)

RegisterNUICallback("slay_all", function (data)
    local target_id = data.id
    TriggerServerEvent("kc_adminV2:slay", -1)
end)

RegisterNUICallback("revive", function (data)
    local target_id = data.id
    TriggerServerEvent("kc_adminV2:revive", target_id)
end)

RegisterNUICallback("revive_all", function (data)
    local target_id = data.id
    TriggerServerEvent("kc_adminV2:revive", -1)
end)

RegisterNUICallback("freeze", function (data)
    local target_id = data.id
    TriggerServerEvent("kc_adminV2:freeze", target_id)
end)

RegisterNUICallback("freeze_all", function (data)
    local target_id = data.id
    TriggerServerEvent("kc_adminV2:freeze", -1)
end)

RegisterNUICallback("jail", function (data)
    local target_id = data.id
    local time = tonumber(data.time)
    TriggerServerEvent("kc_adminV2:jail", target_id, time)
end)

RegisterNUICallback("unjail", function (data)
    local target_id = data.id
    TriggerServerEvent("kc_adminV2:unjail", target_id, true)
end)

RegisterNUICallback("set_money", function (data)
    local target_id = data.id
    local money_type = data.money_type
    local money_amount = data.amount
    TriggerServerEvent("kc_adminV2:set_money", target_id, money_amount, money_type)
end)

RegisterNUICallback("set_job", function (data)
    local target_id = data.id
    local job_name = data.job_name
    local job_grade = data.job_grade
    TriggerServerEvent("kc_adminV2:set_job", target_id, job_name, job_grade)
end)

RegisterNUICallback("set_group", function (data)
    local target_id = data.id
    local group = data.group
    TriggerServerEvent("kc_adminV2:set_group", "", target_id, group)
end)

RegisterNUICallback("request_warns", function (data)
    local target_id = data.id
    TriggerServerEvent("kc_adminV2:get_warns", target_id)
end)

RegisterNUICallback("get_bans", function (data)
    local ban_filter_days = data.days
    local ban_filter_name = data.name
    TriggerServerEvent("kc_adminV2:get_bans", ban_filter_days, ban_filter_name)
end)

-- NUI Callbacks --

-- Client Events --

AddEventHandler('playerSpawned', function(spawn)
    loaded = true
    dead = false
    TriggerServerEvent("kc_adminV2:check_jail")
end)

AddEventHandler('esx:onPlayerDeath', function(data)
    dead = true
end)

RegisterNetEvent("kc_adminV2:loaded_player")
AddEventHandler("kc_adminV2:loaded_player", function ()
    Citizen.CreateThread(function ()
        Citizen.Wait(2000)
        loaded = true
    end)
end)

RegisterNetEvent("kc_adminV2:request_jail")
AddEventHandler("kc_adminV2:request_jail", function (target_id, time)
    TriggerServerEvent("kc_adminV2:jail", target_id, time)
end)

RegisterNetEvent("kc_adminV2:recv_warn")
AddEventHandler("kc_adminV2:recv_warn", function (id_, result)
    local Source = source

    if Source ~= "" then
        if tonumber(Source) > 64 then
            SendNUIMessage({type = "add_warns", warns = result, id = id_})
        end
    end

end)

RegisterNetEvent("kc_adminV2:recv_bans")
AddEventHandler("kc_adminV2:recv_bans", function (bans_data)
    local Source = source

    if Source ~= "" then
        if tonumber(Source) > 64 then
            SendNUIMessage({type = "add_bans", bans = bans_data})
        end
    end
end)

RegisterNetEvent("kc_adminV2:send_notify")
AddEventHandler("kc_adminV2:send_notify", function(title_, text_, type_)
    SendNUIMessage({type = "notify", title = title_, text = text_, type_notify = type_})
end)

RegisterNetEvent("kc_adminV2:order_group")
AddEventHandler("kc_adminV2:order_group", function ()
    TriggerServerEvent("kc_adminV2:request_group")
end)

RegisterNetEvent("kc_adminV2:get_group")
AddEventHandler("kc_adminV2:get_group", function (server_group)
    group = server_group
end)

RegisterNetEvent("kc_adminV2:send_message")
AddEventHandler("kc_adminV2:send_message", function (msg)
    SendMessage(msg)
end)

RegisterNetEvent("kc_adminV2:send_raw_message")
AddEventHandler("kc_adminV2:send_raw_message", function (msg)
    TriggerEvent("chatMessage", "", {0, 0, 0}, msg)
end)

RegisterNetEvent("kc_adminV2:fix_table")
AddEventHandler("kc_adminV2:fix_table", function (table_id, warn_id)
    SendNUIMessage({type = "fix_table", table = table_id, warn = warn_id})
end)

RegisterNetEvent("kc_adminV2:remove_table")
AddEventHandler("kc_adminV2:remove_table", function (table_id)
    SendNUIMessage({type = "remove_table", table = table_id})
end)

RegisterNetEvent("kc_adminV2:return_player")
AddEventHandler("kc_adminV2:return_player", function ()
    local Source = source

    if Source ~= "" then
        if tonumber(Source) > 64 then
            if last_pos ~= nil then
                SetEntityCoords(GetPlayerPed(), last_pos)
            end
        end
    end

end)

RegisterNetEvent("kc_adminV2:teleport_player")
AddEventHandler("kc_adminV2:teleport_player", function (coords_vector3)
    local Source = source

    last_pos = fixVector(GetEntityCoords(PlayerPedId()))

    if Source ~= "" then
        if tonumber(Source) > 64 then
            SetEntityCoords(PlayerPedId(), coords_vector3)
            FreezeEntityPosition(PlayerPedId(), true)
            Citizen.Wait(1000)
            FreezeEntityPosition(PlayerPedId(), false)
        end
    end

end)

RegisterNetEvent("kc_adminV2:noclip_player")
AddEventHandler("kc_adminV2:noclip_player", function ()
    local Source = source

    if Source ~= "" then
        if tonumber(Source) > 64 then
            if not noclip then
                noclip_pos = GetEntityCoords(PlayerPedId(), false)
            end

            noclip = not noclip

            if noclip then
                SendMessage(Lang.NoclipOn)
                CancelEvent()
                return
            end

            SendMessage(Lang.NoclipOff)
        end
    end

end)

RegisterNetEvent("kc_adminV2:visibility_player")
AddEventHandler("kc_adminV2:visibility_player", function ()
    local Source = source

    if Source ~= "" then
        if tonumber(Source) > 64 then
            if not visibility then
                SetEntityVisible(PlayerPedId(), true)
                SendMessage("Ahora eres ^2visible^0")
            else
                SetEntityVisible(PlayerPedId(), false)
                SendMessage("Ahora eres ^3invisible^0")
            end
        end
    end

    visibility = not visibility

end)

RegisterNetEvent("kc_adminV2:slay_player")
AddEventHandler("kc_adminV2:slay_player", function ()
    local Source = source

    if Source ~= "" then
        if tonumber(Source) > 64 then
            local local_ped = PlayerPedId()
            SendMessage("^1" .. Lang.Slay)

            if Config.AmbulanceJob then
                TriggerServerEvent('esx_ambulancejob:setDeathStatus', true)
            end

            SetEntityHealth(local_ped, 0)
        end
    end

end)

RegisterNetEvent("kc_adminV2:revive_player")
AddEventHandler("kc_adminV2:revive_player", function()
    local local_ped = PlayerPedId()
    local local_coords = GetEntityCoords(local_ped)

    if not dead then
        SetEntityHealth(local_ped, 200)
        CancelEvent()
        return
    end

    Citizen.CreateThread(function()
        DoScreenFadeOut(800)

        while not IsScreenFadedOut() do
            Citizen.Wait(50)
        end

        if Config.AmbulanceJob then
            TriggerServerEvent('esx_ambulancejob:setDeathStatus', false)
            TriggerServerEvent('esx:updateLastPosition', local_coords)
        end

        RespawnPed(local_ped, local_coords, 0.0)

        SendMessage("^2" .. Lang.Revive)

        StopScreenEffect('DeathFailOut')
        DoScreenFadeIn(800)
    end)

end)

RegisterNetEvent("kc_adminV2:freeze_player")
AddEventHandler("kc_adminV2:freeze_player", function ()
    local Source = source

    if Source ~= "" then
        if tonumber(Source) > 64 then
            freeze = not freeze

            local local_ped = PlayerPedId()

            FreezeEntityPosition(local_ped, freeze)

            if freeze then
                SendMessage(Lang.FreezeMsg)
            else
                SendMessage(Lang.UnFreezeMsg)
            end
        end
    end

end)

RegisterNetEvent("kc_adminV2:jail_player")
AddEventHandler("kc_adminV2:jail_player", function (time)
    local Source = source

    if Source ~= "" then
        if tonumber(Source) > 64 then
            local local_ped = PlayerPedId()
            local time_minutes = math.floor(time / 60)
            local Jail = randomArray(Config.Jails)

            actual_jail = Jail

            if jailed == false then
                RemoveAllPedWeapons(local_ped, true)
                SetEntityCoords(local_ped, Jail.x, Jail.y, Jail.z)
                FreezeEntityPosition(local_ped, true)
                jail_time = time
                jailed = true
                SendMessage("^1" .. Lang.Jailed .. tostring(time_minutes) .. " " .. Lang.Minutes)
                Citizen.Wait(1000)
                FreezeEntityPosition(local_ped, false)
                FreezeEntityPosition(local_ped, false)
            else
                jail_time = jail_time + time
                SendMessage("^1" .. Lang.Jailed .. tostring(time_minutes) .. "" .. Lang.Minutes .. " " .. Lang.Plus)
                FreezeEntityPosition(local_ped, false)
            end
        end
    end
end)

RegisterNetEvent("kc_adminV2:unjail_player")
AddEventHandler("kc_adminV2:unjail_player", function ()
    local Source = source

    if Source ~= "" then
        if tonumber(Source) > 64 then
            local local_ped = PlayerPedId()
            local local_player = PlayerId()

            SendMessage("^2" .. Lang.UnJailed)
            jailed = false
            jail_time = nil
            SetPlayerInvincible(local_player, false)
            SetEntityCoords(local_ped, Config.ExitFromJail.x, Config.ExitFromJail.y, Config.ExitFromJail.z)
            SetPlayerInvincible(local_player, false)
        end
    end

end)

-- Clients Events --