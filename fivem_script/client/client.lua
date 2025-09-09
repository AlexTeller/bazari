local QBCore = exports['qb-core']:GetCoreObject()

-- Global Variables
local MarketStands = {}
local CurrentStand = nil
local CreatingStand = false
local StandBlips = {}
local StandPeds = {}

-- Initialize
CreateThread(function()
    Wait(1000)
    RequestStandsFromServer()
    CreateSellingZoneBlips()
end)

-- Events
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    RequestStandsFromServer()
end)

RegisterNetEvent('marketstand:client:standCreated', function(standId, standData)
    MarketStands[standId] = standData
    CreateStandBlip(standId, standData)
    CreateStandPed(standId, standData)
end)

RegisterNetEvent('marketstand:client:standDeleted', function(standId)
    RemoveStandBlip(standId)
    RemoveStandPed(standId)
    MarketStands[standId] = nil
end)

RegisterNetEvent('marketstand:client:refreshStands', function()
    RequestStandsFromServer()
end)

RegisterNetEvent('marketstand:client:refreshStandItems', function(standId)
    -- Refresh items for specific stand if needed
end)

-- Main Thread
CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        -- Check proximity to market stands
        for standId, stand in pairs(MarketStands) do
            if stand.status == 'active' then
                local distance = #(playerCoords - vector3(stand.location.x, stand.location.y, stand.location.z))
                
                if distance < 3.0 then
                    sleep = 0
                    ShowFloatingHelpNotification(Lang:t('press_to_interact'), vector3(stand.location.x, stand.location.y, stand.location.z + 1.0))
                    
                    if IsControlJustReleased(0, 38) then -- E key
                        OpenStandMenu(standId, stand)
                    end
                end
            end
        end
        
        Wait(sleep)
    end
end)

-- Stand Management Functions
function RequestStandsFromServer()
    QBCore.Functions.TriggerCallback('marketstand:server:getStands', function(stands)
        MarketStands = stands
        RefreshAllBlips()
        RefreshAllPeds()
    end)
end

function CreateStand()
    if CreatingStand then return end
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)
    
    -- Check if in selling zone (if enabled)
    if Config.SellingZones.enabled then
        local inZone = false
        for _, zone in pairs(Config.SellingZones.zones) do
            local distance = #(playerCoords - zone.coords)
            if distance <= zone.radius then
                inZone = true
                break
            end
        end
        
        if not inZone then
            ShowNotification(Lang:t('outside_selling_zone'), 'error')
            return
        end
    end
    
    CreatingStand = true
    
    -- Get stand name from player
    local standName = GetTextInput(Lang:t('enter_stand_name'), '', 50)
    if not standName or standName == '' then
        CreatingStand = false
        return
    end
    
    local standData = {
        name = standName,
        location = {
            x = playerCoords.x,
            y = playerCoords.y,
            z = playerCoords.z,
            h = playerHeading
        }
    }
    
    TriggerServerEvent('marketstand:server:createStand', standData)
    CreatingStand = false
end

function OpenStandMenu(standId, stand)
    CurrentStand = standId
    local playerData = QBCore.Functions.GetPlayerData()
    
    -- Determine player's permission level
    local isOwner = stand.owner_id == playerData.citizenid
    local isStaff = HasStaffPermission(standId, playerData.citizenid)
    local isPolice = IsPlayerPolice(playerData.job.name)
    
    local menuOptions = {}
    
    if isOwner or isStaff then
        -- Owner/Staff Menu
        table.insert(menuOptions, {
            header = stand.name,
            isMenuHeader = true,
            icon = 'fas fa-store'
        })
        
        table.insert(menuOptions, {
            header = Lang:t('manage_stand'),
            txt = 'View and manage your market stand',
            icon = 'fas fa-cog',
            params = {
                event = 'marketstand:client:openManageMenu',
                args = {standId = standId}
            }
        })
        
        if isOwner then
            table.insert(menuOptions, {
                header = Lang:t('staff_list'),
                txt = 'Manage your staff members',
                icon = 'fas fa-users',
                params = {
                    event = 'marketstand:client:openStaffMenu',
                    args = {standId = standId}
                }
            })
            
            if Config.RentSystem.enabled then
                table.insert(menuOptions, {
                    header = Lang:t('pay_rent'),
                    txt = 'Extend your market stand rent',
                    icon = 'fas fa-money-bill',
                    params = {
                        event = 'marketstand:client:payRent',
                        args = {standId = standId}
                    }
                })
            end
            
            if Config.OwnershipTransfer.enabled then
                table.insert(menuOptions, {
                    header = Lang:t('transfer_ownership'),
                    txt = 'Transfer ownership to another player',
                    icon = 'fas fa-exchange-alt',
                    params = {
                        event = 'marketstand:client:transferOwnership',
                        args = {standId = standId}
                    }
                })
            end
            
            table.insert(menuOptions, {
                header = Lang:t('delete_stand'),
                txt = 'Permanently delete this market stand',
                icon = 'fas fa-trash',
                params = {
                    event = 'marketstand:client:deleteStand',
                    args = {standId = standId}
                }
            })
        end
    else
        -- Customer Menu
        table.insert(menuOptions, {
            header = stand.name,
            txt = 'Owned by: ' .. stand.owner_name,
            isMenuHeader = true,
            icon = 'fas fa-store'
        })
        
        table.insert(menuOptions, {
            header = 'Browse Items',
            txt = 'View items available for purchase',
            icon = 'fas fa-shopping-cart',
            params = {
                event = 'marketstand:client:browseItems',
                args = {standId = standId}
            }
        })
    end
    
    -- Police Menu
    if isPolice and Config.PenaltySystem.enabled then
        table.insert(menuOptions, {
            header = 'Police Actions',
            txt = 'Inspect for illegal items',
            icon = 'fas fa-shield-alt',
            params = {
                event = 'marketstand:client:policeInspect',
                args = {standId = standId}
            }
        })
    end
    
    OpenMenu(menuOptions)
