local QBCore = exports['qb-core']:GetCoreObject()

-- Global Variables
local MarketStands = {}
local PlayerStands = {}
local StandItems = {}
local StandStaff = {}
local ActiveRentChecks = {}

-- Initialize the script
CreateThread(function()
    Wait(1000)
    print("^2[Market Stand] ^7Loading market stands from database...")
    LoadMarketStands()
    LoadStandItems()
    LoadStandStaff()
    
    if Config.RentSystem.enabled then
        StartRentChecker()
    end
    
    print("^2[Market Stand] ^7Script initialized successfully!")
end)

-- Database Functions
function LoadMarketStands()
    local result = MySQL.Sync.fetchAll('SELECT * FROM market_stands', {})
    if result then
        for _, stand in pairs(result) do
            local location = json.decode(stand.location)
            MarketStands[stand.id] = {
                id = stand.id,
                owner_id = stand.owner_id,
                owner_name = stand.owner_name,
                name = stand.name,
                location = location,
                zone_id = stand.zone_id,
                status = stand.status,
                rent_expires = stand.rent_expires,
                created_at = stand.created_at,
                updated_at = stand.updated_at,
                earnings = stand.earnings,
                total_sales = stand.total_sales
            }
            
            -- Track player stands
            if not PlayerStands[stand.owner_id] then
                PlayerStands[stand.owner_id] = {}
            end
            table.insert(PlayerStands[stand.owner_id], stand.id)
        end
    end
end

function LoadStandItems()
    local result = MySQL.Sync.fetchAll('SELECT * FROM market_stand_items', {})
    if result then
        for _, item in pairs(result) do
            if not StandItems[item.stand_id] then
                StandItems[item.stand_id] = {}
            end
            StandItems[item.stand_id][item.item_name] = {
                id = item.id,
                stand_id = item.stand_id,
                item_name = item.item_name,
                display_name = item.display_name,
                price = item.price,
                stock = item.stock,
                max_stock = item.max_stock,
                description = item.description
            }
        end
    end
end

function LoadStandStaff()
    local result = MySQL.Sync.fetchAll('SELECT * FROM market_stand_staff WHERE is_active = 1', {})
    if result then
        for _, staff in pairs(result) do
            if not StandStaff[staff.stand_id] then
                StandStaff[staff.stand_id] = {}
            end
            StandStaff[staff.stand_id][staff.player_id] = {
                id = staff.id,
                stand_id = staff.stand_id,
                player_id = staff.player_id,
                player_name = staff.player_name,
                role = staff.role,
                wage_per_hour = staff.wage_per_hour,
                working_hours = json.decode(staff.working_hours),
                hired_at = staff.hired_at,
                is_active = staff.is_active
            }
        end
    end
end

-- Market Stand Management
RegisterNetEvent('marketstand:server:createStand', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local playerStandCount = GetPlayerStandCount(Player.PlayerData.citizenid)
    if playerStandCount >= Config.MaxStandsPerPlayer then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('max_stands_reached'), 'error')
        return
    end
    
    -- Check if player is in allowed zone (if zones are enabled)
    if Config.SellingZones.enabled then
        local playerCoords = GetEntityCoords(GetPlayerPed(src))
        local inZone, zoneId = IsPlayerInSellingZone(playerCoords)
        if not inZone then
            TriggerClientEvent('QBCore:Notify', src, Lang:t('outside_selling_zone'), 'error')
            return
        end
        
        if IsZoneFull(zoneId) then
            TriggerClientEvent('QBCore:Notify', src, Lang:t('zone_full'), 'error')
            return
        end
        data.zone_id = zoneId
    end
    
    -- Check if player has enough money for initial rent
    local rentCost = Config.RentSystem.defaultRentDays * Config.RentSystem.rentCostPerDay
    if Config.RentSystem.enabled and Player.PlayerData.money.cash < rentCost then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('insufficient_funds'), 'error')
        return
    end
    
    -- Create market stand
    local location = json.encode(data.location)
    local rent_expires = nil
    
    if Config.RentSystem.enabled then
        rent_expires = os.date('%Y-%m-%d %H:%M:%S', os.time() + (Config.RentSystem.defaultRentDays * 24 * 60 * 60))
        Player.Functions.RemoveMoney('cash', rentCost)
    end
    
    MySQL.Async.insert('INSERT INTO market_stands (owner_id, owner_name, name, location, zone_id, rent_expires) VALUES (?, ?, ?, ?, ?, ?)', {
        Player.PlayerData.citizenid,
        Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        data.name,
        location,
        data.zone_id,
        rent_expires
    }, function(standId)
        if standId then
            -- Add to memory
            MarketStands[standId] = {
                id = standId,
                owner_id = Player.PlayerData.citizenid,
                owner_name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
                name = data.name,
                location = data.location,
                zone_id = data.zone_id,
                status = 'active',
                rent_expires = rent_expires,
                created_at = os.date('%Y-%m-%d %H:%M:%S'),
                earnings = 0,
                total_sales = 0
            }
            
            -- Track player stands
            if not PlayerStands[Player.PlayerData.citizenid] then
                PlayerStands[Player.PlayerData.citizenid] = {}
            end
            table.insert(PlayerStands[Player.PlayerData.citizenid], standId)
            
            -- Log transaction
            if Config.RentSystem.enabled then
                LogTransaction(standId, Player.PlayerData.citizenid, Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname, 'rent_payment', nil, 1, rentCost, 'Initial rent payment')
            end
            
            TriggerClientEvent('QBCore:Notify', src, Lang:t('stand_created'), 'success')
            TriggerClientEvent('marketstand:client:standCreated', src, standId, MarketStands[standId])
            TriggerClientEvent('marketstand:client:refreshStands', -1)
        end
    end)
