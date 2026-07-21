class_name TransitionOverlay
extends CanvasLayer

# Transitions sensorielles entre districts — gommer la couture du fondu-téléport
# sans casser le modèle hub : le téléport a DÉJÀ eu lieu quand l'overlay se
# joue ; il couvre l'écran le temps de « vivre » le trajet (lampes du tunnel
# qui défilent, traversée de la baie au bastingage), puis se dissout sur le
# district d'arrivée. Le joueur est gelé pendant l'overlay (même mécanisme que
# les dialogues : set_physics_process). Aucune scène — tout est construit en
# code, l'instance s'auto-libère.

const TUNNEL_SEC: float = 1.9
const BARCA_SEC: float = 2.6

static func play_tunnel(tree: SceneTree) -> void:
	var o: TransitionOverlay = TransitionOverlay.new()
	o.layer = 90
	tree.current_scene.add_child(o)
	o._run_tunnel()

static func play_barca(tree: SceneTree) -> void:
	var o: TransitionOverlay = TransitionOverlay.new()
	o.layer = 90
	tree.current_scene.add_child(o)
	o._run_barca()

func _freeze_player(frozen: bool) -> void:
	var p: Node = GameManager.player
	if p == null or not is_instance_valid(p):
		return
	# Ne pas dégeler par-dessus un gel de dialogue (le dialogue rend la main
	# lui-même à sa fermeture).
	if not frozen and DialogueBridge.is_active():
		return
	p.set_physics_process(not frozen)

func _full_rect(color: Color) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = color
	r.anchor_right = 1.0
	r.anchor_bottom = 1.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r

func _label(text: String, y: float, size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.offset_top = y
	l.offset_bottom = y + 40.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

# Le Túnel Novo à pied : noir complet, les veilleuses ambrées défilent en sens
# inverse de la marche, la sortie apparaît en fondu.
func _run_tunnel() -> void:
	_freeze_player(true)
	var black: ColorRect = _full_rect(Color(0.02, 0.02, 0.03, 1))
	var vw: float = 1200.0
	var lamps: Array = []
	for i in 5:
		var lamp: ColorRect = ColorRect.new()
		lamp.color = Color(1.0, 0.78, 0.42, 0.85)
		lamp.offset_left = vw + i * 300.0
		lamp.offset_right = vw + i * 300.0 + 26.0
		lamp.offset_top = 120.0
		lamp.offset_bottom = 132.0
		lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lamp)
		lamps.append(lamp)
		var halo: ColorRect = ColorRect.new()
		halo.color = Color(1.0, 0.8, 0.45, 0.12)
		halo.offset_left = lamp.offset_left - 40.0
		halo.offset_right = lamp.offset_right + 40.0
		halo.offset_top = 100.0
		halo.offset_bottom = 260.0
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(halo)
		lamps.append(halo)
	_label("TÚNEL NOVO", 200.0, 16, Color(0.6, 0.55, 0.5, 0.5))
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	for n in lamps:
		tw.tween_property(n, "offset_left", n.offset_left - vw - 1700.0, TUNNEL_SEC * 0.9)
		tw.tween_property(n, "offset_right", n.offset_right - vw - 1700.0, TUNNEL_SEC * 0.9)
	tw.chain().tween_property(black, "modulate:a", 0.0, 0.45)
	for n in get_children():
		if n != black:
			tw.parallel().tween_property(n, "modulate:a", 0.0, 0.3)
	await tw.finished
	_freeze_player(false)
	queue_free()

# La barca Rio–Niterói : ciel du large, la baie qui glisse, le Pão de Açúcar
# qui s'éloigne derrière le bastingage, deux mouettes.
func _run_barca() -> void:
	_freeze_player(true)
	var sky: ColorRect = _full_rect(Color(0.55, 0.68, 0.80, 1))
	var sea: ColorRect = ColorRect.new()
	sea.color = Color(0.22, 0.42, 0.55, 1)
	sea.anchor_right = 1.0
	sea.anchor_top = 0.55
	sea.anchor_bottom = 1.0
	sea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sea)
	# Le Pão de Açúcar qui recule (silhouette qui glisse vers la gauche).
	var pao: ColorRect = ColorRect.new()
	pao.color = Color(0.32, 0.38, 0.44, 1)
	pao.offset_left = 700.0
	pao.offset_right = 860.0
	pao.offset_top = 160.0
	pao.offset_bottom = 340.0
	pao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pao)
	var morro: ColorRect = ColorRect.new()
	morro.color = Color(0.36, 0.42, 0.46, 1)
	morro.offset_left = 520.0
	morro.offset_right = 700.0
	morro.offset_top = 240.0
	morro.offset_bottom = 340.0
	morro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(morro)
	# Bastingage au premier plan + sillage.
	var rail: ColorRect = ColorRect.new()
	rail.color = Color(0.92, 0.92, 0.9, 1)
	rail.anchor_right = 1.0
	rail.anchor_top = 0.82
	rail.anchor_bottom = 0.84
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rail)
	var wake: ColorRect = ColorRect.new()
	wake.color = Color(0.9, 0.95, 0.97, 0.5)
	wake.offset_left = -200.0
	wake.offset_right = 300.0
	wake.offset_top = 420.0
	wake.offset_bottom = 428.0
	wake.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wake)
	for g in [Vector2(300, 120), Vector2(420, 90)]:
		var gull: Label = Label.new()
		gull.text = "ᵛ"
		gull.position = g
		gull.add_theme_font_size_override("font_size", 18)
		gull.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		gull.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(gull)
	_label("BARCA RIO — NITERÓI · travessia da Baía de Guanabara", 40.0, 15,
		Color(0.15, 0.2, 0.25, 0.8))
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(pao, "offset_left", 180.0, BARCA_SEC * 0.9)
	tw.tween_property(pao, "offset_right", 340.0, BARCA_SEC * 0.9)
	tw.tween_property(morro, "offset_left", 20.0, BARCA_SEC * 0.9)
	tw.tween_property(morro, "offset_right", 200.0, BARCA_SEC * 0.9)
	tw.tween_property(wake, "offset_left", 500.0, BARCA_SEC * 0.9)
	tw.tween_property(wake, "offset_right", 1100.0, BARCA_SEC * 0.9)
	await tw.finished
	var fade: Tween = create_tween()
	for n in get_children():
		fade.parallel().tween_property(n, "modulate:a", 0.0, 0.4)
	await fade.finished
	_freeze_player(false)
	queue_free()
