class_name ExerciseGame
extends Node2D

# Treino da academia — la forme avant la force, au standard volley/surf.
# Fini le mash : chaque rep est un appui-relâché. TENIR fait monter la barre
# (vitesse propre à la série), RELÂCHER dans la zone de forme = rep — au
# centre de la zone : Perfeito (3 pts), sinon Boa (1 pt). Relâcher hors zone
# ou laisser la barre taper le plafond = Falha (la forme casse). Le gás est
# la vraie limite : chaque rep en consomme (une Falha en brûle le double) —
# à sec, la séance s'arrête. 3 séries : Supino, Agachamento, Remada — de
# plus en plus rapides, zones de plus en plus étroites.
# Contrat conservé : match_ended(qualifies, reps) (le launcher crédite
# CHARISMA, source "gym") ; minigame_ended("exercise", {reps, qualifies, won}).

signal match_ended(won: bool, reps: int)

const SETS: Array = [
	{"name": "Supino", "icon": "🏋", "rise": 55.0, "zone_w": 18.0},
	{"name": "Agachamento", "icon": "🦵", "rise": 75.0, "zone_w": 14.0},
	{"name": "Remada", "icon": "🚣", "rise": 95.0, "zone_w": 11.0},
]
const REPS_PER_SET: int = 5
const QUALIFY_SCORE: int = 24          # max 45 (15 reps × 3)
const GAS_MAX: float = 100.0
const GAS_PERFEITO: float = 4.0
const GAS_BOA: float = 7.0
const GAS_FALHA: float = 12.0
const BAR_FALL: float = 220.0          # relâché : la charge redescend vite

@onready var bar: ProgressBar = $UI/Bar
@onready var rep_label: Label = $UI/RepLabel
@onready var gas_label: Label = $UI/TimerLabel
@onready var status_label: Label = $UI/Status
@onready var action_btn: Button = $UI/ActionButton
@onready var barbell: ColorRect = $Barbell

var _set_index: int = 0
var _rep_in_set: int = 0
var _reps: int = 0
var _score: int = 0
var _gas: float = GAS_MAX
var _value: float = 0.0
var _holding: bool = false
var _zone_center: float = 0.0
var _zone_overlay: ColorRect = null
var _barbell_base_y: float = 0.0
var _ended: bool = false
var _resting: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	EventBus.minigame_started.emit("exercise")
	_rng.randomize()
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	if action_btn:
		action_btn.button_down.connect(_on_press)
		action_btn.button_up.connect(_on_release)
		action_btn.text = "💪 TENIR / LÂCHER"
	var quit_btn: CanvasLayer = get_node_or_null("MinigameQuitButton")
	if quit_btn and quit_btn.has_signal("quit_pressed"):
		quit_btn.quit_pressed.connect(_end_game)
	if barbell:
		_barbell_base_y = barbell.position.y
	_build_zone_overlay()
	_next_rep()
	_set_status("La forme avant la force : TIENS pour soulever, LÂCHE dans la zone verte.")

# Zone de forme dessinée par-dessus la ProgressBar (position en % de barre).
func _build_zone_overlay() -> void:
	_zone_overlay = ColorRect.new()
	_zone_overlay.name = "FormZone"
	_zone_overlay.color = Color(0.3, 0.85, 0.4, 0.55)
	_zone_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_zone_overlay)

func _layout_zone() -> void:
	var zone_w: float = float(SETS[_set_index].zone_w)
	var left_pct: float = (_zone_center - zone_w * 0.5) / 100.0
	var right_pct: float = (_zone_center + zone_w * 0.5) / 100.0
	_zone_overlay.offset_left = bar.size.x * left_pct
	_zone_overlay.offset_right = bar.size.x * right_pct
	_zone_overlay.offset_top = 0.0
	_zone_overlay.offset_bottom = bar.size.y

func _next_rep() -> void:
	_value = 0.0
	_zone_center = _rng.randf_range(58.0, 86.0)
	_layout_zone()
	_refresh_labels()

