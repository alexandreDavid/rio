class_name FishingGame
extends MinigameBase

# Pesca da Colônia — vraie pêche en 3 temps, au standard volley/surf :
#   1. LANCER : jauge oscillante, 3 bandes d'eau (perto/meio/fundo) — plus
#      loin = meilleur poisson, mais ferrage plus court et combat plus dur.
#   2. LA TOUCHE : le bouchon frémit (leurres) puis PLONGE — ferrer dans la
#      fenêtre. Ferrer sur un frémissement fait fuir le poisson ; réflexe
#      éclair = Perfeito (valeur ×1.5).
#   3. LE COMBAT : tenir pour mouliner (la tension monte), lâcher pendant
#      les puxadas annoncées — tension pleine = ligne cassée.
# Session : 6 lancers ou 120 s. Contrat conservé : match_ended(won, payout)
# (le launcher paie et coche bruno_pesca_baia si payout > 0) ;
# minigame_ended("fishing", {catches, payout, qualifies, won}).

signal match_ended(won: bool, payout: int)

const SESSION_SEC: float = 120.0
const MAX_CASTS: int = 6
const QUALIFY_SCORE: int = 45
const PERFEITO_WINDOW: float = 0.18

# Bandes d'eau : espèce dominante, fenêtre de ferrage, combat.
const BANDS: Array = [
	{"name": "perto", "label": "PERTO", "y": 40.0,
		"species": "Tainha", "value": 10, "strike_window": 0.55,
		"pull_every": [2.2, 3.2], "pull_len": 0.7, "reel": 26.0,
		"tension_hold": 16.0, "tension_pull": 55.0},
	{"name": "meio", "label": "MEIO", "y": -30.0,
		"species": "Xerelete", "value": 18, "strike_window": 0.42,
		"pull_every": [1.6, 2.6], "pull_len": 0.9, "reel": 22.0,
		"tension_hold": 20.0, "tension_pull": 70.0},
	{"name": "fundo", "label": "FUNDO", "y": -95.0,
		"species": "Robalo", "value": 30, "strike_window": 0.32,
		"pull_every": [1.2, 2.0], "pull_len": 1.1, "reel": 19.0,
		"tension_hold": 24.0, "tension_pull": 88.0},
]

const CAST_SPEED: float = 1.1          # cycles de jauge par seconde
const TENSION_DECAY: float = 34.0      # relâché : la ligne respire
const PROGRESS_DECAY: float = 6.0      # relâché : le poisson reprend du fil

enum Phase { CAST, WAIT, FIGHT, PAUSE, ENDED }

@onready var status_label: Label = $UI/Status
@onready var score_label: Label = $UI/Score
@onready var timing_bar: Panel = $UI/TimingBar
@onready var cursor: ColorRect = $UI/TimingBar/Cursor
@onready var target_zone: ColorRect = $UI/TimingBar/TargetZone
@onready var action_btn: Button = $UI/ActionButton

var _phase: int = Phase.CAST
var _time_left: float = SESSION_SEC
var _casts: int = 0
var _catches: int = 0
var _score: int = 0
var _ended: bool = false
var _holding: bool = false

# Lancer
var _cursor_pos: float = 0.0
# Touche
var _band: Dictionary = {}
var _nibbles_left: int = 0
var _event_timer: float = 0.0
var _strike_active: bool = false
var _strike_elapsed: float = 0.0
# Combat
var _tension: float = 0.0
var _progress: float = 0.0
var _pull_active: bool = false
var _pull_timer: float = 0.0
var _perfeito: bool = false

var _bobber: ColorRect = null
var _tension_bar: ProgressBar = null
var _progress_bar: ProgressBar = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	EventBus.minigame_started.emit("fishing")
	_rng.randomize()
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	if action_btn:
		action_btn.button_down.connect(_on_press)
		action_btn.button_up.connect(_on_release)
	_build_cast_bands()
	_build_fight_bars()
	_build_bobber()
	_dress_pier()
	_update_score()
	_enter_cast()

# --- UI construite en code (bandes de lancer, barres de combat, bouchon) ---

