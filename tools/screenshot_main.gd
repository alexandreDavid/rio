extends Node

# Outil dev : captures du JEU complet (Main.tscn : monde + HUD + bandeau +
# contrôles tactiles), nouvelle partie, joueur téléporté à des positions
# monde. Usage : godot --path . tools/ScreenshotMain.tscn -- <prefix> "x:y[:phase],..."
# (phase 0/1/2 = matin/après-midi/soir pour voir DayLighting).

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("args: <out_prefix> <x:y[:phase],...>")
		get_tree().quit(2)
		return
	await get_tree().process_frame  # la racine finit d'installer ses enfants
	SaveSystem._loading = true
	var main: Node = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	for i in 20:
		await get_tree().process_frame
	while DialogueBridge.is_active():
		DialogueBridge.choose(0)
		await get_tree().process_frame
	CampaignManager.set_flag("act1_started")
	CampaignManager.set_flag("intro_bump_seen")
	QuestManager.accept("act1_heritage")
	var player: Node2D = GameManager.player as Node2D
	if player == null:
		push_error("[ScreenshotMain] pas de joueur")
		get_tree().quit(3)
		return
	# Laisse passer le fondu d'ouverture (IntroFade) et le fondu d'éclairage.
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		await get_tree().process_frame
	var idx: int = 0
	for c in args[1].split(","):
		var parts: PackedStringArray = c.split(":")
		player.global_position = Vector2(float(parts[0]), float(parts[1]))
		if parts.size() >= 3:
			TimeOfDay.current_phase = int(parts[2])
			EventBus.time_of_day_changed.emit(TimeOfDay.current_phase)
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.reset_smoothing()
		var t1: int = Time.get_ticks_msec()
		var wait_ms: int = int(OS.get_environment("SHOT_WAIT_MS")) if OS.has_environment("SHOT_WAIT_MS") else 1200
		while Time.get_ticks_msec() - t1 < wait_ms:
			await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("%s_%d.png" % [args[0], idx])
		print("saved %s_%d.png" % [args[0], idx])
		idx += 1
	get_tree().quit(0)
