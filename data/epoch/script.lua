-- Freeciv - Copyright (C) 2007 - The Freeciv Project
--   This program is free software; you can redistribute it and/or modify
--   it under the terms of the GNU General Public License as published by
--   the Free Software Foundation; either version 2, or (at your option)
--   any later version.
--
--   This program is distributed in the hope that it will be useful,
--   but WITHOUT ANY WARRANTY; without even the implied warranty of
--   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--   GNU General Public License for more details.

-- This file is for lua-functionality that is specific to a given
-- ruleset. When freeciv loads a ruleset, it also loads script
-- file called 'default.lua'. The one loaded if your ruleset
-- does not provide an override is default/default.lua.


-- Place Ruins at the location of the destroyed city.
function city_destroyed_callback(city, loser, destroyer)
  city.tile:create_extra("Ruins", NIL)
  -- continue processing
  return false
end

signal.connect("city_destroyed", "city_destroyed_callback")

-- Check if there is certain terrain in ANY CAdjacent tile.
function adjacent_to(tile, terrain_name)
  for adj_tile in tile:circle_iterate(1) do
    if adj_tile.id ~= tile.id then
      local adj_terr = adj_tile.terrain
      local adj_name = adj_terr:rule_name()
      if adj_name == terrain_name then
        return true
      end
    end
  end
  return false
end

-- Check if there is certain terrain in ALL CAdjacent tiles.
function surrounded_by(tile, terrain_name)
  for adj_tile in tile:circle_iterate(1) do
    if adj_tile.id ~= tile.id then
      local adj_terr = adj_tile.terrain
      local adj_name = adj_terr:rule_name()
      if adj_name ~= terrain_name then
        return false
      end
    end
  end
  return true
end

