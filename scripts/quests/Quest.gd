class_name Quest
extends Resource

# Authored as .tres files in resources/quests/.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_multiline var journal_text: String = ""
@export var giver_npc_id: String = ""
@export var ink_knot: String = ""  # entry point in .ink script
@export var objectives: Array[QuestObjective] = []
@export var money_reward: int = 0
@export var reputation_rewards: Dictionary = {}   # Axis(int) -> delta(int)
@export var required_reputation: Dictionary = {}  # Axis(int) -> seuil minimum (int)
@export var required_act: int = 0                 # 0 = aucun prérequis d'acte ; 1/2/3 = acte minimum
