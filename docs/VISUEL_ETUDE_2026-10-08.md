# Rendu visuel — étude des possibilités (2026-10-08)

Base : captures du **jeu complet** (HUD, nouvelle partie, 1920×1080, caméra
×3) prises avec le nouvel outil `tools/ScreenshotMain.tscn`
(`godot --path . tools/ScreenshotMain.tscn -- <prefix> "x:y[:phase],..."`,
`SHOT_WAIT_MS` pour laisser passer les fondus). Vues examinées : calçadão de
Copa (matin, après-midi, soir), Av. Atlântica / Palace (jour et soir), 2e
rangée (Academia), favela du morro (jour et soir), Zona Sul (Arpoador),
Botafogo, maison de tio Zé, Corcovado.

## Ce que l'écran montre aujourd'hui

**Trois langages graphiques cohabitent**, et c'est ce que l'œil remarque en
premier :

1. **Peint** (atlas IA, `buildings_ai_clean.png`, `tileset_ai.png`) : le
   Palace, le Cantinho Carioca, le Quiosque do Zé, Rio Style, les palmiers,
   parasols, serviettes, le motif du calçadão, le sable, l'écume. Détail
   élevé, ombrage doux, bords anti-aliasés.
2. **Pixel-art GBA** (`CharacterSpriteFactory`) : tous les personnages —
   21×32 natif, contour sombre, 2-3 tons, affichage NEAREST. Lisible et
   homogène, c'est le style voulu.
3. **Aplats** (ColorRect + `BuildingDressing`) : **tous les autres
   bâtiments** de Copa (deux rangées), la totalité des 12 districts (la
   favela = 205 ColorRect, Botafogo = 311), les intérieurs (la maison = un
   rectangle brun, un tapis rouge, 18 rects). Le relief de `BuildingDressing`
   (ombre, arête, bande de toit, fenêtres carrées) reste invisible à l'échelle
   du jeu : à l'écran, ce sont des rectangles beiges à trois carrés bleus.

Par calque :

| Calque | Copa | Districts | Verdict |
|---|---|---|---|
| Sols | tuiles peintes (sable, calçadão, route, écume) : bon | `DistrictDresser` tuile sable/mer/route ; le morro et Botafogo restent un grain brun-gris uniforme, les escaliers de la favela sont une colonne brune | moyen |
| Bâtiments | 4 façades peintes qui portent l'écran, le reste en aplat | 100 % aplat, un carré par fenêtre | **faible — le chantier** |
| Personnages | GBA net, bonne lisibilité, ombre au sol | idem | bon |
| Props | palmiers/parasols peints, ancrés au pied, mais rééchantillonnés à l'échelle non entière (pixels irréguliers, légère bouillie) | idem | moyen |
| Lumière | matin doré subtil, **soir = un voile bleu uniforme** (`CanvasModulate`) ; les fenêtres ne s'allument pas, les halos « nightlight » sont discrets | idem | faible |
| Mouvement | PNJ qui marchent, trafic ; **rien ne bouge dans le décor** (mer figée, palmiers figés, stores figés) | idem | faible |
| UI | lisible ; le Diário occupe en permanence 1/6 de l'écran, bandeau d'objectif large, boutons tactiles opaques, cadres « Godot » sans rapport avec le monde | — | moyen |
| Échelle | le Cantinho Carioca est plus petit que les immeubles génériques, le Palace deux fois plus haut ; les voitures font la taille d'un piéton | — | moyen |

**Diagnostic en une phrase** : Copacabana tient grâce à quatre façades
peintes et aux palmiers ; dès qu'on s'en éloigne (favela, Botafogo,
intérieurs, nuit), le jeu redevient un prototype à rectangles, et le style
GBA des personnages n'a pas de décor à sa hauteur.

## Pistes, par impact décroissant

