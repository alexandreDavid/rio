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

### P4. Le monde vivant s'arrête aux limites de Copacabana
24 random events, vie du soir, Domingo, blocos, coût humain : tous exclusifs à
Copa. 12 districts figés, 4 coquilles (Marina 7 interactifs, Forte, Santos
Dumont, Aterro). 4 intérieurs sans gameplay (Police, Palace Lobby, Bar,
Mercadinho). Le cobrador et les visites créancières ne suivent pas le joueur
hors Copa/ZonaSul/Favela.

### P5. Les récompenses ne tiennent pas la longueur
Réputation farmable (`ActivityRewards.modify` sans cap, doublé par les
launchers), jamais décroissante, affinité sans effet mécanique fort (le
jeitinho ne débloque que 9 dialogues). Milho anecdotique passé l'acte 1.
Cash ≠ dette jamais expliqué à l'écran.

## Bugs & frictions à corriger vite (petits, forts en impact)

| # | Problème | Où |
|---|---|---|
| B1 | Kite pointe `Surf.tscn` → id/récompenses surf + auto-complétion d'objectifs MINIJEU `surf` par le kite | `scenes/props/KiteStation.tscn` |
| B2 | Double canal de réputation, part `ActivityRewards.modify` **sans cap** | `ActivityRewards.gd` + launchers |
| B3 | Exercise affiche « +1 Charisma », donne aussi STREET caché | `ExerciseGame.gd:91`, `ActivityRewards` |
| B4 | Sprint tactile = déflexion 0.85, incompatible direction fine (esquives cobrador/PM) | `VirtualJoystick.gd` — bouton sprint dédié ? |
| B5 | Missions dynamiques chronométrées inter-districts : le chrono court pendant le taxi | `DynamicMissionManager.gd` |
| B6 | Visites créancières possibles en intérieur (détection inerte, « à raffiner ») | `CreditorVisitManager.gd` L85-89 |
| B7 | HUD : delta d'argent affiché seulement en positif ; un seul chrono visible | `HUD.gd` |
| B8 | App Fotos affiche un chemin OS absolu (inutile sur iOS) | `Phone.gd` |
| B9 | `print()` de debug actifs dans PlayerController | `PlayerController.gd` |

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

### D. Exporter la vie hors de Copa
RandomEventManager filtrant par district (les 24 events ont déjà des
`spawn_zones` — il faut des bbox par district), evening_life pour ZonaSul et
Botafogo (mureta déjà là), bouton ⚽ sur les plages d'Ipanema/Icaraí (TODO déjà
noté dans `MobileControls.gd`). Meubler en priorité les 2 coquilles les plus
visitées par la trame (Forte, Aterro) plutôt que tout.

### E. Faire travailler réputation & affinité (pilier jeitinho)
Caper `ActivityRewards` (B2), puis donner des effets mécaniques : tiers
d'affinité → remises/accès/infos chez les marchands, réputation STREET/POLICE →
comportement PMPatrol et cobrador, décroissance douce ou usage négatif. Le
jeitinho doit se sentir manette en main, pas seulement dans les salutations.

### F. Approfondir ou requalifier Fishing/Exercise
Les deux mini-jeux les plus pauvres. Soit les remonter au standard
volley/surf (le pêcheur a un arc narratif — un vrai jeu de pêche aurait un
port d'attache), soit réduire leur poids de récompense au rang d'ambiance.

## Méthode

Chaque chantier retenu passe par `BACKLOG.md` (skill `backlog`), le contenu
s'écrit après lecture du skill `ame-carioca`, tout objectif mécanique se
déclare dans `SCRIPT_COMPLETED_OBJECTIVES` + `NavigationDirector.STEP` +
`MAIN_NEXT_HINT`, et `./run_tests.sh` doit rester vert. Attention : les tests
ne couvrent ni RandomEventManager, ni NPCScheduler, ni TimeOfDay — tout
chantier sur la vie ambiante (axe D) devrait commencer par ajouter ces
assertions.
