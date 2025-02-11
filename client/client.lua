ESX = exports['es_extended']:getSharedObject()

local customerBlip = nil
local customerPed = nil
local isPhoneActive = false 

local function spawnCustomer(location)

     PlaySoundFrontend(-1, 'Menu_Accept', 'Phone_SoundSet_Default', true)
 
     local animDict = 'cellphone@'
     local animName = 'cellphone_call_listen_base'

     ESX.Streaming.RequestAnimDict(animDict, function()
          TaskPlayAnim(PlayerPedId(), animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false)

          local phoneModel = GetHashKey('prop_npc_phone_02') 
          RequestModel(phoneModel)
          while not HasModelLoaded(phoneModel) do
              Wait(10)
          end
  
          local phoneProp = CreateObject(phoneModel, 0, 0, 0, true, true, false)
          AttachEntityToEntity(
              phoneProp, 
              PlayerPedId(), 
              GetPedBoneIndex(PlayerPedId(), 60309), 
              0.1, 0.0, 0.0, 
              0.0, 0.0, 0.0, 
              true, true, false, true, 1, true
          )
  
          SetTimeout(5000, function()
              ClearPedTasks(PlayerPedId())
              DeleteObject(phoneProp) 
          end)
      end)

     local model = GetHashKey('a_m_y_hipster_01')
     RequestModel(model)
     while not HasModelLoaded(model) do
         Wait(10)
     end
 
     customerPed = CreatePed(4, model, location.coords.x, location.coords.y, location.coords.z - 1.0, location.heading, false, true)
     SetEntityAsMissionEntity(customerPed, true, true)
     SetBlockingOfNonTemporaryEvents(customerPed, true)
     FreezeEntityPosition(customerPed, true)
 
     customerBlip = AddBlipForCoord(location.coords.x, location.coords.y, location.coords.z)
     SetBlipSprite(customerBlip, 1)
     SetBlipColour(customerBlip, 2)
     SetBlipScale(customerBlip, 0.8)
     BeginTextCommandSetBlipName('STRING')
     AddTextComponentString(Translate["customer"])
     EndTextCommandSetBlipName(customerBlip)
end

local function sellDrugsToCustomer(drugName)
    if not customerPed then
        TriggerEvent('ox_lib:notify', { type = 'error', description = Translate["no_customer"] })
        return
    end

    local animDict = Config.SellAnimation.dict
    local animName = Config.SellAnimation.anim
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end

    -- Spuštění animace
    TaskPlayAnim(PlayerPedId(), animDict, animName, 8.0, -8.0, Config.SellAnimation.duration, 0, 0, false, false, false)
    Wait(Config.SellAnimation.duration)

    -- Zrušení animace
    ClearPedTasks(PlayerPedId())
    FreezeEntityPosition(customerPed, false)
    -- Náhodné rozhodnutí NPC
    local rejectChance = math.random(1, 100)
    if rejectChance <= Config.RejectChance then
        -- NPC odmítne nabídku
        TriggerEvent('ox_lib:notify', { type = 'error', description = Translate["offer_rejected"] })

        -- Šance, že NPC vytáhne zbraň
        local weaponChance = math.random(1, 100)
        if weaponChance <= Config.WeaponChance then
            GiveWeaponToPed(customerPed, GetHashKey("WEAPON_PISTOL"), 1, false, true)
            TaskCombatPed(customerPed, PlayerPedId(), 0, 16)
        end

        -- Šance, že někdo zavolá policii
        local policeChance = math.random(1, 100)
        if policeChance <= Config.PoliceCall then
            if Config.Dispatch == 'defalut' then
            TriggerServerEvent('way_drugsell:callPolice', GetEntityCoords(PlayerPedId()))
            elseif Config.Dispatch == 'custom' then
                    DispatchCall()
            end
        end
    else
        -- NPC koupí drogu
        TriggerServerEvent('way_drugsell:sellDrug', drugName)
        TriggerEvent('ox_lib:notify', { type = 'success', description = Translate["drug_sold"] })
    end

    if customerBlip then
        RemoveBlip(customerBlip)
        customerBlip = nil
    end
    -- NPC zůstane na místě, aby mohlo být okradeno nebo zaútočit
    SetTimeout(1200000, function() -- Po 10 sekundách NPC zmizí, pokud nebylo okradeno
        if DoesEntityExist(customerPed) then
            DeleteEntity(customerPed)
            customerPed = nil
        end
    end)
