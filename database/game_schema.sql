PRAGMA foreign_keys = ON;

BEGIN TRANSACTION;

-- ============================================================
-- 1) Users + login/logout session tracking
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    user_id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    password_salt TEXT NOT NULL,
    display_name TEXT,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    last_login_at TEXT
);

CREATE TABLE IF NOT EXISTS auth_sessions (
    session_id TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    access_token_hash TEXT,
    refresh_token_hash TEXT,
    user_agent TEXT,
    ip_address TEXT,
    login_at TEXT NOT NULL DEFAULT (datetime('now')),
    logout_at TEXT,
    expires_at TEXT,
    is_revoked INTEGER NOT NULL DEFAULT 0 CHECK (is_revoked IN (0, 1)),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_auth_sessions_user_id
    ON auth_sessions(user_id);

CREATE INDEX IF NOT EXISTS idx_auth_sessions_user_active
    ON auth_sessions(user_id, logout_at, is_revoked);

-- ============================================================
-- 2) Generic game object catalog (all game objects)
-- ============================================================
CREATE TABLE IF NOT EXISTS game_object_definitions (
    object_id TEXT PRIMARY KEY,
    object_type TEXT NOT NULL CHECK (
        object_type IN ('item', 'currency', 'enemy', 'npc', 'world_object', 'quest_item')
    ),
    display_name TEXT NOT NULL,
    description TEXT,
    scene_path TEXT,
    script_path TEXT,
    stackable INTEGER NOT NULL DEFAULT 0 CHECK (stackable IN (0, 1)),
    max_stack INTEGER NOT NULL DEFAULT 1,
    default_shop_price INTEGER,
    effect_json TEXT,
    stats_json TEXT,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Runtime map/world representation of spawned objects.
CREATE TABLE IF NOT EXISTS world_object_instances (
    instance_id INTEGER PRIMARY KEY AUTOINCREMENT,
    object_id TEXT NOT NULL,
    map_name TEXT NOT NULL,
    position_x REAL NOT NULL,
    position_y REAL NOT NULL,
    state_json TEXT,
    is_collected INTEGER NOT NULL DEFAULT 0 CHECK (is_collected IN (0, 1)),
    spawned_at TEXT NOT NULL DEFAULT (datetime('now')),
    despawned_at TEXT,
    FOREIGN KEY (object_id) REFERENCES game_object_definitions(object_id)
);

CREATE INDEX IF NOT EXISTS idx_world_object_instances_map
    ON world_object_instances(map_name, object_id);

-- ============================================================
-- 3) Player representation (character profile/save data)
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
    current_speed REAL NOT NULL DEFAULT 80.0,
    speed_boost_active INTEGER NOT NULL DEFAULT 0 CHECK (speed_boost_active IN (0, 1)),
    speed_boost_multiplier REAL NOT NULL DEFAULT 1.0,
    speed_boost_source_object_id TEXT,
    speed_boost_applied_at TEXT,
    last_scene_path TEXT,
    position_x REAL NOT NULL DEFAULT 0.0,
    position_y REAL NOT NULL DEFAULT 0.0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (speed_boost_source_object_id) REFERENCES game_object_definitions(object_id),
    UNIQUE (user_id, profile_name)
);

CREATE INDEX IF NOT EXISTS idx_player_profiles_user_id
    ON player_profiles(user_id);

-- ============================================================
-- 4) Inventory + action slots
-- ============================================================
CREATE TABLE IF NOT EXISTS player_inventory (
    profile_id INTEGER NOT NULL,
    object_id TEXT NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (profile_id, object_id),
    FOREIGN KEY (profile_id) REFERENCES player_profiles(profile_id) ON DELETE CASCADE,
    FOREIGN KEY (object_id) REFERENCES game_object_definitions(object_id)
);

-- Generic action slot mapping, ex: slot_key='R' -> speed_potion.
CREATE TABLE IF NOT EXISTS action_slot_assignments (
    profile_id INTEGER NOT NULL,
    slot_key TEXT NOT NULL,
    object_id TEXT,
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (profile_id, slot_key),
    FOREIGN KEY (profile_id) REFERENCES player_profiles(profile_id) ON DELETE CASCADE,
    FOREIGN KEY (object_id) REFERENCES game_object_definitions(object_id)
);