end

function OpenManageMenu(data)
    local standId = data.standId
    QBCore.Functions.TriggerCallback('marketstand:server:getStandItems', function(items)
        local menuOptions = {}
        
        table.insert(menuOptions, {
            header = '< Go Back',
            params = {
                event = 'marketstand:client:reopenMainMenu',
                args = {standId = standId}
            }
        })
        
        table.insert(menuOptions, {
            header = Lang:t('add_item'),
            txt = 'Add an item to your market stand',
            icon = 'fas fa-plus',
            params = {
                event = 'marketstand:client:addItem',
                args = {standId = standId}
            }
        })
        
        -- List current items
        for itemName, item in pairs(items) do
            table.insert(menuOptions, {
                header = item.display_name,
                txt = string.format('Price: %s | Stock: %d', Shared.FormatMoney(item.price), item.stock),
                icon = 'fas fa-box',
                params = {
                    event = 'marketstand:client:manageItem',
                    args = {standId = standId, itemName = itemName, item = item}
                }
            })
        end
        
        OpenMenu(menuOptions)
    end, standId)
end

function AddItem(data)
    local standId = data.standId
    
    -- Get item name
    local itemName = GetTextInput('Enter item name', '', 50)
    if not itemName or itemName == '' then return end
    
    -- Check if item exists in player inventory
    local playerData = QBCore.Functions.GetPlayerData()
    local hasItem = false
    local itemLabel = itemName
    
    for _, item in pairs(playerData.items) do
        if item.name == itemName and item.amount > 0 then
            hasItem = true
            itemLabel = item.label or item.name
            break
        end
    end
    
    if not hasItem then
        ShowNotification('You don\'t have this item in your inventory', 'error')
        return
    end
    
    -- Get price
    local price = GetNumberInput('Enter price per item', 1)
    if not price or price <= 0 then return end
    
    -- Get stock
    local stock = GetNumberInput('Enter stock amount', 1)
    if not stock or stock <= 0 then return end
    
    -- Get description (optional)
    local description = GetTextInput('Enter item description (optional)', '', 100) or ''
    
    local itemData = {
        item_name = itemName,
        display_name = itemLabel,
        price = price,
        stock = stock,
        description = description
    }
    
    TriggerServerEvent('marketstand:server:addItem', standId, itemData)
end

function BrowseItems(data)
    local standId = data.standId
    QBCore.Functions.TriggerCallback('marketstand:server:getStandItems', function(items)
        local menuOptions = {}
        
        table.insert(menuOptions, {
            header = '< Go Back',
            params = {
                event = 'marketstand:client:reopenMainMenu',
                args = {standId = standId}
            }
        })
        
        for itemName, item in pairs(items) do
            if item.stock > 0 then
                table.insert(menuOptions, {
                    header = item.display_name,
                    txt = string.format('Price: %s | Stock: %d<br>%s', Shared.FormatMoney(item.price), item.stock, item.description or ''),
                    icon = 'fas fa-shopping-cart',
                    params = {
                        event = 'marketstand:client:purchaseItem',
                        args = {standId = standId, itemName = itemName, item = item}
                    }
                })
            end
        end
        
        if #menuOptions == 1 then
            table.insert(menuOptions, {
                header = 'No Items Available',
                txt = 'This stand has no items for sale',
                icon = 'fas fa-exclamation-triangle'
            })
        end
        
        OpenMenu(menuOptions)
    end, standId)
end