end)

RegisterNetEvent('marketstand:server:deleteStand', function(standId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local stand = MarketStands[standId]
    if not stand then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('stand_not_found'), 'error')
        return
    end
    
    if stand.owner_id ~= Player.PlayerData.citizenid then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('no_permission'), 'error')
        return
    end
    
    -- Delete from database
    MySQL.Async.execute('DELETE FROM market_stands WHERE id = ?', {standId})
    
    -- Remove from memory
    MarketStands[standId] = nil
    StandItems[standId] = nil
    StandStaff[standId] = nil
    
    -- Remove from player stands
    if PlayerStands[Player.PlayerData.citizenid] then
        for i, id in pairs(PlayerStands[Player.PlayerData.citizenid]) do
            if id == standId then
                table.remove(PlayerStands[Player.PlayerData.citizenid], i)
                break
            end
        end
    end
    
    TriggerClientEvent('QBCore:Notify', src, Lang:t('stand_deleted'), 'success')
    TriggerClientEvent('marketstand:client:standDeleted', src, standId)
    TriggerClientEvent('marketstand:client:refreshStands', -1)
end)

-- Item Management
RegisterNetEvent('marketstand:server:addItem', function(standId, itemData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local stand = MarketStands[standId]
    if not stand then return end
    
    -- Check permissions
    if not HasStandPermission(Player.PlayerData.citizenid, standId, 'manage') then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('no_permission'), 'error')
        return
    end
    
    -- Check if item is allowed
    if not Shared.IsItemAllowed(itemData.item_name) then
        TriggerClientEvent('QBCore:Notify', src, 'This item is not allowed to be sold', 'error')
        return
    end
    
    -- Check max items limit
    local currentItemCount = GetStandItemCount(standId)
    if currentItemCount >= Config.MaxItemsPerStand then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('max_items_reached'), 'error')
        return
    end
    
    -- Check if player has the item in inventory
    local hasItem = Player.Functions.GetItemByName(itemData.item_name)
    if not hasItem or hasItem.amount < itemData.stock then
        TriggerClientEvent('QBCore:Notify', src, 'You don\'t have enough items in your inventory', 'error')
        return
    end
    
    -- Remove items from player inventory
    Player.Functions.RemoveItem(itemData.item_name, itemData.stock)
    
    -- Add to database
    MySQL.Async.insert('INSERT INTO market_stand_items (stand_id, item_name, display_name, price, stock, max_stock, description) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        standId,
        itemData.item_name,
        itemData.display_name,
        itemData.price,
        itemData.stock,
        itemData.max_stock or 100,
        itemData.description or ''
    }, function(itemId)
        if itemId then
            -- Add to memory
            if not StandItems[standId] then
                StandItems[standId] = {}
            end
            StandItems[standId][itemData.item_name] = {
                id = itemId,
                stand_id = standId,
                item_name = itemData.item_name,
                display_name = itemData.display_name,
                price = itemData.price,
                stock = itemData.stock,
                max_stock = itemData.max_stock or 100,
                description = itemData.description or ''
            }
            
            TriggerClientEvent('QBCore:Notify', src, Lang:t('item_added'), 'success')
            TriggerClientEvent('marketstand:client:refreshStandItems', -1, standId)
        end
    end)
end)

RegisterNetEvent('marketstand:server:removeItem', function(standId, itemName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Check permissions
    if not HasStandPermission(Player.PlayerData.citizenid, standId, 'manage') then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('no_permission'), 'error')
        return
    end
    
    local standItems = StandItems[standId]
    if not standItems or not standItems[itemName] then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('item_not_available'), 'error')
        return
    end
    
    local item = standItems[itemName]
    
    -- Return remaining stock to player
    if item.stock > 0 then
        Player.Functions.AddItem(itemName, item.stock)
    end
    
    -- Remove from database
    MySQL.Async.execute('DELETE FROM market_stand_items WHERE id = ?', {item.id})
    
    -- Remove from memory
    StandItems[standId][itemName] = nil
    
    TriggerClientEvent('QBCore:Notify', src, Lang:t('item_removed'), 'success')
    TriggerClientEvent('marketstand:client:refreshStandItems', -1, standId)