func _build_cast_bands() -> void:
	if timing_bar == null:
		return
	if target_zone:
		target_zone.visible = false
	var colors: Array = [Color(0.55, 0.8, 0.55, 0.4), Color(0.95, 0.85, 0.4, 0.4), Color(0.9, 0.5, 0.35, 0.4)]
	for i in BANDS.size():
		var band_rect: ColorRect = ColorRect.new()
		band_rect.name = "Band%d" % i
		band_rect.offset_top = 4.0
		band_rect.offset_bottom = 46.0
		band_rect.color = colors[i]
		band_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		timing_bar.add_child(band_rect)
		var lbl: Label = Label.new()
		lbl.text = "%s · %s" % [BANDS[i].label, BANDS[i].species]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.offset_top = 6.0
		lbl.offset_left = 4.0
		band_rect.add_child(lbl)
	_layout_cast_bands()

func _layout_cast_bands() -> void:
	var w: float = timing_bar.size.x
	for i in BANDS.size():
		var band_rect: ColorRect = timing_bar.get_node_or_null("Band%d" % i)
		if band_rect:
			band_rect.offset_left = w * (float(i) / BANDS.size())
			band_rect.offset_right = w * (float(i + 1) / BANDS.size())

func _build_fight_bars() -> void:
	_progress_bar = ProgressBar.new()
	_progress_bar.name = "ProgressBar"
	_progress_bar.max_value = 100.0
	_progress_bar.show_percentage = false
	_progress_bar.anchor_left = 0.5
	_progress_bar.anchor_right = 0.5
	_progress_bar.offset_left = -240.0
	_progress_bar.offset_right = 240.0
	_progress_bar.offset_top = 110.0
	_progress_bar.offset_bottom = 132.0
	_progress_bar.modulate = Color(0.55, 0.9, 0.55, 1)
	_progress_bar.visible = false
	$UI.add_child(_progress_bar)
	_tension_bar = ProgressBar.new()
	_tension_bar.name = "TensionBar"
	_tension_bar.max_value = 100.0
	_tension_bar.show_percentage = false
	_tension_bar.anchor_left = 0.5
	_tension_bar.anchor_right = 0.5
	_tension_bar.offset_left = -240.0
	_tension_bar.offset_right = 240.0
	_tension_bar.offset_top = 140.0
	_tension_bar.offset_bottom = 162.0
	_tension_bar.modulate = Color(0.95, 0.45, 0.4, 1)
	_tension_bar.visible = false
	$UI.add_child(_tension_bar)

# Le décor : ciel et morros de Niterói à l'horizon, mer, quai de la Colônia
# en bas, et le pêcheur (le joueur) avec sa canne — la ligne suit le bouchon.
const ROD_TIP: Vector2 = Vector2(-20, -150)
var _fishing_line: Line2D = null

func _dress_pier() -> void:
	var bg: CanvasItem = get_node_or_null("Background") as CanvasItem
	if bg:
		bg.z_index = -10
	for n in ["RodShaft", "Line", "Hook"]:
		var old: CanvasItem = get_node_or_null(n) as CanvasItem
		if old:
			old.visible = false
	_deco(Rect2(-960, -540, 1920, 380), Color(0.98, 0.78, 0.55, 1), -9)
	_deco(Rect2(-960, -300, 1920, 140), Color(0.95, 0.68, 0.5, 1), -9)
	var morro: Polygon2D = Polygon2D.new()
	morro.polygon = PackedVector2Array([Vector2(-960, -160), Vector2(-760, -230), Vector2(-620, -300), Vector2(-540, -250), Vector2(-380, -200), Vector2(-120, -175), Vector2(260, -190), Vector2(420, -245), Vector2(500, -215), Vector2(960, -170), Vector2(960, -160)])
	morro.color = Color(0.36, 0.42, 0.5, 1)
	morro.z_index = -8
	add_child(morro)
	_deco(Rect2(-960, -162, 1920, 4), Color(0.92, 0.95, 0.98, 0.7), -7)
	# Quai en planches.
	_deco(Rect2(-960, 150, 1920, 390), Color(0.5, 0.36, 0.24, 1), -3)
	for i in 10:
		_deco(Rect2(-960, 150 + i * 40, 1920, 3), Color(0.38, 0.27, 0.18, 1), -2)
	_deco(Rect2(-960, 146, 1920, 8), Color(0.62, 0.47, 0.32, 1), -2)
	var fisher: Sprite2D = char_sprite(260.0)
	fisher.position = Vector2(-260, 420)
	fisher.z_index = -1
	add_child(fisher)
	var rod: Line2D = Line2D.new()
	rod.points = PackedVector2Array([Vector2(-235, 300), ROD_TIP])
	rod.width = 6.0
	rod.default_color = Color(0.4, 0.25, 0.14, 1)
	add_child(rod)
	_fishing_line = Line2D.new()
	_fishing_line.width = 2.0
	_fishing_line.default_color = Color(0.95, 0.95, 0.95, 0.8)
	add_child(_fishing_line)

