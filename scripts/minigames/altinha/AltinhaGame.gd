class_name AltinhaGame
extends Node2D

# Altinha — roda de 3 (joueur + 2 parceiros), sans les mains. Remplace la
# version "monde ouvert" (scripts/world/AltinhaSession.gd, jugée pas assez
# fun) par un vrai mini-jeu au gabarit du beach-volley : déplacement pour se
# placer sous le point de chute, fenêtre de timing Perfeito/Boa/Mole, visée du
# parceiro, combo, parceiro "quente" qui déclenche un geste técnico.
#
# Boucle : la balle part du joueur vers un parceiro (visée + qualité de la
# frappe), le parceiro la relance systématiquement au joueur SAUF sur une
# passe Mole qu'il peut laisser tomber (probabilité croissante avec le
# niveau). 3 chutes cumulées = fin de partie. Aucune récompense monétaire ici
# (contenu culturel) : ActivityRewards branche la réputation côté launcher.

signal match_ended(qualifies: bool, score: int)

enum Phase { TO_PLAYER, TO_PARTNER, PAUSED }
enum { QUALITY_SOFT, QUALITY_GOOD, QUALITY_PERFECT }

# --- Disposition de la roda (espace local du root, partagé par tous les
# enfants — aucun n'a de transform propre en dehors de sa `position`) ---
const PLAYER_Y: float = 150.0
const PLAYER_MIN_X: float = -190.0
const PLAYER_MAX_X: float = 190.0
const PLAYER_SPEED: float = 230.0
const PARTNER_LEFT_POS: Vector2 = Vector2(-150.0, -70.0)
const PARTNER_RIGHT_POS: Vector2 = Vector2(150.0, -70.0)

# --- Fenêtre de frappe : distance combinée (latéral + hauteur) entre le
# point de contact idéal du joueur et la balle au moment du tap. Même langage
# que VolleyPlayer.try_hit() — juste transposé à une balle qui simule sa
# hauteur plutôt qu'un RigidBody. ~24px d'écart hauteur ≈ 0.12s de réaction
# proche du sol (la balle y descend à une vitesse voisine de v0, 165-260 px/s).
const CONTACT_HEIGHT: float = 30.0
const HIT_PERFECT_DIST: float = 24.0
const HIT_GOOD_DIST: float = 48.0
const HIT_SOFT_DIST: float = 78.0
const HIT_LOCK: float = 0.22

const MAX_DROPS: int = 3

# --- Difficulté croissante avec le nombre de toques réussis (`_touches`) ---
const DRIFT_MIN_BASE: float = 50.0
const DRIFT_MAX_BASE: float = 110.0
const DRIFT_MIN_GROWTH: float = 1.0
const DRIFT_MAX_GROWTH: float = 2.0
const DRIFT_MIN_CAP: float = 90.0
const DRIFT_MAX_CAP: float = 170.0

const TO_PLAYER_V0_BASE: float = 260.0
const TO_PLAYER_V0_MIN: float = 165.0
const TO_PLAYER_V0_DECAY: float = 4.0

const SOFT_DROP_BASE: float = 0.05
const SOFT_DROP_GROWTH: float = 0.01
const SOFT_DROP_CAP: float = 0.55

# --- Vitesse d'envoi joueur → parceiro selon la qualité : contre-intuitif
# mais physiquement cohérent avec le modèle à un seul paramètre de
# AltinhaBall (v0 fixe hauteur ET durée) — Perfeito = v0 bas = arc court et
# rapide = passe TENDUE ; Mole = v0 haut = arc haut et lent = balle bâtarde,
# plus longue à lire, plus facile à mal négocier (d'où le risque de chute).
const TO_PARTNER_V0_PERFECT: float = 150.0
const TO_PARTNER_V0_GOOD: float = 195.0
const TO_PARTNER_V0_SOFT: float = 255.0

# --- Score ---
const PTS_SOFT: int = 2
const PTS_GOOD: int = 6
const PTS_PERFECT: int = 14
const COMBO_CAP: int = 20
const TECNICO_BONUS: int = 40

