extends PanelContainer

# Panneau « Objectif » unique et persistant (haut-centre). Consolide ce qui était
# auparavant éclaté entre le bandeau d'objectif et le Quest Tracker :
#   - Ligne ACTE  : où j'en suis dans la trame + barre de progression vers l'acte suivant.
#   - Ligne QUOI  : le prochain pas, calculé par NavigationDirector.
#   - Ligne OÙ    : destination + mode (📍 lieu / 🚕 quartier).
# Le bord et la barre se teintent de la couleur de la voie scellée. Le QUOI fait
# un petit « punch » quand il change. Tap → rejoue le dernier toast jalon.

@onready var act_line: Label = $Margin/VBox/ActLine
@onready var act_bar: ProgressBar = $Margin/VBox/ActBar
@onready var what_label: Label = $Margin/VBox/WhatLabel
@onready var place_line: Label = $Margin/VBox/PlaceLine

var _panel_style: StyleBoxFlat = null
var _bar_fill: StyleBoxFlat = null
var _last_what: String = ""

func _ready() -> void:
	# Copies locales des styles pour pouvoir les recolorer sans toucher la ressource partagée.
	var ps: StyleBox = get_theme_stylebox("panel")
	if ps is StyleBoxFlat:
		_panel_style = (ps as StyleBoxFlat).duplicate()
		add_theme_stylebox_override("panel", _panel_style)
	if act_bar:
		var fs: StyleBox = act_bar.get_theme_stylebox("fill")
		if fs is StyleBoxFlat:
			_bar_fill = (fs as StyleBoxFlat).duplicate()
			act_bar.add_theme_stylebox_override("fill", _bar_fill)
	NavigationDirector.nav_target_changed.connect(_refresh)
	gui_input.connect(_on_gui_input)
	_refresh()

func _refresh() -> void:
	var what: String = NavigationDirector.current_text()
	visible = what != ""
	if not visible:
		_last_what = ""
		return
	# Teinte d'identité de la voie (bord + barre).
	var voie: Color = NavigationDirector.voie_color()
	if _panel_style:
		_panel_style.border_color = Color(voie.r, voie.g, voie.b, 0.7)
	if _bar_fill:
		_bar_fill.bg_color = voie
	# Ligne QUOI + punch au changement.
	if what_label:
		what_label.text = what
		if what != _last_what and _last_what != "":
			_punch()
	_last_what = what
	# Ligne ACTE + barre.
	var act: Dictionary = _act_state()
	if act_line:
		act_line.text = act.label
		act_line.visible = act.label != ""
	if act_bar:
		var ratio: float = act.ratio
		act_bar.visible = ratio >= 0.0
		if ratio >= 0.0:
			act_bar.value = ratio
	# Ligne OÙ.
	if place_line:
		var p: String = _place_line()
		place_line.text = p
		place_line.visible = p != ""

# État de la ligne d'acte : { label, ratio (-1 = pas de barre) }.
func _act_state() -> Dictionary:
	var act: int = CampaignManager.current_act
	if act >= 5 and CampaignManager.chosen_endgame != CampaignManager.Endgame.NONE:
		return {"label": "👑 Reinado · %s" % CampaignManager.reign_title(), "ratio": -1.0}
	if act == 4:
		return {"label": "Acte 4 · Os Grandes Lances", "ratio": -1.0}
	var thr: int = 0
	match act:
		1: thr = CampaignManager.ACT1_THRESHOLD
		2: thr = CampaignManager.ACT2_THRESHOLD
		3: thr = CampaignManager.ACT3_THRESHOLD
	if thr > 0:
		var paid: int = clampi(CampaignManager.debt_paid, 0, thr)
		return {"label": "Acte %d → Acte %d" % [act, act + 1], "ratio": float(paid) / float(thr)}
	return {"label": "Acte %d" % act, "ratio": -1.0}

# Ligne OÙ : libellé + pictogramme selon le mode de cible.
func _place_line() -> String:
	var live: Dictionary = NavigationDirector.get_live()
	var label: String = live.get("label", "")
	if label == "":
		return ""
	var kind: int = live.get("kind", NavigationDirector.Kind.NONE)
	if kind == NavigationDirector.Kind.TRAVEL:
		return "🚕 → %s" % label
	if kind == NavigationDirector.Kind.POINT:
		return "📍 %s" % label
	return ""

func _punch() -> void:
	pivot_offset = size / 2.0
	scale = Vector2(0.94, 0.94)
	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.22)

func _on_gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
	if not tapped:
		return
	var hud: Node = get_node_or_null("../HUD")
	if hud and hud.has_method("replay_last_milestone") and hud.replay_last_milestone():
		return
	var journal: Node = get_tree().current_scene.get_node_or_null("JournalUI")
	if journal and journal.has_method("toggle"):
		journal.toggle()
