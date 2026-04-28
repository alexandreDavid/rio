extends CanvasLayer

# Overlay du tableau de missions. Affiche 3 cartes (une par catégorie) avec :
#   - intitulé / narration / récompense / progression
#   - bouton "Accepter" (ou "Acceptée" / "En cours" si déjà actif)
# Mise à jour live via les signaux du DynamicMissionManager.

@onready var panel: Control = $Root
@onready var voyou_card: Control = $Root/Panel/Margin/Layout/Cards/Voyou
@onready var police_card: Control = $Root/Panel/Margin/Layout/Cards/Police
@onready var maire_card: Control = $Root/Panel/Margin/Layout/Cards/Maire
@onready var close_button: Button = $Root/Panel/Margin/Layout/Footer/Close

func _ready() -> void:
	visible = false
	if close_button:
		close_button.pressed.connect(close)
	DynamicMissionManager.missions_changed.connect(_refresh)
	DynamicMissionManager.mission_progressed.connect(_on_progress)
	DynamicMissionManager.mission_completed.connect(_on_completed)
	# Câble les boutons "Accepter" de chaque carte.
	for cat in DynamicMissionManager.Category.values():
		var card: Control = _card_for(cat)
		if card == null:
			continue
		var btn: Button = card.get_node_or_null("Accept") as Button
		if btn:
			btn.pressed.connect(func(): _on_accept(cat))

func open() -> void:
	visible = true
	_refresh()
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

func _on_accept(cat: int) -> void:
	if DynamicMissionManager.accept(cat):
		_refresh()

func _on_progress(_cat: int, _progress: int, _total: int) -> void:
	_refresh()

func _on_completed(_cat: int, _money: int, _rep: int) -> void:
	_refresh()

func _refresh() -> void:
	for cat in DynamicMissionManager.Category.values():
		_refresh_card(cat)

func _refresh_card(cat: int) -> void:
	var card: Control = _card_for(cat)
	if card == null:
		return
	var m: Dictionary = DynamicMissionManager.get_mission(cat)
	var tier: int = DynamicMissionManager.get_tier(cat)
	var label_cat: String = DynamicMissionManager.CATEGORY_LABELS.get(cat, "?")
	var title: Label = card.get_node_or_null("Title") as Label
	var narrative: Label = card.get_node_or_null("Narrative") as Label
	var reward: Label = card.get_node_or_null("Reward") as Label
	var progress: Label = card.get_node_or_null("Progress") as Label
	var btn: Button = card.get_node_or_null("Accept") as Button
	if title:
		title.text = "%s · niveau %d" % [label_cat, tier + 1]
	if not m.is_empty():
		if narrative:
			narrative.text = "%s\n— %s" % [m.title, m.narrative]
		if reward:
			reward.text = "+ R$ %d  ·  +%d %s" % [int(m.money), int(m.rep), label_cat.to_upper()]
		if progress:
			if m.get("accepted", false):
				progress.text = "Progression : %d / %d" % [int(m.get("progress", 0)), (m.points as Array).size()]
				progress.visible = true
			else:
				progress.visible = false
		if btn:
			if m.get("accepted", false):
				btn.text = "En cours…"
				btn.disabled = true
			else:
				btn.text = "Accepter"
				btn.disabled = false
	else:
		if narrative:
			narrative.text = "Aucune mission disponible"
		if btn:
			btn.disabled = true

func _card_for(cat: int) -> Control:
	match cat:
		DynamicMissionManager.Category.VOYOU:
			return voyou_card
		DynamicMissionManager.Category.POLICE:
			return police_card
		DynamicMissionManager.Category.MAIRE:
			return maire_card
	return null