-- ============================================================
-- 5) Quest model
-- ============================================================
CREATE TABLE IF NOT EXISTS quest_definitions (
    quest_id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    target_type TEXT,
    target_count INTEGER NOT NULL DEFAULT 0,
    reward_gold INTEGER NOT NULL DEFAULT 0,
    is_repeatable INTEGER NOT NULL DEFAULT 0 CHECK (is_repeatable IN (0, 1))
);

CREATE TABLE IF NOT EXISTS player_quests (
    profile_id INTEGER NOT NULL,
    quest_id TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('not_started', 'in_progress', 'completed')),
    current_progress INTEGER NOT NULL DEFAULT 0,
    target_progress INTEGER NOT NULL DEFAULT 0,
    started_at TEXT,
    completed_at TEXT,
    PRIMARY KEY (profile_id, quest_id),
    FOREIGN KEY (profile_id) REFERENCES player_profiles(profile_id) ON DELETE CASCADE,
    FOREIGN KEY (quest_id) REFERENCES quest_definitions(quest_id)
);

-- ============================================================
-- 6) Shop model
-- ============================================================
CREATE TABLE IF NOT EXISTS shop_definitions (
    shop_id TEXT PRIMARY KEY,
    shop_name TEXT NOT NULL,
    npc_object_id TEXT,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    FOREIGN KEY (npc_object_id) REFERENCES game_object_definitions(object_id)
);

CREATE TABLE IF NOT EXISTS shop_inventory (
    shop_id TEXT NOT NULL,
    object_id TEXT NOT NULL,
    price INTEGER NOT NULL,
    stock INTEGER,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    PRIMARY KEY (shop_id, object_id),
    FOREIGN KEY (shop_id) REFERENCES shop_definitions(shop_id) ON DELETE CASCADE,
    FOREIGN KEY (object_id) REFERENCES game_object_definitions(object_id)
);

-- ============================================================
-- 7) Seeds matching current gameplay
-- ============================================================
INSERT OR IGNORE INTO game_object_definitions (
    object_id,
    object_type,
    display_name,
    description,
    scene_path,
    stackable,
    max_stack,
    default_shop_price,
    effect_json,
    stats_json
) VALUES
    (
        'healing_potion',
        'item',
        'Healing Potion',
        'Restores health points.',
        NULL,
        1,
        99,
        25,
        '{"heal_amount":20}',
        NULL
    ),
    (
        'speed_potion',
        'item',
        'Speed Boost Potion',
        'Boosts speed until player is hit.',
        NULL,
        1,
        99,
        40,
        '{"speed_multiplier":1.6,"expires_on_hit":true}',
        NULL
    ),
    (
        'gold_coin',
        'currency',
        'Gold Coin',
        'Basic currency unit.',
        'res://scenes/object/coinGold.tscn',
        1,
        999999,
        1,
        NULL,
        NULL
    ),
    (
        'slime_enemy',
        'enemy',
        'Slime',
        'Dungeon enemy that can drop coins.',
        'res://scenes/monster/slime.tscn',
        0,
        1,
        NULL,
        NULL,
        '{"base_health":20,"attack":5,"defense":0}'
    );

INSERT OR IGNORE INTO quest_definitions (
    quest_id,
    title,
    description,
    target_type,
    target_count,
    reward_gold,
    is_repeatable
) VALUES (
    'slime_cleanup',
    'Dungeon Cleanup',
    'Defeat slimes in the dungeon.',
    'slime',
    5,
    50,
    0
);

INSERT OR IGNORE INTO shop_definitions (
    shop_id,
    shop_name,
    npc_object_id,
    is_active
) VALUES (
    'default_shop',
    'Village Shop',
    NULL,
    1
);

INSERT OR IGNORE INTO shop_inventory (
    shop_id,
    object_id,
    price,
    stock,
    is_active
) VALUES
    ('default_shop', 'healing_potion', 25, NULL, 1),
    ('default_shop', 'speed_potion', 40, NULL, 1);

COMMIT;

-- ============================================================
-- Login/logout example flow (for app layer):
-- 1) Login success:
--    INSERT INTO auth_sessions(session_id, user_id, access_token_hash, refresh_token_hash, expires_at)
--    VALUES (?, ?, ?, ?, ?);
--    UPDATE users SET last_login_at = datetime('now') WHERE user_id = ?;
--
-- 2) Logout:
--    UPDATE auth_sessions
--    SET logout_at = datetime('now'), is_revoked = 1
--    WHERE session_id = ? AND user_id = ?;
-- ============================================================
