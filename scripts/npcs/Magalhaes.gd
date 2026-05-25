extends NPC

# Sr. Magalhães : gérant du condomínio Riserva Uno (Barra da Tijuca).
# Cible de la SIDE quest consortium_barra_security (intimidate + close),
# puis donneur de la MAIN pacto_barra (prereq = consortium_peninsula).

const SIDE_QUEST_ID: String = "consortium_barra_security"
const OBJ_INTIMIDATE: String = "intimidate_magalhaes"
const OBJ_CLOSE: String = "close_deal"

const MAIN_QUEST_ID: String = "pacto_barra"
const OBJ_SEAL: String = "seal_pacto"

func _on_interacted(_by: Node) -> void:
	if data == null:
		return
	await _approach_player_if_far()
	DialogueBridge.start_dialogue(data.id, _pick_knot())

func _pick_knot() -> String:
	# --- VOIE CONSORTIUM : pacte avec Magalhães (priorité une fois le 1er
	# acompte payé, l'enfant retrouvé et la nuit passée — `act1_closed` —
	# tant qu'aucune autre voie n'est scellée). Les spots prennent le relais
	# (C1+) ; Magalhães offre, rappelle C1, puis scelle le couronnement
	# (Pacto da Barra → endgame CONSORTIUM).
	if QuestManager.is_completed("prologue_pedrinho") \
			and QuestManager.is_completed("act1_heritage") \
			and CampaignManager.has_flag("act1_closed") \
			and not CampaignManager.has_flag("voie_trafico") \
			and not CampaignManager.has_flag("voie_policia") \
			and not CampaignManager.has_flag("voie_prefeito"):
		if not CampaignManager.has_flag("voie_consortium"):
			return "magalhaes_pacto_consortium_offer"
		if QuestManager.is_active("consortium_c9_pacto"):
			return "magalhaes_consortium_pacto"
		if QuestManager.is_active("consortium_c1_recouvrement"):
			return "magalhaes_pacto_consortium_remind"

	# Pacto MAIN — priorité absolue dès que ses prereqs sont OK.
	if QuestManager.is_completed(MAIN_QUEST_ID):
		return "magalhaes_after_pacto"
	if QuestManager.is_active(MAIN_QUEST_ID):
		return "magalhaes_pacto_seal"
	if QuestManager.is_available(MAIN_QUEST_ID):
		return "magalhaes_pacto_offer"
	# SIDE consortium chain — états historiques.
	if QuestManager.is_completed(SIDE_QUEST_ID):
		return "magalhaes_after_deal"
	if QuestManager.is_objective_done(SIDE_QUEST_ID, OBJ_INTIMIDATE) \
			and not QuestManager.is_objective_done(SIDE_QUEST_ID, OBJ_CLOSE):
		return "magalhaes_close_deal"
	if QuestManager.is_active(SIDE_QUEST_ID) \
			and not QuestManager.is_objective_done(SIDE_QUEST_ID, OBJ_INTIMIDATE):
		return "magalhaes_first_visit"
	return "magalhaes_default"
