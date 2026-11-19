class_name AltinhaGame
extends MinigameBase

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

const Art := preload("res://scripts/minigames/altinha/AltinhaArt.gd")

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
# point de contact idéal du joueur et la balle au moment du tap (balle qui
# simule sa hauteur). ~24px d'écart hauteur ≈ 0.12s de réaction
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

# Défi scénarisé (ex. Juca au prologue) : la partie s'arrête au N-ième toque
# au lieu d'attendre 3 chutes. 0 = roda libre.
var touch_goal: int = 0
# "praia" (défaut) ou "laje" : toit du morro, ciel et maisons au lieu de la mer.
var setting: String = "praia"

var _phase: int = Phase.PAUSED
var _ended: bool = false

var _score: int = 0
var _touches: int = 0
var _perfeitos: int = 0
var _combo: int = 0
var _best_combo: int = 0
var _drops: int = 0

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
var _art: Node2D = null
var _partner_left: AltinhaPartner = null
var _partner_right: AltinhaPartner = null
var _ball: AltinhaBall = null
var _cam: Camera2D = null
var _flash: ColorRect = null

var score_label: Label = null
var sub_label: Label = null
var status_label: Label = null
var result_label: Label = null
var help_label: Label = null

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
	_art = Art.new()
	_art.name = "Art"
	add_child(_art)
	move_child(_art, 0)
	_art.build(setting)
	_dress_backdrops()
	_build_player_visual()
	if _ball:
		_ball.contact_height = CONTACT_HEIGHT

	score_label = get_node_or_null("UI/ScoreLabel") as Label
	sub_label = get_node_or_null("UI/SubLabel") as Label
	status_label = get_node_or_null("UI/StatusLabel") as Label
	result_label = get_node_or_null("UI/ResultLabel") as Label
	help_label = get_node_or_null("UI/Help") as Label

	var hit_btn: Button = get_node_or_null("UI/HitButton") as Button
	if hit_btn:
		hit_btn.pressed.connect(_try_hit)
		# Sur le sable peint, la pastille translucide laissait voir le décor.
		var box: StyleBoxTexture = UITheme.pastille_box(UITheme.CREAM, Color(0.08, 0.09, 0.12, 0.82))
		hit_btn.add_theme_stylebox_override("normal", box)
		hit_btn.add_theme_stylebox_override("hover", box)

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
	_art.make_player(_player)

# Les dalles unies de la scène ne servent plus que de filet sous le décor
# peint (bords d'écran très larges) : on les accorde à ses couleurs.
func _dress_backdrops() -> void:
	var laje: bool = setting == "laje"
	var top: ColorRect = get_node_or_null("Sea") as ColorRect
	if top:
		top.color = Color(0.31, 0.56, 0.88)
	var ground: ColorRect = get_node_or_null("Sand") as ColorRect
	if ground:
		ground.color = Color(0.70, 0.67, 0.62) if laje else Color(0.95, 0.86, 0.58)
	var seam: ColorRect = get_node_or_null("Horizon") as ColorRect
	if seam:
		seam.visible = false

func _process(delta: float) -> void:
	if _ended:
		return
	_hit_lock = maxf(0.0, _hit_lock - delta)
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump"):
		_try_hit()
	_move_player(delta)
	_update_hot_timer(delta)
	_shake_process(delta)
	_update_visuals(delta)
	if _phase == Phase.TO_PLAYER or _phase == Phase.TO_PARTNER:
		var grounded_now: bool = _ball.advance(delta)
		if grounded_now:
			if _phase == Phase.TO_PLAYER:
				_register_drop("A bola caiu na laje..." if setting == "laje" else "A bola caiu na areia...")
			else:
				_on_partner_arrival()

func _move_player(delta: float) -> void:
	if _player == null:
		return
	var axis: float = _movement_axis()
	_player.position.x = clampf(_player.position.x + axis * PLAYER_SPEED * delta, PLAYER_MIN_X, PLAYER_MAX_X)

