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

func _ready() -> void:
	EventBus.time_of_day_changed.connect(_on_phase_changed)
	EventBus.day_elapsed.connect(_on_day_elapsed)

func weekday() -> int:
	return (TimeOfDay.day_count + WEEKDAY_OFFSET) % 7

func weekday_name() -> String:
	return WEEKDAYS[weekday()]

func is_domingo() -> bool:
	return weekday() == DOMINGO

func days_until_carnaval() -> int:
	return max(0, CARNAVAL_DAY - TimeOfDay.day_count)

# Libellé court pour le HUD : « Domingo · J-25 » puis « É CARNAVAL! ».
func hud_label() -> String:
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
