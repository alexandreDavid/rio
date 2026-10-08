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
6. **Ancrage** : un prop ou un personnage est ancré par ses pieds ; un
   bâtiment par le bas de sa façade. Le tri en Y suit l'ancre.
7. **Tailles** : porte 7×11 natifs, fenêtre 5×6, étage ≈ 11 natifs, un
   personnage fait un étage. Un bâtiment de Copa = 33×21 natifs, une maison du
   morro = 14-20 natifs de haut.
8. **Texte dans le monde** : étiquettes en police UI avec contour, jamais
   dessinées dans les sprites (localisation).

## Vérifier
- `tools/visual_refs.sh` : 6 vues de référence (Copa jour/soir, favela, Zona
  Sul, maison) comparées pixel à pixel ; `--update` après un changement
  d'art validé à l'œil.
- `tools/ScreenshotMain.tscn` pour toute autre vue ; `tools/preview_character_factory.gd`
  pour les personnages.
- On ne livre jamais un changement d'art sans l'avoir regardé.
