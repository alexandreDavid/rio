extends Node

# Outil dev : audit tactile de l'interface. Charge le jeu complet, passe en
# revue chaque écran (HUD, dialogue, téléphone, Diário, Missões, táxi…) et
# liste les boutons trop petits pour un doigt (< 44 pt) et ceux qui se
# chevauchent. Une capture par écran.
#   RIO_SAFE_INSETS=167,0,167,54 godot --path . --resolution 1311x603 \
#       tools/UiTouchAudit.tscn -- <out_prefix>
# (format iPhone 17 ; à lancer via un script qui met les sauvegardes à l'abri).

const MIN_PT: float = 44.0
var _prefix: String = ""
var _main: Node = null
var _problems: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_prefix = args[0] if args.size() > 0 else "/tmp/ui_audit"
	await get_tree().process_frame
	SaveSystem._loading = true
	_main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	await _frames(20)
	while DialogueBridge.is_active():
		DialogueBridge.choose(0)
		await get_tree().process_frame
	CampaignManager.set_flag("act1_started")
	CampaignManager.set_flag("intro_bump_seen")
	QuestManager.accept("act1_heritage")
	var player: Node2D = GameManager.player as Node2D
	player.global_position = Vector2(1000, 250)  # sur le sable : bouton altinha visible
	await _wait(5000)

	# Position de chaque élément d'interface (hors monde) : tools/export_check.sh
	# compare ces lignes entre l'éditeur et le paquet exporté.
	for child in _main.get_children():
		if child.name != &"World":
			_dump_layout(child)
	var hud_roots: Array = [_main.get_node("UI"), _main.get_node("MobileLayer")]
	await _shot("hud", hud_roots)
	var log: Node = _main.get_node("UI/QuestLog")
	log.call("toggle")
	await _wait(600)
	await _shot("hud_diario_ouvert", hud_roots)
	log.call("toggle")

	DialogueBridge.register_runtime_dialogue("audit_knot", {
		"speaker": "Seu João",
		"text": "Meu filho, a carrocinha do Zé tá te esperando lá embaixo. Tu vai descer hoje ou vai ficar enrolando aqui em cima até o sol baixar ?",
		"choices": [
			"Je descends tout de suite, tio — la carrocinha ne va pas se pousser toute seule.",
			"D'abord un café avec vovó, après on voit.",
			"Et la dette de Zé, on en parle quand ?",
			"Pas aujourd'hui.",
		],
	})
	DialogueBridge.start_dialogue("seu_joao", "audit_knot")
	await _wait(2500)
	await _shot("dialogue", [_main.get_node("UI/DialogueUI")])
	DialogueBridge.end_dialogue()
	await _wait(400)

	var phone: Node = _main.get_node("Phone")
	phone.call("open")
	for screen in ["home", "cronica", "mapa", "stats", "conquistas", "photos", "ajustes", "noticias", "taxi"]:
		phone.call("_show_screen", screen)
		await _wait(500)
		await _shot("phone_%s" % screen, [phone])
	phone.call("close")
	await _wait(300)

	for pair in [["JournalUI", "toggle", "toggle"], ["MissionBoardUI", "open", "close"], ["TaxiUI", "open", "close"], ["Tutorial", "open", ""], ["CharacterCreator", "open", ""]]:
		var n: Node = _main.get_node_or_null(pair[0])
		if n == null or not n.has_method(pair[1]):
			continue
		n.call(pair[1])
		await _wait(700)
		await _shot(String(pair[0]).to_lower(), [n])
		if pair[2] != "" and n.has_method(pair[2]):
			n.call(pair[2])
		elif n is CanvasItem:
			(n as CanvasItem).visible = false
		elif n is CanvasLayer:
			(n as CanvasLayer).visible = false
		await _wait(300)
	print("== AUDIT TACTILE : %d problème(s)" % _problems)
	get_tree().quit(0)


func _dump_layout(n: Node) -> void:
	if n is Control and not String(n.name).begins_with("@"):
		var r: Rect2 = (n as Control).get_global_rect()
		print("LAYOUT %s|%d,%d,%d,%d" % [_main.get_path_to(n), r.position.x, r.position.y, r.size.x, r.size.y])
	for ch in n.get_children():
		_dump_layout(ch)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(ms: int) -> void:
	var t: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < ms:
		await get_tree().process_frame


func _shot(label: String, roots: Array) -> void:
	await _frames(2)
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_prefix, label])
	var canvas: Vector2 = get_viewport().get_visible_rect().size
	# 44 pt en unités du canevas : la hauteur du canevas vaut 402 pt sur iPhone 17.
	var min_px: float = MIN_PT * canvas.y / 402.0
	var buttons: Array = []
	for r in roots:
		_collect(r, buttons, Rect2(Vector2.ZERO, canvas))
	print("-- %s : %d boutons (canevas %dx%d, 44 pt = %d px)" % [label, buttons.size(), canvas.x, canvas.y, min_px])
	for b in buttons:
		var r: Rect2 = b[1]
		if r.size.x < min_px - 1.0 or r.size.y < min_px - 1.0:
			_problems += 1
			print("   PETIT   %-46s %dx%d px = %dx%d pt" % [b[0], r.size.x, r.size.y, r.size.x * 402.0 / canvas.y, r.size.y * 402.0 / canvas.y])
	var ins: Vector4 = SafeArea.insets(get_viewport())
	var safe: Rect2 = Rect2(ins.x, ins.y, canvas.x - ins.x - ins.z, canvas.y - ins.y - ins.w).grow(2.0)
	for b in buttons:
		if not safe.encloses(b[1]):
			_problems += 1
			print("   HORS ZONE SÛRE %s  %s" % [b[0], b[1]])
	for i in buttons.size():
		for j in range(i + 1, buttons.size()):
			var a: Rect2 = buttons[i][1]
			var c: Rect2 = buttons[j][1]
			var inter: Rect2 = a.intersection(c)
			if inter.size.x > 3.0 and inter.size.y > 3.0 and not _related(buttons[i][2], buttons[j][2]):
				_problems += 1
				print("   CHEVAUCHE %s  ×  %s  (%dx%d px)" % [buttons[i][0], buttons[j][0], inter.size.x, inter.size.y])


func _related(a: Node, b: Node) -> bool:
	return a.is_ancestor_of(b) or b.is_ancestor_of(a)


func _collect(n: Node, out: Array, clip: Rect2) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is CanvasLayer and not (n as CanvasLayer).visible:
		return
	if n is Control:
		var c: Control = n
		var rect: Rect2 = c.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, c.size)
		if c.clip_contents or c is ScrollContainer:
			clip = clip.intersection(rect)
		if c is BaseButton and c.mouse_filter != Control.MOUSE_FILTER_IGNORE and not (c as BaseButton).disabled:
			var seen: Rect2 = rect.intersection(clip)
			# Une ligne à moitié sortie d'une liste défilante n'est pas un défaut.
			if seen.size.x > 8.0 and seen.size.y > 8.0 and seen.get_area() >= rect.get_area() * 0.95:
				out.append([String(_main.get_path_to(c)), rect, c])
	for child in n.get_children():
		_collect(child, out, clip)
