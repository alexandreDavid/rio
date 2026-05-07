extends Node

# Outil de skip d'acte pour le test manuel. Autoload, actif uniquement en build
# debug (Editor + builds non-release). En production, queue_free() au démarrage.
# Desktop only — les hotkeys ci-dessous ne servent à rien sur mobile (touch).
#
# Hotkeys (Ctrl ou Cmd-on-Mac pour ne pas conflicter avec F5/F9 du SaveSystem) :
#   Ctrl/Cmd + F1 ou 1 : reset complet → Acte 1, dette 0, quêtes vierges, flags clear
#   Ctrl/Cmd + F2 ou 2 : skip → Acte 2 (complète act1_heritage + meet_ramos + meet_tito + paie 500)
#   Ctrl/Cmd + F3 ou 3 : skip → Acte 3 (+ act2_intro + paie 25k)
#   Ctrl/Cmd + F4 ou 4 : skip → Acte 4 voie POLÍCIA (+ chaîne act3_policia + endgame)
#   Ctrl/Cmd + Shift + F4 ou 4 : Acte 4 voie TRÁFICO
#   Ctrl/Cmd + Alt + F4 ou 4   : Acte 4 voie PREFEITO
#
# Sur Mac, les F-keys nécessitent souvent Fn (Fn+F1 par défaut). Les digits
# (1, 2, 3, 4) marchent dans tous les cas et sont préférables.
#
# Le skip pose les flags narratifs minimaux (act1_started, met_consortium,
# tio_ze_revealed) pour que les NPCs servent les bons knots.

const _PAYLOADS: Dictionary = {
	"act1_skip_flags": ["act1_started", "met_consortium", "first_payment_done"],
	"act2_skip_flags": ["tio_ze_revealed", "act2_reveal_played", "should_visit_home", "home_visit_done"],
}

var _toast: Label = null
var _toast_tween: Tween = null

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	_setup_toast()
	print("[DebugConsole] actif — Ctrl/Cmd + 1..4 (ou F1..F4) pour reset/skip d'acte")

func _setup_toast() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 16)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55))
	_toast.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1, 1))
	_toast.add_theme_constant_override("outline_size", 4)
	_toast.position = Vector2(20, 90)
	_toast.visible = false
	canvas.add_child(_toast)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# Ctrl OU Cmd (Meta) — sur Mac les F-keys demandent Fn donc on accepte aussi
	# les digits avec Cmd. Sur Linux/Windows, Ctrl+F1..4 et Ctrl+1..4 marchent.
	if not (event.ctrl_pressed or event.meta_pressed):
		return
	match event.keycode:
		KEY_F1, KEY_1:
			_reset_to_act1()
		KEY_F2, KEY_2:
			_skip_to_act(2)
		KEY_F3, KEY_3:
			_skip_to_act(3)
		KEY_F4, KEY_4:
			if event.shift_pressed:
				_skip_to_act4(CampaignManager.Endgame.TRAFICO)
			elif event.alt_pressed:
				_skip_to_act4(CampaignManager.Endgame.PREFEITO)
			else:
				_skip_to_act4(CampaignManager.Endgame.POLICIA)
		_:
			return
	get_viewport().set_input_as_handled()

# --- Actions ---

func _reset_to_act1() -> void:
	# Restaure tous les états AVAILABLE pour les quêtes registered.
	for qid in QuestManager._quests.keys():
		QuestManager._state[qid] = QuestManager.State.AVAILABLE
	QuestManager._objectives.clear()
	CampaignManager.current_act = 1
	CampaignManager.debt_paid = 0
	CampaignManager.chosen_endgame = CampaignManager.Endgame.NONE
	CampaignManager.flags.clear()
	EventBus.act_changed.emit(1)
	EventBus.debt_paid.emit(0, CampaignManager.DEBT_TOTAL)
	_toast_msg("Reset → Acte 1")

func _skip_to_act(target: int) -> void:
	# Acte 1 → 2
	if target >= 2 and CampaignManager.current_act < 2:
		for f in _PAYLOADS["act1_skip_flags"]:
			CampaignManager.set_flag(f)
		# Pose aussi les flags de la cutscene d'intro pour éviter qu'elle ne
		# rejoue après un skip (le joueur n'a jamais cliqué Sortir).
		CampaignManager.set_flag("intro_bump_seen")
		CampaignManager.set_flag("intro_seen")
		_complete_quest("act1_heritage")
		_complete_quest("act1_meet_ramos")
		_complete_quest("act1_meet_tito")
		_pay_up_to(CampaignManager.ACT1_THRESHOLD)
	# Acte 2 → 3
	if target >= 3 and CampaignManager.current_act < 3:
		for f in _PAYLOADS["act2_skip_flags"]:
			CampaignManager.set_flag(f)
		_complete_quest("act2_intro")
		_pay_up_to(CampaignManager.ACT2_THRESHOLD)
	# Force la persistance immédiate (set_flag ne trigger pas auto-save, donc
	# si l'utilisateur Cmd+Q juste après, l'état serait perdu).
	SaveSystem.save_game()
	_toast_msg("Skip → Acte %d" % CampaignManager.current_act)

func _skip_to_act4(endgame: int) -> void:
	_skip_to_act(3)
	match endgame:
		CampaignManager.Endgame.POLICIA:
			_complete_quest("act3_policia_intel")
			_complete_quest("act3_policia_madrugada")
		CampaignManager.Endgame.TRAFICO:
			_complete_quest("act3_trafico_pickup")
			_complete_quest("act3_trafico_corrida")
		CampaignManager.Endgame.PREFEITO:
			_complete_quest("act3_prefeito_endorsements")
			_complete_quest("act3_prefeito_eleicao")
	CampaignManager.complete_endgame(endgame)
	var labels: Dictionary = {
		CampaignManager.Endgame.POLICIA: "Polícia",
		CampaignManager.Endgame.TRAFICO: "Tráfico",
		CampaignManager.Endgame.PREFEITO: "Prefeito",
	}
	_toast_msg("Skip → Acte 4 voie %s" % labels.get(endgame, "?"))

# --- Helpers ---

func _complete_quest(quest_id: String) -> void:
	if QuestManager.is_completed(quest_id):
		return
	if not QuestManager.is_active(quest_id):
		QuestManager.accept(quest_id)
	var q: Quest = QuestManager._quests.get(quest_id)
	if q == null:
		push_warning("[DebugConsole] quête inconnue : %s" % quest_id)
		return
	for obj in q.objectives:
		if not obj.optional:
			QuestManager.complete_objective(quest_id, obj.id)

func _pay_up_to(target: int) -> void:
	var to_pay: int = max(target - CampaignManager.debt_paid, 0)
	if to_pay > 0:
		CampaignManager.pay_debt(to_pay)

func _toast_msg(text: String) -> void:
	print("[DebugConsole] ", text)
	if _toast == null:
		return
	_toast.text = "[DEBUG] " + text
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.5)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func(): if _toast: _toast.visible = false)