# Seuil qualifies — calibré pour représenter ~1 minute de jeu propre :
# un cycle joueur↔parceiro dure ~2.1s en moyenne (vol vers le joueur
# 1.0-1.5s selon le niveau + retour automatique du parceiro ~0.85-1.5s) →
# ~25-28 toques joueur en 60s sans chute. Avec un mix réaliste (~70% Boa,
# ~20% Perfeito, ~10% Mole) et un combo qui grimpe sans interruption
# (bonus plafonné à 20/toque), le score cumulé atteint ~550-600 sur cette
# minute propre. Le seuil est fixé un cran en dessous pour tolérer 1-2
# accrocs sans faire échouer une partie honnête.
const QUALIFY_SCORE_THRESHOLD: int = 400

var _phase: int = Phase.PAUSED
var _ended: bool = false

var _score: int = 0
var _touches: int = 0
var _perfeitos: int = 0
var _combo: int = 0
var _best_combo: int = 0
var _drops: int = 0

var _move_left_held: bool = false
var _move_right_held: bool = false
var _hit_lock: float = 0.0
var _no_aim_toggle: bool = false

var _aimed_partner: int = 1        # 1 = gauche, 2 = droite (parceiro visé pendant TO_PARTNER)
var _pending_quality: int = QUALITY_GOOD
var _pending_tecnico: bool = false

var _hot_partner: int = 1
var _hot_timer: float = 0.0

var _shake_time: float = 0.0
var _shake_strength: float = 0.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _player: Node2D = null
var _player_sprite: Sprite2D = null
var _partner_left: AltinhaPartner = null
var _partner_right: AltinhaPartner = null
var _ball: AltinhaBall = null
var _cam: Camera2D = null
var _flash: ColorRect = null

var score_label: Label = null
var sub_label: Label = null
var status_label: Label = null
var result_label: Label = null

func _ready() -> void:
	EventBus.minigame_started.emit("altinha")
	_rng.randomize()

	_cam = get_node_or_null("Camera2D") as Camera2D
	if _cam:
		_cam.make_current()

	_partner_left = get_node_or_null("PartnerLeft") as AltinhaPartner
	_partner_right = get_node_or_null("PartnerRight") as AltinhaPartner
	_ball = get_node_or_null("Ball") as AltinhaBall
	_player = get_node_or_null("Player") as Node2D
	_build_player_visual()
	_build_parasols()

	score_label = get_node_or_null("UI/ScoreLabel") as Label
	sub_label = get_node_or_null("UI/SubLabel") as Label
	status_label = get_node_or_null("UI/StatusLabel") as Label
	result_label = get_node_or_null("UI/ResultLabel") as Label

	var left_btn: Button = get_node_or_null("UI/MoveLeftButton") as Button
	if left_btn:
		left_btn.button_down.connect(func() -> void: _move_left_held = true)
		left_btn.button_up.connect(func() -> void: _move_left_held = false)
	var right_btn: Button = get_node_or_null("UI/MoveRightButton") as Button
	if right_btn:
		right_btn.button_down.connect(func() -> void: _move_right_held = true)
		right_btn.button_up.connect(func() -> void: _move_right_held = false)
	var hit_btn: Button = get_node_or_null("UI/HitButton") as Button
	if hit_btn:
		hit_btn.pressed.connect(_try_hit)
	var quit_btn: CanvasLayer = get_node_or_null("MinigameQuitButton")
	if quit_btn and quit_btn.has_signal("quit_pressed"):
		quit_btn.quit_pressed.connect(_end_game)

	var ui: CanvasLayer = get_node_or_null("UI") as CanvasLayer
	if ui:
		_flash = ColorRect.new()
		_flash.name = "HitFlash"
		_flash.color = Color(1.0, 1.0, 1.0, 0.0)
		_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		ui.add_child(_flash)

	_hot_timer = _rng.randf_range(5.0, 8.0)
	_set_hot(1 if _rng.randi() % 2 == 0 else 2)
	_update_labels()
	if status_label:
		status_label.text = "Prepara..."
	await get_tree().create_timer(1.0).timeout
	_launch_serve()

