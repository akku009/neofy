-- Run as MySQL root: mysql -u root -p < setup_db.sql
-- Creates the production database and a dedicated app user.

CREATE DATABASE IF NOT EXISTS neofy_production
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- Use a strong password — store in .env as DATABASE_PASSWORD
CREATE USER IF NOT EXISTS 'neofy'@'localhost'
  IDENTIFIED BY 'CHANGE_THIS_STRONG_PASSWORD';

GRANT ALL PRIVILEGES ON neofy_production.* TO 'neofy'@'localhost';

-- Read-only user for analytics/reporting queries
CREATE USER IF NOT EXISTS 'neofy_readonly'@'localhost'
  IDENTIFIED BY 'CHANGE_THIS_READONLY_PASSWORD';

GRANT SELECT ON neofy_production.* TO 'neofy_readonly'@'localhost';

FLUSH PRIVILEGES;

SELECT 'Database setup complete' AS status;
