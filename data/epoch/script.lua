-- Epoch ruleset — Lua systems
-- All balance constants live in EPOCH_CONFIG; tune here, no recompile.

-- ============================================================
-- Configuration (the one tuning surface)
-- ============================================================
EPOCH_CONFIG = {
  -- Public Works economy
  pw = {
    base_rate       = 0.10,   -- fraction of city production that becomes PW each turn
    gov_multipliers = {       -- keyed by government type id
      Anarchy         = 0.05,
      Tyranny         = 0.08,
      Monarchy        = 0.10,
      Theocracy       = 0.09,
      Republic        = 0.12,
      Democracy       = 0.14,
      Ecotopia        = 0.18,
      Technocracy     = 0.16,
    },
    improvement_costs = {     -- PW points to place each extra type
      Road            = 10,
      Railroad        = 25,
      Mine            = 20,
      Farm            = 15,
      Irrigation      = 15,
      Forest          = 12,
      SolarPanel      = 30,   -- solarpunk far-future improvement
      SeaTunnel       = 40,   -- undersea tunnel
    },
  },

  -- Special-action framework (unconventional warfare)
  -- Each action: { cost, range, base_success, counter_flag, effect_fn_name }
  special_actions = {
    convert_city = {
      unit_type     = "Cleric",
      cost          = 100,      -- gold cost to attempt
      range         = 2,        -- tiles from unit
      base_success  = 0.35,
      counter_flag  = "injunction",
      effect        = "sa_convert_city",
    },
    franchise = {
      unit_type     = "CorporateBranch",
      cost          = 80,
      range         = 1,
      base_success  = 0.50,
      counter_flag  = "injunction",
      effect        = "sa_franchise",
    },
    sue = {
      unit_type     = "Lawyer",
      cost          = 60,
      range         = 3,
      base_success  = 0.60,
      counter_flag  = nil,
      effect        = "sa_sue",
    },
    injunction = {
      unit_type     = "Lawyer",
      cost          = 50,
      range         = 3,
      base_success  = 0.70,
      counter_flag  = nil,
      effect        = "sa_injunction",
    },
    ecoterror = {
      unit_type     = "Ecoterrorist",
      cost          = 40,
      range         = 1,
      base_success  = 0.45,
      counter_flag  = nil,
      effect        = "sa_ecoterror",
    },
    enslave = {
      unit_type     = "Slaver",
      cost          = 70,
      range         = 1,
      base_success  = 0.40,
      counter_flag  = nil,
      effect        = "sa_enslave",
    },
    televangelize = {
      unit_type     = "Televangelist",
      cost          = 90,
      range         = 3,
      base_success  = 0.30,
      counter_flag  = "injunction",
      effect        = "sa_televangelize",
    },
    subvert = {
      unit_type     = "Subverter",
      cost          = 120,
      range         = 1,
      base_success  = 0.25,
      counter_flag  = "injunction",
      effect        = "sa_subvert",
    },
  },

  -- Era definitions (for telemetry event labeling + UI era-transition triggers)
  eras = {
    { id = "ancient",     min_tech = 0,   label = "Ancient Age" },
    { id = "renaissance", min_tech = 20,  label = "Renaissance" },
    { id = "modern",      min_tech = 45,  label = "Modern Era" },
    { id = "genetic",     min_tech = 70,  label = "Genetic Age" },
    { id = "diamond",     min_tech = 90,  label = "Diamond Age" },
  },

  -- Victory
  victory = {
    gaia_obelisk_coverage = 0.60,   -- fraction of map tiles needed for Gaia victory
  },
}

-- ============================================================
-- Public Works state
-- ============================================================
local pw_pool = {}   -- player_id → accumulated PW points

local function get_pw(player)
  local id = player.id
  if not pw_pool[id] then pw_pool[id] = 0 end
  return pw_pool[id]
end

local function add_pw(player, amount)
  pw_pool[player.id] = (pw_pool[player.id] or 0) + amount
end

local function spend_pw(player, amount)
  local bal = get_pw(player)
  if bal < amount then return false end
  pw_pool[player.id] = bal - amount
  return true
end

-- Called each turn: accumulate PW from city production
function pw_tick()
  players:iterate(function(player)
    if player.is_alive and not player.is_ai_controlled then
      local cfg = EPOCH_CONFIG.pw
      local gov_name = player.government and player.government.name or "Anarchy"
      local mult = cfg.gov_multipliers[gov_name] or cfg.base_rate
      player.cities:iterate(function(city)
        local gain = math.floor(city.prod_output * mult)
        add_pw(player, gain)
      end)
    end
  end)
