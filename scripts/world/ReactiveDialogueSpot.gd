class_name ReactiveDialogueSpot
extends Node2D

# Variante de DialogueSpot qui choisit le texte en fonction de l'état narratif
# (flags CampaignManager + acte courant). Permet à un personnage statique
# (mère, grand-mère, voisin) de réagir à la progression du joueur sans avoir
# besoin d'un NPC scripté.
#
# `variants` est une liste de Dictionnaires :
#   { "flag": "first_payment_done", "text": "...", "speaker": "...", "choices": [...] }
# La 1re variante dont la condition match est utilisée. La condition peut être :
#   - "flag": un flag CampaignManager qui doit être set
#   - "not_flag": un flag CampaignManager qui doit NE PAS être set
#   - "act": acte minimal requis
# Une variante sans condition (le "default") doit toujours être en dernier.

@export var npc_id: String = "spot"
@export var prompt: String = "Parler"

# Variantes de dialogue. Format ci-dessus. Doit contenir au moins une entrée.
@export var variants: Array[Dictionary] = []

# Apparence visible — même style que les NPCs (CharacterSpriteFactory, filtre
# LINEAR). Un spot logique sans personne reste invisible (laisser à 0 / vide).
#  - character_appearance : indices CharacterSpriteFactory (contrôle précis)
#  - character_seed       : sinon, config aléatoire stable (≠ 0)
@export var character_appearance: Dictionary = {}
@export var character_seed: int = 0

# Gating de présence : si défini, le spot (sprite + interaction) n'apparaît que
# lorsque ce flag CampaignManager est posé. Sert à ne pas afficher les 4 « tio
# Zé concierge » de chaque voie en même temps devant le Palace — seul celui de
# la voie choisie se montre.
@export var required_flag: String = ""

@onready var interactable: Interactable = $Interactable

func _ready() -> void:
	if interactable == null:
		return
	interactable.prompt = prompt
	interactable.interacted.connect(_on_interacted)
	_refresh_gate()

# Active/masque le spot selon required_flag. Tant qu'il est masqué on poll
# (léger : ≤ qq spots, seulement avant que la voie soit choisie).
func _refresh_gate() -> void:
	var active: bool = required_flag == "" or CampaignManager.has_flag(required_flag)
	visible = active
	if interactable:
		interactable.enabled = active
	if active:
		_spawn_character_sprite()
	set_process(required_flag != "" and not active)

func _process(_delta: float) -> void:
	if CampaignManager.has_flag(required_flag):
		_refresh_gate()

# Affiche un personnage rendu par CharacterSpriteFactory (cellule DOWN/idle),
# au même gabarit et filtrage que les NPCs scriptés — pour ne plus avoir de
# spots invisibles ni de bouts de ColorRect hors style.
func _spawn_character_sprite() -> void:
	if get_node_or_null("CharSprite") != null:
		return
	var config: Dictionary = {}
	if not character_appearance.is_empty():
		config = CharacterSpriteFactory.config_from_indices(character_appearance)
	elif character_seed != 0:
		config = CharacterSpriteFactory.random_config(character_seed)
	else:
		return  # spot purement logique : pas de visuel
	var cw: int = CharacterSpriteFactory.CELL_W
	var ch: int = CharacterSpriteFactory.CELL_H
	# Ombre ovale au sol (ancre le perso), sous le sprite.
	var shadow: ColorRect = ColorRect.new()
	shadow.name = "CharShadow"
	shadow.offset_left = -13.0
	shadow.offset_top = 4.0
	shadow.offset_right = 13.0
	shadow.offset_bottom = 10.0
	shadow.color = Color(0.0, 0.0, 0.0, 0.28)
	shadow.z_index = -1
	add_child(shadow)
	var spr: Sprite2D = Sprite2D.new()
	spr.name = "CharSprite"
	spr.texture = CharacterSpriteFactory.build_sheet(config)
	spr.region_enabled = true
	spr.region_rect = Rect2(0, 0, cw, ch)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var s: float = 48.0 / float(ch)
	spr.scale = Vector2(s, s)
	# Pieds ~ à l'origine du spot (le sprite est centré sur la cellule).
	spr.position = Vector2(0, -24.0)
	add_child(spr)

