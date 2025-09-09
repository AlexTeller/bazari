Config = {}

-- General Settings
Config.Framework = 'qb-core' -- 'qb-core' or 'qbox'
Config.Debug = false
Config.Locale = 'en'

-- Database Settings
Config.UseOxMySQL = true

-- Market Stand Settings
Config.MaxMarketStands = 50 -- Maximum number of market stands on server
Config.MaxItemsPerStand = 20 -- Maximum items per market stand
Config.MaxStandsPerPlayer = 3 -- Maximum stands per player

-- Rent System
Config.RentSystem = {
    enabled = true,
    defaultRentDays = 7, -- Default rent days when creating stand
    maxRentDays = 30, -- Maximum rent days allowed
    rentCostPerDay = 100, -- Cost per day in money
    warningDaysBeforeExpiry = 2, -- Days before expiry to warn player
    checkInterval = 60 -- Minutes between rent checks
}

-- Staff System
Config.StaffSystem = {
    enabled = true,
    maxStaffPerStand = 5,
    staffWagePerHour = 50,
    workingHours = {
        min = 8, -- 8 AM
        max = 22 -- 10 PM
    }
}

-- Selling Zones
Config.SellingZones = {
    enabled = true, -- If false, players can place stands anywhere
    zones = {
        {
            name = "Legion Square Market",
            coords = vector3(195.17, -934.75, 30.69),
            radius = 50.0,
            blip = true,
            maxStands = 10
        },
        {
            name = "Sandy Shores Market",
            coords = vector3(1961.21, 3750.48, 32.34),
            radius = 30.0,
            blip = true,
            maxStands = 5
        },
        {
            name = "Paleto Bay Market",
            coords = vector3(-276.25, 6228.06, 31.70),
            radius = 25.0,
            blip = true,
            maxStands = 3
        }
    }
}

-- Penalty System
Config.PenaltySystem = {
    enabled = true,
    policeJobs = {'police', 'sheriff', 'state'}, -- Jobs that can issue penalties
    illegalItems = {
        'weed',
        'cocaine',
        'heroin',
        'methamphetamine',
        'lockpick',
        'weapon_pistol'
    },
    penaltyAmount = 1000, -- Fine amount for illegal items
    confiscateItems = true -- Whether to confiscate illegal items
}

-- Ownership Transfer
Config.OwnershipTransfer = {
    enabled = true,
    transferFee = 500, -- Fee charged for transferring ownership
    requireBothPlayersOnline = true
}

-- Target System Compatibility
Config.TargetSystem = 'ox_target' -- 'ox_target', 'qb-target', 'qtarget'

-- Context Menu Compatibility  
Config.ContextMenu = 'ox_lib' -- 'ox_lib', 'qb-menu', 'nh-context'

-- Input System Compatibility
Config.InputSystem = 'ox_lib' -- 'ox_lib', 'qb-input', 'nh-keyboard'

-- Market Stand Props
Config.StandProps = {
    'prop_market_stall01',
    'prop_market_stall02',
    'prop_market_stall03'
}

-- Allowed Items (can be sold at market stands)
Config.AllowedItems = {
    -- Food Items
    'burger', 'water', 'coffee', 'sandwich', 'apple', 'banana',
    -- Crafting Materials
    'plastic', 'metalscrap', 'rubber', 'glass',
    -- Electronics
    'phone', 'radio', 'tablet',
    -- Clothing
    'tshirt', 'jeans', 'sneakers', 'hat',
    -- Tools
    'repairkit', 'advancedrepairkit', 'cleaningkit'
}

-- Blip Settings
Config.Blips = {
    marketZone = {
        sprite = 52,
        color = 2,
        scale = 0.8,
        name = "Market Zone"
    },
    marketStand = {
        sprite = 500,
        color = 5,
        scale = 0.7,
        name = "Market Stand"
    }
}

-- Notifications
Config.Notifications = {
    type = 'ox_lib', -- 'ox_lib', 'qb-core', 'mythic_notify'
    position = 'top-right'
}

-- Exploit Protection
Config.ExploitProtection = {
    enabled = true,
    maxTransactionsPerMinute = 10,
    maxMoneyPerTransaction = 100000,
    logSuspiciousActivity = true
}