extends Control

# Écran d'ouverture style « Mario » : 3 slots toujours visibles + bouton reset
# par slot. Le narratif d'ouverture (« Ce matin, tu te réveilles... ») ne vit
# plus ici — il est joué EN JEU par MainBoot avec le décor en fond.
# Tap slot → charge la save si présente, sinon démarre une nouvelle partie.
# Tap reset → confirmation au 2ᵉ tap (état stocké dans `_reset_pending`).

const MAIN_SCENE: String = "res://scenes/main/Main.tscn"

@onready var slot_buttons: Array[Button] = [$Layout/Slot1Row/Slot1, $Layout/Slot2Row/Slot2, $Layout/Slot3Row/Slot3]
@onready var reset_buttons: Array[Button] = [$Layout/Slot1Row/Slot1Reset, $Layout/Slot2Row/Slot2Reset, $Layout/Slot3Row/Slot3Reset]
@onready var reset_hint: Label = $Layout/ResetHint

var _reset_pending: int = 0  # 1..3 = slot en attente de confirmation, 0 = aucun

func _ready() -> void:
	UITheme.apply(get_tree().root)
	for i in 3:
		var slot: int = i + 1
		slot_buttons[i].pressed.connect(_on_slot_pressed.bind(slot))
		reset_buttons[i].pressed.connect(_on_reset_pressed.bind(slot))
	_refresh()

func _refresh() -> void:
	for i in 3:
		var slot: int = i + 1
		var info: Dictionary = SaveSystem.slot_info(slot)
		var current: bool = slot == Settings.current_slot
		var prefix: String = "📍 " if current else "  "
		var text: String
		if info.is_empty():
			text = "%sSlot %d  ·  ✨ Nouvelle partie" % [prefix, slot]
		else:
			var act: int = int(info.get("act", 1))
			var day: int = int(info.get("day", 1))
			var debt: int = int(info.get("debt_paid", 0))
			var endgame: int = int(info.get("endgame", 0))
			var path_str: String = ""
			if voie_label(endgame) != "":
				path_str = "  ·  " + voie_label(endgame)
			text = "%sSlot %d  ·  Jour %d  ·  Acte %d%s  ·  R$ %d payés" % [
					prefix, slot, day, act, path_str, debt]
		slot_buttons[i].text = text
		reset_buttons[i].disabled = info.is_empty()
		# Icône reset : 🗑 par défaut, ⚠ Confirmer si en attente.
		if _reset_pending == slot:
			reset_buttons[i].text = "⚠"
			reset_buttons[i].modulate = Color(1, 0.7, 0.7)
		else:
			reset_buttons[i].text = "🗑"
			reset_buttons[i].modulate = Color(1, 1, 1)
	reset_hint.visible = _reset_pending != 0

# Indexé par l'enum Endgame (NONE, PREFEITO, POLICIA, TRAFICO, CONSORTIUM) —
# l'ancien tableau positionnel décalait toutes les voies d'un cran.
static func voie_label(endgame: int) -> String:
	match endgame:
		CampaignManager.Endgame.PREFEITO: return "Prefeito"
		CampaignManager.Endgame.POLICIA: return "Polícia"
		CampaignManager.Endgame.TRAFICO: return "Tráfico"
		CampaignManager.Endgame.CONSORTIUM: return "Consórcio"
	return ""

func _on_slot_pressed(slot: int) -> void:
	# Tap sur un slot annule un éventuel reset en cours sur un autre.
	_reset_pending = 0
	Settings.set_current_slot(slot)
	if not SaveSystem.has_save_at(slot):
		# Slot vide → nouvelle partie propre (pas de save à charger).
		SaveSystem.discard_save()
	get_tree().change_scene_to_file(MAIN_SCENE)

func _on_reset_pressed(slot: int) -> void:
	if _reset_pending == slot:
		# 2ᵉ tap → on supprime pour de bon.
		SaveSystem.discard_save_at(slot)
		_reset_pending = 0
	else:
		# 1er tap → on arme la confirmation.
		_reset_pending = slot
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_reset_pending = 0
			_refresh()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_SPACE:
			_on_slot_pressed(Settings.current_slot)
			get_viewport().set_input_as_handled()
