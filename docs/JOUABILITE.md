# Jouabilité — diagnostic croisé & axes d'amélioration (2026-07-21)

Synthèse des trois cartographies (`SYSTEMES.md`, `NARRATIF.md`, `MONDE.md`),
alignée sur les critiques tracées dans `BACKLOG.md` (2026-06-11 « âme
carioca », 2026-07-12 « manque de fun », 2026-07-15 « actes 2-4 insipides »)
et les piliers du skill `ame-carioca`.

## Ce qui est solide (à ne pas casser)

- L'acte 1 (prologue Pedrinho + héritage) : gabarit d'enquête incarné, donneur
  qui vient au joueur, resolution par follower — LE modèle à répliquer.
- 5-6 mini-jeux profonds (volley, altinha, surf, padaria, valet, racha) avec
  vraie courbe de skill.
- Les 3 verbes de résistance livrés (chase, stakeout, négociation à caution) et
  l'économie `debt_credit` qui fait franchir les seuils en jouant.
- Le guidage (NavigationDirector + ObjectiveBanner + Compass) et la suite de
  tests (~3100 assertions) qui garantit la complétabilité.
- La vie de Copacabana (evening/domingo/bloco/human_cost/ze_memories).

## Diagnostic — les 5 problèmes structurants

### P1. ~80 % des MAIN restent « marche-parle-choix 0 » — RÉSOLU sur les voies
**[Axe A terminé le 2026-07-21]** État initial : 9 beats mécaniques sur 45
MAIN, CHRONO jamais utilisé. Après les deux tranches : **24 beats (~53 %)** —
Tráfico 7 (3 chases + CHRONO A3 + FUITE A5 + MINIJEU A6 + FUITE tioze A7),
Polícia 6 (3 stakeouts + filature B4 + escorte B3 + planque tioze B6),
Consórcio 6 (négos C3/C5/C7/C8 + CHRONO C4 + levier tioze C6), Prefeito 6
(mutirão D5 + enquête D3 + escorte D4 + discours D6 + écoute tioze D7 +
levier Neném). La cause racine du zéro-CHRONO était un trou système : l'état
FAILED était un cul-de-sac — corrigé (ré-acceptation au donneur + variante
`quest_failed` des spots). Le milieu de chaîne des 4 voies joue désormais son
verbe partout ; ce qui reste dialogué l'est par choix (couronnements, pivots).

### P2. Presque aucun choix dont le monde se souvient — RÉSOLU
**[Axe B livré le 2026-07-21]** État initial : 2 vrais choix (voie + pêcheur
SIDE). Désormais **11** : le choix de voie + `act2_pecheur_secret` (requalifiée
MAIN) + 8 carrefours à 3 issues greffés sur les beats existants, 2 par voie
(A5/A8, B4/B7, C2/C8, D3/D6) + le reinado D6. Chaque issue pose un flag ;
mémoire du monde par variantes de spots (balcon du 1601, kiosque libre, Neném
au parvis…) et 9 événements de rue en payoff différé (modèle `mare_limpa`).
Les skill-checks à tell (C3/C5/C7/D5) restent des checks — c'est leur rôle.
Reste ouvert : refléter ces flags dans l'Épilogue.

### P3. L'acte 5 est vide — RÉSOLU (Reinado)
**[Axe C livré le 2026-07-21]** État initial : 1 quête → 1 mini-jeu → écran de
texte. Désormais : **2 quêtes MAIN de règne par voie** (8 quêtes
`reinado_*`, R1 à Copa dans le verbe de la voie, R2 en climax au Sambódromo),
guidage acte 5 réécrit (règne d'abord, desfile en climax), toasts jalons
chaînés couronnement → R1 → R2 → desfile, et Copa reflète le règne
(`_rebuild_reinado()` : faixa par voie + un habitant dont le salut dit ce que
le bairro pense du pouvoir). Le Sambódromo passe de coquille à lieu de climax
(4 spots). Reste ouvert : le monde post-desfile (« continuer à explorer »)
n'évolue plus après l'épilogue.

### P4. Le monde vivant s'arrête aux limites de Copacabana — LARGEMENT RÉSOLU
**[Axe D livré le 2026-07-21]** RandomEventManager multi-districts (zonage
local par district + filtre `districts`, conversion locale→monde via l'offset
du nœud ; 11 événements génériques tournent à Ipanema, la mureta et Icaraí,
les payoffs narratifs restent à Copa) ; vie du soir hors Copa (palmas
d'Arpoador, seresta d'Icaraí) ; bouton ⚽ altinha sur les plages d'Ipanema et
Icaraí ; Forte et Aterro meublés (fila du Colombo, pêcheur, vétéran, pipas,
queijo coalho, flâneurs) ; ~330 assertions de test sur l'ambiance (pool,
éligibilité, bandes de plage, EveningOnly). **Reste ouvert** : Marina da
Glória et Santos Dumont toujours squelettiques, 4 intérieurs sans gameplay
(Police, Palace Lobby, Bar, Mercadinho), domingo/blocos/coût humain encore
Copa-only, cobrador limité à Copa/ZonaSul/Favela.