-- Add random labels to the map.
function place_map_labels()
  local rivers = 0
  local deeps = 0
  local oceans = 0
  local lakes = 0
  local swamps = 0
  local glaciers = 0
  local tundras = 0
  local deserts = 0
  local plains = 0
  local grasslands = 0
  local jungles = 0
  local forests = 0
  local hills = 0
  local mountains = 0

  local selected_river = 0
  local selected_deep = 0
  local selected_ocean = 0
  local selected_lake = 0
  local selected_swamp = 0
  local selected_glacier = 0
  local selected_tundra = 0
  local selected_desert = 0
  local selected_plain = 0
  local selected_grassland = 0
  local selected_jungle = 0
  local selected_forest = 0
  local selected_hill = 0
  local selected_mountain = 0

  -- Count the tiles that has a terrain type that may get a label.
  for place in whole_map_iterate() do
    local terr = place.terrain
    local tname = terr:rule_name()

    if place:has_extra("River") then
      rivers = rivers + 1
    elseif tname == "Deep Ocean" then
      deeps = deeps + 1
    elseif tname == "Ocean" then
      oceans = oceans + 1
    elseif tname == "Lake" then
      lakes = lakes + 1
    elseif tname == "Swamp" then
      swamps = swamps + 1
    elseif tname == "Glacier" then
      glaciers = glaciers + 1
    elseif tname == "Tundra" then
      tundras = tundras + 1
    elseif tname == "Desert" then
      deserts = deserts + 1
    elseif tname == "Plains" then
      plains = plains + 1
    elseif tname == "Grassland" then
      grasslands = grasslands + 1
    elseif tname == "Jungle" then
      jungles = jungles + 1
    elseif tname == "Forest" then
      forests = forests + 1
    elseif tname == "Hills" then
      hills = hills + 1
    elseif tname == "Mountains" then
      mountains = mountains + 1
    end
  end

  -- Decide if a label should be included and, in case it should, where.
    if random(1, 100) <= rivers then
      selected_river = random(1, rivers)
    end
    if random(1, 100) <= deeps then
      selected_deep = random(1, deeps)
    end
    if random(1, 100) <= oceans then
      selected_ocean = random(1, oceans)
    end
    if random(1, 100) <= lakes then
      selected_lake = random(1, lakes)
    end
    if random(1, 100) <= swamps then
      selected_swamp = random(1, swamps)
    end
    if random(1, 100) <= glaciers then
      selected_glacier = random(1, glaciers)
    end
    if random(1, 100) <= tundras then
      selected_tundra = random(1, tundras)
    end
    if random(1, 100) <= deserts then
      selected_desert = random(1, deserts)
    end
    if random(1, 100) <= plains then
      selected_plain = random(1, plains)
    end
    if random(1, 100) <= grasslands then
      selected_grassland = random(1, grasslands)
    end
    if random(1, 100) <= jungles then
      selected_jungle = random(1, jungles)
    end
    if random(1, 100) <= forests then
      selected_forest = random(1, forests)
    end
    if random(1, 100) <= hills then
      selected_hill = random(1, hills)
    end
    if random(1, 100) <= mountains then
      selected_mountain = random(1, mountains)
    end

  -- Place the included labels at the location determined above.
  for place in whole_map_iterate() do
    local terr = place.terrain
    local tname = terr:rule_name()

    if place:has_extra("River") then
      selected_river = selected_river - 1
      if selected_river == 0 then
        if tname == "Hills" then
          place:set_label(_("Grand Canyon"))
        elseif tname == "Mountains" then
          place:set_label(_("Deep Gorge"))
        elseif tname == "Tundra" then
          place:set_label(_("Fjords"))
        elseif random(1, 100) <= 50 then
          place:set_label(_("Waterfalls"))
        else
          place:set_label(_("Travertine Terraces"))
        end
      end
    elseif tname == "Deep Ocean" then
      selected_deep = selected_deep - 1
      if selected_deep == 0 then
        if surrounded_by(place, "Deep Ocean") then
          -- Fully surrounded
          place:set_label(_("Deep Trench"))
        else
          place:set_label(_("Thermal Vent"))
        end
      end
    elseif tname == "Ocean" then
      selected_ocean = selected_ocean - 1
      if selected_ocean == 0 then
        if surrounded_by(place, "Ocean") then
          -- Fully surrounded
          place:set_label(_("Atoll Chain"))
        elseif adjacent_to(place, "Glacier") then
          place:set_label(_("Glacier Bay"))
        elseif adjacent_to(place, "Deep Ocean") then
          place:set_label(_("Great Barrier Reef"))
        else
          -- Coast (not adjacent to glacier nor deep ocean)
          place:set_label(_("Great Blue Hole"))
        end
      end
    elseif tname == "Lake" then
      selected_lake = selected_lake - 1
      if selected_lake == 0 then
        if surrounded_by(place, "Lake") then
          -- Fully surrounded
          place:set_label(_("Great Lakes"))
        elseif not adjacent_to(place, "Lake") then
          -- Isolated
          place:set_label(_("Dead Sea"))
        else
          place:set_label(_("Rift Lake"))
        end
      end
    elseif tname == "Swamp" then
      selected_swamp = selected_swamp - 1
      if selected_swamp == 0 then
        if not adjacent_to(place, "Swamp") then
          -- Isolated
          place:set_label(_("Grand Prismatic Spring"))
        elseif adjacent_to(place, "Ocean") then
          -- Coast
          place:set_label(_("Mangrove Forest"))
        else
          place:set_label(_("Cenotes"))
        end
      end
    elseif tname == "Glacier" then
      selected_glacier = selected_glacier - 1
      if selected_glacier == 0 then
        if surrounded_by(place, "Glacier") then
          -- Fully surrounded
          place:set_label(_("Ice Sheet"))
        elseif not adjacent_to(place, "Glacier") then
          -- Isolated
          place:set_label(_("Frozen Lake"))
        elseif adjacent_to(place, "Ocean") then
          -- Coast
          place:set_label(_("Ice Shelf"))
        else
          place:set_label(_("Advancing Glacier"))
        end
      end
    elseif tname == "Tundra" then
      selected_tundra = selected_tundra - 1
      if selected_tundra == 0 then
          place:set_label(_("Geothermal Area"))
      end
    elseif tname == "Desert" then
      selected_desert = selected_desert - 1
      if selected_desert == 0 then
        if surrounded_by(place, "Desert") then
          -- Fully surrounded
          place:set_label(_("Sand Sea"))
        elseif not adjacent_to(place, "Desert") then
          -- Isolated
          place:set_label(_("Salt Flat"))
        elseif random(1, 100) <= 50 then
          place:set_label(_("Singing Dunes"))
        else
          place:set_label(_("White Desert"))
        end
      end
    elseif tname == "Plains" then
      selected_plain = selected_plain - 1
      if selected_plain == 0 then
        if adjacent_to(place, "Ocean") then
          -- Coast
          place:set_label(_("Long Beach"))
        elseif random(1, 100) <= 50 then
          place:set_label(_("Valley of Geysers"))
        else
          place:set_label(_("Rock Pillars"))
        end
      end
    elseif tname == "Grassland" then
      selected_grassland = selected_grassland - 1
      if selected_grassland == 0 then
        if adjacent_to(place, "Ocean") then
          -- Coast
          place:set_label(_("White Cliffs"))
        elseif random(1, 100) <= 50 then
          place:set_label(_("Giant Cave"))
        else
          place:set_label(_("Rock Formation"))
        end
      end
    elseif tname == "Jungle" then
      selected_jungle = selected_jungle - 1
      if selected_jungle == 0 then
        if surrounded_by(place, "Jungle") then
          -- Fully surrounded
          place:set_label(_("Rainforest"))
        elseif adjacent_to(place, "Ocean") then
          -- Coast
          place:set_label(_("Subterranean River"))
        else
          place:set_label(_("Sinkholes"))
        end
      end
    elseif tname == "Forest" then
      selected_forest = selected_forest - 1
      if selected_forest == 0 then
        if adjacent_to(place, "Mountains") then
          place:set_label(_("Stone Forest"))
        elseif surrounded_by(place, "Forest") then
          -- Fully surrounded
          place:set_label(_("Sequoia Forest"))
        else
          place:set_label(_("Millenary Trees"))
        end
      end
    elseif tname == "Hills" then
      selected_hill = selected_hill - 1
      if selected_hill == 0 then
        if not adjacent_to(place, "Hills") then
          if adjacent_to(place, "Mountains") then
            -- Isolated (but adjacent to mountains)
            place:set_label(_("Table Mountain"))
          else
            -- Isolated (not adjacent to hills nor mountains)
            place:set_label(_("Inselberg"))
          end
        elseif random(1, 100) <= 50 then
          place:set_label(_("Karst Landscape"))
        else
          place:set_label(_("Mud Volcanoes"))
        end
      end
    elseif tname == "Mountains" then
      selected_mountain = selected_mountain - 1
      if selected_mountain == 0 then
        if surrounded_by(place, "Mountains") then
          -- Fully surrounded
          place:set_label(_("Highest Peak"))
        elseif not adjacent_to(place, "Mountains") then
          -- Isolated
          place:set_label(_("Sacred Mount"))
        elseif adjacent_to(place, "Ocean") then
          -- Coast
          place:set_label(_("Cliff Coast"))
        elseif random(1, 100) <= 50 then
          place:set_label(_("Active Volcano"))
        else
          place:set_label(_("High Summit"))
        end
      end
    end
  end
  return false
end

