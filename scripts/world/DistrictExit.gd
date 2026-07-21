class_name DistrictExit
extends Area2D

# Sortie de quartier piétonne. Quand le joueur entre dans la zone, il est
# téléporté vers la position cible (taux 0 — c'est à pied, pas en taxi).
#
# Verrou narratif optionnel : si `require_quest_completed` est défini, la
# sortie reste bloquée tant que cette quête n'est pas complétée — on affiche
# `block_message` sur le panneau et on NE téléporte pas. Sert au prologue
# (on ne quitte pas le morro avant d'avoir retrouvé l'enfant).

@export var target_district: String = "copacabana"
@export var label_text: String = "→ Quartier"
# Couture : les deux districts sont physiquement contigus (littoral continu
# Copa ↔ Arpoador) — pas de téléport, on bascule juste le référentiel
# (DistrictManager.seam_to). Le joueur et son véhicule continuent leur route.
@export var seamless: bool = false
@export var require_quest_completed: String = ""
@export_multiline var block_message: String = ""
# Si vrai : quand la sortie est verrouillée, la mère de Pedrinho rattrape le
# joueur (cutscene MaeAborde) au lieu d'un simple panneau texte. Le panneau
# reste le fallback si la cutscene ne peut pas tourner.
@export var block_approach_cutscene: bool = false

const _MaeAborde: Script = preload("res://scripts/cutscenes/MaeAborde.gd")

@onready var label_node: Label = $Label

# Évite de re-flasher le message à chaque frame tant que le joueur reste dans
# la zone bloquée.
var _block_flash_active: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if label_node:
		label_node.text = label_text

func _is_locked() -> bool:
	return require_quest_completed != "" \
			and not QuestManager.is_completed(require_quest_completed)

func _on_body_entered(body: Node) -> void:
	var is_player: bool = body.is_in_group("player")
	var is_mounted: bool = body is Rideable and (body as Rideable).is_ridden()
	if not is_player and not is_mounted:
		return
	# Verrou narratif : on bloque la traversée et on prévient le joueur.
	if _is_locked():
		if block_approach_cutscene and not _block_flash_active \
				and not CutsceneRunner.is_running() and not DialogueBridge.is_active():
			# La mère vient le supplier en personne (rejouée à chaque ré-entrée
			# dans la zone : _block_flash_active est remis à zéro à la sortie).
			_block_flash_active = true
			_MaeAborde.run("plea")
		else:
			_flash_block_message()
		return
	if seamless:
		DistrictManager.seam_to(target_district)
		return
	if is_player:
		DistrictManager.walk_to(target_district)
		return
	# Joueur sur un véhicule : le véhicule traverse aussi — on reste monté.
	DistrictManager.walk_to(target_district, body)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") or (body is Rideable and (body as Rideable).is_ridden()):
		_block_flash_active = false
		if label_node:
			label_node.text = label_text
			label_node.modulate = Color(1, 1, 1, 1)

func _flash_block_message() -> void:
	if _block_flash_active or label_node == null:
		return
	_block_flash_active = true
	var msg: String = block_message if block_message != "" else "Pas encore — il te reste quelque chose à faire ici."
	label_node.text = msg
	label_node.modulate = Color(1.0, 0.55, 0.5, 1.0)
