class_name UIFit
extends RefCounted

# Agrandit un panneau dessiné à petite échelle pour qu'il occupe l'écran, et
# garantit une taille de texte lisible sur iPhone (un px de canevas 1080p
# ≈ 0,36 pt en paysage : ~25 px réels est le plancher du jeu).

const MIN_SCREEN_FONT: float = 25.0
const META: StringName = &"_ui_fit_fill"


# Échelle uniforme pour que `c` (taille de conception = sa taille actuelle,
# centré) remplisse `fill` de la vue. Se réapplique à chaque rotation.
static func fit(c: Control, fill: Vector2 = Vector2(0.92, 0.9)) -> float:
	var design: Vector2 = c.size
	if design.x <= 0.0 or design.y <= 0.0:
		design = Vector2(c.offset_right - c.offset_left, c.offset_bottom - c.offset_top)
	var view: Vector2 = c.get_viewport_rect().size
	var k: float = minf(view.x * fill.x / design.x, view.y * fill.y / design.y)
	c.pivot_offset = design * 0.5
	c.scale = Vector2(k, k)
	if not c.has_meta(META):
		c.set_meta(META, fill)
		c.get_viewport().size_changed.connect(func() -> void: fit(c, c.get_meta(META)))
	return k


# Plancher de police dans le repère de `root`, déduit de son échelle.
static func design_floor(scale: float) -> int:
	return int(ceilf(MIN_SCREEN_FONT / maxf(scale, 0.01)))


static func floor_fonts(root: Node, min_size: int) -> void:
	if root is Label or root is Button or root is RichTextLabel:
		var c: Control = root
		var key: String = "normal_font_size" if root is RichTextLabel else "font_size"
		if c.get_theme_font_size(key) < min_size:
			c.add_theme_font_size_override(key, min_size)
	for child in root.get_children():
		floor_fonts(child, min_size)


# Les lignes construites plus tard (listes rafraîchies) passent aussi au plancher.
static func keep_floor(root: Control, min_size: int) -> void:
	floor_fonts(root, min_size)
	root.get_tree().node_added.connect(func(n: Node) -> void:
		if is_instance_valid(root) and root.is_ancestor_of(n):
			(func() -> void:
				if is_instance_valid(n):
					floor_fonts(n, min_size)).call_deferred())