function PurchaseItem(data)
    local quantity = GetNumberInput('Enter quantity to purchase', 1)
    if not quantity or quantity <= 0 then return end
    
    if quantity > data.item.stock then
        ShowNotification(Lang:t('insufficient_stock'), 'error')
        return
    end
    
    local totalCost = data.item.price * quantity
    ShowConfirmDialog(
        string.format('Purchase %dx %s for %s?', quantity, data.item.display_name, Shared.FormatMoney(totalCost)),
        function()
            TriggerServerEvent('marketstand:server:purchaseItem', data.standId, data.itemName, quantity)
        end
    )
end

-- Utility Functions
function HasStaffPermission(standId, citizenid)
    -- This would need to be implemented based on server-side staff data
    return false
end

function IsPlayerPolice(jobName)
    for _, policeJob in pairs(Config.PenaltySystem.policeJobs) do
        if jobName == policeJob then
            return true
        end
    end
    return false
end

-- UI Functions (Framework-dependent)
function ShowNotification(message, type)
    if Config.Notifications.type == 'ox_lib' then
        exports.ox_lib:notify({
            title = 'Market Stand',
            description = message,
            type = type or 'inform',
            position = Config.Notifications.position
        })
    elseif Config.Notifications.type == 'qb-core' then
        QBCore.Functions.Notify(message, type or 'primary')
    end
end

function OpenMenu(options)
    if Config.ContextMenu == 'ox_lib' then
        exports.ox_lib:registerContext({
            id = 'marketstand_menu',
            title = 'Market Stand',
            options = options
        })
        exports.ox_lib:showContext('marketstand_menu')
    elseif Config.ContextMenu == 'qb-menu' then
        exports['qb-menu']:openMenu(options)
    elseif Config.ContextMenu == 'nh-context' then
        TriggerEvent('nh-context:sendMenu', options)
    end
end

function GetTextInput(headerText, placeholderText, maxLength)
    if Config.InputSystem == 'ox_lib' then
        local input = exports.ox_lib:inputDialog(headerText, {
            {type = 'input', label = headerText, placeholder = placeholderText, required = true, max = maxLength}
        })
        return input and input[1] or nil
    elseif Config.InputSystem == 'qb-input' then
        local input = exports['qb-input']:ShowInput({
            header = headerText,
            submitText = "Submit",
            inputs = {
                {
                    text = headerText,
                    name = "input",
                    type = "text",
                    isRequired = true,
                    placeholder = placeholderText
                }
            }
        })
        return input and input.input or nil
    elseif Config.InputSystem == 'nh-keyboard' then
        local input = exports['nh-keyboard']:KeyboardInput({
            header = headerText,
            rows = {
                {
                    id = 0,
                    txt = placeholderText
                }
            }
        })
        return input and input[1] and input[1].input or nil
    end
    return nil
end

function GetNumberInput(headerText, defaultValue)
    if Config.InputSystem == 'ox_lib' then
        local input = exports.ox_lib:inputDialog(headerText, {
            {type = 'number', label = headerText, default = defaultValue, required = true, min = 1}
        })
        return input and input[1] or nil
    elseif Config.InputSystem == 'qb-input' then
        local input = exports['qb-input']:ShowInput({
            header = headerText,
            submitText = "Submit",
            inputs = {
                {
                    text = headerText,
                    name = "number",
                    type = "number",
                    isRequired = true,
                    default = defaultValue
                }
            }
        })
        return input and tonumber(input.number) or nil
    end
    return defaultValue
end

function ShowConfirmDialog(message, callback)
    if Config.ContextMenu == 'ox_lib' then
        local alert = exports.ox_lib:alertDialog({
            header = 'Confirm',
            content = message,
            centered = true,
            cancel = true
        })
        if alert == 'confirm' and callback then
            callback()
        end
    else
        -- Fallback confirmation
        if callback then callback() end
    end
end

function ShowFloatingHelpNotification(text, coords)
    if Config.ContextMenu == 'ox_lib' then
        exports.ox_lib:showTextUI(text)
    else
        -- Fallback help text
        SetFloatingHelpTextWorldPosition(1, coords.x, coords.y, coords.z)
        SetFloatingHelpTextStyle(1, 1, 2, -1, 3, 0, 0, 0, 0, 0)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(text)
        EndTextCommandSetBlipName(1)
    end
end