### A. Façades en pixel-art modulaire — le gros gain
Remplacer ColorRect + `BuildingDressing` par un **peintre de façades**
(`FacadePainter`, même principe que `CharacterSpriteFactory` : dessin natif
à l'échelle GBA, upscale ×3 au pixel près, NEAREST) qui compose une façade à
partir d'un kit : mur (enduit, brique, azulejo), fenêtre (volet, store,
clim, linge), balcon, porte/rideau de fer, auvent, enseigne, bande de toit,
caixa d'água, antenne. Paramètres = taille, palette (`BUILDING_COLORS` /
`FAVELA_COLORS`), quartier (favela = tôle et brique nue, Copa = enduit et
balcons, Barra = verre). Les 4 façades peintes restent les repères.
- Impact ★★★★★ · effort **M-L** (2-4 j) · touche `CopacabanaGenerator`,
  `BuildingDressing`, les 58 façades taguées `building`/`building_favela`.
- Variante rapide (1 j, ★★★) : garder les rects mais leur donner une
  **matière** via le shader de `DistrictDresser` (enduit + grille de
  fenêtres + ombre) — la version « sols » appliquée aux murs.
- Alternative : atlas dessiné (main ou IA) par type de bâtiment. Plus beau
  par façade, mais 60 bâtiments à produire et un style à tenir ;
  `kenney_town.png` (16 px) est dans le repo mais trop petit et d'un autre
  style.

### B. Sols et volumes hors Copa
Pavés et **escaliers** dessinés pour le morro (tuile marche + rampe),
trottoirs à bordure, passages piétons, **ombres portées** des bâtiments
(un ColorRect sombre semi-transparent décalé, trivial) et des props. Le morro
cesse d'être un fond brun uni.
- Impact ★★★★ · effort **S-M** (1-2 j) · `DistrictDresser` (nouveaux
  groupes `ground_stairs`, `ground_cobble`), `BuildingDressing` (ombre
  portée).

### C. Un décor qui bouge
Mer qui ondule (shader de déplacement sur la bande eau + écume animée),
palmiers qui plient (shader skew sinusoïdal), stores et drapeaux, mouettes
(RandomEventManager a déjà des spawns), poussière sous les pas sur le sable,
léger « idle bob » des PNJ à l'arrêt.
- Impact ★★★★ (c'est ce qui fait « vivant » sur une capture comme en
  jeu) · effort **S** (1 j) · shaders simples, zéro contenu.

### D. La nuit et la lumière
Le soir devient une scène : fenêtres allumées (sprites émissifs exclus du
`CanvasModulate` via un `CanvasLayer` ou `Light2D` additifs), lampadaires en
`PointLight2D` avec halo, enseignes au néon (Rio Style), reflets sur la
mer, dégradé de ciel par phase, ombres longues le matin.
- Impact ★★★★ · effort **M** (1-2 j) · `DayLighting`, `CopacabanaGenerator`
  (`nightlight`), `DistrictDresser`.

### E. Échelle, profondeur, tri
Harmoniser les tailles (le Cantinho à la hauteur des immeubles voisins, les
véhicules un peu plus grands), **faux 3/4** (toits visibles, bas de façade
plus large que le haut), `y_sort` pour PNJ/props/joueur (aujourd'hui le
joueur passe devant ou derrière selon l'ordre d'instanciation).
- Impact ★★★ · effort **M** · dépend de A.

### F. Hygiène pixel
Props de l'atlas **rééchantillonnés une fois** à une taille entière
(`PropSprites`) au lieu d'une échelle flottante ; base de rendu 640×360 dans
un `SubViewport` à l'échelle entière (le ×3 devient exact sur tous les
écrans, y compris iPhone) ; vérifier NEAREST sur tout ce qui est pixel-art.
- Impact ★★ (mais sans ça, tout le reste bave) · effort **S** (½ j).

### G. Interface
Diário **replié par défaut** (icône + badge, ouvert par tap ou à chaque
nouvelle quête), bandeau d'objectif sur une ligne, boutons tactiles
translucides et plus petits (≥ 44 pt), cadres 9-slice dessinés dans le
style du monde, police pixel pour les étiquettes in-world (« Padaria »,
« P4 »), prompts d'interaction en pastille.
- Impact ★★★ (lisibilité et cohérence immédiates) · effort **S-M** (1 j).

### H. Intérieurs
Un kit de 15-20 tuiles (plancher, carrelage, mur, plinthe, lit, table,
cuisine, étagère, fenêtre avec lumière) + `DistrictDresser` appliqué aux
`scenes/interiors/` (20 scènes). La maison de tio Zé est la vitrine : c'est
là que commence chaque partie.
- Impact ★★★ · effort **M** (1-2 j, surtout du contenu).

