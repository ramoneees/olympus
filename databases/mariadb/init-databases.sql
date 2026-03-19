-- Run after MariaDB is up to create per-service databases and users
-- kubectl exec -it mariadb-0 -n databases -- mariadb -u root -p

-- Nextcloud
CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER 'nextcloud'@'%' IDENTIFIED BY 'CHANGE_ME';
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'%';

-- Firefly III
CREATE DATABASE firefly CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER 'firefly'@'%' IDENTIFIED BY 'CHANGE_ME';
GRANT ALL PRIVILEGES ON firefly.* TO 'firefly'@'%';

-- Invoice Ninja
CREATE DATABASE invoiceninja CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER 'invoiceninja'@'%' IDENTIFIED BY 'CHANGE_ME';
GRANT ALL PRIVILEGES ON invoiceninja.* TO 'invoiceninja'@'%';

FLUSH PRIVILEGES;
