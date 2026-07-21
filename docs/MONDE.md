# Monde, districts & NPCs — état réel (2026-07-21)

Scène jouée unique : `scenes/main/Main.tscn` → `World` = `scenes/world/Copacabana.tscn`
(généré par `scripts/world/CopacabanaGenerator.gd`, 2115 l.). Les 13 scènes de
`scenes/districts/` sont instanciées une seule fois dans cette même scène à des
coordonnées lointaines ; on s'y téléporte.

## 1. Voyage (`scripts/core/DistrictManager.gd`, 15 ids)

1. **Taxi / Mapa** (apps du téléphone) : `travel_to()` déduit le `fare` et
   téléporte au `Marker2D "PlayerSpawn"`.
2. **Sorties piétonnes** (`DistrictExit.gd`, `walk_to`, `WALK_ENTRIES`
   anti ping-pong, verrou `require_quest_completed`) : Copa↔Forte,
   Copa↔Favela, Copa↔Botafogo (×2 Túnel Novo), Copa↔ZonaSul ; ZonaSul↔Barra,
   ZonaSul↔Botafogo ; Botafogo→SantosDumont ; PãoAçúcar→Botafogo.
3. **Bondinho** (`BondinhoLauncher.gd`) : seule entrée du Pão de Açúcar.
   `barca` = habillage du taxi vers Niterói (fare 22).

Taxi-uniquement : corcovado, maracana, sambodromo, niteroi, aterro_flamengo,
marina_gloria. Les `Rideable` non montés reviennent à leur `home_position` à
chaque `district_changed`. `BuildingManager` (autoload) est quasi vide (7 l.) —
il ne stocke qu'un `last_exit_position`.

## 2. Richesse des districts (nœuds / interactifs)

| District | Nœuds | Interactifs | État |
|---|---|---|---|
| ZonaSul | 447 | 56 | Très riche |
| BotafogoFlamengo (+Urca/Aterro) | 414 | 51 | Très riche |
| FavelaDoMorro | 258 | 23 | Riche |
| Niteroi | 217 | 30 | Riche |
| BarraDaTijuca | 198 | 29 | Riche |
| Maracanã / Corcovado / Sambódromo / Pão | 68-79 | 14-19 | Moyen |
| SantosDumont / AterroFlamengo / Forte | 65-80 | 9-12 | Squelettique |
| MarinaDaGloria | 71 | 7 | Le plus pauvre |

Aterro et Santos Dumont partagent la scène BotafogoFlamengo (spawn markers
distincts) — pas de contenu propre. Les scripts district (31-46 l.) ne font que
câbler les portes d'intérieur ; ZonaSul/Niteroi/Barra ont un `AmbientDrifter`
(mouettes/bateaux), Forte est 100 % statique.

## 3. NPCs (46 scènes, 43 `.tres` — aucun NPC mort ni muet)

Base `NPC.tscn` + `scripts/npcs/NPC.gd` (552 l.) : indicateur « ! » flottant,
approche du joueur à l'interaction, mode escort cross-district, cascade de
sprites (PNG → région `characters_ai.png` → procédural).

- **Patrons de voie** : Tito, Ramos, Magalhaes, Padre — gating par script
  (intro acte 2, pacte acte 3, `ratted_on_tito`…).
- **Donneurs à scène** (~30) : SeuJoao, Contessa, Dom Nilton, DonaIrene, etc.
- **Marchands/services** : CoconutVendor, StreetVendor (13 instances, une par
  district), Padeiro, Concierge (= Zé)…
- **Figurants** : Customer (milho), Joggeur, PMPatrol (racket par acte),
  `AmbientWanderer` (718 l.), `AmbientDrifter`.

**Spots fantômes** : beaucoup de maillons de voie (`fixer`, `*_contact`,
`*_tioze`…) sont des `ReactiveDialogueSpot` avec `giver_npc_id` virtuel — sans
corps NPC, sprite, ni « ! ». La lisibilité « à qui parler » repose entièrement
sur `NavigationDirector`.

**NPCScheduler** (210 l.) : règles flag/act/phase/pos, première match gagne ;
repositionne à `act_changed` + `time_of_day_changed` (marche si ≤ 600 px, sinon
téléport). Ex. : ramos → Bar do Policial le soir, musicien → roda du quiosque,
pêcheur/coconut/tourist disparaissent le soir, concierge disparaît si
`tio_ze_revealed`. **Ne couvre qu'~15 NPCs** ; `on_flag_set` non branché (pas
de signal dédié).

## 4. Vie ambiante — 100 % Copacabana

- **RandomEventManager** (329 l.) : 24 événements (`StreetEvent.tscn`), 55 %
  par changement de phase, 1 actif à la fois, **uniquement si district =
  copacabana**. Zones sand/calcadao/av_atlantica/nossa_senhora ; filtres
  `phases` et `flag` (tous posables : `pecheur_to_*` par le choix pêcheur,
  `jogo_*` par le calendrier).
