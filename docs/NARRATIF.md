# Narratif & quêtes — état réel (2026-07-21)

Cartographie vérifiée dans le code (pas dans les intentions). Source de vérité :
`scripts/`, `resources/`, `scenes/` — les dossiers `Rio/`, `Rio2/`, `Rio — Copacabana/`
à la racine sont des artefacts d'export iOS figés, ne jamais s'y fier.

## 1. Actes (`scripts/core/CampaignManager.gd`)

Machine à états pilotée par la **dette payée** + des flags. `DEBT_TOTAL = 50 000`
(soldé de toute façon par `complete_endgame`).

| Transition | Seuil dette | Gate supplémentaire |
|---|---|---|
| 1 → 2 | 500 | `act1_heritage` complétée + flag `act1_closed` (nuit chez tio Zé) |
| 2 → 3 | 2 000 | aucun — la voie se scelle *en* acte 3 |
| 3 → 4 | 6 000 | aucun |
| 4 → 5 | — | `complete_endgame(path)` au couronnement (purge la dette, force acte 5) |

Pivots de dette acte 2 (`ACT2_MILESTONES` : 600/1000/1400/1800) → flags
`mae_letter_triggered`, `mae_consortium_revisit_triggered`, `mae_sick_triggered`,
`tio_ze_letter_triggered`, lus par les spots de la maison (beats famille).

**4 voies** (enum `Endgame` — CONSORTIUM ajouté en 4e position pour préserver les saves) :
Tráfico (Tito, `trafico_a1..a9`), Polícia (Ramos, `policia_b1..b9`),
Consórcio (Magalhães, `consortium_c1..c9`), Prefeito (Padre, `prefeito_d1..d9`).
Colonne vertébrale identique pour les 4 : arrivée (1-2) → missions (3-5) →
pivot tio Zé (a7/b6/c6/d7) → gros coup (8) → couronnement (9).

## 2. Inventaire des quêtes (`resources/quests/`, 95 `.tres`)

**45 MAIN / 50 SIDE.** MAIN : 2 (acte 1) + 36 (4 voies × 9) + 6 « Grandes Lances »
acte 4 (Fixer : `act4_tio_ze_rescue`, `palace_heist`, `press_expose`,
`sambo_sabotage`, `bondinho_drop`, `assassinate_consortium`) + 1 (acte 5,
`act4_carnaval_desfile`).

**Objectifs mécaniques (`QuestObjective.kind`) : 4 quêtes sur 95 seulement.**
- MINIJEU : `camila_ipanema_volley`
- FUITE : `trafico_a2_pickup`, `trafico_a4_ipanema`, `trafico_a8_baia`
- **CHRONO : zéro** — le système (HUD, échec au chrono) existe, aucun contenu écrit

Le vrai contenu mécanique est **authoré dans les `.tscn`** (actions de
`ReactiveDialogueSpot`/`DialogueTriggerZone`), pas via `kind` :
- Poursuites `start_chase` : Copacabana (A2), ZonaSul (A4), Niterói (A8) — 3, tous Tráfico
- Filatures `start_stakeout` : FavelaDoMorro (B2), Corcovado (B5), Maracanã (B8) — 3, tous Polícia
- Négociations à caution (`choice_actions`) : ZonaSul (C3), Copacabana (C8), Maracanã (D5 mutirão)
- Rythme : CarnavalSamba (acte 5)

**Ratio réel : ~9 beats mécaniques sur 45 MAIN (~20 %). ~80 % restent
« va au spot, E, lis, choix 0 ».** Verbes par voie : Tráfico 3, Polícia 3,
Consórcio 2, **Prefeito 1**. Les 4 quêtes tioze et la plupart des 3-5 sont
purement dialoguées.

## 3. Dialogues (`scripts/quests/DialogueBridge.gd` + `scripts/dialogues/*.gd`)

362 knots dans 7 fichiers fusionnés au `_ready` (`register_runtime_dialogue`) :
Act1 61 · Act2 56 · Act3 50 · **Act4 10** · SideBaia 43 · SidePlage 65 · SideServices 77.
Attention : le faible volume d'Act4Dialogues est trompeur — le contenu des actes 3-4
est authoré **inline dans les `.tscn`** via `ReactiveDialogueSpot.variants`.

