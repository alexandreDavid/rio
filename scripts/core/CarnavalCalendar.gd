extends Node

# Autoload : CarnavalCalendar.
# Donne un sens aux jours qui passent (TimeOfDay.day_count, déjà persisté) :
# jours de la semaine cariocas, compte à rebours du Carnaval, et le rituel du
# dimanche — jour de jogo. Le résultat du match colore le lendemain (flags
# jogo_vitoria / jogo_derrota lus par RandomEventManager).
# Tout l'état transitoire vit dans les flags CampaignManager → rien à sérialiser.

const WEEKDAYS: Array = ["Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado", "Domingo"]
const DOMINGO: int = 6
# day_count démarre à 1 → jour 1 = Sexta : le premier dimanche arrive vite,
# le joueur découvre le rituel tôt.
const WEEKDAY_OFFSET: int = 3
# « Le Carnaval est dans un mois » (intro) : jour 1 = J-28.
const CARNAVAL_DAY: int = 29
const QUARTA: int = 2
# Après le desfile, le monde passe en « depois do Carnaval » : la folia tient
# jusqu'au mardi, on se réveille le mercredi des Cendres (une journée de
# lendemain de fête), puis la vie reprend son rythme — feijoada le samedi,
# jogo le dimanche.
const DESFILE_QUEST: String = "act4_carnaval_desfile"
const SABADO: int = 5

func _ready() -> void:
	EventBus.time_of_day_changed.connect(_on_phase_changed)
	EventBus.day_elapsed.connect(_on_day_elapsed)
	EventBus.quest_completed.connect(_on_quest_completed)
	EventBus.epilogue_closed.connect(wake_to_cinzas)
	SaveSystem.save_loaded.connect(_on_save_loaded)

# Saves d'avant le « depois do Carnaval » : desfile fait mais monde jamais basculé.
func _on_save_loaded() -> void:
	if QuestManager.is_completed(DESFILE_QUEST) and not is_pos_carnaval():
		CampaignManager.set_flag("pos_carnaval", true)

func weekday() -> int:
	return (TimeOfDay.day_count + WEEKDAY_OFFSET) % 7

func weekday_name() -> String:
	return WEEKDAYS[weekday()]

func is_domingo() -> bool:
	return weekday() == DOMINGO

func is_sabado() -> bool:
	return weekday() == SABADO

func is_pos_carnaval() -> bool:
	return CampaignManager.has_flag("pos_carnaval")

func is_cinzas() -> bool:
	return CampaignManager.has_flag("cinzas_hoje")

# Jours jusqu'au prochain mercredi (jamais 0 : on dort au moins une nuit).
func days_to_next_quarta() -> int:
	var d: int = (QUARTA - weekday() + 7) % 7
	return 7 if d == 0 else d

func _on_quest_completed(quest_id: String) -> void:
	if quest_id != DESFILE_QUEST:
		return
	CampaignManager.set_flag("pos_carnaval", true)
	CampaignManager.set_flag("cinzas_pending", true)

# Fermeture de l'épilogue : ellipse jusqu'au mercredi des Cendres matin.
func wake_to_cinzas() -> void:
	if not CampaignManager.has_flag("cinzas_pending"):
		return
	TimeOfDay.skip_to_morning(days_to_next_quarta())
	EventBus.notification_requested.emit("🎭 Quarta-feira de Cinzas. La folia a tenu jusqu'au mardi soir — tu te réveilles sur un gradin de la Sapucaí, des paillettes plein les cheveux.",
		Color(0.85, 0.7, 0.95, 1))

func days_until_carnaval() -> int:
	return max(0, CARNAVAL_DAY - TimeOfDay.day_count)

# Libellé court pour le HUD : « Domingo · J-25 » puis « É CARNAVAL! ».
func hud_label() -> String:
	if is_pos_carnaval():
		return "Quarta-feira de Cinzas" if is_cinzas() else weekday_name()
	var d: int = days_until_carnaval()
	if d == 0:
		return "%s · É CARNAVAL!" % weekday_name()
	return "%s · J-%d" % [weekday_name(), d]

# --- Dimanche soir : jogo no Maracanã ---

func _on_phase_changed(phase: int) -> void:
	if phase == TimeOfDay.Phase.EVENING and is_domingo() \
			and not CampaignManager.has_flag("jogo_pending"):
		CampaignManager.set_flag("jogo_pending", true)
		var team: String = DialogueBridge.time_coracao()
		if team == "":
			team = "Flamengo"
		EventBus.notification_requested.emit("🏟️ Hoje tem jogo do %s no Maracanã!" % team,
			Color(0.95, 0.85, 0.4, 1))

func _on_day_elapsed(new_day: int) -> void:
	# Les humeurs post-match ne durent qu'une journée.
	CampaignManager.set_flag("jogo_vitoria", false)
	CampaignManager.set_flag("jogo_derrota", false)
	# Le mercredi des Cendres dure une journée ; il commence au réveil qui suit le desfile.
	CampaignManager.set_flag("cinzas_hoje", false)
	if CampaignManager.has_flag("cinzas_pending"):
		CampaignManager.set_flag("cinzas_pending", false)
		CampaignManager.set_flag("cinzas_hoje", true)
	if not CampaignManager.has_flag("jogo_pending"):
		return
	CampaignManager.set_flag("jogo_pending", false)
	_resolve_match(new_day)

func _resolve_match(day: int) -> void:
	var team: String = DialogueBridge.time_coracao()
	if team == "":
		team = "Flamengo"
	# Résultat déterministe par jour (rechargeable sans resimuler).
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1950 + day
	var roll: float = rng.randf()
	var our_goals: int = rng.randi_range(0, 3)
	if roll < 0.45:
		var their_goals: int = max(0, our_goals - rng.randi_range(1, 2))
		our_goals = max(our_goals, their_goals + 1)
		CampaignManager.set_flag("jogo_vitoria", true)
		EventBus.notification_requested.emit("⚽ FIM DE JOGO : %s %d x %d — o bairro é uma festa!"
			% [team, our_goals, their_goals], Color(0.5, 0.95, 0.6, 1))
	elif roll < 0.70:
		CampaignManager.set_flag("jogo_vitoria", false)
		EventBus.notification_requested.emit("⚽ FIM DE JOGO : %s %d x %d — empate sem graça."
			% [team, our_goals, our_goals], Color(0.85, 0.85, 0.75, 1))
	else:
		var winners: int = our_goals + rng.randi_range(1, 2)
		CampaignManager.set_flag("jogo_derrota", true)
		EventBus.notification_requested.emit("⚽ FIM DE JOGO : %s %d x %d — segunda-feira de luto."
			% [team, our_goals, winners], Color(0.9, 0.55, 0.5, 1))
