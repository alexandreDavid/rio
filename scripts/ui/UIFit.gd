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
	touch_floor_all(c)
	return k


# --- cibles tactiles ------------------------------------------------------

const TOUCH_PT: float = 44.0          # plancher d'Apple pour un doigt
const PHONE_PT_H: float = 402.0       # hauteur d'un iPhone en paysage, en points
const TOUCH_FREE: StringName = &"touch_free"   # méta : bouton exempté


# 44 pt en unités du canevas. Sur téléphone, d'après l'écran réel ; sur
# ordinateur on suppose un iPhone (une seule mise en page, celle de la cible).
static func touch_min_px(vp: Viewport) -> float:
	var pt_h: float = PHONE_PT_H
	if OS.has_feature("mobile"):
		var k: float = maxf(DisplayServer.screen_get_scale(), 1.0)
		pt_h = clampf(float(DisplayServer.window_get_size().y) / k, 320.0, 1100.0)
	return TOUCH_PT * vp.get_visible_rect().size.y / pt_h


# Donne à un bouton la taille minimale d'un doigt, dans SON repère (un bouton
# dans un panneau agrandi par fit() a besoin de moins d'unités locales).
static func touch_floor(b: BaseButton) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree() or b.has_meta(TOUCH_FREE):
		return
	var s: Vector2 = b.get_global_transform_with_canvas().get_scale()
	var px: float = touch_min_px(b.get_viewport())
	var want: Vector2 = Vector2(ceilf(px / maxf(s.x, 0.01)), ceilf(px / maxf(s.y, 0.01)))
	var cur: Vector2 = b.custom_minimum_size
	if cur.x < want.x or cur.y < want.y:
		b.custom_minimum_size = Vector2(maxf(cur.x, want.x), maxf(cur.y, want.y))


# Panneaux plein écran de Main : tant que l'un est ouvert, les commandes du
# monde (joystick, ✋, 🏃, 📱, 📸, badge du Diário) s'effacent — elles
# passaient par-dessus et se chevauchaient avec les boutons du panneau.
const MODALS: Array[StringName] = [
	&"Phone", &"JournalUI", &"MissionBoardUI", &"TaxiUI", &"Tutorial",
	&"CreditsScreen", &"CharacterCreator", &"EndingScreen", &"EpilogueScreen", &"ActCard",
]


static func modal_open(tree: SceneTree) -> bool:
	var main: Node = tree.current_scene
	if main == null:
		return false
	for id in MODALS:
		var n: CanvasLayer = main.get_node_or_null(NodePath(id)) as CanvasLayer
		if n != null and n.visible:
			return true
	return false


# Prévient `on_change` à chaque ouverture/fermeture d'un panneau (signal et
# pas sondage : la plupart des panneaux mettent l'arbre en pause).
static func watch_modals(tree: SceneTree, on_change: Callable) -> void:
	var main: Node = tree.current_scene
	if main == null:
		return
	for id in MODALS:
		var n: CanvasLayer = main.get_node_or_null(NodePath(id)) as CanvasLayer
		if n != null:
			n.visibility_changed.connect(on_change)
	on_change.call()


static func touch_floor_all(root: Node) -> void:
	if root is BaseButton:
		touch_floor(root)
	for child in root.get_children():
		touch_floor_all(child)


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