Verbes d'action (`_apply_placeholder_action`) et fréquence dans les dialogues :
`accept_quest` 57 · `finish_quest` 58 · `set_flag` 33 · `pay_bribe` 18 · `pay_debt` 12 ·
`jeitinho` 9 · `earn` 4 · `set_endgame` 3 · `raid_pct` 3 · `sell_at` 3 · `debt_credit` 2.
`start_chase`/`start_stakeout` : 0 dans les dialogues, uniquement dans les `.tscn`.
Ordre critique des verbes composés : `set_endgame > finish_quest > pay_bribe`.

**Jeitinho** : 3e option de résolution par relation, gate par `NPCAffinity.tier`,
refus sans coût si l'affinité manque (9 usages).

Helpers monde : `ReactiveDialogueSpot.gd` (17 scènes — variante par
flag/acte/phase/quête, `actions`, `choice_actions`, `required_flag`),
`DialogueTriggerZone.gd` (1 scène — le donneur vient au joueur),
`EscortFollower.gd` (1 scène — cortège du Padre en D8).

## 4. Choix à conséquences — toujours 2 sur ~45

1. **`act2_pecheur_secret`** (knot `pecheur_act2_choose`) : 3 issues
   (`pecheur_to_ramos` / `pecheur_to_miguel` / silence), rep/cash/debt_credit
   distincts + payoffs différés via `RandomEventManager` (`mare_limpa` /
   `mare_do_morro`). **Taguée SIDE** — le meilleur design de choix du jeu n'est
   pas sur la trame.
2. **Le choix de voie** (acte 3) : méta-choix 4-way (`voie_*`, endgame, épilogue).

Les autres `choice_actions` (C3, C8, D5) sont des **skill-checks à retry**
(caution perdue, on rejoue) — le monde ne s'en souvient pas. Zéro carrefour de
conscience dans les 36 MAIN de voie + 6 lances acte 4 (item BACKLOG ouvert).

## 5. Gabarit « enquête Pedrinho » & jalons

Origine : `prologue_pedrinho.tres` (5 objectifs chaînés, donneur qui vient au
joueur, résolution incarnée par un follower, sortie de favela verrouillée —
`SeuJoao.gd`). Répliqué sur les 3 beats de voie :
- **Arrivée** : interception `DialogueTriggerZone`.
- **Pivot tio Zé** : 2 témoins chaînés + concierge « retenu » sans une lembrança
  de Zé (photo, chope, fiche, médaille — zéro argent).
- **Gros coups** : A8 flagrante à semer (Niterói), B8 planque 28 s (Maracanã),
  C8 négociation, D8 cortège Padre (`EscortFollower`).
- **Couronnements** a9-d9 (`Act4Dialogues.gd`) : `set_endgame` + payout 5000 →
  `complete_endgame` → acte 5. Solde incarné par Dom Nilton (`nilton_settlement_*`).

**Arc tio Zé transverse** : reveal (variante `medalhao_reveal` → `tio_ze_revealed`)
→ recapture → `act4_tio_ze_rescue` (`ze_rescued`) ; `Epilogue.gd` (`_with_ze_fate`)
réécrit la fin si Zé démasqué sans être secouru. Les 6 lances du Fixer sont
mono-objectif, toutes au même spot (Copacabana.tscn ~L1114-1160).

## 6. Acte 5 — quasi vide (trou majeur)

Contenu jouable réel : **une** quête (`act4_carnaval_desfile`, offerte par Seu
João) → mini-jeu `CarnavalSamba` (rythme, `QUALIFY_SCORE = 240`) → `Epilogue.gd`
(4 épilogues par voie + un paragraphe par carrefour tranché et l'écho du
pêcheur — `CROSSROADS` / `PECHEUR_SECRET`, insérés après « le lendemain » ; NG+ `user://ng_plus.json`, « continuer à explorer »).
Habillage : titre de règne au HUD, manchettes NewsFeed, spots Sambódromo.
« Continuer à explorer » ramène dans un monde acte 4 inchangé.

## 7. Événements & calendrier

`RandomEventManager.gd` : 24 micro-événements, **Copacabana uniquement**
(`DistrictManager.current() == "copacabana"`), 55 % par changement de phase,
1 actif à la fois. Filtres : `spawn_zones`, `phases` (roda_pagode/fla_flu/sunset
= soir ; altinha = après-midi), `flag` (payoffs pêcheur `mare_*`, humeur
`pos_jogo_*`).

`CarnavalCalendar.gd` : jour 1 = Sexta, `CARNAVAL_DAY = 29` (« J-28 » au HUD).
Dimanche soir → `jogo_pending` → résultat déterministe (`seed = 1950 + day`,
45/25/30) → `jogo_vitoria|jogo_derrota` le lendemain.

