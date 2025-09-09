Shared = {}

-- Market Stand Status
Shared.StandStatus = {
    ACTIVE = 'active',
    INACTIVE = 'inactive',
    EXPIRED = 'expired',
    SUSPENDED = 'suspended'
}

-- Transaction Types
Shared.TransactionTypes = {
    PURCHASE = 'purchase',
    SALE = 'sale',
    RENT_PAYMENT = 'rent_payment',
    STAFF_WAGE = 'staff_wage',
    PENALTY = 'penalty',
    TRANSFER_FEE = 'transfer_fee'
}

-- Staff Roles
Shared.StaffRoles = {
    SELLER = 'seller',
    MANAGER = 'manager'
}

-- Permission Levels
Shared.PermissionLevels = {
    OWNER = 'owner',
    STAFF = 'staff',
    CUSTOMER = 'customer'
}

-- Market Stand Data Structure
Shared.MarketStandData = {
    id = nil,
    owner_id = nil,
    owner_name = nil,
    name = nil,
    location = {x = 0, y = 0, z = 0, h = 0},
    zone_id = nil,
    status = Shared.StandStatus.ACTIVE,
    rent_expires = nil,
    created_at = nil,
    updated_at = nil,
    staff = {},
    items = {},
    earnings = 0,
    total_sales = 0
}

-- Item Data Structure
Shared.ItemData = {
    item_name = nil,
    display_name = nil,
    price = 0,
    stock = 0,
    max_stock = 100,
    description = nil
}

-- Staff Data Structure
Shared.StaffData = {
    id = nil,
    stand_id = nil,
    player_id = nil,
    player_name = nil,
    role = Shared.StaffRoles.SELLER,
    wage_per_hour = 0,
    working_hours = {start = 8, end = 20},
    hired_at = nil,
    is_active = true
}

-- Utility Functions
function Shared.Round(num, decimals)
    local mult = 10^(decimals or 0)
    return math.floor(num * mult + 0.5) / mult
end

function Shared.FormatMoney(amount)
    return '$' .. string.format("%d", amount)
end

function Shared.GetDistance(pos1, pos2)
    return #(vector3(pos1.x, pos1.y, pos1.z) - vector3(pos2.x, pos2.y, pos2.z))
end

function Shared.IsPlayerInZone(playerCoords, zone)
    local distance = Shared.GetDistance(playerCoords, zone.coords)
    return distance <= zone.radius
end

function Shared.GenerateUniqueId()
    return tostring(os.time()) .. tostring(math.random(1000, 9999))
end

function Shared.IsItemAllowed(itemName)
    for _, allowedItem in pairs(Config.AllowedItems) do
        if allowedItem == itemName then
            return true
        end
    end
    return false
end

function Shared.IsItemIllegal(itemName)
    for _, illegalItem in pairs(Config.PenaltySystem.illegalItems) do
        if illegalItem == itemName then
            return true
        end
    end
    return false
end