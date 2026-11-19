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
| Voie Tráfico | bureau accéléré | **non bouclée** (voir « Reste ») |
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

- **Voie Tráfico validée jusqu'à A7, pas A8** (suite du 2026-11-19, quatre
  runs bureau). La « poche » de l'ouest de Copa était réelle : le mur ouest
  coupait le sentier de l'Arpoador (corrigé, audit des coutures ajouté). Deux
  autres causes trouvées ensuite : Dom Nilton ne laissait plus verser la dette
  dès qu'une de ses quêtes annexes était active (14 800 R$ en poche, acte 2
  sans issue — corrigé : ses quatre rappels proposent le versement) ; et le
  bot ne complétait pas l'objectif MINIJEU d'A6 (limite du bot, corrigée).
  Résultat : acte 3 à 19 min, acte 4 à 51 min, A1–A7 bouclées. **Reste A8** :
  la poursuite `pm_baia` de Niterói (la plus dure du jeu : 132 px/s, fatigue à
  26 s, abandon à 45 s) est perdue ~130 fois de suite par le bot, qui fuit en
  ligne droite et se fait prendre en 6 à 17 s. En ligne droite elle demande
  ~3 400 px de champ avant la fatigue du PM ; le quai en offre 1 900 à l'ouest
  du spot. Elle n'est gagnable qu'en mettant un obstacle entre soi et le PM :
  à jouer à la main, au tactile, avant de conclure.
- **Écran large (20:9)** : dans la maison, l'intérieur voisin est visible au
  bord gauche ; dans la favela, le bord du quartier (bande d'herbe, vide brun).
- **Petits textes sur téléphone** : consignes et bulles de plusieurs mini-jeux
  (rush du milho, padaria, valet), étiquette de la minimap.
- **Menu des mini-jeux** : un toucher dans les ~3 s qui suivent le retour au
  menu est ignoré.
- **Erreur moteur** « Lambda capture at index 0 was freed » ×7 pendant le run
  mobile (à la carte d'acte 4), sans effet visible.
- Le bot écrivait dans le slot 1 du joueur par les sauvegardes directes
  (bump d'intro, MainBoot). Il écrit maintenant dans un slot fantôme.

## Reproduire

```bash
tools/playtest/android/run_on_emulator.sh                    # jeu normal
tools/playtest/android/run_on_emulator.sh bot 21600 policia 4  # bot, voie imposée, ×4
tools/playtest/run_playtest.sh 21600 out.json prefeito       # bureau accéléré
```
