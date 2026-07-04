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
  -- Age IV — Helix (Slice 1 skeleton: anchor + one leaf; full 13 in Slice 2)
  ["Genome Cartography"]=4, ["Cellular Rewriting"]=4,
  -- Age V — Lattice (Slice 1 skeleton: anchor + one leaf; full 14 in Slice 3)
  ["Molecular Assembly"]=5, ["Metamaterials"]=5,
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
end
signal.connect("turn_begin", "epoch_turn_begin")