func _build_player_visual() -> void:
	if _player == null:
		return
	var config: Dictionary = CharacterSpriteFactory.config_from_indices(CharacterSpriteFactory.default_indices())
	var shadow: ColorRect = ColorRect.new()
	shadow.name = "Shadow"
	shadow.offset_left = -12.0
	shadow.offset_top = 2.0
	shadow.offset_right = 12.0
	shadow.offset_bottom = 9.0
	shadow.color = Color(0.0, 0.0, 0.0, 0.3)
	shadow.z_index = -1
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player.add_child(shadow)
	_player_sprite = Sprite2D.new()
	_player_sprite.name = "CharSprite"
	_player_sprite.texture = CharacterSpriteFactory.build_sheet(config)
	_player_sprite.region_enabled = true
	_player_sprite.region_rect = Rect2(0, 0, CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	_player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var display_h: float = 50.0
	var s: float = display_h / float(CharacterSpriteFactory.CELL_H)
	_player_sprite.scale = Vector2(s, s)
	_player_sprite.position = Vector2(0.0, -display_h * 0.5)
	_player.add_child(_player_sprite)

# 2 parasols décoratifs (polygones code-only, pas d'asset) pour l'ambiance plage.
func _build_parasols() -> void:
	_spawn_parasol(Vector2(-300.0, -30.0), Color(0.85, 0.32, 0.28))
	_spawn_parasol(Vector2(300.0, -30.0), Color(0.35, 0.55, 0.85))

func _spawn_parasol(pos: Vector2, color: Color) -> void:
	var root: Node2D = Node2D.new()
	root.position = pos
	root.z_index = -2
	add_child(root)
	var pole: ColorRect = ColorRect.new()
	pole.offset_left = -2.0
	pole.offset_top = -40.0
	pole.offset_right = 2.0
	pole.offset_bottom = 30.0
	pole.color = Color(0.55, 0.42, 0.3)
	pole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pole)
	var canopy: Polygon2D = Polygon2D.new()
	canopy.polygon = PackedVector2Array([
		Vector2(-38.0, -40.0), Vector2(38.0, -40.0), Vector2(0.0, -78.0),
	])
	canopy.color = color
	root.add_child(canopy)
	var trim: Polygon2D = Polygon2D.new()
	trim.polygon = PackedVector2Array([
		Vector2(-38.0, -40.0), Vector2(-24.0, -32.0), Vector2(-10.0, -40.0),
		Vector2(4.0, -32.0), Vector2(18.0, -40.0), Vector2(32.0, -32.0), Vector2(38.0, -40.0),
	])
	trim.color = color.darkened(0.25)
	root.add_child(trim)

func _process(delta: float) -> void:
	if _ended:
		return
	_hit_lock = maxf(0.0, _hit_lock - delta)
	_move_player(delta)
	_update_hot_timer(delta)
	_shake_process(delta)
	if _phase == Phase.TO_PLAYER or _phase == Phase.TO_PARTNER:
		var grounded_now: bool = _ball.advance(delta)
		if grounded_now:
			if _phase == Phase.TO_PLAYER:
				_register_drop("A bola caiu na areia...")
			else:
				_on_partner_arrival()

func _move_player(delta: float) -> void:
	if _player == null:
		return
	var axis: float = _movement_axis()
	_player.position.x = clampf(_player.position.x + axis * PLAYER_SPEED * delta, PLAYER_MIN_X, PLAYER_MAX_X)
	if _player_sprite and absf(axis) > 0.05:
		_player_sprite.flip_h = axis < 0.0

# Clavier (bonus dev) sinon boutons tactiles ◀ ▶ — même schéma que VolleyPlayer.
func _movement_axis() -> float:
	var axis: float = Input.get_axis("move_left", "move_right")
	if absf(axis) >= 0.05:
		return axis
	return (-1.0 if _move_left_held else 0.0) + (1.0 if _move_right_held else 0.0)

func _update_hot_timer(delta: float) -> void:
	_hot_timer -= delta
	if _hot_timer <= 0.0:
		_set_hot(2 if _hot_partner == 1 else 1)
		_hot_timer = _rng.randf_range(6.0, 10.0)

func _set_hot(which: int) -> void:
	_hot_partner = which
	if _partner_left:
		_partner_left.set_hot(which == 1)
	if _partner_right:
		_partner_right.set_hot(which == 2)

# --- Vols de balle ---

func _launch_serve() -> void:
	_phase = Phase.TO_PLAYER
	var from: Vector2 = Vector2(0.0, -120.0)
	var to: Vector2 = _random_player_landing()
	_ball.show_marker = true
	_ball.launch(from, to, _to_player_kick_velocity())
	if status_label:
		status_label.text = "Positionne-toi sous le cercle !"

