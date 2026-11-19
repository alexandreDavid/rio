# Playtest complet sur mobile émulé — 2026-11-18

Objectif : jouer le jeu entier sur un simulateur mobile. Ce document dit ce
qui a été joué, sur quoi, ce qui a été trouvé et corrigé, et ce qui reste.

## Sur quoi

- **Simulateur iOS : impossible aujourd'hui.** Le gabarit iOS de Godot 4.6.2
  ne contient qu'une tranche `x86_64` pour simulateur (le dossier s'appelle
  `ios-arm64_x86_64-simulator`, la bibliothèque ne l'est pas). Le simulateur
  iOS 27 refuse d'installer un exécutable x86_64. Il faudrait compiler un
  gabarit `arm64` simulateur depuis les sources de Godot (non fait : c'est un
  téléchargement et une compilation à décider).
- **Émulateur Android (Pixel 6a, Android 14, arm64) : fait.** Pas de Java sur
  la machine, donc pas d'export Android classique : le projet exporté est
  injecté dans le gabarit APK de Godot et signé (APK Signature Scheme v2) par
  `tools/playtest/android/make_apk.py`. Script : `tools/playtest/android/run_on_emulator.sh`.
  Rendu : OpenGL ES 3 (Compatibility), pas le Forward+/Metal de l'iPhone.

## Ce qui a été joué

| Parcours | Support | Résultat |
|---|---|---|
| Voie Polícia, nouvelle partie → acte 5 + 2 quêtes de règne | Android émulé, bot ×4 | 334 min de jeu, 0 erreur de script |
| Voie Polícia | bureau accéléré | acte 5 à 116 min |
| Voie Prefeito | bureau accéléré | acte 5 à 127 min |
| Voie Consórcio | bureau accéléré | acte 5 à 115 min |
| Voie Tráfico | bureau accéléré | acte 5 à 151 min (2026-11-19, voir plus bas) |
| Titre → nouvelle partie → intro → joystick → action → téléphone | Android émulé, vrais touchers | OK |
| Les 19 mini-jeux (menu « Mini-jeux (test) ») : lancement, toucher, Sair | Android émulé, vrais touchers | 19/19, 0 plantage, 0 erreur |

Le bot (`tools/playtest/PlaytestBot.gd`) joue par le HUD et marche réellement,
mais il injecte des actions, pas des touchers, et il simule les mini-jeux.
Les touchers réels ont donc été testés à part.

Journal du run mobile : `docs/captures/mobile_2026-11-18/run_policia_android.json`.

## Défauts de jeu trouvés et corrigés

1. **Nouvelle partie : sortir de la maison envoyait dans le vide.** La porte
   gardait en dur l'ancienne position monde de la favela (déplacée depuis).
   `BuildingDoor` retrouve maintenant la porte d'entrée réelle.
2. **Prologue bloquant.** La mère de Pedrinho ne confiait la recherche que si
   l'on traversait une zone de 240×120 px devant la maison. En longeant le
   mur, on arrivait à la sortie du morro verrouillée, sans quête ni guidage.
   Elle confie désormais la recherche quand elle barre la sortie.
3. **A2 (Tráfico)** : le texte disait « va au Palace », la flèche pointait le
   contact du calçadão. Elle pointe la sacoche.
4. **C2 (Consórcio)** : la tournée des loyers se fait à Barra, le bandeau
   envoyait à Copa « chez les commerçants ».
5. **67 étapes de quête sans flèche** (dont A3, chronométrée à 210 s, ratée
   66 fois de suite par le bot). Une étape sans ancre pointe maintenant le
   spot dont la variante servie attend son objectif.
6. **Mission de voie échouée** : le guide renvoyait au patron, qui n'a rien à
   dire. Il renvoie au donneur, qui propose de recommencer.
7. **Acte 4, entre deux missions** : « retrouve ton parrain » sans flèche. Le
   guide pointe le donneur de la mission suivante, comme en acte 3.
8. **Une activité libre confisquait le bandeau** (« prévenir Ronaldo » affiché
   287 min en acte 2). À partir de l'acte 2 la trame passe d'abord.

Tests ajoutés (`TestGroupWorld._test_playtest_mobile_fixes`) : sortie de la
maison, portes de sortie orphelines, ancres A2/C2, étapes chronométrées sans
spot porteur. Suite complète : 4 656 assertions, 0 échec, audit OK.

## Constats non corrigés