### I. Outillage et garde-fous
`ScreenshotMain` existe désormais ; y ajouter un jeu de vues de référence et
une comparaison (diff d'images) dans `run_tests.sh` en mode optionnel, et
écrire un **style guide** d'une page (palette, tailles, règles d'ombre et de
contour) pour que tout nouvel asset respecte le langage GBA.
- Impact ★★ · effort **S** (½ j).

## Livré (2026-10-08)

- **F** : `PropSprites.resampled` — palmiers, parasols, serviettes et
  carrocinha réduits une fois à la densité GBA (hauteur/3, LANCZOS, alpha
  durci) puis affichés ×3 NEAREST.
- **I** : `tools/visual_refs.sh` (6 vues de référence, diff `tools/image_diff.gd`,
  seuil 4 %) + `docs/STYLE_VISUEL.md`.
- **A, en peintre procédural** : `scripts/world/FacadePainter.gd` dessine
  chaque façade à largeur/3 × hauteur/3 (rampe de 5 tons dérivée de la
  couleur, enduit ou brique, étages compacts de 8 px natifs, fenêtres à
  volets, balcons, climatiseurs, rez-de-chaussée porte ou vitrine à auvent,
  arêtes, fondation, contour). Styles `copa`, `favela`, `igreja`. Branché
  dans `BuildingDressing.paint_relief` (les rects de relief ne restent que
  pour l'ombre, la bande de toit et le décor de toit), donc actif sur les
  deux rangées de Copa, les 6 repères de la 2e rangée (post-traitement
  `_paint_landmark_facades`), les maisons du morro et les façades taguées des
  12 districts. Les 4 façades peintes de l'atlas (Palace, Cantinho, Quiosque,
  Rio Style) restent telles quelles — décision à prendre.

- **B** : `GroundPainter` (pavés irréguliers, terre à cailloux et touffes,
  marches nez/giron/contremarche) branché dans `DistrictDresser` pour les
  groupes `ground_plaza`, `ground_dirt` et le nouveau `ground_stairs` (les
  deux escaliers du morro sont tagués) ; chaque dalle garde sa couleur, la
  tuile est générée dedans à la densité GBA. Les ombres portées existaient
  déjà (rect à 30 %).