func _random_player_landing() -> Vector2:
	var range_v: Vector2 = _drift_range()
	var dist: float = _rng.randf_range(range_v.x, range_v.y)
	var dir: float = 1.0 if _rng.randf() < 0.5 else -1.0
	var px: float = _player.position.x if _player else 0.0
	var target_x: float = clampf(px + dir * dist, PLAYER_MIN_X, PLAYER_MAX_X)
	return Vector2(target_x, PLAYER_Y)

func _to_player_kick_velocity() -> float:
	return clampf(TO_PLAYER_V0_BASE - float(_touches) * TO_PLAYER_V0_DECAY, TO_PLAYER_V0_MIN, TO_PLAYER_V0_BASE)

func _drift_range() -> Vector2:
	var mn: float = clampf(DRIFT_MIN_BASE + float(_touches) * DRIFT_MIN_GROWTH, DRIFT_MIN_BASE, DRIFT_MIN_CAP)
	var mx: float = clampf(DRIFT_MAX_BASE + float(_touches) * DRIFT_MAX_GROWTH, DRIFT_MAX_BASE, DRIFT_MAX_CAP)
	return Vector2(mn, mx)

func _soft_drop_probability() -> float:
	return clampf(SOFT_DROP_BASE + float(_touches) * SOFT_DROP_GROWTH, SOFT_DROP_BASE, SOFT_DROP_CAP)

# --- Frappe du joueur ---

func _try_hit() -> void:
	if _ended or _phase != Phase.TO_PLAYER or _hit_lock > 0.0:
		return
	var origin: Vector2 = Vector2(_player.position.x if _player else 0.0, PLAYER_Y - CONTACT_HEIGHT)
	var dist: float = origin.distance_to(_ball.world_pos())
	if dist > HIT_SOFT_DIST:
		_hit_lock = HIT_LOCK
		return
	var quality: int = QUALITY_SOFT
	if dist <= HIT_PERFECT_DIST:
		quality = QUALITY_PERFECT
	elif dist <= HIT_GOOD_DIST:
		quality = QUALITY_GOOD
	_resolve_player_hit(quality)

func _resolve_player_hit(quality: int) -> void:
	_combo += 1
	_touches += 1
	if quality == QUALITY_PERFECT:
		_perfeitos += 1
	var target_which: int = _pick_aim()
	var is_tecnico: bool = quality == QUALITY_PERFECT and target_which == _hot_partner

	var base_pts: int = PTS_SOFT
	if quality == QUALITY_GOOD:
		base_pts = PTS_GOOD
	elif quality == QUALITY_PERFECT:
		base_pts = PTS_PERFECT
	var combo_bonus: int = mini(_combo, COMBO_CAP)
	var gain: int = base_pts + combo_bonus + (TECNICO_BONUS if is_tecnico else 0)
	_score += gain
	_best_combo = maxi(_best_combo, _combo)

	_show_quality_label(quality, gain)
	if quality == QUALITY_PERFECT:
		_start_shake(4.0, 0.12)
		_flash_screen()

	_aimed_partner = target_which
	_pending_quality = quality
	_pending_tecnico = is_tecnico
	var to_pos: Vector2 = PARTNER_LEFT_POS if target_which == 1 else PARTNER_RIGHT_POS
	var v0: float = TO_PARTNER_V0_PERFECT
	if quality == QUALITY_GOOD:
		v0 = TO_PARTNER_V0_GOOD
	elif quality == QUALITY_SOFT:
		v0 = TO_PARTNER_V0_SOFT
	_phase = Phase.TO_PARTNER
	_ball.show_marker = false
	_ball.launch(_ball.world_pos(), to_pos, v0)
	_update_labels()

# Visée : la direction tenue au moment du tap choisit le parceiro. Neutre =
# on alterne (garde la roda vivante même sans intention de visée explicite).
func _pick_aim() -> int:
	var axis: float = _movement_axis()
	if axis > 0.15:
		return 2
	if axis < -0.15:
		return 1
	_no_aim_toggle = not _no_aim_toggle
	return 2 if _no_aim_toggle else 1

# --- Réception du parceiro ---

