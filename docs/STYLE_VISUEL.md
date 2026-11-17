# Style visuel — règles d'une page

Le jeu s'écrit en **pixel-art net, densité GBA** : 1 pixel natif = 3 px
monde (caméra ×3 → un pixel natif = 3×3 pixels écran en 1080p). Tout ce qui
est dessiné ou rééchantillonné respecte cette grille.

## Les règles
1. **Densité** : personnages 21×32 natifs (`CharacterSpriteFactory`), props
   de l'atlas réduits à hauteur/3 puis affichés ×3 (`PropSprites.resampled`),
   façades peintes par `FacadePainter` à largeur/3 × hauteur/3. Jamais une
   échelle flottante sur un sprite.
2. **Filtrage** : `TEXTURE_FILTER_NEAREST` partout (réglage projet + sprites).
   Jamais LINEAR sur du pixel-art (les tests le verrouillent pour les persos).
3. **Contour** : 1 pixel natif sombre (teinte de la couleur locale, luminance
   ×0,35) autour des personnages, props et éléments de façade qui se
   détachent. Pas de contour sur les sols.
4. **Ombrage** : 2 à 3 tons par matière (clair / base / ombre), lumière venant
   du haut-gauche ; ombre portée au sol = ovale ou rectangle noir à 28-30 %.
5. **Palette** : `BUILDING_COLORS` (enduits de Copa) et `FAVELA_COLORS`
   (morro) sont les bases ; les rampes dérivent par `FacadePainter.ramp()`
   (−35 % / base / +12 % / vitres bleu `WINDOW_COLOR`). Pas de couleur
   « Godot » brute (ni blanc pur ni noir pur sur une surface).
6. **Ancrage et tri** : un prop ou un personnage est ancré par ses pieds ;
   un bâtiment par le bas de sa façade. Le monde est en `y_sort_enabled`
   (`WorldFx.enable_y_sort`) : l'ordre de dessin suit l'origine du nœud,
   donc **l'origine d'un Sprite2D est toujours au pied** — `position` = la
   base, `offset = Vector2(0, -hauteur*0.5)` (ou `-hauteur` avec `centered`
   à faux) remonte le dessin. Pas de `z_index` fixe sur ce qui vit dans le
   monde ; il reste réservé aux sols (négatif) et aux effets au ras de l'eau.
7. **Tailles** : porte 7×9 natifs, fenêtre 5×5, étage 8 natifs
   (rez-de-chaussée 10), un personnage fait un étage et demi. Un bâtiment de
   Copa = 33×21 natifs, une maison du morro = 13-40 natifs de haut. Sols
   peints : tuile 16×16 natifs (48 px monde), marche de 3 natifs ; sable et
   mer : tuile 64×64 natifs (192 px monde, cellules retournées une sur deux
   par hachage), écume : bande de 12 natifs à cheval sur la couture.
8. **Mouvement** : tout reste sur la grille de pixels. La mer défile d'un
   texel entier (1,5 pas/s, la tuile boucle) et alterne 2 frames de reflets ;
   l'écume avance sur le sable en 4 frames ping-pong (2 s) — shader de tuiles
   `crisp` de `DistrictDresser`, jamais de déformation d'UV sur du pixel-art.
   Les couronnes de palmiers se balancent par `WorldFx`, phase dérivée de la
   position pour ne jamais être en chœur ; les mouettes et la poussière de
   pas sont les seuls éléments animés en code. Tout mouvement est lent (périodes de 2 à 6 s) : il doit
   se remarquer à la deuxième seconde, pas à la première.
9. **Texte dans le monde** : étiquettes en `PixelFont` (5×7, échelle
   entière ×1/×2/×3 choisie par `PixelFont.style_world_label`, contour
   noir cuit pour les couleurs claires, pas de contour pour les sombres),
   jamais dessinées dans les sprites (localisation). Les emojis viennent
   de la police de secours, à la même taille.
10. **Interface** : cadres 9-slice de `UITheme` (trait sombre / liseré or /
   trait / fond nuit à 92 %), jamais de `StyleBoxFlat` à coins arrondis ni
   de couleur « Godot ». Les boutons tactiles sont des pastilles rondes
   translucides (`TouchButton`, ≥ 104 px), les prompts des `Pastille`, les
   titres en `PixelTitle` (police pixel ×2) ; le corps de texte reste en
   police système (lisibilité sur téléphone). Le thème est fusionné dans
   le thème par défaut du moteur (`UITheme.apply`) : il vaut pour tout
   Control, même sous un CanvasLayer ou instancié plus tard.
11. **Intérieurs** : un sol peint dans la couleur du rect (planches,
   carrelage, marbre, moquette, pierre — genre par nom de scène dans
   `InteriorDresser.FLOOR_KINDS`), un mur du fond de 10 natifs avec plinthe
   et fenêtres, des murs sombres autour ; chaque meuble = contour 1 natif,
   arête claire haut-gauche, ombre portée à 1 natif. Tout ce qui est
   ajouté est enfant du rect habillé.

## Vérifier
- `tools/visual_refs.sh` : 6 vues de référence (Copa jour/soir, favela, Zona
  Sul, maison) comparées pixel à pixel ; `--update` après un changement
  d'art validé à l'œil.
- `tools/capture_main.sh <prefix> "x:y:zoom,…"` pour toute autre vue du jeu
  complet (sauvegardes du joueur mises à l'abri) ; `tools/preview_character_factory.gd`
  pour les personnages, `tools/preview_pixel_font.gd` pour la police,
  `tools/preview_ui_theme.gd` pour les cadres et boutons du thème.
- On ne livre jamais un changement d'art sans l'avoir regardé.
