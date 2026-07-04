# Epoch Five-Age Tech Tree — Design Document

**Status:** Proposed design for backlog item 1.1 (five-age tech tree). Governs 1.2 (unit rosters), 1.3 (PW tiers), 1.7 (governments), 2.1/2.2 (undersea), 3.1–3.4 (far-future content, orbital, solarpunk, victory).
**Author:** Fable 5 design session (2026-07-02), reviewed against engine capabilities before implementation.
**Source material:** `data/epoch/techs.ruleset` (civ2civ3, 87 techs), `doc/ROADMAP.md`, `doc/design/epoch-lua-systems-draft.lua`.

> **Engine-claim verification (checked 2026-07-02 against this build before Slice 0 — all PASS):**
> - **Tech classes + `cost_pct`** — documented in `techs.ruleset` header (`[techclass_*]`, per-tech `class=`, `cost_pct` default 100%). Per-age pacing knobs work.
> - **`root_req` + inheritance** — confirmed: "All techs with any direct or indirect dependency on this one will *also* have this root_req." Also: `root_req = None` explicitly halts inheritance; `root_req = <self>` = acquirable only by scripting/init_techs. The techs.ruleset "not supported yet" caveat applies to `research_reqs`, NOT `root_req` — no gotcha for our design (we gate via req1/req2/root_req).
> - **`tech_researched` signal** — confirmed present in this build's shipped Lua. Full verified signal set for future Epoch Lua work: `turn_begin`, `tech_researched`, `city_built`, `city_destroyed`, `city_transferred`, `building_built`, `unit_lost`, `hut_enter`, `hut_frighten`, `action_started_unit_tile`, `action_started_unit_unit`, `disaster_occurred`, `map_generated`.

---

## 1. The Five Ages

Each age is named for its defining *artifact or structure* — a material metaphor ending on the crystal lattice (the actual structure of diamond) without using Activision's era names. All names original.

| # | Age | CtP2 analogue | Fiction / feel | Tech count | Rough game span |
|---|-----|---------------|----------------|-----------|-----------------|
| I | **The Ember Age** | Ancient | Firelight, first cities, bronze and iron, first laws and gods. Long, foundational. | 26 (existing) | ~20% of turns |
| II | **The Compass Age** | Renaissance (+medieval) | Faith transformed, universities, powder and sail; the world becomes navigable and knowable. | 17 (existing) | ~15% |
| III | **The Dynamo Age** | Modern | Steam to silicon in one violent compression: rail, steel, flight, the atom, the computer, first rockets. | 45 (44 existing + 1 new) | ~30% |
| IV | **The Helix Age** | Genetic | The biological turn: rewritten cells, grown materials, sealed ecologies, first ocean-floor colonies, minds bridged to machines. | 14 (13 new + reassignments) | ~15% |
| V | **The Lattice Age** | Diamond | Matter becomes programmable: atom-precise fabrication, cyborg symbiosis, plasma weapons, orbital tethers, synthetic minds — and the solarpunk choice: a gardened planet or a conquered one. | 14 (all new) | ~20% |

Total: **115 techs** (87 existing + 28 new). Dynamo is deliberately fat (as in CtP2); per-tech research cost accelerates through it so wall-clock share stays ~30%. Pacing enforced with **tech classes** (one per age) carrying a rising `cost_pct` multiplier — those five multipliers are the era-pacing tuning knobs (live in `EPOCH_CONFIG`).

---

## 2. Era Detection — Recommendation