end)

-- Purchase System
RegisterNetEvent('marketstand:server:purchaseItem', function(standId, itemName, quantity)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local stand = MarketStands[standId]
    if not stand or stand.status ~= 'active' then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('stand_not_found'), 'error')
        return
    end
    
    local standItems = StandItems[standId]
    if not standItems or not standItems[itemName] then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('item_not_available'), 'error')
        return
    end
    
    local item = standItems[itemName]
    if item.stock < quantity then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('insufficient_stock'), 'error')
        return
    end
    
    local totalCost = item.price * quantity
    if Player.PlayerData.money.cash < totalCost then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('insufficient_funds'), 'error')
        return
    end
    
    -- Exploit protection
    if Config.ExploitProtection.enabled then
        if totalCost > Config.ExploitProtection.maxMoneyPerTransaction then
            TriggerClientEvent('QBCore:Notify', src, 'Transaction amount too high', 'error')
            return
        end
        
        -- Check transaction frequency
        if not CheckTransactionFrequency(Player.PlayerData.citizenid) then
            TriggerClientEvent('QBCore:Notify', src, 'You are making transactions too frequently', 'error')
            return
        end
    end
    
    -- Process transaction
    Player.Functions.RemoveMoney('cash', totalCost)
    Player.Functions.AddItem(itemName, quantity)
    
    -- Update stock
    item.stock = item.stock - quantity
    MySQL.Async.execute('UPDATE market_stand_items SET stock = ? WHERE id = ?', {item.stock, item.id})
    
    -- Update stand earnings
    stand.earnings = stand.earnings + totalCost
    stand.total_sales = stand.total_sales + quantity
    MySQL.Async.execute('UPDATE market_stands SET earnings = ?, total_sales = ? WHERE id = ?', {stand.earnings, stand.total_sales, standId})
    
    -- Pay stand owner (if online)
    local Owner = QBCore.Functions.GetPlayerByCitizenId(stand.owner_id)
    if Owner then
        Owner.Functions.AddMoney('cash', totalCost)
        TriggerClientEvent('QBCore:Notify', Owner.PlayerData.source, string.format('Market Stand Sale: +%s', Shared.FormatMoney(totalCost)), 'success')
    end
    
    -- Log transaction
    LogTransaction(standId, Player.PlayerData.citizenid, Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname, 'purchase', itemName, quantity, totalCost, 'Item purchase')
    
    TriggerClientEvent('QBCore:Notify', src, Lang:t('item_purchased'), 'success')
    TriggerClientEvent('marketstand:client:refreshStandItems', -1, standId)
end)

-- Staff Management
RegisterNetEvent('marketstand:server:hireStaff', function(standId, targetId, staffData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(targetId)
    
    if not Player or not Target then return end
    
    local stand = MarketStands[standId]
    if not stand or stand.owner_id ~= Player.PlayerData.citizenid then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('no_permission'), 'error')
        return
    end
    
    -- Check max staff limit
    local currentStaffCount = GetStandStaffCount(standId)
    if currentStaffCount >= Config.StaffSystem.maxStaffPerStand then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('max_staff_reached'), 'error')
        return
    end
    
    -- Check if player is already staff
    if StandStaff[standId] and StandStaff[standId][Target.PlayerData.citizenid] then
        TriggerClientEvent('QBCore:Notify', src, 'Player is already hired as staff', 'error')
        return
    end
    
    -- Add to database
    MySQL.Async.insert('INSERT INTO market_stand_staff (stand_id, player_id, player_name, role, wage_per_hour, working_hours) VALUES (?, ?, ?, ?, ?, ?)', {
        standId,
        Target.PlayerData.citizenid,
        Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname,
        staffData.role,
        staffData.wage_per_hour,
        json.encode(staffData.working_hours)
    }, function(staffId)
        if staffId then
            -- Add to memory
            if not StandStaff[standId] then
                StandStaff[standId] = {}
            end
            StandStaff[standId][Target.PlayerData.citizenid] = {
                id = staffId,
                stand_id = standId,
                player_id = Target.PlayerData.citizenid,
                player_name = Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname,
                role = staffData.role,
                wage_per_hour = staffData.wage_per_hour,
                working_hours = staffData.working_hours,
                hired_at = os.date('%Y-%m-%d %H:%M:%S'),
                is_active = true
            }
            
            TriggerClientEvent('QBCore:Notify', src, Lang:t('staff_hired'), 'success')
            TriggerClientEvent('QBCore:Notify', targetId, string.format('You have been hired at %s', stand.name), 'success')
        end
    end)