end


local function openDrugMenu(inventory)
    local options = {}
    for _, drug in ipairs(Config.Drugs) do
        if inventory[drug.name] and inventory[drug.name] > 0 then
            table.insert(options, {
                label = drug.label .. ' - $' .. drug.price,
                value = drug.name
            })
        end
    end

    if #options == 0 then
        TriggerEvent('ox_lib:notify', { type = 'error', description = Translate["no_drugs"] })
        return
    end

    local input = lib.inputDialog(Translate["menu_title"], {
        { type = 'select', label = Translate["select_drug"], options = options }
    })

    if input then
        local selectedDrug = input[1]

        local location = Config.CustomerLocations[math.random(#Config.CustomerLocations)]
        spawnCustomer(location)

        TriggerEvent('ox_lib:notify', { type = 'info', description = Translate["customer_waiting"] })

        CreateThread(function()
            while true do
                Wait(500)
                local playerCoords = GetEntityCoords(PlayerPedId())
                local distance = #(playerCoords - location.coords)

                if distance < 1.0 then
                    -- Kontrola, zda hráč není ve vozidle
                    if IsPedInAnyVehicle(PlayerPedId(), false) then
                        TriggerEvent('ox_lib:notify', { type = 'error', description = Translate["not_outside_vehicle"] })
                        break -- Ukončíme smyčku, pokud je hráč ve vozidle
                    end
                
                    -- Pokud hráč není ve vozidle, zahájíme prodej
                    sellDrugsToCustomer(selectedDrug)
                    break
                end
                
            end
        end)
    end
end

RegisterNetEvent('way_drugsell:interactWithCustomer', function()
    TriggerServerEvent('way_drugsell:checkInventory')
end)

RegisterNetEvent('way_drugsell:openMenu', function(inventory)
    openDrugMenu(inventory)
end)

if Config.Interaction == 'item' then
    RegisterNetEvent('way_drugsell:useItem', function()
        TriggerServerEvent('way_drugsell:checkInventory')
    end)
end

if Config.Interaction == 'prop' then
    exports.ox_target:addModel(Config.AllowedProps, {
        {
            name = 'sell_drugs_prop',
            event = 'way_drugsell:useProp',
            icon = 'fa-solid fa-cannabis',
            label = Translate["sell_drugs"]
        }
    })

    RegisterNetEvent('way_drugsell:useProp', function()
        TriggerServerEvent('way_drugsell:checkInventory')
    end)
end

if Config.Interaction == 'radial' then
    exports.ox_radial:addOption(Config.RadialMenu.id, {
        title = Config.RadialMenu.title,
        icon = Config.RadialMenu.icon,
        onSelect = function()
            TriggerServerEvent('way_drugsell:checkInventory')
        end
    })
end

if Config.Interaction == 'command' then
    RegisterCommand(Config.Command, function()
        TriggerServerEvent('way_drugsell:checkInventory')
    end)
end


AddEventHandler('onPedDeath', function(ped)
    if ped == customerPed then
        local playerCoords = GetEntityCoords(PlayerPedId())
        local pedCoords = GetEntityCoords(ped)

        if #(playerCoords - pedCoords) < 3.0 then
            local stolenMoney = math.random(50, 100) -- 50 % z ceny drogy
            TriggerServerEvent('way_drugsell:stealMoney', stolenMoney)
            TriggerEvent('ox_lib:notify', { type = 'success', description = Translate["stolen_money"]:format(stolenMoney) })
        end
    end
end)

