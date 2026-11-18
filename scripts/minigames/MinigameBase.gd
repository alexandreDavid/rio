class_name MinigameBase
extends Node2D

# Socle commun des scènes de mini-jeu (contrat : _end_* → minigame_ended +
# match_ended). Pris en charge ici, sans que chaque jeu ait à y penser :
#  - bouton « ✕ Sair » (tap, B manette, Échap) posé si la scène n'en a pas ;
#    quitter = abandon, qui ne qualifie JAMAIS (`final_qualifies`) ;
#  - cadre plein écran : les dalles de fond qui couvrent la largeur de design
#    (1920) sont étirées jusqu'aux bords réels (écrans 19,5:9 → plus de bandes
#    grises), et à nouveau à chaque rotation ;
#  - retour sensoriel : `sfx(nom)` et `pulse()` (son + vibration manette/tél.).

const QUIT_SCENE: PackedScene = preload("res://scenes/ui/MinigameQuitButton.tscn")
const DESIGN_WIDTH: float = 1920.0

var forfeited: bool = false
var _quit_wired: bool = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_wire_quit.call_deferred()
		_fit_backdrops.call_deferred()
		_silence_buttons.call_deferred()
		get_viewport().size_changed.connect(_fit_backdrops)

# À surcharger : termine la partie sur abandon (forfeited est déjà vrai).
func quit_game() -> void:
	if has_method("_end_game"):
		call("_end_game")

# Un abandon ne qualifie jamais, quel que soit le score au moment de partir.
func final_qualifies(qualifies: bool) -> bool:
	return qualifies and not forfeited

func sfx(key: String, pitch: float = 1.0) -> void:
	AudioManager.play(key, pitch)

func pulse(strength: float = 0.5, duration: float = 0.08) -> void:
	GamepadBridge.pulse(strength, duration)

# Cale un contrôle d'interface (ancré à gauche) sous une abscisse du monde :
# les boutons de lane restent sous leur lane quelle que soit la largeur d'écran.
func align_under_world_x(ctrl: Control, world_x: float) -> void:
	var place: Callable = func() -> void:
		if not is_instance_valid(ctrl) or not ctrl.is_inside_tree():
			return
		var sx: float = (get_viewport().get_canvas_transform() * Vector2(world_x, 0)).x
		var w: float = ctrl.offset_right - ctrl.offset_left
		ctrl.anchor_left = 0.0
		ctrl.anchor_right = 0.0
		ctrl.offset_left = sx - w * 0.5
		ctrl.offset_right = sx + w * 0.5
	place.call_deferred()
	get_viewport().size_changed.connect(place)

# Personnage pixel-art (même usine que le monde) ancré par les pieds.
# `cfg` vide = l'apparence du joueur.
func char_sprite(height: float, cfg: Dictionary = {}) -> Sprite2D:
	if cfg.is_empty():
		cfg = CharacterSpriteFactory.config_from_indices(CharacterSpriteFactory.default_indices())
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = CharacterSpriteFactory.build_sheet(cfg)
	spr.region_enabled = true
	spr.region_rect = Rect2(0, 0, CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = true
	spr.offset = Vector2(0, -CharacterSpriteFactory.CELL_H * 0.5)
	var s: float = height / float(CharacterSpriteFactory.CELL_H)
	spr.scale = Vector2(s, s)
	return spr

func _wire_quit() -> void:
	if _quit_wired or not is_inside_tree():
		return
	_quit_wired = true
	var btn: Node = null
	for c in find_children("*", "CanvasLayer", true, false):
		if c.has_signal("quit_pressed"):
			btn = c
			break
	if btn == null:
		btn = QUIT_SCENE.instantiate()
		add_child(btn)
	btn.quit_pressed.connect(_on_quit_pressed)
	_dodge_quit.call_deferred(btn)

# Les HUD posés en haut à droite (chrono, compteur) glissent à gauche du
# bouton au lieu de passer dessous.
func _dodge_quit(btn: Node) -> void:
	var b: Control = btn.get_node_or_null("Button") as Control
	if b == null or not b.is_inside_tree():
		return
	var zone: Rect2 = b.get_global_rect().grow(12.0)
	var moved: Array[Control] = []
	for n in find_children("*", "Control", true, false):
		var c: Control = n
		if moved.any(func(m: Control) -> bool: return m.is_ancestor_of(c)):
			continue
		if c == b or b.is_ancestor_of(c) or c.anchor_left < 0.5 or not c.is_visible_in_tree():
			continue
		if not _in_canvas_layer(c) or c is BaseButton:
			continue
		var r: Rect2 = c.get_global_rect()
		if not r.intersects(zone):
			continue
		var shift: float = r.end.x - zone.position.x
		# Un texte plus large que son cadre doit déborder vers la gauche.
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		c.offset_left -= shift
		c.offset_right -= shift
		moved.append(c)

# En jeu, chaque geste a son propre son (sfx) : le clic d'interface générique
# d'AudioManager ferait doublon sur les pads, frappes et commandes.
func _silence_buttons() -> void:
	for n in find_children("*", "BaseButton", true, false):
		var b: BaseButton = n
		b.set_meta("silent_click", true)
		for c in b.pressed.get_connections():
			var target: Object = (c.callable as Callable).get_object()
			if target != null and target.get_script() != null \
					and String(target.get_script().resource_path).ends_with("AudioManager.gd"):
				b.pressed.disconnect(c.callable)

func _on_quit_pressed() -> void:
	forfeited = true
	quit_game()

# Étire les fonds pleine largeur jusqu'aux bords visibles (monde).
func _fit_backdrops() -> void:
	if not is_inside_tree():
		return
	var vp: Viewport = get_viewport()
	var vis_size: Vector2 = vp.get_visible_rect().size
	var inv: Transform2D = vp.get_canvas_transform().affine_inverse()
	var left: float = (inv * Vector2.ZERO).x
	var right: float = (inv * Vector2(vis_size.x, 0)).x
	var design_w: float = (right - left) * DESIGN_WIDTH / maxf(vis_size.x, 1.0)
	for n in find_children("*", "ColorRect", true, false):
		var r: ColorRect = n
		if not r.has_meta(&"_fit_base"):
			if _in_canvas_layer(r) or r.get_global_rect().size.x < design_w * 0.95:
				continue
			r.set_meta(&"_fit_base", true)
		r.global_position.x = left - 8.0
		r.size.x = right - left + 16.0

func _in_canvas_layer(n: Node) -> bool:
	var p: Node = n.get_parent()
	while p and p != self:
		if p is CanvasLayer:
			return true
		p = p.get_parent()
	return false
