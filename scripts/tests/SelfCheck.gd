extends Node

# Diagnostic au boot. Vérifie l'intégrité des scènes critiques et imprime
# un rapport clair dans la Sortie. Si un [X] apparaît, c'est là qu'il faut creuser.

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame  # 2 frames pour laisser tous les _ready se terminer
	print("")
	print("===== SELF-CHECK =====")
	_check_autoloads()
	_check_scene_tree()
	_check_groups()
	_check_npcs()
	_check_cart()
	_check_volley_scene()
	print("===== END SELF-CHECK =====")
	print("")

func _ok(ok: bool, label: String) -> void:
	print("  [%s] %s" % ["✓" if ok else "X", label])

func _check_autoloads() -> void:
	print("AUTOLOADS:")
	for name in ["EventBus", "GameManager", "ReputationSystem", "TimeOfDay",
			"QuestManager", "DialogueBridge", "SaveSystem", "AudioManager"]:
		_ok(get_node_or_null("/root/" + name) != null, name)

func _check_scene_tree() -> void:
	print("SCENE:")
	var root: Node = get_tree().current_scene
	_ok(root != null, "current_scene = %s" % (root.name if root else "<null>"))
	if root == null:
		return
	_ok(root.get_node_or_null("World") != null, "Main/World")
	_ok(root.get_node_or_null("UI") != null, "Main/UI")
	_ok(root.get_node_or_null("UI/HUD") != null, "Main/UI/HUD")
	_ok(root.get_node_or_null("UI/DialogueUI") != null, "Main/UI/DialogueUI")
	_ok(root.get_node_or_null("UI/QuestLog") != null, "Main/UI/QuestLog")

func _check_groups() -> void:
	print("GROUPS:")
	var players: Array = get_tree().get_nodes_in_group("player")
	_ok(players.size() == 1, "group 'player' = %d node(s)" % players.size())
	var carts: Array = get_tree().get_nodes_in_group("corn_cart")
	_ok(carts.size() == 1, "group 'corn_cart' = %d node(s)" % carts.size())

func _check_npcs() -> void:
	print("NPCs:")
	for npc_name in ["SeuJoao", "CornCart", "CustomerTourist", "CustomerLocal", "CustomerKid", "PMPatrol", "VolleyNet"]:
		var node: Node = _find_by_name(npc_name)
		if node == null:
			_ok(false, "%s introuvable" % npc_name)
			continue
		var interactable: Node = node.get_node_or_null("Interactable") if node.has_node("Interactable") else null
		var trigger: Node = node.get_node_or_null("Trigger") if node.has_node("Trigger") else null
		var connection_count: int = 0
		if interactable and interactable.has_signal("interacted"):
			connection_count = interactable.interacted.get_connections().size()
		elif trigger and trigger.has_signal("player_entered"):
			connection_count = trigger.player_entered.get_connections().size()
		_ok(connection_count > 0, "%s signal connecté (%d)" % [npc_name, connection_count])

func _check_cart() -> void:
	print("CART:")
	var cart: Node = _find_by_name("CornCart")
	if cart == null:
		_ok(false, "CornCart introuvable dans la scène")
		return
	_ok("stock" in cart, "cart.stock = %s" % cart.get("stock") if "stock" in cart else "?")
	_ok("is_carrying" in cart or cart.has_method("is_carrying"), "cart.is_carrying() = %s" % cart.is_carrying() if cart.has_method("is_carrying") else "?")

func _check_volley_scene() -> void:
	print("VOLLEY SCENE (test de chargement) :")
	var scene_path: String = "res://scenes/minigames/BeachVolley.tscn"
	var ok: bool = ResourceLoader.exists(scene_path)
	_ok(ok, "%s existe" % scene_path)
	if not ok:
		return
	var packed: PackedScene = load(scene_path) as PackedScene
	_ok(packed != null, "PackedScene chargé")

func _find_by_name(target_name: String) -> Node:
	var root: Node = get_tree().current_scene
	if root == null:
		return null
	return _find_recursive(root, target_name)

func _find_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var result: Node = _find_recursive(child, target_name)
		if result:
			return result
	return null