func _deco(r: Rect2, color: Color, z: int) -> void:
	var c: ColorRect = ColorRect.new()
	c.position = r.position
	c.size = r.size
	c.color = color
	c.z_index = z
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)

func _update_line() -> void:
	if _fishing_line == null or _bobber == null:
		return
	var end: Vector2 = _bobber.position + Vector2(7, 7) if _bobber.visible or _phase == Phase.FIGHT \
			else ROD_TIP + Vector2(0, 120)
	_fishing_line.points = PackedVector2Array([ROD_TIP, end])

func _build_bobber() -> void:
	_bobber = ColorRect.new()
	_bobber.name = "Bobber"
	_bobber.size = Vector2(14, 14)
	_bobber.color = Color(0.95, 0.3, 0.25, 1)
	_bobber.visible = false
	add_child(_bobber)

# --- Machine à états ---

func _enter_cast() -> void:
	if _casts >= MAX_CASTS or _time_left <= 0.0:
		_end_game()
		return
	_phase = Phase.CAST
	_cursor_pos = 0.0
	_bobber.visible = false
	_progress_bar.visible = false
	_tension_bar.visible = false
	timing_bar.visible = true
	cursor.visible = true
	_layout_cast_bands()
	_set_action_text("🎣 LANCER")
	_set_status("Lance ta ligne — loin, le Robalo ; près, la Tainha (lancer %d/%d)"
			% [_casts + 1, MAX_CASTS])

func _enter_wait(band_index: int) -> void:
	_phase = Phase.WAIT
	_band = BANDS[band_index]
	_casts += 1
	timing_bar.visible = false
	cursor.visible = false
	_bobber.visible = true
	_bobber.position = Vector2(_rng.randf_range(-80.0, 220.0), float(_band.y))
	_nibbles_left = _rng.randi_range(1, 3)
	_event_timer = _rng.randf_range(1.0, 2.0)
	_strike_active = false
	_set_action_text("🫳 …ATTENDRE")
	_set_status("Le bouchon flotte (%s)… ferre à la VRAIE touche, pas aux frémissements."
			% String(_band.label).to_lower())

func _enter_fight() -> void:
	_phase = Phase.FIGHT
	_tension = 0.0
	_progress = 20.0 if _perfeito else 8.0
	_pull_active = false
	_pull_timer = _rng.randf_range(float(_band.pull_every[0]), float(_band.pull_every[1]))
	_progress_bar.visible = true
	_tension_bar.visible = true
	_set_action_text("🎣 MOULINER (tenir)")
	_set_status("%s ferré%s ! Tiens pour mouliner — LÂCHE pendant les puxadas !"
			% [_band.species, " PERFEITO" if _perfeito else ""])

func _enter_pause(text: String) -> void:
	_phase = Phase.PAUSE
	_bobber.visible = false
	_progress_bar.visible = false
	_tension_bar.visible = false
	_set_status(text)
	_update_score()
	await get_tree().create_timer(1.3).timeout
	if not _ended:
		_enter_cast()

# --- Boucle ---

func _process(delta: float) -> void:
	if _ended:
		return
	_update_line()
	_time_left -= delta
	if _time_left <= 0.0 and _phase != Phase.FIGHT:
		_end_game()
		return
	# Clavier : E tient/relâche comme le bouton tactile.
	if Input.is_action_just_pressed("interact"):
		_on_press()
	elif Input.is_action_just_released("interact"):
		_on_release()
	match _phase:
		Phase.CAST:
			_cursor_pos += CAST_SPEED * delta
			if _cursor_pos > 1.0:
				_cursor_pos -= 1.0
			var w: float = timing_bar.size.x
			cursor.position.x = w * _cursor_pos - cursor.size.x * 0.5
		Phase.WAIT:
			_tick_wait(delta)
		Phase.FIGHT:
			_tick_fight(delta)
	_update_score()