**Marker-based, generalized to bucket-membership, with two hard `root_req` anchors for the future ages. Do NOT use tech counts.** (Replaces the draft Lua's `min_tech` count thresholds — counts are fragile, exploitable via cheap-tech lawnmowering, and wrong for acquired techs.)

**The rule: a player's age = the highest age of any tech they know.** This is CtP2's actual behavior — the era turns the moment you hold your first next-age advance. Implementation shape:

- A single Lua table mapping tech name → age (1–5). This table *is* §3's bucket assignment; one source of truth.
- On the `tech_researched` signal (research, trade, theft, conquest): look up the tech's age; if greater than the player's stored era, transition — notify + fire `era_transition` telemetry `{player, from, to, turn, trigger_tech}`.
- Safety net: full rescan of known techs at `turn_begin` and on load (Lua state doesn't survive saves). Era is monotonic — never regresses.

**Herald / anchor techs:**

| Age | Herald / anchor | Enforcement |
|---|---|---|
| I Ember | — (game start) | — |
| II Compass | **Feudalism** (heralds; Monotheism / University alternate doors) | Soft — bucket membership |
| III Dynamo | **Steam Engine** (heralds; Conscription / Sanitation alternate) | Soft — bucket membership |
| IV Helix | **Genome Cartography** (new) | **Hard** — all Helix techs descend from it or carry `root_req = Genome Cartography` |
| V Lattice | **Molecular Assembly** (new) | **Hard** — all Lattice techs descend from it or carry `root_req = Molecular Assembly` |

Invariant for the two future ages: *no age-IV/V tech can be acquired by any means (incl. theft/trade) without the age's anchor in your ancestry.* Freeciv `root_req` inheritance propagates automatically. Detection and gating therefore agree by construction — impossible to hold a Helix tech while reading as Dynamo.

---

## 3. Age Assignment — All 87 Existing Techs

### Age I — Ember (26)
Alphabet, Pottery, Masonry, Bronze Working, Ceremonial Burial, Horseback Riding, Warrior Code, The Wheel, Writing, Code of Laws, Mysticism, Map Making, Currency, Iron Working, Mathematics, Polytheism, Trade, Seafaring, Construction, Bridge Building, Literacy, Monarchy, Philosophy, The Republic, Astronomy, Medicine.

*(Astronomy & Medicine stay Ember — Hellenistic science — and Medicine becomes a direct ancient root of the Helix age; see §5.)*

### Age II — Compass (17)
Feudalism, Chivalry, Monotheism, Theology, University, Invention, Gunpowder, Banking, Navigation, Physics, Magnetism, Theory of Gravity, Leadership, Metallurgy, Chemistry, Economics, Democracy.

### Age III — Dynamo (45)
Steam Engine, Railroad, Industrialization, The Corporation, Sanitation, Explosives, Refining, Electricity, Engineering, Steel, Conscription, Tactics, Machine Tools, Combustion, Automobile, Mass Production, Refrigeration, Atomic Theory, Electronics, Radio, Flight, Advanced Flight, Mobile Warfare, Combined Arms, Amphibious Warfare, Guerilla Warfare, Espionage, Communism, Labor Union, Nuclear Fission, Nuclear Power, Miniaturization, Computers, Rocketry, Space Flight, Laser, Superconductors, Robotics, Plastics, Stealth, Recycling, Environmentalism, Genetic Engineering, Fusion Power, **+ Networked Computing (new)**.

*(Genetic Engineering & Fusion Power are bucketed Dynamo, not Helix — the doorway and the power source, both prereqs of the future anchors. Keeps the Helix boundary strictly at Genome Cartography.)*

### Cut/merge flags (keep all 87 for the initial port; flag for a later balance pass — do rehoming once, with unit work 1.2)
- Amphibious Warfare → fold into Combined Arms. Guerilla Warfare → fold into Espionage/Communism. Atomic Theory → fold into Nuclear Fission. Leadership → fold into Gunpowder (weakest candidate; does useful graph work).

---

## 4. New Techs (28) — name — *req1 + req2* — meaning

### Dynamo gap-fill (1)
- **Networked Computing** — *Computers + Mass Production* — planetary data networks; the internet-analogue civ2civ3 lacked; bridge to everything after.

### Helix Age (13)
- **Genome Cartography** ⚓ — *Genetic Engineering + Networked Computing* — **anchor.** Complete mapping of life's code.
- **Cellular Rewriting** — *Genome Cartography + Medicine* — gene-level healing; longevity, plague immunity. (Medicine is Ember — a deliberate 4,000-yr edge.)
- **Chimeric Agriculture** — *Genome Cartography + Refrigeration* — grown/engineered crops.
- **Cultured Materials** — *Genome Cartography + Plastics* — vat-grown structural materials.
- **Pressure Ecology** — *Cellular Rewriting + Superconductors* — deep-sea biology/hulls. **Undersea colonization opens.**
- **Abyssal Engineering** — *Pressure Ecology + Steel* — undersea cities/tunnels/mines. **Undersea building tier.**
- **Cybernetic Symbiosis** — *Cellular Rewriting + Robotics* — cyborg unit line begins.
- **Machine Cognition** — *Networked Computing + Robotics* — learning machines; automation.
- **Closed Biospheres** — *Chimeric Agriculture + Environmentalism* — sealed ecologies/arcologies; solarpunk foundation.
- **Reclamation Science** — *Closed Biospheres + Recycling* — terraforming/de-pollution; solarpunk PW.
- **Directed Energy** — *Laser + Fusion Power* — plasma/energy-weapon precursor.
- **Orbital Logistics** — *Space Flight + Machine Cognition* — routine orbit presence. **Orbital tier opens.**
- **Synthetic Cognition** — *Machine Cognition + Cellular Rewriting* — artificial minds; endgame AI branch; joins silicon + cell threads.

### Lattice Age (14)
- **Molecular Assembly** ⚓ — *Cultured Materials + Synthetic Cognition* — **anchor.** Atom-precise fabrication; programmable matter.
- **Metamaterials** — *Molecular Assembly + Superconductors* — impossible bulk properties; super-armor/stealth.
- **Adaptive Fabrication** — *Molecular Assembly + Machine Cognition* — self-configuring factories; PW/construction leap.
- **Plasma Containment** — *Directed Energy + Metamaterials* — signature Lattice weapon tier.
- **Orbital Foundries** — *Orbital Logistics + Adaptive Fabrication* — zero-g manufacturing.
- **Orbital Ordnance** — *Orbital Foundries + Plasma Containment* — **orbital weapon platforms** (Gap 3). Hard-gated Lattice.
- **Skyhook Tethers** — *Orbital Logistics + Metamaterials* — space elevators/mass drivers; cheap orbit access.
- **Deep Habitation** — *Abyssal Engineering + Molecular Assembly* — mature undersea megacities.
- **Neural Uplink** — *Cybernetic Symbiosis + Synthetic Cognition* — mind-network integration; endgame cyborg + hive/technocratic government substrate.
- **Autonomous Legions** — *Adaptive Fabrication + Neural Uplink* — war-walkers, drone armies.
- **Living Architecture** — *Reclamation Science + Molecular Assembly* — buildings that grow/self-repair; peak solarpunk.
- **Planetary Stewardship** — *Living Architecture + Closed Biospheres* — whole-world biosphere management; eco-victory branch.
- **Fusion Lattices** — *Fusion Power + Metamaterials* — ubiquitous compact fusion; power ceiling.
- **Ascendant Intelligence** — *Neural Uplink + Fusion Lattices* — civilization-scale supermind; AI/tech victory capstone.

⚓ = age anchor / `root_req` carrier. All nodes ≤2 prereqs. 1 + 13 + 14 = 28 new.

---

## 5. Dependency Structure — "Late Rooted in Early"

Five signature throughlines, each starting at an Ember/Compass tech and ending at a Lattice capstone (all legitimate ≤2-prereq paths):

1. **Orbital line (Ember→Lattice):** Mathematics → Astronomy → … Physics → Theory of Gravity → Rocketry → Space Flight → **Orbital Logistics** → **Orbital Foundries** → **Orbital Ordnance**.
2. **Bio line (Ember→Lattice):** Ceremonial Burial → Medicine → Genetic Engineering → **Genome Cartography** → **Cellular Rewriting** → **Cybernetic Symbiosis** → **Neural Uplink** → **Ascendant Intelligence**. (Deliberate Medicine→Cellular Rewriting 4,000-yr edge.)
3. **Undersea line (Compass→Lattice):** Seafaring/Navigation → Superconductors → **Pressure Ecology** → **Abyssal Engineering** → **Deep Habitation**.
4. **Energy-weapon line (Compass→Lattice):** Physics → Laser + Fusion Power → **Directed Energy** → **Plasma Containment**.
5. **Synthetic-mind line (Dynamo→Lattice), the great convergence:** (Computers → Networked Computing → Machine Cognition) + Robotics braid at **Synthetic Cognition**, which feeds BOTH **Molecular Assembly** and **Neural Uplink** — the intentional AI bottleneck of the endgame.

**`root_req` usage — minimal, but corrected in Slice 2 (2026-07-03):** two anchors, plus
explicit `root_req` on the ENTRY nodes that don't otherwise inherit the anchor. **Genome
Cartography** stamps the entire Helix+Lattice tree; **Molecular Assembly** hard-gates
pure-Lattice capabilities. The subtlety the original text missed: an anchor has *no* `root_req`
itself (it must stay researchable), so its children do **not** inherit anything from it —
`root_req` only flows from a tech that *has* one to that tech's dependents. Therefore every
Helix **entry node** needs an explicit `root_req = "Genome Cartography"` to seed the
inheritance; downstream techs then inherit automatically. The entry nodes are:
- **Direct anchor children:** Cellular Rewriting, Chimeric Agriculture, Cultured Materials
  (require GC via `req1`, but theft/trade ignore `req1`, so they still need `root_req`).
- **Dynamo-rooted orphan lines** (the real leak the original "at most Pressure Ecology, Orbital
  Logistics" guess missed): **Machine Cognition** (Networked Computing + Robotics) and
  **Directed Energy** (Laser + Fusion Power) — neither prereq touches the anchor, so without
  explicit `root_req` they'd be researchable/stealable while still Dynamo.

Everything else (Pressure Ecology, Abyssal Engineering, Cybernetic Symbiosis, Synthetic
Cognition, Closed Biospheres, Reclamation Science, Orbital Logistics) **inherits** GC through
one of those entry nodes and needs nothing explicit. **Verified in Slice 2:** with req1+req2
held, Machine Cognition and Directed Energy are `can_research == false` until Genome Cartography
is known. The Lattice age will need the analogous treatment for **Molecular Assembly** on its
own Dynamo/Helix-rooted entry nodes in Slice 3.

**Key branch points:** Genome Cartography (bio/agri/materials fork), Synthetic Cognition (convergence), Molecular Assembly (weapons/industry/habitat/space fork), Living Architecture vs Autonomous Legions (solarpunk-vs-militarist → victory paths).

---

## 6. Category-Level Unlock Map

| Category | Ember I | Compass II | Dynamo III | Helix IV | Lattice V |
|---|---|---|---|---|---|
| **Units** | warriors, spearmen, archers, chariots, early ships, catapults | knights, pikemen, musketeers, cannon, galleons, frigates | rifle→mech-inf, armor, artillery, battleships, aircraft, subs, nukes, early robots | cyborg infantry, gene-troops, drones, undersea craft, deep-sea colonizers | war-walkers, plasma units, star-cruisers/space-planes, orbital platforms, synthetic legions |
| **Buildings/wonders** | granary, temple, walls, library, market, aqueduct | cathedral, university, bank, harbor | factory, power plant, hospital, research lab, spaceport | gene-clinic, arcology seed, biosphere dome, undersea core, orbital station | nanofab, plasma foundry, living-arcology, orbital foundry, planetary-steward complex |
| **Governments (1.7)** | Despotism, Monarchy | Republic, Theocracy, Feudal Monarchy | Democracy, Communism, Corporatocracy | **Technocracy** (Machine Cognition), **Ecotopia** (Closed Biospheres) | **Neural Collective** (Neural Uplink), **Gaia Stewardship** (Planetary Stewardship) |
| **Public Works (1.3)** | roads, irrigation, mines, forestry | farmland, fortresses, harbors | railroads, advanced mines, transit corridors | **sea tunnels/undersea mines** (Abyssal Eng.), bio-farms, eco-restoration | **solar/fusion arrays**, nanofab districts, skyhook nodes, climate works |
| **Era-locked systems** | — | — | — | **undersea colonization** (Pressure Ecology→Abyssal Eng.); cyborg + AI lines begin | **orbital weapon platforms** (Orbital Ordnance); deep-sea megacities (Deep Habitation); programmable-matter economy |
| **Victory hooks (3.4)** | — | — | space-race preserved | — | **Gaia/Planetary Stewardship** (eco) vs **Ascendant Intelligence** (AI/tech) vs conquest |

---

## 7. Implementation Staging

Smoke-test each slice against `scripts/epoch-smoke-test.sh` (Phase 3 discipline). First slice proves the five-age arc transitions end-to-end, not full content.

- **Slice 0 — Detection harness on the existing tree (MVP backbone).** Before any new tech: replace the draft's `min_tech` counts with the tech→age lookup for the 87 existing techs (ages I–III populated; IV/V empty). Wire `tech_researched` + `turn_begin` rescan. Wire five tech classes with placeholder `cost_pct`. **Test:** autogame fires era_transition I→II→III at sane turns; telemetry logs `{from,to,trigger_tech}`; zero Lua errors.
- **Slice 1 — Anchors + skeletal future ages. ✅ DONE (2026-07-03).** Added the 2 anchors
  (Genome Cartography IV, Molecular Assembly V) + Networked Computing + one leaf per future age
  (Cellular Rewriting IV, Metamaterials V) with `root_req`; extended `EPOCH_TECH_AGE`.
  **Verified in-container:** era detection fires III→IV→V on the new anchors
  (`era_transition … to=4 (helix) … to=5 (lattice)`); the hard gate holds — a player holding
  Metamaterials' `req1`+`req2` but not the anchor has `can_research(Metamaterials)==false`
  (inherited `root_req=Genome Cartography` blocks acquisition by any means), flipping to `true`
  the moment the anchor is granted. Key API finding: `edit.give_tech` **force-grants** (bypasses
  `root_req`, the "scripting" special case) so it is NOT a denial-test vector; `player:can_research`
  (= `research_invention_state == TECH_PREREQS_KNOWN`) is the correct probe as it honors `root_req`.
  *Skeletal prereqs* (Molecular Assembly ← Cellular Rewriting only, etc.) get replaced by the full
  graph in Slices 2–3.
- **Slice 2 — Full Helix (13). ✅ DONE (2026-07-03).** Added the 11 remaining Helix advances
  with real `req1/req2` pairs (Chimeric Agriculture, Cultured Materials, Pressure Ecology,
  Abyssal Engineering, Cybernetic Symbiosis, Machine Cognition, Synthetic Cognition, Closed
  Biospheres, Reclamation Science, Directed Energy, Orbital Logistics); rewired Molecular
  Assembly to its canonical prereqs (Cultured Materials + Synthetic Cognition, now available);
  seeded explicit `root_req = Genome Cartography` on the 5 entry nodes (see §5 correction above);
  extended `EPOCH_TECH_AGE` (all 13 Helix at age 4). **Verified in-container:** ruleset loads
  clean; tech→age map = **103 techs, 0 unmatched**; era fires to age 4; the orphan-line gate
  holds (Machine Cognition & Directed Energy `can_research == false` without the anchor, `true`
  with it). Undersea (Pressure/Abyssal) + cyborg/AI (Cybernetic/Machine/Synthetic Cognition)
  branch points now exist — unblocks 2.1/2.2 and Helix units (1.2).
- **Slice 3 — Full Lattice (14). ✅ DONE (2026-07-03).** Added the 12 remaining Lattice advances
  with real `req1/req2` (Adaptive Fabrication, Plasma Containment, Fusion Lattices, Skyhook
  Tethers, Orbital Foundries, Orbital Ordnance, Deep Habitation, Neural Uplink, Autonomous
  Legions, Living Architecture, Planetary Stewardship, Ascendant Intelligence); seeded explicit
  `root_req = Molecular Assembly` on the 4 Lattice entry nodes (Adaptive Fabrication, Deep
  Habitation, Living Architecture, and the pure orphan **Neural Uplink**); extended
  `EPOCH_TECH_AGE` (all 14 Lattice at age 5). **Tree complete at 115 techs.** **Verified
  in-container:** clean load; tech→age map = **115 techs, 0 unmatched**; era fires to age 5;
  and the **both-anchor gate** holds on Neural Uplink — with its Helix prereqs held it is
  `can_research == false` when *either* Molecular Assembly (explicit `root_req`) *or* Genome
  Cartography (inherited via ancestry) is missing, flipping `true` only when both are present.
  Orbital (3.2), undersea megacities, solarpunk PW (3.3), and victory-branch capstones
  (Planetary Stewardship / Ascendant Intelligence, 3.4) are now gated in the graph.
  *(Deferred to Slice 4: the 200+-turn monotonic-transition autogame + `cost_pct` tuning.)*
- **Slice 4 — Tuning + cut/merge.** Tune the five `cost_pct` multipliers to hit §1 span targets; execute §3 cut/merge with 1.2 unit rehoming (move units once). Surface multipliers in `EPOCH_CONFIG`.

**Why this order:** Slices 0–1 de-risk the two things that can silently break the backbone — detection semantics and `root_req` gating — with ~4 techs and the existing tree, before large content investment. Tech *names* are stable by end of Slice 3, so parallel content can start against Helix names after Slice 2.

---

## Critical files
- `data/epoch/techs.ruleset` — the graph; add 28 advances, retarget herald prereqs, add 2 `root_req` anchors + 5 tech classes with `cost_pct`.
- `doc/design/epoch-lua-systems-draft.lua` → `data/epoch/script.lua` — replace `min_tech` era model with tech→age lookup + `tech_researched`/`turn_begin` detection.
- `data/epoch/effects.ruleset` — downstream unit/building/gov/PW gating references new tech names.
- `scripts/epoch-smoke-test.sh` — validates each slice's era transitions + `root_req` gating.
