DROP DATABASE IF EXISTS isucon2;
CREATE DATABASE isucon2 DEFAULT CHARACTER SET 'utf8';

GRANT ALL ON isucon2.* TO 'isucon2app'@'%' IDENTIFIED BY 'isunageruna';
GRANT ALL ON isucon2.* TO 'isucon2app'@'localhost' IDENTIFIED BY 'isunageruna';

FLUSH PRIVILEGES;

CREATE TABLE IF NOT EXISTS isucon2.artist (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(255) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS isucon2.ticket (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `count` INT UNSIGNED DEFAULT '0',
  `name` VARCHAR(255) NOT NULL,
  `artist_id` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS isucon2.variation (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(255) NOT NULL,
  `ticket_id` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS isucon2.stock (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `variation_id` INT UNSIGNED NOT NULL,
  `seat_id` VARCHAR(255) NOT NULL,
  `order_id` INT UNSIGNED DEFAULT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `variation_seat` (`variation_id`,`seat_id`),
  KEY `idx` (`order_id`,`seat_id`,`variation_id`)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS isucon2.order_request (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `member_id` VARCHAR(32) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `member_order` (`member_id`)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS isucon2.recent_sold (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `seat_id` VARCHAR(255) NOT NULL,
  `order_id` int(10) unsigned DEFAULT NULL,
  `a_name` varchar(255) NOT NULL,
  `t_name` varchar(255) NOT NULL,
  `v_name` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `order_id` (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