### P5. Les récompenses ne tiennent pas la longueur — LARGEMENT RÉSOLU
**[Axe E + bugs B1-B3 livrés le 2026-07-21]** ActivityRewards plafonné
(`gain_capped`, cap = 3× la signature — le grind s'arrête au seuil mestre,
le compteur mestre continue) ; kite séparé du surf (`SurfGame.minigame_id`,
signature `kitesurf`) ; Exercise crédite l'axe affiché (CHARISMA). Et la
réputation/affinité se sentent manette en main : **preço de amigo** chez les
13 marchands (tier d'affinité par `vendor_<id>` = −1/−2 R$), **le morro te
couvre** (STREET ≥ 50 : tout poursuivant abandonne plus tôt et fatigue plus
vite), **la PM laisse passer ses alliés** (POLICE ≥ 40 : plus de racket du
calçadão), et l'app Saúde explique enfin cash ≠ dette. **Reste ouvert** :
pas de décroissance de réputation, milho toujours anecdotique passé
l'acte 1, Fishing/Exercise toujours superficiels (axe F).

## Bugs & frictions à corriger vite (petits, forts en impact)

| # | Problème | Où |
|---|---|---|
| B1 | ~~Kite pointe `Surf.tscn` → id/récompenses surf~~ **corrigé 2026-07-21** (`SurfGame.minigame_id`, signature `kitesurf`) | `SurfGame.gd`, `KiteLauncher.gd` |
| B2 | ~~`ActivityRewards.modify` sans cap~~ **corrigé 2026-07-21** (`gain_capped`, cap 3× signature) | `ActivityRewards.gd` |
| B3 | ~~Exercise donne du STREET caché~~ **corrigé 2026-07-21** (axe → CHARISMA) | `ActivityRewards.gd` |
| B4 | ~~Sprint tactile inutilisable finement~~ **corrigé 2026-07-21** : bouton 🏃 à bascule (`RunButton`, `external_run_hold` du joystick, relâché aux dialogues/mini-jeux) — le seuil 0.85 reste en alternative | `MobileControls`, `VirtualJoystick` |
| B5 | ~~Chrono inter-districts intenable~~ **corrigé 2026-07-21** : plancher 180 s dès que la cible est à un offset de district (>3000 px) ; le téléphone pause déjà le jeu, le taxi est instantané | `DynamicMissionManager.gd` |
| B6 | ~~Visites créancières en intérieur~~ **corrigé 2026-07-21** : vrai flag `BuildingManager.is_inside` (posé par les portes, remis à false par tout voyage) | `BuildingManager`, `BuildingDoor`, `CreditorVisitManager` |
| B7 | ~~Delta d'argent positif seulement ; un seul chrono~~ **corrigé 2026-07-21** : les ponctions flashent « −R$ X » en rouge ; les chronos secondaires signalés « (+N ⏱) » | `HUD.gd` |
| B8 | ~~Chemin OS absolu dans Fotos~~ **corrigé 2026-07-21** : compteur de photos (chemin gardé en petit sur desktop) | `Phone.gd` |
| B9 | ~~`print()` de debug~~ **corrigé 2026-07-21** (PlayerController ×5, PMPatrol ×1) | `PlayerController.gd` |

## Axes d'amélioration proposés (par impact décroissant)

### A. Finir la dé-clonification des voies (prolonge BACKLOG « un verbe par voie »)
**[Première tranche livrée le 2026-07-21]** : socle de reprise des quêtes
échouées (FAILED ré-acceptable au donneur, variante `quest_failed`, toast
d'échec orienté) ; A3 et C4 en CHRONO (210 s / 240 s, variantes de reprise chez
le contact et le restaurateur) ; B4 filature StakeoutZone du dealer avant le
coffrage ; C5 négociation à tell avec l'attachée du MAC (caution 250 R$) ; D3
médiation à témoins chaînés (Dona Cléo → levier de Neném — moule Pedrinho) ;
D4 escorte physique de la procession (3 EscortFollower, Ipanema →
capelinha). Au passage : 4 entrées de guidage corrigées (C4/C5/D3/D4
pointaient vers le donneur au lieu du lieu de complétion). Tests : 3406
assertions vertes, stations e2e étendues.
**Deuxième tranche livrée le 2026-07-21 — axe terminé.** Les 4 tioze jouent
« quelqu'un surveille le concierge » chacun dans son verbe (FUITE A7 / planque
B6 / levier C6 / écoute D7 — zéro argent préservé, l'ombre de la Baía
préfigure la re-capture de Zé) ; A5 fuite après l'intimidation ; A6 = mini-jeu
SUP des Cagarras (dont le lanceur `SupRental.tscn` était instancié nulle part
— mini-jeu mort, désormais branché plage de ZonaSul ; NB : son `QUEST_ID`
`pedro_cagarras_sup` référence une quête inexistante, no-op à nettoyer) ; B3
escorte de patrouille ; C7 négociation Península ; D6 discours à la bonne
prise. Six entrées de guidage au mauvais district corrigées en tout
(C4/C5/C7/D3/D4/D6). Cible ~50 % atteinte : **24/45 (~53 %)**.

