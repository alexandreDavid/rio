class_name StreetEvent
extends Node2D

# Événement éphémère spawné par RandomEventManager. Une seule interaction :
# applique money_delta (peut être négatif), rep_axis/amount, affiche un texte
# narratif via DialogueBridge, puis disparaît.

@export var event_id: String = "generic"
@export var label_text: String = "Événement"
@export var icon: String = "✨"
@export var speaker: String = "Sobrinho"
@export_multiline var flavor_text: String = "..."
@export var money_delta: int = 0
@export var rep_axis: int = -1   # -1 = pas de modification rep
@export var rep_amount: int = 0

@onready var marker_label: Label = $Marker
@onready var label_under: Label = $LabelUnder
@onready var interactable: Interactable = $Interactable
@onready var halo: ColorRect = $Halo

var _consumed: bool = false
var _bob_t: float = 0.0

func _ready() -> void:
	if marker_label:
		marker_label.text = icon
	if label_under:
		label_under.text = label_text
	if interactable:
		interactable.interacted.connect(_on_interact)
		interactable.prompt = label_text

func _process(delta: float) -> void:
	# Pulsation lente du halo pour attirer l'œil.
	_bob_t += delta * 2.5
	if halo:
		var pulse: float = 0.45 + 0.25 * (sin(_bob_t) * 0.5 + 0.5)
		halo.color = Color(1, 0.95, 0.55, pulse * 0.4)

func _on_interact(_by: Node) -> void:
	if _consumed:
		return
	_consumed = true
	var inv: Inventory = null
	if GameManager.player:
		inv = GameManager.player.get_node_or_null("Inventory") as Inventory
	if inv:
		if money_delta > 0:
			inv.add_money(money_delta)
		elif money_delta < 0:
			# On essaie de débiter ; si pas assez, l'événement passe quand même
			# (flavor texte mentionne souvent qu'on a payé, on est pas pointilleux).
			inv.spend_money(min(-money_delta, inv.money))
	if rep_axis >= 0 and rep_amount != 0:
		ReputationSystem.modify(rep_axis, rep_amount)
	# Bulle narrative.
	var knot_id: String = "event_" + event_id
	DialogueBridge.register_runtime_dialogue(knot_id, {
		"speaker": speaker,
		"text": flavor_text,
		"choices": ["Continuer"],
	})
	DialogueBridge.start_dialogue("street_event", knot_id)
	# Disparition après interaction (laisse le temps au dialogue de s'ouvrir).
	await get_tree().create_timer(0.3).timeout
	queue_free()