func _refresh_labels() -> void:
	var s: Dictionary = SETS[_set_index]
	if rep_label:
		rep_label.text = "%s %s — série %d/3 · rep %d/%d · %d pts" \
				% [s.icon, s.name, _set_index + 1, _rep_in_set + 1, REPS_PER_SET, _score]
	if gas_label:
		gas_label.text = "Gás : %d" % int(_gas)
		gas_label.add_theme_color_override("font_color",
			Color(0.95, 0.45, 0.4, 1) if _gas <= 25.0 else Color(0.9, 0.9, 0.85, 1))

func _process(delta: float) -> void:
	if _ended or _resting:
		return
	if Input.is_action_just_pressed("interact"):
		_on_press()
	elif Input.is_action_just_released("interact"):
		_on_release()
	var holding: bool = _holding or Input.is_action_pressed("interact")
	if holding:
		_value += float(SETS[_set_index].rise) * delta
		if _value >= 100.0:
			_holding = false
			_resolve_rep(-1.0)  # plafond : la charge t'écrase — Falha
	else:
		_value = maxf(0.0, _value - BAR_FALL * delta)
	if bar:
		bar.value = _value
	if barbell:
		barbell.position.y = _barbell_base_y - _value * 1.2

func _on_press() -> void:
	if _ended or _resting:
		return
	_holding = true

func _on_release() -> void:
	if _ended or _resting or not _holding:
		_holding = false
		return
	_holding = false
	_resolve_rep(_value)

# value < 0 = plafond touché. Sinon : dans la zone → Perfeito/Boa, dehors → Falha.
func _resolve_rep(value: float) -> void:
	var s: Dictionary = SETS[_set_index]
	var zone_w: float = float(s.zone_w)
	if value < 0.0:
		_gas -= GAS_FALHA
		_set_status("💢 Trop lourd — la charge t'écrase ! Contrôle, pas la force.")
	elif absf(value - _zone_center) <= zone_w * 0.5:
		if absf(value - _zone_center) <= zone_w * 0.2:
			_reps += 1
			_score += 3
			_gas -= GAS_PERFEITO
			_set_status("✨ PERFEITO — forme impeccable, o professor aprova !")
		else:
			_reps += 1
			_score += 1
			_gas -= GAS_BOA
			_set_status("✔ Boa — ça compte, mas capricha na forma.")
		_rep_in_set += 1
	else:
		_gas -= GAS_FALHA
		_set_status("✖ Falha — lâché hors de la zone. Respira, recommence.")
	if _gas <= 0.0:
		_set_status("😮‍💨 Sem gás ! La séance s'arrête là — hydrate-toi, guerreiro.")
		_end_game()
		return
	if _rep_in_set >= REPS_PER_SET:
		_set_index += 1
		_rep_in_set = 0
		if _set_index >= SETS.size():
			_end_game()
			return
		_rest_between_sets()
		return
	_next_rep()

func _rest_between_sets() -> void:
	_resting = true
	_value = 0.0
	if bar:
		bar.value = 0.0
	var s: Dictionary = SETS[_set_index]
	_set_status("💧 Pause água… Série suivante : %s %s — plus rapide, zone plus étroite."
			% [s.icon, s.name])
	await get_tree().create_timer(1.6).timeout
	if _ended:
		return
	_resting = false
	_next_rep()

func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q:
			_end_game()
			get_viewport().set_input_as_handled()

func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text

func _end_game() -> void:
	if _ended:
		return
	_ended = true
	var qualifies: bool = _score >= QUALIFY_SCORE
	if status_label:
		if qualifies:
			status_label.text = "Fin — %d reps, %d pts. Monstro ! (+1 Charisma)" % [_reps, _score]
		else:
			status_label.text = "Fin — %d reps, %d pts (min. %d pts pour +Charisma). A forma vem com o tempo." \
					% [_reps, _score, QUALIFY_SCORE]
	await get_tree().create_timer(1.8).timeout
	EventBus.minigame_ended.emit("exercise",
		{"reps": _reps, "score": _score, "qualifies": qualifies, "won": qualifies})
	match_ended.emit(qualifies, _reps)
