-- ============================================================
-- Tukita Queen - MySQL database schema
-- Version: 1.0
-- Notes:
--   - Base design only. No triggers, procedures, or advanced logic.
--   - Uses utf8mb4 for Spanish text, usernames, and symbols.
--   - Import this file in MySQL before connecting the website.
-- ============================================================

CREATE DATABASE IF NOT EXISTS tukita_queen
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE tukita_queen;

-- ============================================================
-- 1. Users and profiles
-- ============================================================

CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  username VARCHAR(50) NOT NULL,
  email VARCHAR(150) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  terms_accepted_at DATETIME NULL,
  status ENUM('active', 'pending', 'blocked', 'deleted') NOT NULL DEFAULT 'pending',
  email_verified_at DATETIME NULL,
  last_login_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_username (username),
  UNIQUE KEY uq_users_email (email),
  KEY idx_users_status (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS user_profiles (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  display_name VARCHAR(80) NULL,
  avatar_url VARCHAR(255) NULL,
  country VARCHAR(80) NULL,
  city VARCHAR(80) NULL,
  steam_id VARCHAR(80) NULL,
  discord_username VARCHAR(80) NULL,
  dota_mmr INT UNSIGNED NULL,
  bio TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_user_profiles_user_id (user_id),
  UNIQUE KEY uq_user_profiles_steam_id (steam_id),
  CONSTRAINT fk_user_profiles_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- 2. Dota 2 roles
-- ============================================================

CREATE TABLE IF NOT EXISTS dota_roles (
  id TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code VARCHAR(20) NOT NULL,
  name VARCHAR(40) NOT NULL,
  position_number TINYINT UNSIGNED NULL,
  description VARCHAR(255) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_dota_roles_code (code)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS user_dota_roles (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  dota_role_id TINYINT UNSIGNED NOT NULL,
  is_main_role TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_user_dota_roles_user_role (user_id, dota_role_id),
  KEY idx_user_dota_roles_role (dota_role_id),
  CONSTRAINT fk_user_dota_roles_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_user_dota_roles_role
    FOREIGN KEY (dota_role_id) REFERENCES dota_roles(id)
    ON DELETE RESTRICT
) ENGINE=InnoDB;

INSERT INTO dota_roles (code, name, position_number, description) VALUES
  ('carry', 'Carry', 1, 'Main farming core role'),
  ('mid', 'Mid', 2, 'Solo middle core role'),
  ('offlane', 'Offlane', 3, 'Durable core or initiator role'),
  ('soft_support', 'Soft Support', 4, 'Roaming support role'),
  ('hard_support', 'Hard Support', 5, 'Main support and vision role')
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  position_number = VALUES(position_number),
  description = VALUES(description);

-- ============================================================
-- 3. Registration referrals and promo codes
-- ============================================================

CREATE TABLE IF NOT EXISTS promo_codes (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  code VARCHAR(32) NOT NULL,
  type ENUM('referral', 'campaign') NOT NULL DEFAULT 'referral',
  status ENUM('active', 'paused', 'expired') NOT NULL DEFAULT 'active',
  uses_count INT UNSIGNED NOT NULL DEFAULT 0,
  max_uses INT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_promo_codes_code (code),
  KEY idx_promo_codes_user (user_id),
  KEY idx_promo_codes_status (status),
  CONSTRAINT fk_promo_codes_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS referrals (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  referrer_user_id BIGINT UNSIGNED NOT NULL,
  referred_user_id BIGINT UNSIGNED NOT NULL,
  promo_code_id BIGINT UNSIGNED NOT NULL,
  status ENUM('registered', 'qualified', 'rewarded', 'cancelled') NOT NULL DEFAULT 'registered',
  reward_status ENUM('none', 'pending', 'approved', 'paid') NOT NULL DEFAULT 'none',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_referrals_referred_user (referred_user_id),
  KEY idx_referrals_referrer (referrer_user_id),
  KEY idx_referrals_code (promo_code_id),
  CONSTRAINT fk_referrals_referrer
    FOREIGN KEY (referrer_user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_referrals_referred
    FOREIGN KEY (referred_user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_referrals_code
    FOREIGN KEY (promo_code_id) REFERENCES promo_codes(id)
    ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS referral_stats (
  user_id BIGINT UNSIGNED NOT NULL,
  invited_count INT UNSIGNED NOT NULL DEFAULT 0,
  qualified_count INT UNSIGNED NOT NULL DEFAULT 0,
  rewards_pending INT UNSIGNED NOT NULL DEFAULT 0,
  rewards_paid INT UNSIGNED NOT NULL DEFAULT 0,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id),
  CONSTRAINT fk_referral_stats_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS referral_rewards (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  referral_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  reward_type VARCHAR(60) NOT NULL DEFAULT 'future_reward',
  reward_value DECIMAL(10,2) NULL,
  description VARCHAR(255) NULL,
  status ENUM('pending', 'approved', 'paid', 'cancelled') NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  paid_at DATETIME NULL,
  PRIMARY KEY (id),
  KEY idx_referral_rewards_referral (referral_id),
  KEY idx_referral_rewards_user (user_id),
  KEY idx_referral_rewards_status (status),
  CONSTRAINT fk_referral_rewards_referral
    FOREIGN KEY (referral_id) REFERENCES referrals(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_referral_rewards_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- 4. Rooms and room players
-- ============================================================

CREATE TABLE IF NOT EXISTS rooms (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  owner_user_id BIGINT UNSIGNED NULL,
  name VARCHAR(100) NOT NULL,
  slug VARCHAR(120) NOT NULL,
  description TEXT NULL,
  game_mode VARCHAR(60) NULL,
  max_players TINYINT UNSIGNED NOT NULL DEFAULT 10,
  status ENUM('open', 'full', 'in_game', 'closed', 'cancelled') NOT NULL DEFAULT 'open',
  starts_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_rooms_slug (slug),
  KEY idx_rooms_status (status),
  KEY idx_rooms_owner (owner_user_id),
  CONSTRAINT fk_rooms_owner
    FOREIGN KEY (owner_user_id) REFERENCES users(id)
    ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS room_players (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  room_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  dota_role_id TINYINT UNSIGNED NULL,
  team_name VARCHAR(60) NULL,
  slot_number TINYINT UNSIGNED NULL,
  status ENUM('joined', 'ready', 'left', 'kicked') NOT NULL DEFAULT 'joined',
  joined_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  left_at DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_room_players_room_user (room_id, user_id),
  KEY idx_room_players_user (user_id),
  KEY idx_room_players_role (dota_role_id),
  CONSTRAINT fk_room_players_room
    FOREIGN KEY (room_id) REFERENCES rooms(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_room_players_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_room_players_role
    FOREIGN KEY (dota_role_id) REFERENCES dota_roles(id)
    ON DELETE SET NULL
) ENGINE=InnoDB;

-- ============================================================
-- 5. Tournaments
-- ============================================================

CREATE TABLE IF NOT EXISTS tournaments (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(120) NOT NULL,
  slug VARCHAR(140) NOT NULL,
  description TEXT NULL,
  format VARCHAR(80) NULL,
  max_teams SMALLINT UNSIGNED NULL,
  max_players SMALLINT UNSIGNED NULL,
  entry_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  prize_pool DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  status ENUM('draft', 'registration_open', 'registration_closed', 'live', 'finished', 'cancelled') NOT NULL DEFAULT 'draft',
  registration_starts_at DATETIME NULL,
  registration_ends_at DATETIME NULL,
  starts_at DATETIME NULL,
  ends_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tournaments_slug (slug),
  KEY idx_tournaments_status (status),
  KEY idx_tournaments_dates (starts_at, ends_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tournament_players (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  tournament_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  team_name VARCHAR(100) NULL,
  status ENUM('registered', 'confirmed', 'disqualified', 'cancelled') NOT NULL DEFAULT 'registered',
  registered_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tournament_players_tournament_user (tournament_id, user_id),
  KEY idx_tournament_players_user (user_id),
  CONSTRAINT fk_tournament_players_tournament
    FOREIGN KEY (tournament_id) REFERENCES tournaments(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_tournament_players_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- 6. Ranking
-- ============================================================

CREATE TABLE IF NOT EXISTS rankings (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  season_name VARCHAR(80) NOT NULL DEFAULT 'General',
  points INT NOT NULL DEFAULT 0,
  wins INT UNSIGNED NOT NULL DEFAULT 0,
  losses INT UNSIGNED NOT NULL DEFAULT 0,
  matches_played INT UNSIGNED NOT NULL DEFAULT 0,
  current_streak INT NOT NULL DEFAULT 0,
  last_match_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_rankings_user_season (user_id, season_name),
  KEY idx_rankings_points (season_name, points),
  CONSTRAINT fk_rankings_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- 7. Streams and events
-- ============================================================

CREATE TABLE IF NOT EXISTS streams (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  title VARCHAR(150) NOT NULL,
  platform ENUM('kick', 'youtube', 'tiktok', 'facebook', 'twitch', 'other') NOT NULL DEFAULT 'kick',
  stream_url VARCHAR(255) NOT NULL,
  thumbnail_url VARCHAR(255) NULL,
  status ENUM('scheduled', 'live', 'finished', 'cancelled') NOT NULL DEFAULT 'scheduled',
  starts_at DATETIME NULL,
  ends_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_streams_status (status),
  KEY idx_streams_starts_at (starts_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  title VARCHAR(150) NOT NULL,
  slug VARCHAR(170) NOT NULL,
  description TEXT NULL,
  event_type ENUM('community', 'stream', 'tournament', 'giveaway', 'special') NOT NULL DEFAULT 'community',
  location_url VARCHAR(255) NULL,
  status ENUM('draft', 'published', 'live', 'finished', 'cancelled') NOT NULL DEFAULT 'draft',
  starts_at DATETIME NULL,
  ends_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_events_slug (slug),
  KEY idx_events_status (status),
  KEY idx_events_dates (starts_at, ends_at)
) ENGINE=InnoDB;

-- ============================================================
-- 8. Prizes
-- ============================================================

CREATE TABLE IF NOT EXISTS prizes (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  tournament_id BIGINT UNSIGNED NULL,
  event_id BIGINT UNSIGNED NULL,
  name VARCHAR(120) NOT NULL,
  description TEXT NULL,
  prize_type ENUM('money', 'item', 'points', 'subscription', 'other') NOT NULL DEFAULT 'other',
  value_amount DECIMAL(10,2) NULL,
  value_currency CHAR(3) NOT NULL DEFAULT 'USD',
  quantity INT UNSIGNED NOT NULL DEFAULT 1,
  status ENUM('available', 'assigned', 'delivered', 'cancelled') NOT NULL DEFAULT 'available',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_prizes_tournament (tournament_id),
  KEY idx_prizes_event (event_id),
  KEY idx_prizes_status (status),
  CONSTRAINT fk_prizes_tournament
    FOREIGN KEY (tournament_id) REFERENCES tournaments(id)
    ON DELETE SET NULL,
  CONSTRAINT fk_prizes_event
    FOREIGN KEY (event_id) REFERENCES events(id)
    ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS prize_claims (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  prize_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  status ENUM('pending', 'approved', 'delivered', 'rejected') NOT NULL DEFAULT 'pending',
  notes TEXT NULL,
  claimed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  delivered_at DATETIME NULL,
  PRIMARY KEY (id),
  KEY idx_prize_claims_prize (prize_id),
  KEY idx_prize_claims_user (user_id),
  KEY idx_prize_claims_status (status),
  CONSTRAINT fk_prize_claims_prize
    FOREIGN KEY (prize_id) REFERENCES prizes(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_prize_claims_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- 9. Payments
-- ============================================================

CREATE TABLE IF NOT EXISTS payments (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  tournament_id BIGINT UNSIGNED NULL,
  payment_reference VARCHAR(120) NULL,
  provider VARCHAR(60) NULL,
  concept VARCHAR(120) NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  status ENUM('pending', 'paid', 'failed', 'refunded', 'cancelled') NOT NULL DEFAULT 'pending',
  paid_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_payments_reference (payment_reference),
  KEY idx_payments_user (user_id),
  KEY idx_payments_tournament (tournament_id),
  KEY idx_payments_status (status),
  CONSTRAINT fk_payments_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_payments_tournament
    FOREIGN KEY (tournament_id) REFERENCES tournaments(id)
    ON DELETE SET NULL
) ENGINE=InnoDB;

-- ============================================================
-- 10. Support
-- ============================================================

CREATE TABLE IF NOT EXISTS support_tickets (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NULL,
  subject VARCHAR(150) NOT NULL,
  category ENUM('account', 'payment', 'room', 'tournament', 'technical', 'other') NOT NULL DEFAULT 'other',
  priority ENUM('low', 'normal', 'high', 'urgent') NOT NULL DEFAULT 'normal',
  status ENUM('open', 'in_progress', 'answered', 'closed') NOT NULL DEFAULT 'open',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  closed_at DATETIME NULL,
  PRIMARY KEY (id),
  KEY idx_support_tickets_user (user_id),
  KEY idx_support_tickets_status (status),
  KEY idx_support_tickets_category (category),
  CONSTRAINT fk_support_tickets_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS support_messages (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  ticket_id BIGINT UNSIGNED NOT NULL,
  sender_user_id BIGINT UNSIGNED NULL,
  sender_type ENUM('user', 'admin', 'system') NOT NULL DEFAULT 'user',
  message TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_support_messages_ticket (ticket_id),
  KEY idx_support_messages_sender (sender_user_id),
  CONSTRAINT fk_support_messages_ticket
    FOREIGN KEY (ticket_id) REFERENCES support_tickets(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_support_messages_sender
    FOREIGN KEY (sender_user_id) REFERENCES users(id)
    ON DELETE SET NULL
) ENGINE=InnoDB;

-- ============================================================
-- End of schema
-- ============================================================