end)

-- Utility Functions
function GetPlayerStandCount(citizenid)
    if not PlayerStands[citizenid] then return 0 end
    return #PlayerStands[citizenid]
end

function GetStandItemCount(standId)
    if not StandItems[standId] then return 0 end
    local count = 0
    for _ in pairs(StandItems[standId]) do
        count = count + 1
    end
    return count
end

function GetStandStaffCount(standId)
    if not StandStaff[standId] then return 0 end
    local count = 0
    for _ in pairs(StandStaff[standId]) do
        count = count + 1
    end
    return count
end

function HasStandPermission(citizenid, standId, action)
    local stand = MarketStands[standId]
    if not stand then return false end
    
    -- Owner has all permissions
    if stand.owner_id == citizenid then return true end
    
    -- Check staff permissions
    if StandStaff[standId] and StandStaff[standId][citizenid] then
        local staff = StandStaff[standId][citizenid]
        if action == 'sell' then
            return true -- All staff can sell
        elseif action == 'manage' then
            return staff.role == 'manager'
        end
    end
    
    return false
end

function IsPlayerInSellingZone(coords)
    for i, zone in pairs(Config.SellingZones.zones) do
        local distance = Shared.GetDistance(coords, zone.coords)
        if distance <= zone.radius then
            return true, i
        end
    end
    return false, nil
end

function IsZoneFull(zoneId)
    local zone = Config.SellingZones.zones[zoneId]
    if not zone then return true end
    
    local count = 0
    for _, stand in pairs(MarketStands) do
        if stand.zone_id == zoneId and stand.status == 'active' then
            count = count + 1
        end
    end
    
    return count >= zone.max_stands
end

function LogTransaction(standId, playerId, playerName, transactionType, itemName, quantity, amount, description)
    MySQL.Async.insert('INSERT INTO market_stand_transactions (stand_id, player_id, player_name, transaction_type, item_name, quantity, amount, description) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        standId, playerId, playerName, transactionType, itemName, quantity, amount, description
    })
end

function CheckTransactionFrequency(citizenid)
    -- Simple implementation - could be enhanced with more sophisticated tracking
    return true
end

-- Rent System
function StartRentChecker()
    CreateThread(function()
        while true do
            Wait(Config.RentSystem.checkInterval * 60 * 1000) -- Convert minutes to milliseconds
            CheckExpiredRent()
        end
    end)
end

function CheckExpiredRent()
    local currentTime = os.time()
    for standId, stand in pairs(MarketStands) do
        if stand.rent_expires then
            local expiryTime = GetTimestamp(stand.rent_expires)
            local timeLeft = expiryTime - currentTime
            
            -- Warn before expiry
            if timeLeft > 0 and timeLeft <= (Config.RentSystem.warningDaysBeforeExpiry * 24 * 60 * 60) then
                local daysLeft = math.ceil(timeLeft / (24 * 60 * 60))
                local Owner = QBCore.Functions.GetPlayerByCitizenId(stand.owner_id)
                if Owner then
                    TriggerClientEvent('QBCore:Notify', Owner.PlayerData.source, string.format(Lang:t('rent_expires_soon'), daysLeft), 'warning')
                end
            end
            
            -- Expire stand
            if timeLeft <= 0 and stand.status ~= 'expired' then
                stand.status = 'expired'
                MySQL.Async.execute('UPDATE market_stands SET status = ? WHERE id = ?', {'expired', standId})
                
                local Owner = QBCore.Functions.GetPlayerByCitizenId(stand.owner_id)
                if Owner then
                    TriggerClientEvent('QBCore:Notify', Owner.PlayerData.source, Lang:t('rent_expired'), 'error')
                end
            end
        end
    end
end

function GetTimestamp(dateString)
    local pattern = "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)"
    local year, month, day, hour, min, sec = dateString:match(pattern)
    return os.time({year=year, month=month, day=day, hour=hour, min=min, sec=sec})
end

-- Callbacks
QBCore.Functions.CreateCallback('marketstand:server:getStands', function(source, cb)
    cb(MarketStands)
end)

QBCore.Functions.CreateCallback('marketstand:server:getStandItems', function(source, cb, standId)
    cb(StandItems[standId] or {})
end)

QBCore.Functions.CreateCallback('marketstand:server:getPlayerStands', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb({}) return end
    
    local playerStands = {}
    if PlayerStands[Player.PlayerData.citizenid] then
        for _, standId in pairs(PlayerStands[Player.PlayerData.citizenid]) do
            playerStands[standId] = MarketStands[standId]
        end
    end
    cb(playerStands)
end)