end

-- Attempt to place a PW improvement; called from client action handler
function pw_place(player, tile, improvement_type)
  local cost = EPOCH_CONFIG.pw.improvement_costs[improvement_type]
  if not cost then
    notify.event(player, nil, E.UNIT_ILLEGAL_ACTION,
      "Unknown improvement type: " .. tostring(improvement_type))
    return false
  end
  if not spend_pw(player, cost) then
    notify.event(player, nil, E.UNIT_ILLEGAL_ACTION,
      string.format("Not enough Public Works points (need %d, have %d).",
        cost, get_pw(player)))
    return false
  end
  -- TODO: actual tile mutation via edit API once wired
  log.normal(string.format("[PW] player %s placed %s at (%d,%d) cost=%d",
    player.name, improvement_type, tile.x, tile.y, cost))
  notify.event(player, tile, E.WORKLIST,
    string.format("Public Works: %s placed.", improvement_type))
  return true
end

-- ============================================================
-- Special-action framework
-- ============================================================
local sa_flags = {}   -- { [target_player_id] = { flag_name = expiry_turn } }

local function has_flag(target, flag)
  local flags = sa_flags[target.id]
  if not flags then return false end
  local expiry = flags[flag]
  if not expiry then return false end
  -- expire check handled at turn start (see sa_expire_flags)
  return true
end

local function set_flag(target, flag, duration_turns)
  if not sa_flags[target.id] then sa_flags[target.id] = {} end
  sa_flags[target.id][flag] = game.turn + duration_turns
end

function sa_expire_flags()
  for pid, flags in pairs(sa_flags) do
    for flag, expiry in pairs(flags) do
      if game.turn >= expiry then
        flags[flag] = nil
      end
    end
  end
end

-- Roll for success (base_success modified by tech difference)
local function roll_success(actor_player, target_player, base_success)
  local roll = math.random()
  -- TODO: tech-difference modifier using player tech counts
  return roll < base_success
end

-- Dispatch a special action attempt
function special_action(actor_unit, target_city, action_key)
  local def = EPOCH_CONFIG.special_actions[action_key]
  if not def then
    log.error("[SA] Unknown special action: " .. tostring(action_key))
    return false
  end

  local actor = actor_unit.owner
  local target = target_city.owner

  -- Counter check
  if def.counter_flag and has_flag(target, def.counter_flag) then
    notify.event(actor, actor_unit.tile, E.UNIT_ILLEGAL_ACTION,
      string.format("Action blocked: %s has an injunction active.", target.name))
    log.normal(string.format("[SA] %s on %s blocked by %s flag",
      action_key, target.name, def.counter_flag))
    return false
  end

  -- Gold cost
  if actor.gold < def.cost then
    notify.event(actor, actor_unit.tile, E.UNIT_ILLEGAL_ACTION,
      string.format("Not enough gold for %s (need %d).", action_key, def.cost))
    return false
  end
  actor.gold = actor.gold - def.cost

  -- Success roll
  local success = roll_success(actor, target, def.base_success)
  log.normal(string.format("[SA] %s by %s on %s city %s: %s",
    action_key, actor.name, target.name, target_city.name,
    success and "SUCCESS" or "FAILED"))

  if success then
    local fn = _G[def.effect]
    if fn then
      fn(actor, actor_unit, target, target_city)
    else
      log.error("[SA] Missing effect function: " .. def.effect)
    end
  else
    notify.event(actor, actor_unit.tile, E.DIPLOMACY,
      string.format("%s attempt on %s failed.", action_key, target_city.name))
  end

  return success
end

-- ============================================================
-- Special-action effect implementations
-- ============================================================

function sa_convert_city(actor, unit, target, city)
  -- Reduce target city happiness; notify both sides
  -- TODO: use city.unhappy_citizens API once confirmed in this Freeciv version
  notify.event(actor, unit.tile, E.DIPLOMACY,
    string.format("Conversion successful! %s population wavers.", city.name))
  notify.event(target, city.tile, E.DIPLOMACY,
    string.format("A Cleric has converted citizens in %s!", city.name))
end

function sa_franchise(actor, unit, target, city)
  local siphon = math.floor(city.prod_output * 0.15)
  actor.gold = actor.gold + siphon
  notify.event(actor, unit.tile, E.DIPLOMACY,
    string.format("Corporate Branch in %s earns %d gold.", city.name, siphon))
  notify.event(target, city.tile, E.DIPLOMACY,
    string.format("A foreign Corporate Branch is active in %s!", city.name))