func _on_partner_arrival() -> void:
	var partner: AltinhaPartner = _partner_left if _aimed_partner == 1 else _partner_right
	var quality: int = _pending_quality
	var caught: bool = true
	if quality == QUALITY_SOFT:
		caught = _rng.randf() >= _soft_drop_probability()
	if not caught:
		if partner:
			partner.bounce()
		_register_drop("O parceiro deixou a mole cair...")
		return
	if partner:
		partner.bounce()
		if _pending_tecnico:
			partner.show_tecnico()
			# On tourne le "quente" après un técnico — pas de farm sur la même cible.
			_set_hot(2 if _aimed_partner == 1 else 1)
			_hot_timer = _rng.randf_range(6.0, 10.0)
	# Le parceiro relance systématiquement — nouveau point de chute à couvrir.
	_phase = Phase.TO_PLAYER
	_ball.show_marker = true
	var from: Vector2 = _ball.target()
	var to_pos: Vector2 = _random_player_landing()
	_ball.launch(from, to_pos, _to_player_kick_velocity())
	if status_label:
		status_label.text = ""

# --- Chutes / fin de partie ---

func _register_drop(msg: String) -> void:
	_drops += 1
	_combo = 0
	if status_label:
		status_label.text = msg
	_float_label(_ball.target(), "Caiu...", Color(0.9, 0.4, 0.35), 16)
	_start_shake(3.0, 0.15)
	_update_labels()
	if _drops >= MAX_DROPS:
		_end_game()
		return
	_phase = Phase.PAUSED
	await get_tree().create_timer(1.1).timeout
	if _ended:
		return
	_launch_serve()

func _end_game() -> void:
	if _ended:
		return
	_ended = true
	_phase = Phase.PAUSED
	var qualifies: bool = _score >= QUALIFY_SCORE_THRESHOLD
	if status_label:
		status_label.text = ""
	if result_label:
		result_label.visible = true
		var headline: String = "A praia respeita !" if qualifies else "A roda esfriou..."
		result_label.text = "%s\nScore : %d — Melhor combo : x%d\nToques : %d (Perfeitos : %d)" \
			% [headline, _score, _best_combo, _touches, _perfeitos]
	await get_tree().create_timer(2.0).timeout
	var result: Dictionary = {
		"touches": _touches,
		"perfeitos": _perfeitos,
		"score": _score,
		"qualifies": qualifies,
		"won": qualifies,
		"best_combo": _best_combo,
		"drops": _drops,
	}
	EventBus.minigame_ended.emit("altinha", result)
	match_ended.emit(qualifies, _score)

# --- Feedback juteux ---

func _show_quality_label(quality: int, gain: int) -> void:
	var text: String
	var color: Color
	match quality:
		QUALITY_PERFECT:
			text = "Perfeito! +%d" % gain
			color = Color(1.0, 0.82, 0.2)
		QUALITY_GOOD:
			text = "Boa! +%d" % gain
			color = Color(0.5, 0.92, 0.55)
		_:
			text = "Mole... +%d" % gain
			color = Color(0.82, 0.82, 0.82)
	_float_label(Vector2(_player.position.x if _player else 0.0, PLAYER_Y - 70.0), text, color, 18)

func _float_label(pos: Vector2, text: String, color: Color, size: int) -> void:
	var label: Label = Label.new()
	label.text = text
	label.z_index = 20
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.position = pos + Vector2(-34.0, 0.0)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 30.0, 0.75)
	tw.tween_property(label, "modulate:a", 0.0, 0.75).set_delay(0.15)
	tw.chain().tween_callback(label.queue_free)

func _start_shake(strength: float, time: float) -> void:
	_shake_strength = strength
	_shake_time = time

func _shake_process(delta: float) -> void:
	if _shake_time <= 0.0 or _cam == null:
		return
	_shake_time -= delta
	if _shake_time <= 0.0:
		_cam.offset = Vector2.ZERO
	else:
		_cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength

func _flash_screen() -> void:
	if _flash == null:
		return
	_flash.color.a = 0.14
	var tw: Tween = create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.2)

func _update_labels() -> void:
	if score_label:
		score_label.text = "⚽ %d" % _score
	if sub_label:
		sub_label.text = "Combo x%d   Quedas %d/%d" % [_combo, _drops, MAX_DROPS]

# --- Clavier (bonus dev) ---

func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		return
	if not (event is InputEventKey and event.pressed):
		return
	if event.physical_keycode == KEY_Q:
		_end_game()
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_E:
		_try_hit()
		get_viewport().set_input_as_handled()
