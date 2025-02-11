ESX = nil
QBCore = nil

if GetResourceState('es_extended') == 'started' then
    ESX = exports['es_extended']:getSharedObject()
elseif GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
end

local function sendDiscordLog(title, description, color)
    if not Config.DiscordWebhook then return end

    PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers) end, 'POST', json.encode({
        embeds = {{
            title = title,
            description = description,
            color = color
        }}
    }), { ['Content-Type'] = 'application/json' })
end

RegisterServerEvent('way_drugsell:checkInventory', function()
    local xPlayer = ESX and ESX.GetPlayerFromId(source) or QBCore.Functions.GetPlayer(source)
    local inventory = {}

    for _, drug in ipairs(Config.Drugs) do
        local count = xPlayer.getInventoryItem(drug.name).count
        if count > 0 then
            inventory[drug.name] = count
        end
    end

    TriggerClientEvent('way_drugsell:openMenu', source, inventory)
end)

RegisterServerEvent('way_drugsell:sellDrug', function(drugName)
    local xPlayer = ESX and ESX.GetPlayerFromId(source) or QBCore.Functions.GetPlayer(source)
    local drug = nil

    for _, d in ipairs(Config.Drugs) do
        if d.name == drugName then
            drug = d
            break
        end
    end

    if not drug then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = Translate["invalid_drug"] })
        sendDiscordLog(Translate["discord_invalid_drug_title"], Translate["discord_invalid_drug_desc"]:format(GetPlayerName(source), drugName), 16711680) -- Červená barva
        return
    end

    if xPlayer.getInventoryItem(drug.name).count > 0 then
        xPlayer.removeInventoryItem(drug.name, 1)
        xPlayer.addMoney(drug.price)
        TriggerClientEvent('ox_lib:notify', source, { type = 'success', description = Translate["sold_drug"]:format(drug.label, drug.price) })
        sendDiscordLog(Translate["discord_sold_drug_title"], Translate["discord_sold_drug_desc"]:format(GetPlayerName(source), drug.label, drug.price), 65280) -- Zelená barva
    else
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = Translate["no_drug"]:format(drug.label) })
        sendDiscordLog(Translate["discord_no_drug_title"], Translate["discord_no_drug_desc"]:format(GetPlayerName(source), drug.label), 16711680) -- Červená barva
    end
end)


RegisterServerEvent('way_drugsell:callPolice', function(coords)
    local xPlayers = ESX.GetPlayers()

    for _, playerId in ipairs(xPlayers) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer.job.name == 'police' then
            TriggerClientEvent('ox_lib:notify', playerId, { type = 'info', description = Translate["police_alert"] })
            TriggerClientEvent('way_drugsell:policeBlip', playerId, coords)
        end
    end
end)



RegisterServerEvent('way_drugsell:stealMoney', function(amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    xPlayer.addMoney(amount)
    sendDiscordLog(Translate["discord_steal_money_title"], Translate["discord_steal_money_desc"]:format(GetPlayerName(source), amount), 16776960) -- Žlutá barva
end)