func _tick_wait(delta: float) -> void:
	if _strike_active:
		_strike_elapsed += delta
		_bobber.position.y = float(_band.y) + 16.0 + sin(_strike_elapsed * 40.0) * 3.0
		if _strike_elapsed > float(_band.strike_window):
			_strike_active = false
			_enter_pause("Trop lent — le %s a recraché l'hameçon. A tainha passa quando quer…"
					% _band.species)
		return
	_event_timer -= delta
	# Flottement de base.
	_bobber.position.y = float(_band.y) + sin(Time.get_ticks_msec() / 300.0) * 2.0
	if _event_timer <= 0.0:
		if _nibbles_left > 0:
			_nibbles_left -= 1
			_event_timer = _rng.randf_range(0.8, 1.8)
			_set_status("…le bouchon frémit. Pas encore. Segura a onda.")
			sfx("fish_bite", 0.7)
			pulse(0.15, 0.04)
			_bobber.position.y = float(_band.y) + 6.0
		else:
			_strike_active = true
			_strike_elapsed = 0.0
			_set_status("‼ FISGA AGORA !")
			sfx("fish_bite", 1.2)
			pulse(0.8, 0.15)
			_set_action_text("⚡ FERRER !")

func _tick_fight(delta: float) -> void:
	_pull_timer -= delta
	if _pull_timer <= 0.0:
		_pull_active = not _pull_active
		if _pull_active:
			_pull_timer = float(_band.pull_len)
			_set_status("⚠ PUXADA — lâche, laisse-le tirer !")
			pulse(0.6, 0.25)
		else:
			_pull_timer = _rng.randf_range(float(_band.pull_every[0]), float(_band.pull_every[1]))
			_set_status("Il fatigue — mouline !")
	var reeling: bool = _holding or Input.is_action_pressed("interact")
	if reeling:
		_progress += float(_band.reel) * delta
		_tension += (float(_band.tension_pull) if _pull_active else float(_band.tension_hold)) * delta
	else:
		_tension = maxf(0.0, _tension - TENSION_DECAY * delta)
		_progress = maxf(0.0, _progress - PROGRESS_DECAY * delta)
	_bobber.position.x += (-30.0 * delta) if reeling else (12.0 * delta)
	_progress_bar.value = _progress
	_tension_bar.value = _tension
	if _tension >= 100.0:
		sfx("mg_miss")
		pulse(0.8, 0.2)
		_enter_pause("💥 LIGNE CASSÉE ! Le %s repart avec ton hameçon." % _band.species)
	elif _progress >= 100.0:
		var value: int = int(round(float(_band.value) * (1.5 if _perfeito else 1.0)))
		_catches += 1
		_score += value
		sfx("splash")
		sfx("mg_perfect" if _perfeito else "mg_good")
		_enter_pause("🐟 %s au sec%s — +%d pts !"
				% [_band.species, " (ferrage Perfeito ×1.5)" if _perfeito else "", value])

# --- Entrées ---

func _on_press() -> void:
	if _ended:
		return
	_holding = true
	match _phase:
		Phase.CAST:
			var idx: int = clampi(int(_cursor_pos * BANDS.size()), 0, BANDS.size() - 1)
			sfx("splash", 1.4)
			_enter_wait(idx)
		Phase.WAIT:
			if _strike_active:
				_perfeito = _strike_elapsed <= PERFEITO_WINDOW
				_strike_active = false
				_enter_fight()
			else:
				sfx("mg_miss")
				_enter_pause("Ferré dans le vide — le banc s'est enfui. Calma, pescador…")

func _on_release() -> void:
	_holding = false

func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q:
			_end_game()
			get_viewport().set_input_as_handled()

# --- Fin ---

func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text

func _set_action_text(text: String) -> void:
	if action_btn:
		action_btn.text = text

func _update_score() -> void:
	if score_label:
		score_label.text = "%d prises · %d pts · %ds" % [_catches, _score, int(maxf(_time_left, 0.0))]

func _end_game() -> void:
	if _ended:
		return
	_ended = true
	_phase = Phase.ENDED
	var payout: int = _score
	var qualifies: bool = final_qualifies(_score >= QUALIFY_SCORE)
	if status_label:
		if qualifies:
			status_label.text = "Fin — %d prises, %d pts. La colônia te respecte, pescador. (+R$ %d)" \
					% [_catches, _score, payout]
		elif _catches > 0:
			status_label.text = "Fin — %d prises, %d pts (+R$ %d). Le Robalo t'attend au fundo." \
					% [_catches, _score, payout]
		else:
			status_label.text = "Bredouille. La mer ne doit rien à personne — reviens à la marée."
	await get_tree().create_timer(2.0).timeout
	EventBus.minigame_ended.emit("fishing",
		{"catches": _catches, "payout": payout, "score": _score,
			"qualifies": qualifies, "won": _catches > 0})
	match_ended.emit(_catches > 0, payout)