end

function sa_sue(actor, unit, target, city)
  local drain = math.min(target.gold, math.floor(target.gold * 0.10))
  target.gold = target.gold - drain
  actor.gold = actor.gold + drain
  notify.event(actor, unit.tile, E.DIPLOMACY,
    string.format("Lawsuit successful: seized %d gold from %s.", drain, target.name))
  notify.event(target, city.tile, E.DIPLOMACY,
    string.format("Lawsuit! Lost %d gold to %s.", drain, actor.name))
end

function sa_injunction(actor, unit, target, city)
  set_flag(target, "injunction", 5)
  notify.event(actor, unit.tile, E.DIPLOMACY,
    string.format("Injunction served on %s (5 turns).", target.name))
  notify.event(target, city.tile, E.DIPLOMACY,
    string.format("%s has served an injunction — special operations blocked for 5 turns!", actor.name))
end

function sa_ecoterror(actor, unit, target, city)
  -- Spawn pollution tile near the city
  -- TODO: tile:set_pollution API
  notify.event(actor, unit.tile, E.DIPLOMACY,
    string.format("Ecoterrorism: pollution event near %s.", city.name))
  notify.event(target, city.tile, E.DIPLOMACY,
    string.format("Ecoterrorists struck near %s!", city.name))
end

function sa_enslave(actor, unit, target, city)
  if city.size > 2 then
    -- Approximate: drain city size by 1, give actor a worker unit
    -- TODO: city.size -= 1 and create_unit API
    notify.event(actor, unit.tile, E.DIPLOMACY,
      string.format("Enslaved population from %s.", city.name))
    notify.event(target, city.tile, E.DIPLOMACY,
      string.format("A Slaver has captured people from %s!", city.name))
  end
end

function sa_televangelize(actor, unit, target, city)
  -- Area convert — hits multiple nearby cities
  -- TODO: iterate cities within range
  sa_convert_city(actor, unit, target, city)
  notify.event(actor, unit.tile, E.DIPLOMACY,
    string.format("Televangelist broadcast from near %s (area effect).", city.name))
end

function sa_subvert(actor, unit, target, city)
  -- Disable a random improvement in the city for N turns
  notify.event(actor, unit.tile, E.DIPLOMACY,
    string.format("Subversion in %s successful.", city.name))
  notify.event(target, city.tile, E.DIPLOMACY,
    string.format("A Subverter has disabled a facility in %s!", city.name))
end

-- ============================================================
-- Victory check
-- ============================================================

function check_gaia_victory()
  local cfg = EPOCH_CONFIG.victory
  players:iterate(function(player)
    if not player.is_alive then return end
    local obelisk_count = 0
    -- TODO: iterate player's cities/tiles for Gaia Obelisk improvement
    -- Placeholder: check for wonder "GaiaController" in any city
    player.cities:iterate(function(city)
      if city:has_building("GaiaController") then
        obelisk_count = obelisk_count + 1
      end
    end)
    -- map_size available as game.map.xsize * game.map.ysize (approximate tile count)
    local total_tiles = game.map.xsize * game.map.ysize
    if (obelisk_count / total_tiles) >= cfg.gaia_obelisk_coverage then
      notify.all(string.format("%s has achieved the Gaia Controller victory!", player.name))
      game:end_game()
    end
  end)
end

-- ============================================================
-- Era transition tracking
-- ============================================================

local player_era = {}   -- player_id → current era id

local function current_era(player)
  local tech_count = 0
  -- TODO: count techs known by player
  local current = EPOCH_CONFIG.eras[1]
  for _, era in ipairs(EPOCH_CONFIG.eras) do
    if tech_count >= era.min_tech then
      current = era
    end
  end
  return current
end

function check_era_transitions()
  players:iterate(function(player)
    if not player.is_alive then return end
    local era = current_era(player)
    local prev = player_era[player.id]
    if prev ~= era.id then
      player_era[player.id] = era.id
      if prev then
        notify.event(player, nil, E.TECH_GAIN,
          string.format("*** %s has entered the %s! ***", player.name, era.label))
        log.normal(string.format("[ERA] %s → %s (turn %d)", player.name, era.id, game.turn))
      end
    end
  end)
end

-- ============================================================
-- Turn hooks
-- ============================================================

function turn_begin_handler(turn, year)
  sa_expire_flags()
  pw_tick()
  check_era_transitions()
  check_gaia_victory()
end

signal.connect("turn_begin", "turn_begin_handler")
