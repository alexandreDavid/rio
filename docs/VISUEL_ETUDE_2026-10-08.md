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