## Trous & déséquilibres (entrée pour JOUABILITE.md)

1. **Acte 5 vide** — 1 mini-jeu + un écran de texte, aucun contenu de règne.
2. **~80 % des MAIN sans mécanique** — 9 beats/45 seulement.
3. **Verbes inégaux** : Tráfico 3, Polícia 3, Consórcio 2, Prefeito 1 ; tioze et
   missions 3-5 restent dialoguées.
4. **CHRONO jamais utilisé** (0/95).
5. **2 vrais choix** au total ; le meilleur (`act2_pecheur_secret`) est SIDE et
   jamais répliqué.
6. **Arc Contessa orphelin** après le gala (item BACKLOG ouvert).
7. **Lances acte 4 mono-objectif**, toutes chez le Fixer.
8. **Symétrie A/B/C/D = calque structurel** (même squelette 1→9).
9. **Vie aléatoire cloisonnée à Copacabana** — les autres districts sont inertes
   hors quêtes scriptées.

## 8. Clarté du scénario — chantier du 2026-09-16

Retour : « le scénario est un peu confusant ». Diagnostic vérifié dans les
surfaces joueur (guidage, Diário, HUD, tutoriel, app Saúde, dialogues) :

1. **Seu João était appelé « tio Zé »** partout dans le guidage (« Parle à tio
   Zé » pointait `npc:seu_joao`), dans les titres du Diário et une conquista —
   alors que l'intro annonce la disparition de Zé. Le joueur ne pouvait pas
   comprendre qui avait disparu. Mãe appelait son fils « sobrinho », vovó son
   petit-fils aussi. → Canon posé dans `CampaignManager` (en-tête) et
   `CLAUDE.md` ; toutes les surfaces réécrites ; l'intro narrative situe Seu
   João (compadre de Zé, pas du sang) ; mãe dit « meu filho », vovó « meu neto ».
2. **Titres d'acte incohérents** : HUD « Os verdadeiros rostos », Diário « Le
   carrefour », Saúde « Choisir une voie » — et une bascule d'acte = toast de
   1,2 s. → `CampaignManager.ACT_TITLES` (source unique) + **carte d'acte**
   (`scenes/ui/ActCard.tscn`, `scripts/ui/ActCard.gd`) à chaque bascule 2→5 :
   titre, sous-titre, et un corps concret (ce qui vient de se passer, qui te
   propose quoi, où, le prochain seuil). Pause du jeu, bouton Continuer ≥ 44 pt,
   attend la fin du dialogue/cinématique en cours, jamais au chargement d'une
   save ni en headless ; `Act3IntroCutscene` attend sa fermeture.
3. **Chiffres et comptes faux** : Nilton (acte 3) disait « vingt-cinq mille
   reais » (seuil réel 2 000) et « trois portes » ; Seu João, le tutoriel, l'app
   Saúde disaient 3 voies (et « Miguel » pour Tito). → 4 voies partout, seuils
   réels, Magalhães présenté comme « la maison en costume propre » (lien
   Nilton ↔ Consórcio enfin dit).
4. **Messages contradictoires en acte 2** : « il est temps de choisir un camp »
   au réveil, puis « signe le pacte avec Tito (acte 3) » après la mission intro
   alors que rien ne se signe avant 2 000 R$. → réveil : « écoute-les tous, le
   choix c'est pour plus tard » ; toasts a1/b1/c1/d1 : « goûte les autres
   patrons ; le pacte se signe à l'acte 3, quand Nilton aura ses 2 000 R$ ».
5. **Aucun résumé de situation** (le Diário = codex de knots lus). →
   `NarrativeJournal.story_so_far()` : 4-7 phrases générées depuis l'état (Zé
   disparu / concierge / secouru, Seu João, Nilton, dette + palier, prologue,
   patrons goûtés / restants, voie + progression, règne, J-x Carnaval). Affiché
   en tête de l'app Crônica (« ONDE ESTOU ») et comme première catégorie du
   Diário.

Tests : `TestGroupNarrative._test_story_clarity()` (identités dans le guidage,
source unique des titres, cartes non vides, résumé par état, maison sans
« sobrinho », Nilton/Seu João à 4 patrons) + `PlaythroughDriver` vérifie que
le guidage post-acompte nomme Seu João et jamais « tio Zé ».
Aperçu visuel de la carte sans jouer : `godot --path . tools/PreviewActCard.tscn -- <acte> <out.png> [w] [h]`
(vérifié en 1280×720 et 390×844 — panneau adaptatif, hauteur au contenu).