-- Blip Management
function CreateSellingZoneBlips()
    if not Config.SellingZones.enabled then return end
    
    for i, zone in pairs(Config.SellingZones.zones) do
        if zone.blip then
            local blip = AddBlipForRadius(zone.coords.x, zone.coords.y, zone.coords.z, zone.radius)
            SetBlipHighDetail(blip, true)
            SetBlipColour(blip, Config.Blips.marketZone.color)
            SetBlipAlpha(blip, 128)
            
            local zoneBlip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
            SetBlipSprite(zoneBlip, Config.Blips.marketZone.sprite)
            SetBlipDisplay(zoneBlip, 4)
            SetBlipScale(zoneBlip, Config.Blips.marketZone.scale)
            SetBlipColour(zoneBlip, Config.Blips.marketZone.color)
            SetBlipAsShortRange(zoneBlip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(zone.name)
            EndTextCommandSetBlipName(zoneBlip)
        end
    end
end

function CreateStandBlip(standId, stand)
    local blip = AddBlipForCoord(stand.location.x, stand.location.y, stand.location.z)
    SetBlipSprite(blip, Config.Blips.marketStand.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, Config.Blips.marketStand.scale)
    SetBlipColour(blip, Config.Blips.marketStand.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(stand.name)
    EndTextCommandSetBlipName(blip)
    
    StandBlips[standId] = blip
end

function RemoveStandBlip(standId)
    if StandBlips[standId] then
        RemoveBlip(StandBlips[standId])
        StandBlips[standId] = nil
    end
end

function CreateStandPed(standId, stand)
    -- Create a ped for the market stand (optional)
    RequestModel(GetHashKey('a_m_m_business_01'))
    while not HasModelLoaded(GetHashKey('a_m_m_business_01')) do
        Wait(1)
    end
    
    local ped = CreatePed(4, GetHashKey('a_m_m_business_01'), stand.location.x, stand.location.y, stand.location.z - 1.0, stand.location.h, false, true)
    SetEntityCanBeDamaged(ped, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    TaskStartScenarioInPlace(ped, "WORLD_HUMAN_STAND_IMPATIENT", 0, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    
    StandPeds[standId] = ped
end

function RemoveStandPed(standId)
    if StandPeds[standId] then
        DeleteEntity(StandPeds[standId])
        StandPeds[standId] = nil
    end
end

function RefreshAllBlips()
    -- Remove existing blips
    for standId, blip in pairs(StandBlips) do
        RemoveBlip(blip)
    end
    StandBlips = {}
    
    -- Create new blips
    for standId, stand in pairs(MarketStands) do
        if stand.status == 'active' then
            CreateStandBlip(standId, stand)
        end
    end
end

function RefreshAllPeds()
    -- Remove existing peds
    for standId, ped in pairs(StandPeds) do
        DeleteEntity(ped)
    end
    StandPeds = {}
    
    -- Create new peds
    for standId, stand in pairs(MarketStands) do
        if stand.status == 'active' then
            CreateStandPed(standId, stand)
        end
    end
end

-- Event Handlers
RegisterNetEvent('marketstand:client:openManageMenu', function(data)
    OpenManageMenu(data)
end)

RegisterNetEvent('marketstand:client:addItem', function(data)
    AddItem(data)
end)

RegisterNetEvent('marketstand:client:browseItems', function(data)
    BrowseItems(data)
end)

RegisterNetEvent('marketstand:client:purchaseItem', function(data)
    PurchaseItem(data)
end)

RegisterNetEvent('marketstand:client:deleteStand', function(data)
    ShowConfirmDialog('Are you sure you want to delete this market stand?', function()
        TriggerServerEvent('marketstand:server:deleteStand', data.standId)
    end)
end)

RegisterNetEvent('marketstand:client:reopenMainMenu', function(data)
    local stand = MarketStands[data.standId]
    if stand then
        OpenStandMenu(data.standId, stand)
    end
end)

-- Commands
RegisterCommand('createstand', function()
    CreateStand()
end, false)

RegisterCommand('myStands', function()
    QBCore.Functions.TriggerCallback('marketstand:server:getPlayerStands', function(stands)
        local menuOptions = {}
        
        table.insert(menuOptions, {
            header = 'My Market Stands',
            isMenuHeader = true,
            icon = 'fas fa-store'
        })
        
        for standId, stand in pairs(stands) do
            table.insert(menuOptions, {
                header = stand.name,
                txt = string.format('Status: %s | Earnings: %s', string.upper(stand.status), Shared.FormatMoney(stand.earnings)),
                icon = 'fas fa-store',
                params = {
                    event = 'marketstand:client:teleportToStand',
                    args = {standId = standId, location = stand.location}
                }
            })
        end
        
        if #menuOptions == 1 then
            table.insert(menuOptions, {
                header = 'No Market Stands',
                txt = 'You don\'t own any market stands',
                icon = 'fas fa-exclamation-triangle'
            })
        end
        
        OpenMenu(menuOptions)
    end)
end, false)

RegisterNetEvent('marketstand:client:teleportToStand', function(data)
    SetEntityCoords(PlayerPedId(), data.location.x, data.location.y, data.location.z)
end)