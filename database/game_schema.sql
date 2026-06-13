PRAGMA foreign_keys = ON;

BEGIN TRANSACTION;

-- ============================================================
-- Minimal schema for: Godot -> HTTPRequest -> API -> SQL
-- Keep only persistent server data.
-- Do not persist transient runtime entities from Godot.
-- ============================================================

-- ============================================================
-- 1) User accounts + login/logout sessions
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    user_id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    display_name TEXT,
);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id
    ON user_sessions(user_id);

CREATE INDEX IF NOT EXISTS idx_user_sessions_active
    ON user_sessions(user_id, logout_at, is_revoked);

-- ============================================================
-- 2) Player profile persistence
-- ============================================================
CREATE TABLE IF NOT EXISTS player_profiles (
    profile_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    profile_name TEXT NOT NULL,
    level INTEGER NOT NULL DEFAULT 1,
    experience INTEGER NOT NULL DEFAULT 0,
    gold INTEGER NOT NULL DEFAULT 100,
    current_health INTEGER NOT NULL DEFAULT 25,
    max_health INTEGER NOT NULL DEFAULT 25,
    attack INTEGER NOT NULL DEFAULT 10,
    defense INTEGER NOT NULL DEFAULT 3,
    base_speed REAL NOT NULL DEFAULT 80.0,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    UNIQUE (user_id, profile_name)
);

CREATE INDEX IF NOT EXISTS idx_player_profiles_user_id
    ON player_profiles(user_id);

-- ============================================================
-- 3) Item catalog (for inventory + shop)
-- ============================================================
CREATE TABLE IF NOT EXISTS item_catalog (
    item_id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    item_kind TEXT NOT NULL CHECK (item_kind IN ('consumable', 'currency')),
    effect_type TEXT CHECK (effect_type IN ('heal', 'speed_boost') OR effect_type IS NULL),
    effect_value REAL,
);

-- ============================================================
-- 4) Inventory + action slots (ex: key R)
-- ============================================================
CREATE TABLE IF NOT EXISTS player_inventory (
    profile_id INTEGER NOT NULL,
    item_id TEXT NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (profile_id, item_id),
    FOREIGN KEY (profile_id) REFERENCES player_profiles(profile_id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES item_catalog(item_id)
);

-- ============================================================
-- 6) Quest persistence (minimal)
-- ============================================================
CREATE TABLE IF NOT EXISTS quest_catalog (
    quest_id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    target_type TEXT,
    target_count INTEGER NOT NULL DEFAULT 0,
    reward_gold INTEGER NOT NULL DEFAULT 0,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
);

CREATE TABLE IF NOT EXISTS player_quests (
    profile_id INTEGER NOT NULL,
    quest_id TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('not_started', 'in_progress', 'completed')),
    current_progress INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (profile_id, quest_id),
    FOREIGN KEY (profile_id) REFERENCES player_profiles(profile_id) ON DELETE CASCADE,
    FOREIGN KEY (quest_id) REFERENCES quest_catalog(quest_id)
);

-- ============================================================
-- Seeds for current game features
-- ============================================================
-- INSERT OR IGNORE INTO item_catalog (
--     item_id,
--     display_name,
--     item_kind,
--     stackable,
--     max_stack,
--     effect_type,
--     effect_value,
--     effect_flags_json,
--     is_active
-- ) VALUES
--     (
--         'healing_potion',
--         'Healing Potion',
--         'consumable',
--         1,
--         99,
--         'heal',
--         20,
--         NULL,
--         1
--     ),
--     (
--         'speed_potion',
--         'Speed Boost Potion',
--         'consumable',
--         1,
--         99,
--         'speed_boost',
--         1.6,
--         '{"expires_on_hit":true}',
--         1
--     ),
--     (
--         'gold_coin',
--         'Gold Coin',
--         'currency',
--         1,
--         999999,
--         NULL,
--         NULL,
--         NULL,
--         1
--     );

-- INSERT OR IGNORE INTO shops (
--     shop_id,
--     shop_name,
--     is_active
-- ) VALUES (
--     'default_shop',
--     'Village Shop',
--     1
-- );

-- INSERT OR IGNORE INTO shop_items (
--     shop_id,
--     item_id,
--     price,
--     stock,
--     is_active
-- ) VALUES
--     ('default_shop', 'healing_potion', 25, NULL, 1),
--     ('default_shop', 'speed_potion', 40, NULL, 1);

-- INSERT OR IGNORE INTO quest_catalog (
--     quest_id,
--     title,
--     target_type,
--     target_count,
--     reward_gold,
--     is_active
-- ) VALUES (
--     'slime_cleanup',
--     'Dungeon Cleanup',
--     'slime',
--     5,
--     50,
--     1
-- );

-- COMMIT;

-- ============================================================
-- REST/API notes
-- ============================================================
-- Godot should never query SQL directly.
-- Godot uses HTTPRequest and JSON against your backend API.
--
-- Suggested endpoint set:
-- POST /auth/login
-- POST /auth/logout
-- GET  /profiles/{profile_id}
-- PUT  /profiles/{profile_id}
-- GET  /profiles/{profile_id}/inventory
-- PUT  /profiles/{profile_id}/action-slots/{slot_key}
-- GET  /shops/default_shop/items
-- POST /shops/default_shop/purchase
-- POST /profiles/{profile_id}/quests/{quest_id}/progress
-- ============================================================
