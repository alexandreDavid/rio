extends CanvasLayer

# Carte d'acte : à chaque bascule d'acte (2 → 5), un panneau plein écran dit le
# titre de l'acte, ce qui vient de se passer et ce qu'on attend du joueur
# (textes dans CampaignManager.ACT_CARDS — source unique avec le Diário, le HUD
# et l'app Saúde). Répond au retour « le scénario est confus » : la bascule
# d'acte était un toast de 1,2 s avec un titre portugais sans explication.
#
# Règles :
#   - ne joue que sur une VRAIE progression (pas au chargement d'une save, qui
#     ré-émet act_changed) ;
#   - attend la fin de tout dialogue / cinématique en cours (un paiement chez
#     Nilton peut faire basculer l'acte en plein dialogue) ;
#   - met le jeu en pause comme le Tutorial (process_mode ALWAYS sur la carte) ;
#   - jamais en headless (tests) — la carte y serait un panneau muet qui bloque.
# Les cinématiques d'entrée d'acte (Act3IntroCutscene) attendent `dismissed`
# via le groupe "act_card" pour ne pas parler par-dessous.

signal dismissed

const MIN_READ_TIME: float = 0.6
# Largeur max du panneau (desktop) ; sur téléphone : écran − 2 × MARGIN.
const MAX_WIDTH: float = 560.0
const MARGIN: float = 16.0

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var subtitle_label: Label = $Panel/Margin/VBox/Subtitle
@onready var body_label: Label = $Panel/Margin/VBox/Body
@onready var continue_btn: Button = $Panel/Margin/VBox/Continue

var _last_act: int = 1
var _showing: bool = false
var _queue: Array[int] = []

func _ready() -> void:
	add_to_group("act_card")
	_hide_all()
	_last_act = CampaignManager.current_act
	continue_btn.pressed.connect(_dismiss)
	EventBus.act_changed.connect(_on_act_changed)
	# Une save chargée ré-émet act_changed : on resynchronise sans afficher.
	if SaveSystem.has_signal("save_loaded"):
		SaveSystem.save_loaded.connect(_on_save_loaded)

func is_showing() -> bool:
	return _showing

func _on_save_loaded() -> void:
	_last_act = CampaignManager.current_act
	_queue.clear()

func _on_act_changed(new_act: int) -> void:
	if new_act <= _last_act:
		_last_act = new_act
		return
	_last_act = new_act
	if new_act < 2 or CampaignManager.act_card_body(new_act) == "":
		return
	if DisplayServer.get_name() == "headless":
		return
	_queue.append(new_act)
	if not _showing:
		_drain()

func _drain() -> void:
	while not _queue.is_empty():
		var act: int = _queue.pop_front()
		# Laisse finir le dialogue / la cinématique qui a provoqué la bascule.
		while DialogueBridge.is_active() or CutsceneRunner.is_running():
			await get_tree().process_frame
		await _show_act(act)

func _show_act(act: int) -> void:
	_showing = true
	title_label.text = CampaignManager.act_title(act)
	subtitle_label.text = CampaignManager.act_subtitle(act)
	body_label.text = CampaignManager.act_card_body(act)
	visible = true
	backdrop.visible = true
	panel.visible = true
	continue_btn.disabled = true
	get_tree().paused = true
	await _layout()
	# Petit délai anti-tap réflexe : la carte doit être lue, pas balayée.
	await get_tree().create_timer(MIN_READ_TIME, true).timeout
	continue_btn.disabled = false
	await dismissed

func _dismiss() -> void:
	if not _showing:
		return
	_showing = false
	get_tree().paused = false
	_hide_all()
	dismissed.emit()

# Panneau adaptatif : largeur bornée par l'écran, hauteur au contenu, centré.
# (Un panneau à offsets fixes débordait au format téléphone.)
func _layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var w: float = minf(MAX_WIDTH, vp.x - 2.0 * MARGIN)
	# 1. Largeur d'abord : le Label (autowrap) ne connaît sa hauteur qu'une fois
	#    sa largeur distribuée par le conteneur.
	panel.custom_minimum_size = Vector2(w, 0)
	panel.size = Vector2(w, 0)
	body_label.custom_minimum_size = Vector2(w - 2.0 * 26.0, 0)  # marges internes du style
	await get_tree().process_frame
	await get_tree().process_frame
	# 2. Hauteur au contenu, bornée à l'écran, puis centrage.
	var h: float = minf(panel.get_combined_minimum_size().y, vp.y - 2.0 * MARGIN)
	panel.size = Vector2(w, h)
	panel.position = ((vp - panel.size) / 2.0).floor()

func _hide_all() -> void:
	visible = false
	if backdrop:
		backdrop.visible = false
	if panel:
		panel.visible = false
