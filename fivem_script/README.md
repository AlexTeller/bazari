# Market Stand Script for FiveM - Qbox Compatible

A comprehensive market stand script for FiveM servers using the Qbox framework, featuring a dynamic player-driven economy, staff management, rent system, and multi-framework compatibility.

## 🌟 Features

### Core Features
- **Dynamic Player-Driven Economy**: Players create and manage their own market stands
- **Flexible Selling Zones**: Configure specific zones or allow placement anywhere
- **Staff Management**: Hire staff with working hours and wage system
- **Rent System**: Automatic rent expiry with warnings and extension options
- **Ownership Transfer**: Transfer stand ownership to other players
- **Penalty Enforcement**: Police can issue penalties for illegal items
- **Server Exploit Protection**: Built-in protection against exploits
- **Multi-Framework Compatibility**: Compatible with multiple target and menu systems

### Framework Compatibility
- **Target Systems**: ox_target, qb-target, qtarget
- **Context Menus**: ox_lib, qb-menu, nh-context
- **Input Systems**: ox_lib, qb-input, nh-keyboard
- **Notifications**: ox_lib, qb-core, mythic_notify

## 📦 Installation

### 1. Database Setup
Execute the SQL file to create the required database tables:
```sql
-- Run the content of sql/install.sql in your MySQL database
```

### 2. Resource Installation
1. Copy the `fivem_script` folder to your FiveM server's `resources` directory
2. Rename it to `market-stand` or your preferred name
3. Add `ensure market-stand` to your `server.cfg`

### 3. Dependencies
Ensure you have the following resources installed:
- **qb-core** or **qbox** (framework)
- **oxmysql** (database)
- One of the supported target systems (ox_target, qb-target, qtarget)
- One of the supported menu systems (ox_lib, qb-menu, nh-context)

### 4. Configuration
Edit `config.lua` to customize the script according to your server needs:
- Set your framework type
- Configure selling zones
- Adjust rent prices and limits
- Set staff wages and limits
- Configure penalty system

## 🎮 Usage

### Player Commands
- `/createstand` - Create a new market stand
- `/myStands` - View and manage your market stands

### Admin Commands (via web panel)
- Manage all market stands
- View statistics and earnings
- Update stand statuses
- Delete problematic stands

### Player Actions
1. **Creating a Stand**: Use `/createstand` in a designated selling zone
2. **Managing Items**: Interact with your stand to add/remove items
3. **Hiring Staff**: Hire other players to work at your stand
4. **Paying Rent**: Extend your stand's rent to keep it active
5. **Transferring Ownership**: Sell your stand to another player

## 🗃️ Database Schema

### Main Tables
- `market_stands` - Store market stand information
- `market_stand_items` - Items available at each stand
- `market_stand_staff` - Staff members and their details
- `market_stand_transactions` - All transaction history
- `market_stand_penalties` - Police-issued penalties
- `market_stand_rent_history` - Rent payment history
- `market_zones` - Selling zone configurations

## 🔧 Configuration Options

### Key Configuration Settings

```lua
-- Framework Settings
Config.Framework = 'qb-core' -- 'qb-core' or 'qbox'
Config.TargetSystem = 'ox_target' -- 'ox_target', 'qb-target', 'qtarget'
Config.ContextMenu = 'ox_lib' -- 'ox_lib', 'qb-menu', 'nh-context'

-- Limits
Config.MaxMarketStands = 50 -- Server-wide limit
Config.MaxStandsPerPlayer = 3 -- Per player limit
Config.MaxItemsPerStand = 20 -- Items per stand

-- Rent System
Config.RentSystem = {
    enabled = true,
    defaultRentDays = 7,
    rentCostPerDay = 100,
    warningDaysBeforeExpiry = 2
}

-- Staff System
Config.StaffSystem = {
    enabled = true,
    maxStaffPerStand = 5,
    staffWagePerHour = 50
}
```

### Selling Zones
Configure predefined selling zones or disable to allow placement anywhere:

```lua
Config.SellingZones = {
    enabled = true, -- Set to false for anywhere placement
    zones = {
        {
            name = "Legion Square Market",
            coords = vector3(195.17, -934.75, 30.69),
            radius = 50.0,
            maxStands = 10
        }
    }
}
```

## 🌐 Web Admin Panel

The script includes a comprehensive web-based admin panel built with React and FastAPI.

### Features
- **Dashboard**: Overview statistics and recent transactions
- **Stand Management**: View, edit, and delete market stands
- **Real-time Updates**: Live data from the game server
- **Status Management**: Change stand statuses (active, inactive, suspended, expired)

### Access
The web panel runs on your configured backend URL and provides:
- Market stand statistics
- Transaction history
- Administrative controls
- Stand status management

## 🔒 Security Features

### Exploit Protection
- Transaction frequency limits
- Maximum transaction amount limits
- Suspicious activity logging
- Input validation and sanitization

### Permission System
- Role-based access control
- Owner/staff/customer permissions
- Police-specific actions for penalty system

## 🚀 Advanced Features

### Staff Management
- Hire players as staff members
- Set individual wages and working hours
- Role-based permissions (seller, manager)
- Automatic wage calculations

### Penalty System
- Police can inspect stands for illegal items
- Configurable penalty amounts
- Item confiscation system
- Stand suspension for unpaid penalties

### Rent System
- Automatic rent expiry checks
- Warning notifications before expiry
- Flexible rent extension options
- Rent payment history tracking

## 🔄 Multi-Framework Support

The script automatically detects and adapts to your server's installed frameworks:

### Supported Target Systems
- **ox_target**: Modern and efficient targeting
- **qb-target**: QB-Core's built-in targeting
- **qtarget**: Alternative targeting system

### Supported Menu Systems
- **ox_lib**: Modern UI with ox_lib
- **qb-menu**: QB-Core's menu system
- **nh-context**: NoHabbit's context menu

## 📊 API Endpoints

The backend provides RESTful API endpoints for the web admin panel:

- `GET /api/market-stands` - Get all market stands
- `GET /api/market-stands/{id}` - Get specific stand
- `GET /api/market-stands/{id}/items` - Get stand items
- `GET /api/market-stands/{id}/staff` - Get stand staff
- `GET /api/market-stands/{id}/transactions` - Get transactions
- `GET /api/dashboard/stats` - Get dashboard statistics
- `DELETE /api/market-stands/{id}` - Delete stand (admin)
- `PUT /api/market-stands/{id}/status` - Update stand status

## 🐛 Troubleshooting

### Common Issues

1. **Database Connection**: Ensure MySQL credentials are correct in the backend `.env` file
2. **Framework Detection**: Verify the correct framework is set in `config.lua`
3. **Resource Dependencies**: Make sure all required resources are installed and started
4. **Permissions**: Check that the database user has proper permissions

### Debug Mode
Enable debug mode in `config.lua` for detailed logging:
```lua
Config.Debug = true
```

## 📝 License

This Market Stand Script is created for FiveM servers and is compatible with the Qbox framework. 

## 🤝 Support

For support and updates, please refer to the documentation or contact the development team.

---

**Version**: 1.0  
**Compatibility**: FiveM, Qbox Framework, QB-Core  
**Requirements**: MySQL, oxmysql, target system, menu system  
**Created**: 2025