func _on_interacted(_by: Node) -> void:
	var variant: Dictionary = _pick_variant()
	if variant.is_empty():
		return
	var knot_id: String = "spot_%s_%s" % [npc_id, str(variant.get("id", "default"))]
	var data: Dictionary = {
		"speaker": variant.get("speaker", "Speaker"),
		"text": variant.get("text", "..."),
		"choices": variant.get("choices", ["D'accord"]),
	}
	# Actions post-lecture (choix 0). Raccourcis usuels (set_flag_after, earn_after)
	# + un passthrough `actions` qui permet d'utiliser n'importe quel verbe supporté
	# par DialogueBridge (accept_quest, finish_quest, rep, pay_debt…).
	var post_actions: Dictionary = {}
	var post_flag: String = variant.get("set_flag_after", "")
	if post_flag != "":
		post_actions["set_flag"] = post_flag
	var earn_after: int = int(variant.get("earn_after", 0))
	if earn_after > 0:
		post_actions["earn"] = earn_after
	var passthrough: Dictionary = variant.get("actions", {})
	for k in passthrough:
		post_actions[k] = passthrough[k]
	if not post_actions.is_empty():
		data["on_choose"] = {"0": post_actions}
	# `choice_actions` : actions PAR INDEX de choix ({"0": {...}, "1": {...}}) —
	# pour les variantes où chaque option a des conséquences distinctes
	# (négociations à caution du Consórcio). Prioritaire sur `actions`/raccourcis
	# pour les index qu'il définit ; le "0" des raccourcis est conservé s'il
	# n'est pas redéfini.
	var per_choice: Dictionary = variant.get("choice_actions", {})
	if not per_choice.is_empty():
		var on_choose: Dictionary = data.get("on_choose", {})
		for idx in per_choice:
			on_choose[str(idx)] = per_choice[idx]
		data["on_choose"] = on_choose
	DialogueBridge.register_runtime_dialogue(knot_id, data)
	DialogueBridge.start_dialogue(npc_id, knot_id)

# Sélectionne la 1re variante dont la condition est satisfaite (ordre = priorité).
func _pick_variant() -> Dictionary:
	for v in variants:
		if _variant_matches(v):
			return v
	return {}

func _variant_matches(v: Dictionary) -> bool:
	var flag: String = v.get("flag", "")
	if flag != "" and not CampaignManager.has_flag(flag):
		return false
	var not_flag: String = v.get("not_flag", "")
	if not_flag != "" and CampaignManager.has_flag(not_flag):
		return false
	var min_act: int = int(v.get("act", 0))
	if min_act > 0 and CampaignManager.current_act < min_act:
		return false
	# Conditions liées aux quêtes — permettent à un spot de réagir à l'état narratif
	# sans avoir à miroiter chaque objectif dans un flag.
	var quest_active: String = v.get("quest_active", "")
	if quest_active != "" and not QuestManager.is_active(quest_active):
		return false
	var quest_completed: String = v.get("quest_completed", "")
	if quest_completed != "" and not QuestManager.is_completed(quest_completed):
		return false
	var quest_not_active: String = v.get("quest_not_active", "")
	if quest_not_active != "" and QuestManager.is_active(quest_not_active):
		return false
	var quest_not_completed: String = v.get("quest_not_completed", "")
	if quest_not_completed != "" and QuestManager.is_completed(quest_not_completed):
		return false
	# `objective_done` / `objective_pending` : [quest_id, objective_id]. Pour
	# `done`, la quête peut être active ou complétée — on regarde juste l'état
	# de l'objectif. Pour `pending`, la quête doit être active et l'objectif false.
	var obj_done: Array = v.get("objective_done", [])
	if obj_done.size() == 2:
		var state: Dictionary = QuestManager.get_objectives_state(String(obj_done[0]))
		if not bool(state.get(String(obj_done[1]), false)):
			return false
	var obj_pending: Array = v.get("objective_pending", [])
	if obj_pending.size() == 2:
		if not QuestManager.is_active(String(obj_pending[0])):
			return false
		var state2: Dictionary = QuestManager.get_objectives_state(String(obj_pending[0]))
		if bool(state2.get(String(obj_pending[1]), false)):
			return false
	# Phase de la journée — TimeOfDay.Phase : 0=MORNING, 1=AFTERNOON, 2=EVENING.
	# `phase` : la variante ne s'affiche que pendant cette phase.
	# `not_phase` : la variante ne s'affiche PAS pendant cette phase.
	if v.has("phase") and TimeOfDay.current_phase != int(v.get("phase", -1)):
		return false
	if v.has("not_phase") and TimeOfDay.current_phase == int(v.get("not_phase", -1)):
		return false
	return true