- `_spawn_evening_life()` : roda de samba au quiosque do Zé + futevôlei posto 3
  (visible en EVENING seulement).
- `_spawn_domingo_life()` : baigneurs, parasols, sortie de messe.
- `_spawn_bloco_rehearsal()` : répétition de bloco qui grossit avec l'acte
  (rien acte 1 → cortège + confettis acte 4+).
- `_rebuild_human_cost()` : voisine + selon flags `voie_trafico` (commerce
  fermé, mémorial) / `voie_consortium` (DESPEJO, Despejado).
- `_spawn_ze_memories()` : 3 spots contemplatifs sans récompense.
- Mureta da Urca : `BotafogoFlamengo.tscn` + `EveningOnly.gd`.

Densité faible : 1 event × 55 % × 3 phases/jour ; les events flag-gatés
(pos_jogo, mare_*) n'apparaissent que dans des fenêtres étroites — rarement vus.

## 5. Intérieurs (21 scènes)

Instanciés une fois à y≈-3000, accès par `BuildingDoor.tscn` (destination →
`SpawnPoint`). Utiles : HouseInterior (hub narratif famille/Zé), Church (Padre),
Pharmacy, Padaria (mini-jeu), Restaurant, Shop, Academia (mini-jeu), MACInterior
(Helena), OfficeIpanema, ArpoadorBar, PenthouseLeblon, LeParc/Peninsula/
BarraShopping, 3 intérieurs du Forte (1 spot réactif chacun).

**Vides (figurants seulement, zéro gameplay)** : PoliceInterior,
PalaceLobbyInterior, BarInterior, MercadinhoInterior.

## 6. TimeOfDay (`scripts/core/TimeOfDay.gd`, 49 l.)

3 phases MORNING/AFTERNOON/EVENING, **300 s/phase = 15 min/jour**. Pas de vraie
nuit (EVENING = la nuit). Changements concrets : tint `DayLighting`
(CanvasModulate global, EVENING bleuté ~55 % + groupe `nightlight`),
repositionnement NPCScheduler, EveningLife, re-tirage RandomEventManager,
jogo du Domingo soir (`CarnavalCalendar`).

Limites : jour très court → fenêtres flag-gatées vite manquées ; tint global
subi par tous les districts sans contenu de soirée propre.

## 7. Mobile / iOS

`MobileControls.tscn` : joystick (`run` à 0.85 de déflexion), bouton Action,
bouton ⚽ altinha (**sable de Copa uniquement**). `MinigameTouchControls.tscn` +
`MinigameQuitButton.tscn` pour les mini-jeux. HUD : 📱 (téléphone), 📷 (photo).

Téléphone (`Phone.gd`, 1040 l., pause le jeu) : Taxi, Mapa (régions), Saúde
(stats/rép/tracker d'acte), Crônica, Missões, Fotos, Notícias, Conquistas,
Ajustes (audio, apparence, 3 slots de save). Friction : l'app Fotos affiche un
chemin OS absolu, inutile sur iOS sandboxé.

## 8. Tests (`run_tests.sh` : 3 scènes agrégées)

`IntegrationTest.tscn` (5 groupes : Load/World/Narrative/Sprites/Districts,
~280 sites `_assert` → ~3100 assertions runtime via boucles sur 95 quêtes/43
NPCs/13 districts/4 voies), `PlaythroughDriver.tscn` (parcours réel acte 1→2),
`VoieDriver.tscn` (contrat complet des 4 voies jusqu'au couronnement).
`IntegrationTestBase.gd` (729 l.) : `QUEST_RESOURCES`,
`SCRIPT_COMPLETED_OBJECTIVES`, stations e2e.

Couvert : complétabilité de la trame, intégrité .tres/dialogues, anti-soft-lock
géométrique, conformité tactile (≥ 44 pt). **Non couvert** : RandomEventManager,
TimeOfDay, NPCScheduler, vie du soir/dimanche — les systèmes « vivants » ne
sont pas garantis ; la richesse de contenu des districts non plus (les coquilles
Marina/Forte/SantosDumont passent les tests).

## Disparités prioritaires (entrée pour JOUABILITE.md)

1. Toute la vie ambiante + 24 random events exclusifs à Copacabana ; 12
   districts figés, 4 coquilles (Marina, Forte, Santos Dumont, Aterro).
2. 4 intérieurs sans aucun gameplay (Police, Palace Lobby, Bar, Mercadinho).
3. Donneurs fantômes sans corps ni « ! » — lisibilité 100 % NavigationDirector.
4. Cycle 15 min/jour, 3 phases, variation réelle limitée au soir de Copa.
5. UX tactile monde : un seul bouton contextuel (⚽, sable de Copa).
6. Tests aveugles aux systèmes d'ambiance.