# Joystick commun (MinigameTouchControls injecte move_left/right), clavier et
# croix/stick de la manette passent par les mêmes actions.
func _movement_axis() -> float:
	var axis: float = Input.get_axis("move_left", "move_right")
	return axis if absf(axis) >= 0.05 else 0.0

# Visuel seulement : poses, regards, couleur du cercle de réception.
func _update_visuals(delta: float) -> void:
	if _art:
		_art.tick(delta)
		_art.update_player(delta, _movement_axis(), _ball.ground_pos().x if _ball else 0.0)
	if _ball == null:
		return
	var bx: float = _ball.ground_pos().x
	var to_other: bool = _phase == Phase.TO_PARTNER
	if _partner_left:
		_partner_left.look_toward(bx, to_other and _aimed_partner == 2)
	if _partner_right:
		_partner_right.look_toward(bx, to_other and _aimed_partner == 1)
	_ball.hint = AltinhaBall.HINT_NONE
	if _phase == Phase.TO_PLAYER and _player:
		var dist: float = Vector2(_player.position.x, PLAYER_Y - CONTACT_HEIGHT).distance_to(_ball.world_pos())
		if dist <= HIT_PERFECT_DIST:
			_ball.hint = AltinhaBall.HINT_PERFECT
		elif dist <= HIT_GOOD_DIST:
			_ball.hint = AltinhaBall.HINT_GOOD
		elif dist <= HIT_SOFT_DIST:
			_ball.hint = AltinhaBall.HINT_SOFT

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
	if _art:
		_art.player_kick(quality, target_which == 2)
	if _touches == 3 and help_label:
		var fade: Tween = create_tween()
		fade.tween_property(help_label, "modulate:a", 0.0, 0.6)
	sfx("mg_hit", 1.0 + 0.04 * float(mini(_combo, 10)))
	if quality == QUALITY_PERFECT:
		sfx("mg_perfect")
		pulse(0.4, 0.06)
		_start_shake(4.0, 0.12)
		_flash_screen()
	if touch_goal > 0 and _touches >= touch_goal:
		_update_labels()
		_end_game()
		return

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
	_float_label(_ball.target() + Vector2(0.0, -40.0), "Caiu!", Color(1.0, 0.45, 0.38), 22)
	_sand_puff(_ball.target())
	sfx("mg_drop")
	pulse(0.6, 0.15)
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
	var qualifies: bool = final_qualifies(_score >= QUALIFY_SCORE_THRESHOLD)
	if status_label:
		status_label.text = ""
	if result_label:
		result_label.visible = true
		var headline: String = "A praia respeita !" if qualifies else "A roda esfriou..."
		if touch_goal > 0:
			headline = "Desafio cumprido !" if _touches >= touch_goal else "Faltou pouco..."
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
		"goal_reached": touch_goal > 0 and _touches >= touch_goal,
	}
	EventBus.minigame_ended.emit("altinha", result)
	match_ended.emit(qualifies, _score)

# --- Feedback juteux ---

func _show_quality_label(quality: int, gain: int) -> void:
	var text: String
	var color: Color
	var size: int = 22
	var sparks: int = 0
	match quality:
		QUALITY_PERFECT:
			text = "PERFEITO! +%d" % gain
			color = Color(1.0, 0.84, 0.18)
			size = 33
			sparks = 14
		QUALITY_GOOD:
			text = "Boa! +%d" % gain
			color = Color(0.5, 0.95, 0.52)
			sparks = 8
		_:
			text = "Mole... +%d" % gain
			color = Color(0.86, 0.86, 0.84)
	var at: Vector2 = Vector2(_player.position.x if _player else 0.0, PLAYER_Y - 130.0)
	_float_label(at, text, color, size)
	_burst(Vector2(at.x, PLAYER_Y - CONTACT_HEIGHT), color, sparks)