- **Voie Tráfico bouclée le 2026-11-19** (bureau accéléré, six runs) : acte 5
  à 151 min, dette soldée, A1–A9 complétées, règne entamé. Quatre causes
  successives : (1) la « poche » de l'ouest de Copa était réelle — le mur
  ouest coupait le sentier de l'Arpoador (corrigé, audit des coutures) ;
  (2) Dom Nilton ne laissait plus verser la dette dès qu'une de ses quêtes
  annexes était active (14 800 R$ en poche, acte 2 sans issue — ses quatre
  rappels proposent maintenant le versement) ; (3) limites du bot : fin de
  mini-jeu sans id (A6) et fuite qui s'arrêtait net au premier obstacle ;
  (4) la poursuite `pm_baia` d'A8 (la plus dure du jeu : 132 px/s, fatigue à
  26 s, abandon à 45 s) reçoit une clémence — après deux captures d'affilée
  le PM repart entamé (`mercy_after`, `CobradorChase.mercy_config`). Même
  ainsi le bot ne la sème qu'au 7ᵉ essai : **à jouer à la main, au tactile**,
  pour juger si le réglage de base est juste.
- **Voies Consórcio et Prefeito bouclées le 2026-11-19** (bureau accéléré,
  deux runs chacune) : aucune ne bloquait, mais le bandeau égarait le joueur
  cinq fois. (1) L'ancre « palace » pointait la porte du Palace alors que les
  témoins de C6/D7 sont sur le trottoir (13 min perdues) — les ancres fixes de
  Copa cèdent désormais au spot qui attend l'objectif. (2) « Prévenir
  Ronaldo » visait l'av. Atlântica, à 950 px de lui : jamais trouvé en 3 h 30,
  sur les deux voies — ancre `npc:musicien`. (3) En acte 5, cette quête annexe
  masquait l'offre du règne (58 min sans R1) — la trame prime, et le bandeau
  pointe le recruteur de la voie sur le sable (`REINADO_SPOTS`). (4) D9
  « remporter l'élection » visait l'avenue au lieu du Padre. (5) Règne mené,
  le bandeau envoyait au Sambódromo alors que le défilé ne compte qu'une fois
  la quête prise chez Seu João (trois défilés joués pour rien) — il renvoie
  d'abord à la maison, puis à la scène. Après corrections : Consórcio
  couronnée à 56 min avec ses deux quêtes de règne ; Prefeito jusqu'au défilé
  (59 min), Cendres et feijoada. **À regarder** : la durée d'une partie varie
  de 56 à 158 min selon ce que l'acte 2 rapporte (une annexe généreuse comme
  « Cristo en couverture » franchit le seuil de 2 000 R$ d'un coup) ; et la
  borne du Sambódromo laisse toujours jouer le défilé sans la quête.
- **Suites du 2026-11-19 (seconde passe)** — durées mesurées sur les quatre
  voies après corrections : acte 3 entre 20 et 27 min, couronnement entre 53
  et 76 min, défilé vers 65 min (le bot Tráfico rate trois fois le défilé,
  hasard de sa simulation). L'acte 2 de 95 min venait du bandeau, pas de
  l'économie : la course de l'aéroport de Dom Nilton (800 R$ + 500 de dette)
  restait derrière une invitation à 0 R$ — entre annexes, le bandeau montre
  maintenant la mieux payée. Dom Nilton encaisse d'abord quand on a de quoi
  franchir le seuil. Un défilé réussi à la borne du Sambódromo compte même
  sans être passé chez Seu João (acte 5).
- **Écran large (20:9)** — corrigé : dans un intérieur, les intérieurs
  voisins se cachent (`InteriorCurtain`) et un fond sombre remplace le vide
  gris autour des murs. Les bords de la favela sont fermés par la mata depuis
  le commit « Morro et maison ». Captures : `RIO_RES=1340x603 tools/capture_main.sh`.
- **Petits textes sur téléphone** — corrigé pour les mini-jeux : 64 textes
  sous le plancher (22 px, jusqu'à 11 à la pêche) ; `MinigameBase` impose
  désormais `UIFit.MIN_SCREEN_FONT` à l'écran, textes créés en cours de partie
  compris. Outil : `tools/minigame_text_audit.sh <prefix>` (une capture par
  jeu). À la pêche, le bouton LANCER couvrait le tiers central de la barre de
  lancer : barre et consigne remontées. Reste l'étiquette de la minimap, et le
  bandeau du Desembarque qui passe sous l'enseigne.
- **Menu des mini-jeux** — corrigé : ce n'était pas le menu mais le bilan de
  fin (2 à 2,6 s) imposé même sur abandon, pendant lequel rien ne répond.
  `MinigameBase.bilan_delay` l'abrège à 0,35 s quand on quitte (18 jeux).
- **Erreur moteur** « Lambda capture at index 0 was freed » — corrigée : le
  plancher de police (`UIFit.keep_floor`) capturait une ligne libérée dans la
  même trame ; il passe par l'identifiant d'instance.
- Le bot écrivait dans le slot 1 du joueur par les sauvegardes directes
  (bump d'intro, MainBoot). Il écrit maintenant dans un slot fantôme.

## Reproduire

```bash
tools/playtest/android/run_on_emulator.sh                    # jeu normal
tools/playtest/android/run_on_emulator.sh bot 21600 policia 4  # bot, voie imposée, ×4
tools/playtest/run_playtest.sh 21600 out.json prefeito       # bureau accéléré
```
