extends PanelContainer

# Panneau « Objectif » unique et persistant (haut-centre), sur UNE ligne :
#   🎯 le prochain pas (NavigationDirector)  ·  📍 destination / 🚕 quartier
# et, dessous, une barre fine de progression vers l'acte suivant (le titre
# d'acte complet est en infobulle ; le HUD le dit déjà en haut à gauche).
# Le cadre et la barre se teintent de la couleur de la voie scellée. Le texte
# fait un petit « punch » quand il change. Tap → rejoue le dernier toast jalon.

@onready var act_bar: ProgressBar = $Margin/VBox/ActBar
@onready var what_label: Label = $Margin/VBox/WhatLabel

var _panel_style: StyleBox = null
var _bar_fill: StyleBox = null
var _last_what: String = ""

func _ready() -> void:
	# Copies locales des styles pour pouvoir les recolorer sans toucher la ressource partagée.
	var ps: StyleBox = get_theme_stylebox("panel")
	if ps != null:
		_panel_style = ps.duplicate()
		add_theme_stylebox_override("panel", _panel_style)
	if act_bar:
		var fs: StyleBox = act_bar.get_theme_stylebox("fill")
		if fs != null:
			_bar_fill = fs.duplicate()
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
	# Teinte d'identité de la voie (cadre + barre).
	var voie: Color = NavigationDirector.voie_color()
	_tint(_panel_style, Color(voie.r, voie.g, voie.b, 1.0).lerp(Color.WHITE, 0.35))
	_tint(_bar_fill, voie)
	# Ligne unique QUOI · OÙ + punch au changement.
	if what_label:
		var p: String = _place_line()
		what_label.text = what if p == "" else "%s   ·   %s" % [what, p]
		if what != _last_what and _last_what != "":
			_punch()
	_last_what = what
	# Barre d'acte (titre en infobulle).
	var act: Dictionary = _act_state()
	tooltip_text = act.label
	if act_bar:
		var ratio: float = act.ratio
		act_bar.visible = ratio >= 0.0
		if ratio >= 0.0:
			act_bar.value = ratio

# Teinte un style (cadre 9-slice du thème ou aplat) sans toucher la ressource partagée.
func _tint(sb: StyleBox, color: Color) -> void:
	if sb is StyleBoxTexture:
		(sb as StyleBoxTexture).modulate_color = color
	elif sb is StyleBoxFlat:
		(sb as StyleBoxFlat).border_color = color

# État de la ligne d'acte : { label, ratio (-1 = pas de barre) }.
func _act_state() -> Dictionary:
	var act: int = CampaignManager.current_act
	if act >= 5 and CampaignManager.chosen_endgame != CampaignManager.Endgame.NONE:
		return {"label": "👑 Reinado · %s" % CampaignManager.reign_title(), "ratio": -1.0}
	if act == 4:
		return {"label": CampaignManager.act_title(4), "ratio": -1.0}
	var thr: int = 0
	match act:
		1: thr = CampaignManager.ACT1_THRESHOLD
		2: thr = CampaignManager.ACT2_THRESHOLD
		3: thr = CampaignManager.ACT3_THRESHOLD
	if thr > 0:
		var paid: int = clampi(CampaignManager.debt_paid, 0, thr)
		return {"label": "%s → Acte %d" % [CampaignManager.act_title(act), act + 1], "ratio": float(paid) / float(thr)}
	return {"label": CampaignManager.act_title(act), "ratio": -1.0}

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
