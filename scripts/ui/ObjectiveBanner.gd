extends Control

# Bandeau d'objectif contextuel en haut de l'écran. Calcule en permanence
# "qu'est-ce que je dois faire MAINTENANT ?" à partir de l'état des quêtes,
# des flags narratifs, et du district courant. Le texte se met à jour
# automatiquement à chaque changement d'état.

@onready var label: Label = $Panel/Label

func _ready() -> void:
	# Écoute tous les signaux qui peuvent changer l'objectif courant.
	EventBus.quest_accepted.connect(_on_event)
	EventBus.quest_updated.connect(_on_quest_updated)
	EventBus.quest_completed.connect(_on_event)
	EventBus.debt_paid.connect(_on_debt_paid)
	EventBus.act_changed.connect(_on_act_changed)
	if Engine.has_singleton("DistrictManager") or get_tree().root.has_node("DistrictManager"):
		DistrictManager.district_changed.connect(_on_district_changed)
	_refresh()

func _on_event(_id: String) -> void:
	_refresh()

func _on_quest_updated(_quest_id: String, _objective_id: String) -> void:
	_refresh()

func _on_debt_paid(_amount: int, _remaining: int) -> void:
	_refresh()

func _on_act_changed(_act: int) -> void:
	_refresh()

func _on_district_changed(_district_id: String) -> void:
	_refresh()

func _refresh() -> void:
	var text: String = _compute_hint()
	if label:
		label.text = text

# Heuristique : à partir des flags + quêtes + district, dérive le prochain pas.
# L'ordre des conditions == l'ordre de priorité (la 1ère qui match gagne).
func _compute_hint() -> String:
	var act: int = CampaignManager.current_act
	var district: String = DistrictManager.current()
	# --- Acte 1 : démarrage ---
	if not CampaignManager.has_flag("act1_started"):
		return "🎯 Parle à tio Zé"
	if district == "favela_morro":
		return "🎯 ↓ Descends l'escalier vers Copacabana"
	if act == 1 and not CampaignManager.has_flag("met_consortium"):
		return "🎯 Va voir Dom Nilton (consortium) sur l'avenida"
	if act == 1 and CampaignManager.debt_paid < CampaignManager.ACT1_THRESHOLD:
		var still_to_pay: int = CampaignManager.ACT1_THRESHOLD - CampaignManager.debt_paid
		return "🎯 Verse %d R$ d'acompte au consortium (vends du milho au calçadão)" % still_to_pay
	# --- Acte 2 ---
	if act == 2 and CampaignManager.debt_paid < CampaignManager.ACT2_THRESHOLD:
		var still: int = CampaignManager.ACT2_THRESHOLD - CampaignManager.debt_paid
		return "🎯 Continue de payer la dette (%s R$ restants pour l'acte 3)" % still
	# --- Acte 3 : choisir une voie ---
	if act == 3 and CampaignManager.chosen_endgame == CampaignManager.Endgame.NONE:
		return "🎯 Choisis ta voie : Prefeito / Polícia / Tráfico"
	# --- Acte 4 : reinado ---
	if act == 4:
		return "🎯 Mène ton règne — défilé du Carnaval au Sambódromo"
	# Fallback
	return ""
