-- Market Stand Database Tables for Qbox Compatibility

-- Market Stands Table
CREATE TABLE IF NOT EXISTS `market_stands` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `owner_id` varchar(50) NOT NULL,
    `owner_name` varchar(100) NOT NULL,
    `name` varchar(100) NOT NULL,
    `location` longtext NOT NULL,
    `zone_id` int(11) DEFAULT NULL,
    `status` enum('active','inactive','expired','suspended') DEFAULT 'active',
    `rent_expires` datetime DEFAULT NULL,
    `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
    `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `earnings` int(11) DEFAULT 0,
    `total_sales` int(11) DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `owner_id` (`owner_id`),
    KEY `status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Market Stand Items Table
CREATE TABLE IF NOT EXISTS `market_stand_items` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `stand_id` int(11) NOT NULL,
    `item_name` varchar(50) NOT NULL,
    `display_name` varchar(100) NOT NULL,
    `price` int(11) NOT NULL,
    `stock` int(11) NOT NULL DEFAULT 0,
    `max_stock` int(11) NOT NULL DEFAULT 100,
    `description` text DEFAULT NULL,
    `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
    `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `stand_id` (`stand_id`),
    KEY `item_name` (`item_name`),
    FOREIGN KEY (`stand_id`) REFERENCES `market_stands`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Market Stand Staff Table
CREATE TABLE IF NOT EXISTS `market_stand_staff` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `stand_id` int(11) NOT NULL,
    `player_id` varchar(50) NOT NULL,
    `player_name` varchar(100) NOT NULL,
    `role` enum('seller','manager') DEFAULT 'seller',
    `wage_per_hour` int(11) NOT NULL DEFAULT 50,
    `working_hours` longtext NOT NULL,
    `hired_at` datetime DEFAULT CURRENT_TIMESTAMP,
    `is_active` tinyint(1) DEFAULT 1,
    PRIMARY KEY (`id`),
    KEY `stand_id` (`stand_id`),
    KEY `player_id` (`player_id`),
    FOREIGN KEY (`stand_id`) REFERENCES `market_stands`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Market Stand Transactions Table
CREATE TABLE IF NOT EXISTS `market_stand_transactions` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `stand_id` int(11) NOT NULL,
    `player_id` varchar(50) NOT NULL,
    `player_name` varchar(100) NOT NULL,
    `transaction_type` enum('purchase','sale','rent_payment','staff_wage','penalty','transfer_fee') NOT NULL,
    `item_name` varchar(50) DEFAULT NULL,
    `quantity` int(11) DEFAULT 1,
    `amount` int(11) NOT NULL,
    `description` text DEFAULT NULL,
    `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `stand_id` (`stand_id`),
    KEY `player_id` (`player_id`),
    KEY `transaction_type` (`transaction_type`),
    KEY `created_at` (`created_at`),
    FOREIGN KEY (`stand_id`) REFERENCES `market_stands`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Market Stand Penalties Table
CREATE TABLE IF NOT EXISTS `market_stand_penalties` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `stand_id` int(11) NOT NULL,
    `issued_by` varchar(50) NOT NULL,
    `issued_by_name` varchar(100) NOT NULL,
    `reason` text NOT NULL,
    `amount` int(11) NOT NULL,
    `is_paid` tinyint(1) DEFAULT 0,
    `items_confiscated` longtext DEFAULT NULL,
    `issued_at` datetime DEFAULT CURRENT_TIMESTAMP,
    `paid_at` datetime DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `stand_id` (`stand_id`),
    KEY `is_paid` (`is_paid`),
    FOREIGN KEY (`stand_id`) REFERENCES `market_stands`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Market Stand Rent History Table
CREATE TABLE IF NOT EXISTS `market_stand_rent_history` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `stand_id` int(11) NOT NULL,
    `days_paid` int(11) NOT NULL,
    `amount_paid` int(11) NOT NULL,
    `paid_by` varchar(50) NOT NULL,
    `paid_by_name` varchar(100) NOT NULL,
    `expires_at` datetime NOT NULL,
    `paid_at` datetime DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `stand_id` (`stand_id`),
    KEY `expires_at` (`expires_at`),
    FOREIGN KEY (`stand_id`) REFERENCES `market_stands`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Market Stand Zones Table (for managing selling zones)
CREATE TABLE IF NOT EXISTS `market_zones` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `name` varchar(100) NOT NULL,
    `coords` longtext NOT NULL,
    `radius` float NOT NULL,
    `max_stands` int(11) NOT NULL DEFAULT 10,
    `current_stands` int(11) NOT NULL DEFAULT 0,
    `is_active` tinyint(1) DEFAULT 1,
    `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Insert default selling zones
INSERT INTO `market_zones` (`name`, `coords`, `radius`, `max_stands`, `is_active`) VALUES
('Legion Square Market', '{"x": 195.17, "y": -934.75, "z": 30.69}', 50.0, 10, 1),
('Sandy Shores Market', '{"x": 1961.21, "y": 3750.48, "z": 32.34}', 30.0, 5, 1),
('Paleto Bay Market', '{"x": -276.25, "y": 6228.06, "z": 31.70}', 25.0, 3, 1);