signal.connect("map_generated", "place_map_labels")


-- ============================================================
-- EPOCH SYSTEMS
-- ------------------------------------------------------------
-- The full Public Works / special-action / era-transition design lives in
-- doc/design/epoch-lua-systems-draft.lua. It is ported into THIS file module
-- by module, each verified against a running server, rather than dropped in
-- wholesale (the draft was written against a guessed API before we had the
-- civ2civ3 script above as ground truth).
--
-- This first slice is deliberately minimal: prove that (a) our code is part of
-- the loaded epoch ruleset and (b) our turn hook actually fires. Everything
-- else builds on a green baseline.
-- ============================================================

log.normal("[EPOCH] Epoch ruleset script loaded (baseline).")

-- ------------------------------------------------------------
-- Era system (Slice 0) — bucket-membership detection.
-- Design: doc/design/epoch-tech-tree.md §2. A player's age = the highest age
-- of any tech they know (research, trade, theft, conquest all count). Monotonic.
-- Ages IV/V (Helix/Lattice) get their techs in later slices; the table below is
-- ages I–III over the existing 87 techs.
-- All Lua API here verified against this build (tech_researched(tech,player,how),
-- find.tech_type, players_iterate, player:knows_tech, notify.event/E.TECH_GAIN).
-- ------------------------------------------------------------

EPOCH_ERAS = {
  [1] = { id = "ember",   label = "The Ember Age" },
  [2] = { id = "compass", label = "The Compass Age" },
  [3] = { id = "dynamo",  label = "The Dynamo Age" },
  [4] = { id = "helix",   label = "The Helix Age" },
  [5] = { id = "lattice", label = "The Lattice Age" },
}

-- ------------------------------------------------------------
-- EPOCH_CONFIG — the single documented tuning surface (roadmap doctrine §2).
-- era_cost_pct MIRRORS the [techclass_*] cost_pct values in techs.ruleset (the
-- engine reads the ruleset, not this table; kept here so all balance knobs are
-- discoverable in one place and so tuning tools can read them). KEEP IN SYNC
-- with techs.ruleset. PACING = "accelerating future grind" (not flat shares):
-- time-to-cross each age rises on a convex curve so the far-future is a
-- deliberate long-game investment that can't be rushed to dominate. Dynamo is
-- discounted (its 45-tech COUNT already makes it the longest historical age);
-- the steep cost is concentrated in Helix/Lattice. Retune from the age-duration
-- curve printed by scripts/epoch-era-autogame.sh.
-- ------------------------------------------------------------
EPOCH_CONFIG = {
  era_cost_pct = {
    [1] = 100,  -- Ember   (normal establishment)
    [2] = 115,  -- Compass (slight rise)
    [3] = 70,   -- Dynamo  (discounted — length is 45-tech-count-driven)
    [4] = 250,  -- Helix   (~3.5x jump: the "true future" difficulty spike)
    [5] = 600,  -- Lattice (~2.4x again: whole-game-length endgame grind)
  },
}

-- tech (rule) name -> age number. Single source of truth for era buckets.
EPOCH_TECH_AGE = {
  -- Age I — Ember (26)
  ["Alphabet"]=1, ["Pottery"]=1, ["Masonry"]=1, ["Bronze Working"]=1,
  ["Ceremonial Burial"]=1, ["Horseback Riding"]=1, ["Warrior Code"]=1,
  ["The Wheel"]=1, ["Writing"]=1, ["Code of Laws"]=1, ["Mysticism"]=1,
  ["Map Making"]=1, ["Currency"]=1, ["Iron Working"]=1, ["Mathematics"]=1,
  ["Polytheism"]=1, ["Trade"]=1, ["Seafaring"]=1, ["Construction"]=1,
  ["Bridge Building"]=1, ["Literacy"]=1, ["Monarchy"]=1, ["Philosophy"]=1,
  ["The Republic"]=1, ["Astronomy"]=1, ["Medicine"]=1,
  -- Age II — Compass (17)
  ["Feudalism"]=2, ["Chivalry"]=2, ["Monotheism"]=2, ["Theology"]=2,
  ["University"]=2, ["Invention"]=2, ["Gunpowder"]=2, ["Banking"]=2,
  ["Navigation"]=2, ["Physics"]=2, ["Magnetism"]=2, ["Theory of Gravity"]=2,
  ["Leadership"]=2, ["Metallurgy"]=2, ["Chemistry"]=2, ["Economics"]=2,
  ["Democracy"]=2,
  -- Age III — Dynamo (44 existing + Networked Computing, the Slice 1 bridge)
  ["Steam Engine"]=3, ["Railroad"]=3, ["Industrialization"]=3,
  ["The Corporation"]=3, ["Sanitation"]=3, ["Explosives"]=3, ["Refining"]=3,
  ["Electricity"]=3, ["Engineering"]=3, ["Steel"]=3, ["Conscription"]=3,
  ["Tactics"]=3, ["Machine Tools"]=3, ["Combustion"]=3, ["Automobile"]=3,
  ["Mass Production"]=3, ["Refrigeration"]=3, ["Atomic Theory"]=3,
  ["Electronics"]=3, ["Radio"]=3, ["Flight"]=3, ["Advanced Flight"]=3,
  ["Mobile Warfare"]=3, ["Combined Arms"]=3, ["Amphibious Warfare"]=3,
  ["Guerilla Warfare"]=3, ["Espionage"]=3, ["Communism"]=3, ["Labor Union"]=3,
  ["Nuclear Fission"]=3, ["Nuclear Power"]=3, ["Miniaturization"]=3,
  ["Computers"]=3, ["Rocketry"]=3, ["Space Flight"]=3, ["Laser"]=3,
  ["Superconductors"]=3, ["Robotics"]=3, ["Plastics"]=3, ["Stealth"]=3,
  ["Recycling"]=3, ["Environmentalism"]=3, ["Genetic Engineering"]=3,
  ["Fusion Power"]=3, ["Networked Computing"]=3,
  -- Age IV — Helix (13: full age wired in Slice 2)
  ["Genome Cartography"]=4, ["Cellular Rewriting"]=4,
  ["Chimeric Agriculture"]=4, ["Cultured Materials"]=4,
  ["Pressure Ecology"]=4, ["Abyssal Engineering"]=4,
  ["Cybernetic Symbiosis"]=4, ["Machine Cognition"]=4,
  ["Synthetic Cognition"]=4, ["Closed Biospheres"]=4,
  ["Reclamation Science"]=4, ["Directed Energy"]=4,
  ["Orbital Logistics"]=4,
  -- Age V — Lattice (14: full age wired in Slice 3; tree complete at 115)
  ["Molecular Assembly"]=5, ["Metamaterials"]=5,
  ["Adaptive Fabrication"]=5, ["Plasma Containment"]=5,
  ["Fusion Lattices"]=5, ["Skyhook Tethers"]=5,
  ["Orbital Foundries"]=5, ["Orbital Ordnance"]=5,
  ["Deep Habitation"]=5, ["Neural Uplink"]=5,
  ["Autonomous Legions"]=5, ["Living Architecture"]=5,
  ["Planetary Stewardship"]=5, ["Ascendant Intelligence"]=5,
}