# Étiquette qui éclate (pop d'échelle) puis s'envole, police pixel du thème.
func _float_label(pos: Vector2, text: String, color: Color, size: int) -> void:
	var label: Label = Label.new()
	label.text = text
	label.z_index = 20
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.05, 1.0))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(260.0, float(size) + 8.0)
	label.pivot_offset = label.size * 0.5
	add_child(label)
	label.position = pos - Vector2(130.0, label.size.y * 0.5)
	label.scale = Vector2(0.3, 0.3)
	var tw: Tween = create_tween()
	tw.tween_property(label, "scale", Vector2(1.25, 1.25), 0.09)
	tw.tween_property(label, "scale", Vector2.ONE, 0.07)
	tw.tween_property(label, "position:y", label.position.y - 30.0, 0.6)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.15)
	tw.tween_callback(label.queue_free)

# Étincelles pixel (carrés de 3 px monde) qui jaillissent du point de touche.
func _burst(pos: Vector2, color: Color, count: int) -> void:
	for i in count:
		var dot: ColorRect = ColorRect.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.size = Vector2(6.0, 6.0) if i % 3 == 0 else Vector2(3.0, 3.0)
		dot.color = color if i % 2 == 0 else Color(1.0, 1.0, 0.95)
		dot.z_index = 19
		dot.position = pos
		add_child(dot)
		var a: float = TAU * float(i) / float(count) + _rng.randf_range(-0.2, 0.2)
		var dist: float = _rng.randf_range(30.0, 58.0)
		var end: Vector2 = (pos + Vector2(cos(a), sin(a) * 0.7) * dist).snapped(Vector2(3.0, 3.0))
		var tw: Tween = create_tween()
		tw.tween_property(dot, "position", end, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(dot, "modulate:a", 0.0, 0.3).set_delay(0.12)
		tw.tween_callback(dot.queue_free)

# Gerbe de sable quand la balle tombe.
func _sand_puff(pos: Vector2) -> void:
	var sand: Color = Color(0.86, 0.74, 0.48) if setting != "laje" else Color(0.6, 0.57, 0.52)
	for i in 10:
		var dot: ColorRect = ColorRect.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.size = Vector2(3.0, 3.0) if i % 2 else Vector2(6.0, 3.0)
		dot.color = sand.darkened(0.1 * float(i % 3))
		dot.z_index = 4
		dot.position = pos
		add_child(dot)
		var dx: float = _rng.randf_range(-36.0, 36.0)
		var up: float = _rng.randf_range(12.0, 30.0)
		var tw: Tween = create_tween()
		tw.tween_property(dot, "position", (pos + Vector2(dx * 0.5, -up)).snapped(Vector2(3.0, 3.0)), 0.16)
		tw.tween_property(dot, "position", (pos + Vector2(dx, 3.0)).snapped(Vector2(3.0, 3.0)), 0.2)
		tw.parallel().tween_property(dot, "modulate:a", 0.0, 0.25).set_delay(0.1)
		tw.tween_callback(dot.queue_free)

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
		score_label.text = "%d pts" % _score
	if sub_label:
		sub_label.text = "Combo x%d   Quedas %d/%d" % [_combo, _drops, MAX_DROPS]
		if touch_goal > 0:
			sub_label.text = "Toques %d/%d   Quedas %d/%d" % [_touches, touch_goal, _drops, MAX_DROPS]
		# Le combo qui chauffe se voit : crème → or ; une chute en rouge.
		var col: Color = Color(1.0, 0.96, 0.86)
		if _combo >= 5:
			col = Color(1.0, 0.84, 0.3)
		if _drops >= MAX_DROPS - 1:
			col = Color(1.0, 0.6, 0.5)
		sub_label.add_theme_color_override("font_color", col)

# --- Clavier (bonus dev) ---

func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		return
	if not (event is InputEventKey and event.pressed):
		return
	if event.physical_keycode == KEY_Q:
		_end_game()
		get_viewport().set_input_as_handled()