### B. Un carrefour par acte et par voie — LIVRÉ le 2026-07-21
8 carrefours à 3 issues sur les beats existants (A5 le voisin, A8 la
traversée, B4 le dealer, B7 la saisie, C2 le 1601, C8 la commerçante, D3
Neném, D6 le discours), flags + mémoire de spots + 9 événements différés ;
`act2_pecheur_secret` requalifiée MAIN avec son toast. Vrais choix : 2 → 11.
Piège d'implémentation documenté : une variante « mémoire » gated par flag
doit être placée APRÈS toutes les variantes de chaîne du spot, sinon elle les
shadow dès que le flag est posé (bug attrapé par l'e2e Consórcio sur C7).
Suite possible : refléter les flags de carrefour dans l'Épilogue.

### C. Donner un corps à l'acte 5 — LIVRÉ le 2026-07-21 (Reinado)
2 quêtes de règne par voie dans son verbe (pedágio+blitz / carga CHRONO ;
ronde du bloco / Sapucaí en planque solo ; charte Riserva / camarote de
l'école — négos à tell ; Bloco do Bairro / ordre des alas — leviers), climax
au Sambódromo, monde-reflet (`_rebuild_reinado()`), guidage et toasts
réécrits. E2e étendus : les 4 reinados joués jusqu'au desfile dans la suite.
Suite possible : faire évoluer le monde post-desfile (après l'épilogue).

### D. Exporter la vie hors de Copa — LIVRÉ le 2026-07-21
`DISTRICT_ZONES` (bbox locales par district) + `eligible_events()` pure et
testée + filtre `districts` par événement ; palmas d'Arpoador et seresta
d'Icaraí (EveningOnly) ; ⚽ altinha via `BEACH_BANDS` (Ipanema, Icaraí) ;
Forte et Aterro meublés. L'audit de pool a immédiatement attrapé 2 events
mal zonés (fake_rolex, fla_flu_debate) — la couverture paie déjà.
Suite possible : Marina/Santos Dumont, domingo hors Copa, intérieurs vides.

### E. Faire travailler réputation & affinité — LIVRÉ le 2026-07-21
Cap posé (B2) + trois effets manette en main : preço de amigo par tier
d'affinité chez les StreetVendor (l'achat crée la relation — le dialogue du
comptoir passe par `vendor_<id>`, donc chaque achat nourrit l'affinité) ;
`CobradorChase.adjusted_config` (STREET ≥ 50 → abandon −25 %, fatigue −20 %,
toast « le morro te couvre ») ; `PMPatrol.waves_through` (POLICE ≥ 40 → la
patrouille salue au lieu de racketter). L'usage négatif existe désormais via
les carrefours (axes qui descendent). Non fait, assumé : décroissance
passive (risque design), effets d'affinité chez les commerçants d'intérieur.

### F. Approfondir Fishing/Exercise — LIVRÉ le 2026-07-21
**Pesca da Colônia** : pêche en 3 temps — lancer visé (3 bandes
perto/meio/fundo : plus loin = Robalo qui vaut plus, fenêtre de ferrage plus
courte, puxadas plus dures), touche lisible (frémissements-leurres puis
vraie FISGA, ferrer un leurre fait fuir le banc, réflexe < 0,18 s =
Perfeito ×1.5), combat à la tension (tenir pour mouliner, lâcher pendant
les puxadas annoncées, tension pleine = ligne cassée). 6 lancers / 120 s,
qualif ≥ 45 pts. **Treino da academia** : fini le mash — appui-relâché dans
la zone de forme (centre = Perfeito 3 pts), 3 séries de plus en plus
rapides aux zones plus étroites (Supino/Agachamento/Remada), gás qui punit
les Falhas et borne la séance, plafond = « la charge t'écrase ». Qualif
≥ 24/45. Contrats préservés (match_ended, payout launcher, hook
bruno_pesca_baia, source gym) ; un garde-fou de test vérifie la monotonie
des courbes de difficulté. NB : la signature de réputation pêche exige
désormais une session qualifiante (standard des autres jeux), le cash reste
à la prise.

## Méthode

Chaque chantier retenu passe par `BACKLOG.md` (skill `backlog`), le contenu
s'écrit après lecture du skill `ame-carioca`, tout objectif mécanique se
déclare dans `SCRIPT_COMPLETED_OBJECTIVES` + `NavigationDirector.STEP` +
`MAIN_NEXT_HINT`, et `./run_tests.sh` doit rester vert. Attention : les tests
ne couvrent ni RandomEventManager, ni NPCScheduler, ni TimeOfDay — tout
chantier sur la vie ambiante (axe D) devrait commencer par ajouter ces
assertions.