- **D** : `FacadePainter.build_night` (vitres allumées une sur trois éteinte,
  halo d'un pixel) posé par `BuildingDressing` en Sprite2D `FacadeNight`
  (groupe `nightlight`) ; `DayLighting` applique à tout nœud `nightlight` un
  matériau **émissif** (shader qui ignore la couleur de vertex, donc le
  `CanvasModulate`) et remplace les halos en rect des lampadaires par un
  dégradé radial 2,4× plus large. Le soir a désormais des lumières au lieu
  de taches jaunes assombries. Non fait : reflets sur la mer, néons des
  enseignes de l'atlas, ombres longues du matin.

- **C** : `scripts/world/WorldFx.gd` — trois shaders de monde : **eau**
  (deux ondes lentes qui décalent l'UV et une bande claire mobile), **écume**
  (opacité qui respire, déphasée selon la position) et **balancement** des
  couronnes de palmiers (torsion douce par l'UV, pied immobile, phase par
  position). Posés sur les tuiles de mer et l'écume de Copa comme des
  districts (`DistrictDresser`), et sur chaque palmier via `PropSprites`.
  **Mouettes** (`Seagulls.gd`, oiseaux 9×5 natifs à 2 frames) qui glissent
  dans une bande au ras de l'eau et rebouclent. **Poussière de pas**
  (`FootDust.gd`, bouffées tous les 22 px quand le joueur court sur le
  sable). Non fait : stores et drapeaux animés, ombres des nuages.
- **E** : **tri en Y** réel. `WorldFx.enable_y_sort` active `y_sort_enabled`
  sur le monde et ses conteneurs ; les `z_index` fixes des personnages
  (joueur, PNJ, clients, Miguel, PM) sont retirés des scènes ; toute texture
  posée (façades `Facade`/`FacadeNight`, palmiers, parasols, carrocinha,
  Palace et commerces peints) a son **origine au pied** (`position` = base,
  `offset` remonte le dessin) pour que l'ordre de dessin suive la hauteur à
  l'écran. Un personnage passe désormais derrière la couronne d'un palmier
  et devant une façade dont il dépasse la base. Les toits reçoivent une
  dalle (`RoofEdge`) qui lit comme un volume vu d'en haut. Les tests
  (`TestGroupWorld`) vérifient l'ancrage du sprite de façade.

- **G** : `scripts/ui/PixelFont.gd` — police bitmap 5×7 dessinée en code
  (capitales, minuscules, chiffres, ponctuation, accents composés, cédille),
  construite en `FontFile` à trois échelles entières (11/22/33 px, atlas
  agrandi NEAREST, contour noir cuit en variante, police système en secours
  pour les emojis). Toutes les étiquettes du monde (enseignes, postos,
  prompts de porte, intérieurs) passent par `PixelFont.style_world_label`
  (échelle choisie par la taille demandée et bornée par la largeur de
  l'enseigne ; une étiquette sombre reste sans contour). `scripts/ui/UITheme.gd`
  — thème construit en code et **fusionné dans le thème par défaut du
  moteur** (un thème posé sur la fenêtre ne traverse pas les CanvasLayer) :
  cadres 9-slice peints (trait / liseré or / trait / fond), boutons, barres,
  variations `TouchButton` (pastille ronde translucide), `Pastille` (prompt
  d'interaction), `PixelTitle` / `PixelButton`. Diário **replié** derrière
  un badge « ✦ principales · activités » (tap = ouvre et épingle, nouvelle
  quête = ouverture 6 s), bandeau d'objectif sur **une ligne** (quoi · où,
  barre d'acte fine, titre d'acte en infobulle), boutons tactiles en
  pastilles ✋ / 🏃 / ⚽ (104-128 px), minimap déplacée en haut à gauche
  (le bas-droit est aux pouces). Outils : `tools/preview_pixel_font.gd`,
  `tools/preview_ui_theme.gd`.
- **H** : `scripts/world/InteriorPainter.gd` (planches, carrelage, marbre,
  moquette, pierre, bande de mur à plinthe et cimaise, fenêtre) +
  `scripts/world/InteriorDresser.gd` appliqué aux **21 scènes** de
  `scenes/interiors/` (par `DistrictDresser.dress` pour les districts, par
  `CopacabanaGenerator` pour Copa) : sol peint dans la couleur de la dalle
  (genre par nom de scène), mur extérieur sombre autour du sol, mur du fond
  avec fenêtres et flaques de lumière, bandes de mur latérales, et pour
  chaque meuble un contour, une arête claire, une ombre portée et un grain
  de bois quand la couleur s'y prête. Tout est **enfant du rect** habillé
  (suit sa visibilité — mémorial, bascules par flag) ; aucune collision
  ajoutée. Non fait : kit de meubles dessinés (lit, cuisinière, étagère
  reconnaissables), portes peintes, nuit dans les intérieurs.

Les neuf pistes sont livrées. Ce qui reste est de l'ordre de la finition :
façades peintes de l'atlas (Palace, Cantinho…) à harmoniser avec le peintre,
meubles dessinés, stores et drapeaux animés, reflets sur la mer.

## Séquence recommandée

1. **F + I** (1 j) : pixels propres et captures de référence — on mesure
   ensuite chaque étape à l'écran.
2. **A** (variante rapide d'abord, 1 j, puis le peintre complet) **+ B** :
   le cœur du problème, visible sur toutes les captures.
3. **D + C** : la nuit et le mouvement — ce qui transforme une capture
   correcte en capture qui donne envie.
4. **G** : l'interface se met au diapason.
5. **H** : les intérieurs, à commencer par la maison.

Deux décisions à prendre avant de lancer A : (1) peintre procédural (comme
les personnages — cohérent, customisable, zéro asset à produire) ou atlas
dessiné (plus riche par bâtiment, mais 60 façades à tenir dans un style) ;
(2) garder le mélange « peint » / « GBA » pour les 4 repères de Copa, ou les
redessiner aussi en pixel-art net pour une seule écriture.
