class_name BondinhoLauncher
extends Node2D

# Téléphérique du Pão de Açúcar (Estação Praia Vermelha → cumeeira).
# Trajet payant qui amène le joueur dans le district PaoAcucar (coucher de
# soleil + DJ booth). Seule porte d'entrée au district — il n'apparaît pas
# dans la liste taxi.

@export var interactable: Interactable
@export var target_district: String = "pao_acucar"
@export var prompt_text: String = "Prendre le bondinho (R$ %d)"
@export var broke_speaker: String = "Operador"
@export_multiline var broke_text: String = "Sem reais pra subir, freguês. O bondinho não dá fiado."

func _ready() -> void:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable:
		var fare: int = DistrictManager.get_fare(target_district)
		interactable.prompt = prompt_text % fare
		interactable.interacted.connect(_on_interacted)

func _on_interacted(_by: Node) -> void:
	var fare: int = DistrictManager.get_fare(target_district)
	var inv: Inventory = null
	if GameManager.player:
		inv = GameManager.player.get_node_or_null("Inventory") as Inventory
	if inv == null:
		return
	if inv.money < fare:
		_show_broke()
		return
	# travel_to gère la dépense et la téléportation
	DistrictManager.travel_to(target_district)

func _show_broke() -> void:
	DialogueBridge.register_runtime_dialogue("bondinho_broke", {
		"speaker": broke_speaker,
		"text": broke_text,
		"choices": ["Volto depois"],
	})
	DialogueBridge.start_dialogue("bondinho", "bondinho_broke")