-- Resolved lookups, built lazily (find.tech_type is safe once rules are loaded).
local epoch_age_by_techid = nil   -- tech.id -> age
local epoch_tech_list = nil       -- array of { tt = Tech_Type, age = n }
local epoch_player_era = {}       -- player.id -> age (nil => age 1)
local epoch_current_turn = 0

local function epoch_build_maps()
  epoch_age_by_techid = {}
  epoch_tech_list = {}
  local missing = 0
  for name, age in pairs(EPOCH_TECH_AGE) do
    local tt = find.tech_type(name)
    if tt ~= nil then
      epoch_age_by_techid[tt.id] = age
      epoch_tech_list[#epoch_tech_list + 1] = { tt = tt, age = age }
    else
      missing = missing + 1
      log.error("[EPOCH] tech->age map: unknown tech name '" .. name .. "'")
    end
  end
  log.normal("[EPOCH] tech->age map built: " .. tostring(#epoch_tech_list)
             .. " techs, " .. tostring(missing) .. " unmatched.")
end

local function epoch_get_era(player)
  return epoch_player_era[player.id] or 1
end

-- Raise a player's era to new_age if higher. Monotonic; announces + logs a
-- structured era_transition line (the telemetry event; goes to the bounded
-- game log for now, to Loki once observability is back on).
local function epoch_set_era(player, new_age, trigger)
  local old = epoch_get_era(player)
  if new_age <= old then return end
  epoch_player_era[player.id] = new_age
  local era = EPOCH_ERAS[new_age]
  log.normal(string.format(
    "[EPOCH][era_transition] player_id=%d from=%d to=%d (%s) turn=%d trigger=%s",
    player.id, old, new_age, era.id, epoch_current_turn, tostring(trigger)))
  notify.event(player, NIL, E.TECH_GAIN,
    _("Your civilization enters %s."), era.label)
end

-- Primary path: fires on any tech acquisition (research/trade/theft/conquest).
function epoch_tech_researched(tech, player, how)
  if tech == nil then return end
  if epoch_age_by_techid == nil then epoch_build_maps() end
  local age = epoch_age_by_techid[tech.id]
  if age ~= nil then
    epoch_set_era(player, age, tech:name_translation())
  end
end
signal.connect("tech_researched", "epoch_tech_researched")

-- Safety-net rescan (Lua state doesn't survive save/load): recompute each
-- player's era from their known techs. Cheap (bounded tech list x players).
function epoch_turn_begin(turn, year)
  epoch_current_turn = turn
  log.normal("[EPOCH] turn_begin fired: turn=" .. tostring(turn)
             .. " year=" .. tostring(year))
  if epoch_tech_list == nil then epoch_build_maps() end
  for player in players_iterate() do
    local maxage = epoch_get_era(player)
    for _, entry in ipairs(epoch_tech_list) do
      if entry.age > maxage and player:knows_tech(entry.tt) then
        maxage = entry.age
      end
    end
    epoch_set_era(player, maxage, "rescan")
  end
  -- Public Works accrual rides the same (single) turn_begin handler so it can
  -- never double-fire relative to the era rescan.
  epoch_pw_accrue(turn)
  -- Expired legal injunctions are swept here too (special-actions module,
  -- defined below; global lookup resolves at call time).
  epoch_inj_sweep(turn)
end
signal.connect("turn_begin", "epoch_turn_begin")

-- ------------------------------------------------------------
-- Public Works (backlog 1.3) — pooled national build economy.
-- Design: doc/design/feature-pw-placement.md. Gesture: the Surveyor unit
-- (units.ruleset, UnitTypeFlag "PublicWorks") issues "User Action 3" /
-- "Field Operation" (actions.ruleset) on an owned tile; the handler below
-- validates and spends from the pool via edit.create_extra.
--
-- API verified against this build (tolua_game.pkg / tolua_server.pkg):
--   player:cities_iterate(), city:size(), player.government:rule_name(),
--   tile.owner / tile.terrain / tile:has_extra / tile.x / tile.y,
--   edit.create_extra(tile, name), find.action(name), utype:has_flag(name),
--   action_started_unit_tile(action, actor, tile).
-- DELIBERATE DEVIATION from the design sketch: this build's Lua API exposes
-- NO city shield/production accessor (checked tolua_game.pkg + server pkg —
-- City has only size/tile/has_building/culture/...). Accrual therefore uses
-- city SIZE as the base, with base_rate scaled so magnitudes match the
-- draft's intent (a Road every turn or two for a small early empire).
-- ------------------------------------------------------------

EPOCH_CONFIG.pw = {
  -- PW points per city-size point per turn, before the government multiplier.
  base_rate = 10,
  -- Keyed by government rule_name (governments.ruleset; verified list).
  -- Intent kept from the draft: Anarchy poorest, the solarpunk/AI future
  -- governments richest, everything else graded between.
  gov_multipliers = {
    ["Anarchy"]        = 0.05,
    ["Tribal"]         = 0.07,
    ["Despotism"]      = 0.08,
    ["Fundamentalism"] = 0.09,
    ["Monarchy"]       = 0.10,
    ["Communism"]      = 0.11,
    ["Republic"]       = 0.12,
    ["Federation"]     = 0.13,
    ["Democracy"]      = 0.14,
    ["Synthesis"]      = 0.16,
    ["Stewardship"]    = 0.18,
  },
  default_gov_multiplier = 0.10,
  -- PW cost per extra (keys are exact Extra rule_names from terrain.ruleset;
  -- "Sea Tunnel" / "Kelp Farm" contain spaces on purpose). The draft's
  -- Farm/Forest/SolarPanel/SeaTunnel names were stale — no such extras exist.
  improvement_costs = {
    ["Road"]       = 10,
    ["Railroad"]   = 25,
    ["Mine"]       = 20,
    ["Irrigation"] = 15,
    ["Farmland"]   = 15,
    ["Sea Tunnel"] = 40,
    ["Kelp Farm"]  = 30,
  },
}

-- Runtime state. player.id -> PW balance.
EPOCH_STATE = { pw = {} }

-- Save/load persistence: freeciv's _freeciv_state_dump (tolua_common_a.pkg)
-- serializes only SCALAR globals (boolean/number/string/userdata) into the
-- savegame's script.vars — tables like EPOCH_STATE are skipped. So we mirror
-- the pool into this string ("pid:balance;pid:balance") after every mutation;
-- on load the engine re-executes the assignment and epoch_pw_rehydrate()
-- parses it back into EPOCH_STATE.pw before first use.
EPOCH_PW_SAVED = ""

local epoch_pw_hydrated = false

local function epoch_pw_serialize()
  local parts = {}
  for pid, bal in pairs(EPOCH_STATE.pw) do
    parts[#parts + 1] = tostring(pid) .. ":" .. tostring(bal)
  end
  EPOCH_PW_SAVED = table.concat(parts, ";")
end

local function epoch_pw_rehydrate()
  if epoch_pw_hydrated then return end
  epoch_pw_hydrated = true
  if EPOCH_PW_SAVED == nil or EPOCH_PW_SAVED == "" then return end
  local n = 0
  for pid, bal in string.gmatch(EPOCH_PW_SAVED, "(%-?%d+):(%-?%d+)") do
    EPOCH_STATE.pw[tonumber(pid)] = tonumber(bal)
    n = n + 1
  end
  log.normal("[EPOCH][pw_load] restored " .. tostring(n)
             .. " Public Works balances from savegame.")
end

local function epoch_pw_balance(player)
  epoch_pw_rehydrate()
  return EPOCH_STATE.pw[player.id] or 0
end

local function epoch_pw_gov_mult(player)
  local gov = player.government
  local mult = nil
  if gov ~= nil then
    mult = EPOCH_CONFIG.pw.gov_multipliers[gov:rule_name()]
  end
  return mult or EPOCH_CONFIG.pw.default_gov_multiplier
end

-- Accrual: called once per turn from epoch_turn_begin.
function epoch_pw_accrue(turn)
  epoch_pw_rehydrate()
  local cfg = EPOCH_CONFIG.pw
  for player in players_iterate() do
    if player.is_alive then
      local sizes = 0
      for city in player:cities_iterate() do
        sizes = sizes + city.size   -- property, not method, in this build
      end
      if sizes > 0 then
        local mult = epoch_pw_gov_mult(player)
        local gain = math.floor(sizes * cfg.base_rate * mult)
        if gain > 0 then
          EPOCH_STATE.pw[player.id] = (EPOCH_STATE.pw[player.id] or 0) + gain
          log.normal(string.format(
            "[EPOCH][pw_accrue] player=%d gov=%s sizes=%d gain=%d balance=%d turn=%d",
            player.id, player.government:rule_name(), sizes, gain,
            EPOCH_STATE.pw[player.id], turn))
        end
      end
    end
  end
  epoch_pw_serialize()
end

-- Terrain-context improvement picker. Returns the Extra rule_name to place on
-- this tile for this player, or nil if nothing is legal. Mirrors the extras'
-- terrain.ruleset requirements (edit.create_extra bypasses them, so this IS
-- the legality check). v1 auto-pick; an explicit-choice UX can come later.
local EPOCH_PW_MINE_TERRAIN = { ["Hills"] = true, ["Mountains"] = true }
local EPOCH_PW_FARM_TERRAIN = {
  ["Grassland"] = true, ["Plains"] = true, ["Desert"] = true, ["Tundra"] = true,
}
local EPOCH_PW_OCEAN_TERRAIN = {
  ["Ocean"] = true, ["Deep Ocean"] = true, ["Lake"] = true,
}

local function epoch_knows(player, techname)
  local tt = find.tech_type(techname)
  return tt ~= nil and player:knows_tech(tt)
end

function epoch_pw_pick_extra(player, tile)
  local tname = tile.terrain:rule_name()
  if EPOCH_PW_OCEAN_TERRAIN[tname] then
    if epoch_knows(player, "Pressure Ecology") and not tile:has_extra("Kelp Farm")
       and tile:city() == nil then
      return "Kelp Farm"
    end
    if epoch_knows(player, "Abyssal Engineering")
       and not tile:has_extra("Sea Tunnel") then
      return "Sea Tunnel"
    end
    return nil
  end
  -- Land from here down.
  if EPOCH_PW_MINE_TERRAIN[tname] and not tile:has_extra("Mine") then
    return "Mine"
  end
  if EPOCH_PW_FARM_TERRAIN[tname] and not EPOCH_PW_MINE_TERRAIN[tname] then
    if not tile:has_extra("Irrigation") then
      return "Irrigation"
    end
    if not tile:has_extra("Farmland") and epoch_knows(player, "Refrigeration") then
      return "Farmland"
    end
  end
  -- General fallback: the road network.
  if not tile:has_extra("Road") then
    return "Road"
  end
  if not tile:has_extra("Railroad") and epoch_knows(player, "Railroad") then
    return "Railroad"
  end
  return nil
end

-- The single server-authoritative spend path (design tenet #3): every caller
-- (Surveyor action now, chat fallback later) funnels through here, and it
-- re-validates everything before debiting or mutating.
function epoch_pw_place(player, kind, tile)
  epoch_pw_rehydrate()
  if kind == nil or tile == nil or player == nil then return false end
  local cost = EPOCH_CONFIG.pw.improvement_costs[kind]
  if cost == nil then
    log.error("[EPOCH][pw_spend] unknown improvement kind '" .. tostring(kind) .. "'")
    return false
  end
  local function refuse(reason)
    log.normal(string.format(
      "[EPOCH][pw_refuse] player=%d kind=%s reason=%s tile=(%d,%d) turn=%d",
      player.id, kind, reason, tile.x, tile.y, epoch_current_turn))
  end
  if tile.owner == nil or tile.owner.id ~= player.id then
    refuse("not_owned")
    notify.event(player, tile, E.SCRIPT,
      _("Public Works: that tile is not part of your territory."))
    return false
  end
  if tile:has_extra(kind) then
    refuse("already_present")
    notify.event(player, tile, E.SCRIPT,
      _("Public Works: a %s is already in place there."), kind)
    return false
  end
  local balance = epoch_pw_balance(player)
  if balance < cost then
    refuse("insufficient_funds")
    notify.event(player, tile, E.SCRIPT,
      _("Public Works: insufficient reserve (%d needed, %d available)."),
      cost, balance)
    return false
  end
  EPOCH_STATE.pw[player.id] = balance - cost
  epoch_pw_serialize()
  edit.create_extra(tile, kind)
  log.normal(string.format(
    "[EPOCH][pw_spend] player=%d kind=%s cost=%d tile=(%d,%d) turn=%d balance=%d",
    player.id, kind, cost, tile.x, tile.y, epoch_current_turn,
    EPOCH_STATE.pw[player.id]))
  notify.event(player, tile, E.SCRIPT,
    _("Public Works: %s commissioned (%d PW spent, %d remaining)."),
    kind, cost, EPOCH_STATE.pw[player.id])
  return true
end

-- Handler for the shared tiles slot. NOTE: "User Action 3" (Field Operation)
-- is MULTIPLEXED — future special-action units (Ecoterrorist etc., see
-- doc/design/feature-special-actions.md section 2) will also arrive on this
-- signal with the same action. The PublicWorks-flag guard below keeps PW
-- logic from firing for them; their handlers must guard likewise.
function epoch_commission_works(action, actor, target_tile)
  if action:rule_name() ~= "User Action 3" then return end
  if not actor.utype:has_flag("PublicWorks") then return end
  local player = actor.owner
  local kind = epoch_pw_pick_extra(player, target_tile)
  if kind == nil then
    notify.event(player, target_tile, E.SCRIPT,
      _("Public Works: nothing to build here."))
    return
  end
  epoch_pw_place(player, kind, target_tile)
end
signal.connect("action_started_unit_tile", "epoch_commission_works")

-- ------------------------------------------------------------
-- Special actions (backlog 1.5 + 1.6) — unconventional warfare.
-- Design: doc/design/feature-special-actions.md. One registry (EPOCH_SPECIAL,
-- keyed by unit rule_name) + one runner (epoch_run_special); the 4 User
-- Action slots are multiplexed by Spec* unit-type flags (actions.ruleset);
-- the Lawyer's counter-injunction persists as the "Injunction" Extra
-- (terrain.ruleset) so it survives save/load — only its expiry TIMER is Lua.
--
-- API verified against this build (tolua_server.pkg / tolua_game.pkg /
-- unithand.c, 2026-07-04):
--   edit.transfer_city(city, new_owner) -> bool   -- 2 args, NOT the 7-arg
--     signature guessed in the design doc.
--   edit.unit_kill(unit, reason, killer_or_nil)   -- reason must be a
--     unit_loss_reason name; "used" is valid ("quiet" is NOT). The engine
--     explicitly tolerates the actor dying inside the action_started signal
--     ("Actor unit was destroyed during pre action Lua" re-check in
--     unithand.c), so per-unit Lua consumption is safe. Consequence: a
--     CONSUMING op makes unit:perform_action() return false even though the
--     op ran — the engine aborts its (empty) native perform when the actor
--     is gone. Callers must not read that as failure.
--   player:gold() (method); city.size/.tile (properties), city.id/.name/
--     .owner (fields); tile.id (index field); find.tile(index).
--   random(1, 100) — the seeded fc_rand binding (MP-deterministic), same
--     one the map-label code above uses.
-- All slots keep actor_consuming_always=FALSE (slot 3 is locked FALSE by
-- Public Works; slot 1 is shared by consuming Cleric + repeatable Corporate
-- Branch), so consumption is ALWAYS the runner's job, per registry row.
-- ------------------------------------------------------------

EPOCH_CONFIG.special = {
  injunction_turns = 5,   -- turns a Lawyer's injunction remains in force
}

local function epoch_clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- ---- Injunction timers -------------------------------------------------
-- The FACT of an injunction is the Extra on the tile (save-safe map data).
-- This table holds only the expiry turn, keyed by tile index, mirrored into
-- the scalar EPOCH_INJ_SAVED for savegames (same pattern as EPOCH_PW_SAVED:
-- _freeciv_state_dump persists scalar globals only).
EPOCH_STATE.injunctions = {}
EPOCH_INJ_SAVED = ""
local epoch_inj_hydrated = false

local function epoch_inj_serialize()
  local parts = {}
  for tid, expiry in pairs(EPOCH_STATE.injunctions) do
    parts[#parts + 1] = tostring(tid) .. ":" .. tostring(expiry)
  end
  EPOCH_INJ_SAVED = table.concat(parts, ";")
end

local function epoch_inj_rehydrate()
  if epoch_inj_hydrated then return end
  epoch_inj_hydrated = true
  if EPOCH_INJ_SAVED == nil or EPOCH_INJ_SAVED == "" then return end
  local n = 0
  for tid, expiry in string.gmatch(EPOCH_INJ_SAVED, "(%d+):(%-?%d+)") do
    EPOCH_STATE.injunctions[tonumber(tid)] = tonumber(expiry)
    n = n + 1
  end
  log.normal("[EPOCH][inj_load] restored " .. tostring(n)
             .. " injunction timers from savegame.")
end

function epoch_place_injunction(tile, turns)
  epoch_inj_rehydrate()
  if not tile:has_extra("Injunction") then
    edit.create_extra(tile, "Injunction")
  end
  EPOCH_STATE.injunctions[tile.id] = epoch_current_turn + turns
  epoch_inj_serialize()
  log.normal(string.format(
    "[EPOCH][inj_place] tile=%d expires=%d turn=%d",
    tile.id, EPOCH_STATE.injunctions[tile.id], epoch_current_turn))
end

-- Called once per turn from epoch_turn_begin (single handler doctrine).
function epoch_inj_sweep(turn)
  epoch_inj_rehydrate()
  local expired = {}
  for tid, expiry in pairs(EPOCH_STATE.injunctions) do
    if turn >= expiry then expired[#expired + 1] = tid end
  end
  for ei, tid in ipairs(expired) do
    EPOCH_STATE.injunctions[tid] = nil
    local tile = find.tile(tid)
    if tile ~= nil and tile:has_extra("Injunction") then
      edit.remove_extra(tile, "Injunction")
    end
    log.normal(string.format("[EPOCH][inj_expire] tile=%d turn=%d", tid, turn))
  end
  if #expired > 0 then epoch_inj_serialize() end
end

-- ---- The registry (one tuning surface) ---------------------------------
-- Keyed by unit rule_name. action = which User Action slot the row answers
-- to (double-checked against the fired action so a future slot reshuffle
-- cannot silently mis-route). cost = gold. success(actor, target) -> 0..1.
-- effect(actor, target) runs only on a successful roll. counter = Extra
-- rule_name that blocks the op when present on the target tile (checked
-- BEFORE any charge). consuming = unit spent on the attempt, win or lose.
EPOCH_SPECIAL = {
  ["Cleric"] = {
    action = "User Action 1",
    cost = 120,
    consuming = true,
    counter = "Injunction",
    telemetry = "convert_city",
    success = function(actor, city)
      return epoch_clamp(0.75 - 0.05 * city.size, 0.05, 0.90)
    end,
    effect = function(actor, city)
      local old_owner = city.owner
      local cname = city.name
      edit.transfer_city(city, actor.owner)
      notify.event(actor.owner, city.tile, E.SCRIPT,
        _("Your Cleric has converted %s to your cause!"), cname)
      notify.event(old_owner, city.tile, E.SCRIPT,
        _("%s has been converted by foreign clerics!"), cname)
    end,
  },
  ["Corporate Branch"] = {
    action = "User Action 1",
    cost = 40,
    consuming = false,
    counter = "Injunction",
    telemetry = "franchise",
    success = function(actor, city)
      return 0.85
    end,
    effect = function(actor, city)
      local take = 60 + 10 * city.size
      edit.change_gold(actor.owner, take)
      notify.event(actor.owner, city.tile, E.SCRIPT,
        _("Your Corporate Branch franchises %s: %d gold skimmed."),
        city.name, take)
      notify.event(city.owner, city.tile, E.SCRIPT,
        _("A foreign corporation has opened a franchise in %s."), city.name)
    end,
  },
  ["Ecoterrorist"] = {
    action = "User Action 3",
    cost = 90,
    consuming = true,
    counter = "Injunction",
    telemetry = "sabotage_tile",
    success = function(actor, tile)
      return 0.65
    end,
    effect = function(actor, tile)
      -- Tear down the most developed improvement first; if the tile is
      -- bare, foul it with pollution instead.
      local order = {
        "Farmland", "Kelp Farm", "Oil Platform", "Oil Well", "Mine",
        "Irrigation", "Maglev", "Railroad", "Sea Tunnel", "Road",
      }
      -- NOTE: loop var must NOT be "_" -- that would shadow the gettext
      -- function called inside the loop body (a number is not callable).
      for oi, name in ipairs(order) do
        if tile:has_extra(name) then
          edit.remove_extra(tile, name)
          notify.event(actor.owner, tile, E.SCRIPT,
            _("Sabotage! The %s at (%d, %d) has been destroyed."),
            name, tile.x, tile.y)
          if tile.owner ~= nil then
            notify.event(tile.owner, tile, E.SCRIPT,
              _("Ecoterrorists have destroyed the %s at (%d, %d)!"),
              name, tile.x, tile.y)
          end
          return
        end
      end
      edit.create_extra(tile, "Pollution")
      notify.event(actor.owner, tile, E.SCRIPT,
        _("Nothing to dismantle -- the operatives befoul the tile instead."))
    end,
  },
  ["Lawyer"] = {
    action = "User Action 4",
    cost = 60,
    consuming = true,
    counter = nil,   -- injunctions do not block filing injunctions
    telemetry = "file_injunction",
    success = function(actor, target)
      return 1.0    -- filing always succeeds; the price is gold + the unit
    end,
    effect = function(actor, target)
      epoch_place_injunction(actor.tile, EPOCH_CONFIG.special.injunction_turns)
      notify.event(actor.owner, actor.tile, E.SCRIPT,
        _("Injunction filed: this tile is legally shielded for %d turns."),
        EPOCH_CONFIG.special.injunction_turns)
    end,
  },
}

-- ---- The shared runner (design doc section 3) ---------------------------
-- Server-authoritative: guard -> charge -> roll -> apply -> consume ->
-- telemetry. Aborted guards notify and charge NOTHING.
function epoch_run_special(reg, actor, target, tile, tdesc)
  local player = actor.owner
  local uname = actor.utype:name_translation()
  -- Guard 1: counter-injunction on the target tile (abort, no charge).
  if reg.counter ~= nil and tile ~= nil and tile:has_extra(reg.counter) then
    notify.event(player, tile, E.SCRIPT,
      _("%s: the operation is blocked by a standing legal injunction."),
      uname)
    log.normal(string.format(
      "[EPOCH][special_action] action=%s actor_type=%s actor=%d target=%s blocked=injunction turn=%d",
      reg.telemetry, actor.utype:rule_name(), actor.id, tdesc,
      epoch_current_turn))
    return
  end
  -- Guard 2: affordability (abort, no charge).
  local gold = player:gold()
  if gold < reg.cost then
    notify.event(player, tile, E.SCRIPT,
      _("%s: not enough gold (%d needed, %d available)."),
      uname, reg.cost, gold)
    log.normal(string.format(
      "[EPOCH][special_action] action=%s actor_type=%s actor=%d target=%s blocked=gold turn=%d",
      reg.telemetry, actor.utype:rule_name(), actor.id, tdesc,
      epoch_current_turn))
    return
  end
  -- Charge.
  edit.change_gold(player, -reg.cost)
  -- Roll — ruleset-global seeded RNG, MP-deterministic.
  local pct = math.floor(reg.success(actor, target) * 100)
  local ok = random(1, 100) <= pct
  -- Apply.
  if ok then
    reg.effect(actor, target)
  else
    notify.event(player, tile, E.SCRIPT,
      _("%s: the operation failed (%d gold spent)."), uname, reg.cost)
  end
  -- Telemetry (before consumption so actor fields are still valid).
  log.normal(string.format(
    "[EPOCH][special_action] action=%s actor_type=%s actor=%d target=%s success=%s cost=%d turn=%d",
    reg.telemetry, actor.utype:rule_name(), actor.id, tdesc, tostring(ok),
    reg.cost, epoch_current_turn))
  -- Consume LAST — unithand.c re-checks unit_is_alive after this handler.
  if reg.consuming then
    edit.unit_kill(actor, "used", nil)
  end
end

-- ---- Slot handlers -------------------------------------------------------
-- Slot 1 (City): Cleric, Corporate Branch.
function epoch_civic_op(action, actor, target_city)
  if action:rule_name() ~= "User Action 1" then return end
  local reg = EPOCH_SPECIAL[actor.utype:rule_name()]
  if reg == nil or reg.action ~= "User Action 1" then return end
  epoch_run_special(reg, actor, target_city, target_city.tile,
                    string.format("city=%d", target_city.id))
end
signal.connect("action_started_unit_city", "epoch_civic_op")

-- Slot 3 (Tile): SECOND handler on action_started_unit_tile, coexisting
-- with epoch_commission_works above. Each guards on its own flags: PW
-- early-returns unless the actor has PublicWorks; this one early-returns
-- FOR PublicWorks units and for any type not in the registry.
function epoch_field_op_special(action, actor, target_tile)
  if action:rule_name() ~= "User Action 3" then return end
  if actor.utype:has_flag("PublicWorks") then return end
  local reg = EPOCH_SPECIAL[actor.utype:rule_name()]
  if reg == nil or reg.action ~= "User Action 3" then return end
  epoch_run_special(reg, actor, target_tile, target_tile,
                    string.format("tile=%d", target_tile.id))
end
signal.connect("action_started_unit_tile", "epoch_field_op_special")

-- Slot 4 (Self): Lawyer. Self actions have no target; the tile is the
-- actor's own.
function epoch_legal_injunction(action, actor)
  if action:rule_name() ~= "User Action 4" then return end
  local reg = EPOCH_SPECIAL[actor.utype:rule_name()]
  if reg == nil or reg.action ~= "User Action 4" then return end
  epoch_run_special(reg, actor, nil, actor.tile, "self")
end
signal.connect("action_started_unit_self", "epoch_legal_injunction")
