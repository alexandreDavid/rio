extends RefCounted

# Rendu du Racha do Porto (aucune règle ici) : horizons par zone (baie et
# ponte, Pão de Açúcar, morros, Copacabana au couchant), route en bandes,
# tunnels en vraie perspective (murs carrelés, voûte, néons, portail), repères
# du trajet (armazéns et Museu do Amanhã, MAM, Pracinhas, voiliers de
# Botafogo, Rio Sul, prédios de la Princesa Isabel), voitures vues de dos.
# Tout est dessiné sur le CanvasItem du jeu, en aplats « pixel » (pas de 4 px).

enum CarKind { RACER, SEDAN, TAXI, KOMBI, BUS }
enum Prop { PALM, LAMP, WAREHOUSE, MUSEU, CRANE, MAM, TREE, PRACINHAS, BOAT, BUILDING, RIOSUL, SOBRADO }

const INK: Color = Color(0.10, 0.10, 0.12)
const LINE_COL: Color = Color(0.96, 0.94, 0.86)
const SHADOW: Color = Color(0, 0, 0, 0.28)
const TILE_H: float = 800.0
const FAR_W: float = 5200.0

# Zone → [sol A, sol B, route A, route B, bordure A, bordure B].
const GROUND: Array = [
	[Color(0.70, 0.68, 0.63), Color(0.66, 0.64, 0.60), Color(0.30, 0.30, 0.33), Color(0.27, 0.27, 0.30), Color(0.85, 0.84, 0.80), Color(0.55, 0.55, 0.56)],
	[Color(0.13, 0.13, 0.15), Color(0.11, 0.11, 0.13), Color(0.22, 0.22, 0.25), Color(0.19, 0.19, 0.22), Color(0.45, 0.45, 0.42), Color(0.30, 0.30, 0.30)],
	[Color(0.40, 0.66, 0.30), Color(0.36, 0.61, 0.27), Color(0.31, 0.31, 0.34), Color(0.28, 0.28, 0.31), Color(0.86, 0.85, 0.80), Color(0.56, 0.56, 0.57)],
	[Color(0.74, 0.72, 0.66), Color(0.70, 0.68, 0.62), Color(0.31, 0.31, 0.34), Color(0.28, 0.28, 0.31), Color(0.86, 0.85, 0.80), Color(0.56, 0.56, 0.57)],
	[Color(0.13, 0.13, 0.15), Color(0.11, 0.11, 0.13), Color(0.22, 0.22, 0.25), Color(0.19, 0.19, 0.22), Color(0.45, 0.45, 0.42), Color(0.30, 0.30, 0.30)],
	[Color(0.34, 0.52, 0.30), Color(0.31, 0.48, 0.27), Color(0.30, 0.30, 0.33), Color(0.27, 0.27, 0.30), Color(0.85, 0.84, 0.80), Color(0.55, 0.55, 0.56)],
	[Color(0.13, 0.13, 0.15), Color(0.11, 0.11, 0.13), Color(0.22, 0.22, 0.25), Color(0.19, 0.19, 0.22), Color(0.45, 0.45, 0.42), Color(0.30, 0.30, 0.30)],
	[Color(0.80, 0.78, 0.72), Color(0.76, 0.74, 0.68), Color(0.31, 0.31, 0.34), Color(0.28, 0.28, 0.31), Color(0.90, 0.89, 0.84), Color(0.20, 0.20, 0.22)],
]
# Ciel par zone de plein air : l'après-midi au Porto, le couchant à Copacabana.
const SKIES: Dictionary = {
	0: [Color(0.36, 0.62, 0.92), Color(0.48, 0.72, 0.95), Color(0.64, 0.82, 0.97), Color(0.82, 0.91, 0.98)],
	2: [Color(0.34, 0.58, 0.90), Color(0.50, 0.70, 0.93), Color(0.72, 0.82, 0.94), Color(0.94, 0.88, 0.80)],
	3: [Color(0.36, 0.52, 0.86), Color(0.58, 0.64, 0.88), Color(0.88, 0.74, 0.74), Color(0.98, 0.84, 0.66)],
	5: [Color(0.40, 0.44, 0.78), Color(0.70, 0.54, 0.76), Color(0.95, 0.66, 0.56), Color(0.99, 0.80, 0.52)],
	7: [Color(0.36, 0.32, 0.66), Color(0.74, 0.42, 0.62), Color(0.97, 0.58, 0.42), Color(1.00, 0.80, 0.46)],
}
const BUILD_COLS: Array[Color] = [Color(0.93, 0.90, 0.82), Color(0.82, 0.86, 0.90), Color(0.95, 0.84, 0.70),
	Color(0.80, 0.74, 0.68), Color(0.72, 0.80, 0.78), Color(0.90, 0.78, 0.74)]
const MURAL: Array[Color] = [Color(0.92, 0.36, 0.22), Color(0.98, 0.76, 0.2), Color(0.2, 0.6, 0.75), Color(0.35, 0.7, 0.4), Color(0.6, 0.3, 0.65)]


# --- Décor du trajet ---

func decorate(g: Node, rng: RandomNumberGenerator) -> void:
	var n: int = g.seg_count()
	var start: Dictionary = {}
	for i in n:
		var z: int = g.zone[i]
		if not start.has(z):
			start[z] = i
		var k: int = i - int(start[z])
		match z:
			0:
				if k % 12 == 3:
					_put(g, i, Prop.LAMP, 1.32, 0)
					_put(g, i, Prop.LAMP, -1.32, 0)
				if k % 44 == 20 and k < 360:
					_put(g, i, Prop.WAREHOUSE, -3.3, rng.randi() % 5)
				if k % 26 == 8:
					_put(g, i, Prop.SOBRADO if rng.randf() < 0.6 else Prop.BUILDING, 2.9, rng.randi() % 6)
				if k % 90 == 60:
					_put(g, i, Prop.CRANE, -5.6, 0)
				if k % 16 == 9:
					_put(g, i, Prop.PALM, 1.7 if k % 32 == 9 else -1.7, rng.randi() % 3)
			2:
				if k % 14 == 5:
					_put(g, i, Prop.LAMP, 1.3, 1)
					_put(g, i, Prop.LAMP, -1.3, 1)
				if k % 5 == 2:
					_put(g, i, Prop.TREE, rng.randf_range(1.9, 4.4) * (1.0 if rng.randf() < 0.5 else -1.0), rng.randi() % 3)
				if k % 9 == 4:
					_put(g, i, Prop.PALM, 1.55 if k % 18 == 4 else -1.55, rng.randi() % 3)
				if k % 40 == 30:
					_put(g, i, Prop.BOAT, -rng.randf_range(7.5, 11.0), rng.randi() % 3)
			3:
				if k % 14 == 5:
					_put(g, i, Prop.LAMP, 1.3, 0)
				if k % 8 == 3:
					_put(g, i, Prop.PALM, -1.32, rng.randi() % 3)
				if k % 7 == 2:
					_put(g, i, Prop.BOAT, -rng.randf_range(3.6, 9.0), rng.randi() % 3)
				if k % 15 == 7:
					_put(g, i, Prop.BUILDING, 2.7, rng.randi() % 6)
			5:
				# Le shopping occupe le côté gauche avant le Túnel Novo : rien devant.
				var mall: bool = k > 250
				if k % 12 == 4:
					_put(g, i, Prop.LAMP, 1.3, 0)
					_put(g, i, Prop.LAMP, -1.3, 0)
				if k % 6 == 1 and not (mall and k % 12 != 1):
					_put(g, i, Prop.TREE, rng.randf_range(1.8, 3.2) * (1.0 if k % 12 == 1 else -1.0), rng.randi() % 3)
				if k % 22 == 14 and not (mall and k % 44 == 14):
					_put(g, i, Prop.BUILDING, -3.0 if k % 44 == 14 else 3.4, rng.randi() % 6)
			7:
				if k % 12 == 4:
					_put(g, i, Prop.LAMP, 1.3, 0)
					_put(g, i, Prop.LAMP, -1.3, 0)
				if k % 11 == 2:
					_put(g, i, Prop.BUILDING, 2.5, rng.randi() % 6)
				if k % 11 == 7:
					_put(g, i, Prop.BUILDING, -2.5, rng.randi() % 6)
				if k % 9 == 5:
					_put(g, i, Prop.PALM, 1.5 if k % 18 == 5 else -1.5, rng.randi() % 3)
	# Repères uniques.
	_put(g, int(start[0]) + 150, Prop.MUSEU, -4.6, 0)
	_put(g, int(start[2]) + 60, Prop.MAM, -4.2, 0)
	_put(g, int(start[2]) + 330, Prop.PRACINHAS, -4.4, 0)
	_put(g, int(start[5]) + 340, Prop.RIOSUL, -4.3, 0)
	g.gantries[10] = "RACHA DO PORTO"
	g.gantries[int(start[2]) + 20] = "ATERRO · ZONA SUL"
	g.gantries[int(start[5]) + 24] = "SHOPPING RIO SUL · TÚNEL NOVO"
	g.gantries[int(start[7]) + 26] = "AV. PRINCESA ISABEL"
	g.gantries[int(g.finish_seg)] = "CHEGADA"


func _put(g: Node, i: int, kind: int, offset: float, variant: int) -> void:
	if i < 0 or i >= g.seg_count():
		return
	if not g.props.has(i):
		g.props[i] = []
	(g.props[i] as Array).append([kind, offset, variant])


# --- Image ---

func draw(g: Node) -> void:
	var v: Rect2 = g.view
	var vl: float = v.position.x - 4.0
	var vr: float = v.end.x + 4.0
	var vt: float = v.position.y - 4.0
	var vb: float = v.end.y + 4.0
	var pseg: int = g.seg_at(g.dist + g.PLAYER_Z)
	# L'horizon est celui de la prochaine zone de plein air (vu par la bouche du tunnel).
	var open_zone: int = g.zone[pseg]
	var j: int = pseg
	while g.is_tunnel(open_zone) and j < g.seg_count() - 1:
		j += 1
		open_zone = g.zone[j]
	_backdrop(g, open_zone, vl, vr, vt)
	var gcol: Array = GROUND[open_zone]
	g.draw_rect(Rect2(vl, g.HORIZON_Y, vr - vl, vb - g.HORIZON_Y), gcol[0])
	var last: int = _road(g, vl, vr, vb)
	_sprites(g, last)
	g.draw_set_transform(Vector2.ZERO)


func _quad(g: Node, a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	g.draw_primitive(PackedVector2Array([a, b, c, d]), PackedColorArray([col, col, col, col]), PackedVector2Array())


func _tile_starts(vl: float, vr: float, off: float, w: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	var x: float = -fposmod(off, w)
	while x > vl:
		x -= w
	while x < vr:
		out.append(x)
		x += w
	return out


# --- Horizons ---

func _backdrop(g: Node, z: int, vl: float, vr: float, vt: float) -> void:
	var hz: float = g.HORIZON_Y
	var key: int = z if SKIES.has(z) else 0
	var sky: Array = SKIES[key]
	var h: float = hz - vt
	for k in sky.size():
		var y0: float = snappedf(vt + h * float(k) / float(sky.size()), g.PIX)
		var y1: float = snappedf(vt + h * float(k + 1) / float(sky.size()), g.PIX)
		g.draw_rect(Rect2(vl, y0, vr - vl, y1 - y0 + 1.0), sky[k])
	var cloud: Color = Color(1, 0.97, 0.93, 0.9) if z < 5 else Color(1.0, 0.78, 0.62, 0.9)
	for x0 in _tile_starts(vl, vr, g.far_off * 0.4 + g.t * 5.0, FAR_W):
		for c: Rect2 in [Rect2(300, -330, 240, 32), Rect2(1500, -280, 320, 40), Rect2(2900, -350, 200, 30), Rect2(4100, -300, 280, 36)]:
			var base: Vector2 = Vector2(x0 + c.position.x, hz + c.position.y)
			g.draw_rect(Rect2(base, c.size), cloud)
			g.draw_rect(Rect2(base + Vector2(c.size.x * 0.2, -c.size.y * 0.6), Vector2(c.size.x * 0.5, c.size.y * 0.6)), cloud)
	match z:
		0:
			_bd_bay(g, vl, vr, hz)
		2:
			_bd_pao(g, vl, vr, hz, 0.8)
		3:
			_bd_pao(g, vl, vr, hz, 1.3)
		5:
			_bd_morros(g, vl, vr, hz)
		_:
			_bd_copa(g, vl, vr, hz)


# Baie de Guanabara : serra au loin, Ponte Rio–Niterói, eau.
func _bd_bay(g: Node, vl: float, vr: float, hz: float) -> void:
	var water: Color = Color(0.26, 0.52, 0.70)
	for x0 in _tile_starts(vl, vr, g.far_off, FAR_W):
		g.draw_set_transform(Vector2(x0, hz - 26.0))
		g.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(0, -60), Vector2(500, -130), Vector2(900, -90),
			Vector2(1400, -170), Vector2(1700, -120), Vector2(2300, -200), Vector2(2800, -110), Vector2(3400, -160),
			Vector2(4100, -90), Vector2(4700, -140), Vector2(5200, -60), Vector2(5200, 0)]), Color(0.58, 0.66, 0.84))
		# La ponte : tablier bas, piles serrées, vão central plus haut.
		var deck: Color = Color(0.80, 0.82, 0.84)
		g.draw_rect(Rect2(0, -44, 5200, 6), deck)
		for k in 58:
			g.draw_rect(Rect2(float(k) * 90.0, -40, 8, 40), deck.darkened(0.15))
		g.draw_colored_polygon(PackedVector2Array([Vector2(2200, -44), Vector2(2500, -72), Vector2(2900, -72), Vector2(3200, -44)]), deck)
		g.draw_rect(Rect2(2500, -72, 12, 72), deck.darkened(0.15))
		g.draw_rect(Rect2(2888, -72, 12, 72), deck.darkened(0.15))
		# Un navire au large.
		g.draw_rect(Rect2(1100, -20, 260, 16), Color(0.22, 0.24, 0.30))
		g.draw_rect(Rect2(1290, -40, 50, 20), Color(0.92, 0.92, 0.90))
		g.draw_rect(Rect2(1130, -30, 120, 10), Color(0.75, 0.30, 0.22))
	g.draw_set_transform(Vector2.ZERO)
	g.draw_rect(Rect2(vl, hz - 26.0, vr - vl, 26.0), water)
	_shine(g, vl, vr, hz - 26.0, 26.0, Color(0.70, 0.86, 0.94))


# Aterro et Botafogo : Niterói au loin, Urca et Pão de Açúcar, bondinho, eau.
func _bd_pao(g: Node, vl: float, vr: float, hz: float, k: float) -> void:
	var rock: Color = Color(0.44, 0.44, 0.52) if k < 1.0 else Color(0.40, 0.36, 0.42)
	var veg: Color = Color(0.24, 0.42, 0.30)
	for x0 in _tile_starts(vl, vr, g.far_off, FAR_W):
		g.draw_set_transform(Vector2(x0, hz - 30.0))
		g.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(0, -50), Vector2(600, -100), Vector2(1300, -60),
			Vector2(2600, -90), Vector2(3600, -130), Vector2(4500, -70), Vector2(5200, -50), Vector2(5200, 0)]), Color(0.60, 0.66, 0.82))
	# Le Pão de Açúcar reste dans le cadre : ancré à l'écran, il ne glisse que
	# de quelques centaines de pixels avec les virages de la zone.
	var slide: float = clampf(g.far_off - g.zone_far0, -520.0, 520.0)
	g.draw_set_transform(Vector2(g.CX + (360.0 if k < 1.0 else -330.0) - slide, hz - 28.0), 0.0, Vector2(k, k))
	# Morro da Urca.
	g.draw_colored_polygon(PackedVector2Array([Vector2(-560, 0), Vector2(-520, -90), Vector2(-420, -150), Vector2(-260, -170),
		Vector2(-140, -140), Vector2(-80, -60), Vector2(-60, 0)]), rock)
	g.draw_colored_polygon(PackedVector2Array([Vector2(-560, 0), Vector2(-540, -50), Vector2(-300, -70), Vector2(-80, -40), Vector2(-60, 0)]), veg)
	# Pão de Açúcar.
	g.draw_colored_polygon(PackedVector2Array([Vector2(-40, 0), Vector2(0, -150), Vector2(40, -270), Vector2(100, -340),
		Vector2(170, -360), Vector2(240, -330), Vector2(290, -240), Vector2(330, -110), Vector2(360, 0)]), rock)
	g.draw_colored_polygon(PackedVector2Array([Vector2(60, -300), Vector2(110, -340), Vector2(170, -356), Vector2(150, -250), Vector2(90, -160)]), rock.lightened(0.14))
	g.draw_colored_polygon(PackedVector2Array([Vector2(-40, 0), Vector2(-10, -70), Vector2(200, -90), Vector2(340, -60), Vector2(360, 0)]), veg)
	# Le câble du bondinho et sa cabine.
	g.draw_line(Vector2(-260, -170), Vector2(150, -358), INK, 2.0)
	var cab: Vector2 = Vector2(-260, -170).lerp(Vector2(150, -358), fposmod(g.t * 0.03, 1.0))
	g.draw_rect(Rect2(cab + Vector2(-8, 2), Vector2(16, 10)), Color(0.95, 0.75, 0.2))
	g.draw_set_transform(Vector2.ZERO)
	g.draw_rect(Rect2(vl, hz - 30.0, vr - vl, 30.0), Color(0.26, 0.50, 0.70) if k < 1.0 else Color(0.34, 0.46, 0.66))
	_shine(g, vl, vr, hz - 30.0, 30.0, Color(0.74, 0.86, 0.94) if k < 1.0 else Color(1.0, 0.84, 0.66))


# Rio Sul : les morros tout proches, le Cristo sur son pic.
func _bd_morros(g: Node, vl: float, vr: float, hz: float) -> void:
	for x0 in _tile_starts(vl, vr, g.far_off, FAR_W):
		g.draw_set_transform(Vector2(x0, hz))
		g.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(0, -120), Vector2(500, -260), Vector2(900, -420),
			Vector2(1000, -470), Vector2(1100, -400), Vector2(1700, -180), Vector2(2300, -90), Vector2(2600, 0)]), Color(0.36, 0.34, 0.50))
		g.draw_rect(Rect2(993, -512, 12, 44), Color(0.98, 0.92, 0.84))
		g.draw_rect(Rect2(978, -504, 42, 7), Color(0.98, 0.92, 0.84))
		g.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(0, -150), Vector2(300, -230), Vector2(700, -160),
			Vector2(1200, -260), Vector2(1700, -140), Vector2(2000, 0)]), Color(0.18, 0.36, 0.26))
		g.draw_colored_polygon(PackedVector2Array([Vector2(2700, 0), Vector2(3100, -210), Vector2(3600, -330), Vector2(4000, -250),
			Vector2(4600, -300), Vector2(5200, -150), Vector2(5200, 0)]), Color(0.20, 0.40, 0.28))
		g.draw_colored_polygon(PackedVector2Array([Vector2(3300, -270), Vector2(3600, -330), Vector2(3900, -270), Vector2(3700, -200)]), Color(0.46, 0.42, 0.44))
	g.draw_set_transform(Vector2.ZERO)


# Copacabana : les prédios en canyon et, au bout de l'avenue, la mer.
func _bd_copa(g: Node, vl: float, vr: float, hz: float) -> void:
	var cx: float = g.CX
	g.draw_rect(Rect2(vl, hz - 34.0, vr - vl, 34.0), Color(0.30, 0.42, 0.66))
	_shine(g, vl, vr, hz - 34.0, 34.0, Color(1.0, 0.80, 0.56))
	# Le soleil se couche derrière les immeubles de droite.
	g.draw_rect(Rect2(cx + 260.0, hz - 150.0, 72, 72), Color(1.0, 0.90, 0.60))
	var hs: Array[float] = [260, 340, 220, 380, 300, 250, 400, 280, 330, 240, 360, 290]
	for side: float in [-1.0, 1.0]:
		var x: float = 150.0
		var k: int = 0 if side < 0.0 else 5
		while x < 1500.0:
			var w: float = 150.0 + float((k * 37) % 70)
			var bh: float = hs[k % hs.size()] * (0.7 + 0.3 * clampf(x / 900.0, 0.0, 1.0))
			var bx: float = cx + side * x - (w if side < 0.0 else 0.0)
			var col: Color = Color(0.42, 0.34, 0.46) if k % 2 == 0 else Color(0.50, 0.38, 0.48)
			g.draw_rect(Rect2(bx, hz - bh, w, bh), col)
			var wy: float = hz - bh + 16.0
			while wy < hz - 16.0:
				g.draw_rect(Rect2(bx + 10.0, wy, w - 20.0, 6), Color(1.0, 0.82, 0.5, 0.5) if int(wy) % 3 == 0 else col.darkened(0.2))
				wy += 22.0
			x += w + 6.0
			k += 1


func _shine(g: Node, vl: float, vr: float, y: float, h: float, col: Color) -> void:
	for k in 9:
		var sx: float = fposmod(float(k) * 431.0 - g.far_off * 1.3 + sin(g.t * 0.7 + float(k)) * 20.0, vr - vl) + vl
		g.draw_rect(Rect2(sx, y + 6.0 + float(k % 3) * (h - 12.0) / 3.0, 40.0 + float(k % 4) * 16.0, 3.0), col)


# --- Route ---

func _road(g: Node, vl: float, vr: float, vb: float) -> int:
	var n_total: int = g.seg_count()
	var base_seg: int = int(g.dist / g.SEG_LEN)
	var base_pct: float = fposmod(g.dist, g.SEG_LEN) / g.SEG_LEN
	var pz: float = g.dist + g.PLAYER_Z
	var pseg: int = g.seg_at(pz)
	var ppct: float = fposmod(pz, g.SEG_LEN) / g.SEG_LEN
	var cam_y: float = lerpf(g.seg_y1(pseg), g.hy[pseg], ppct) + g.CAM_H
	var cam_x: float = g.px * g.ROAD_W
	var maxy: float = vb
	var x: float = 0.0
	var dx: float = -g.curve[mini(base_seg, n_total - 1)] * base_pct
	var last: int = 0
	for n in g.DRAW_DIST:
		var i: int = base_seg + n
		g.pj_seg[n] = -1
		if i >= n_total:
			break
		var z1: float = float(i) * g.SEG_LEN - g.dist
		var z2: float = z1 + g.SEG_LEN
		var rx1: float = x - cam_x
		var rx2: float = x + dx - cam_x
		x += dx
		dx += g.curve[i]
		if z1 <= g.NEAR_Z:
			continue
		var s1: float = g.FOCAL / z1
		var s2: float = g.FOCAL / z2
		var x1: float = g.CX + s1 * rx1
		var x2: float = g.CX + s2 * rx2
		var y1: float = g.HORIZON_Y - s1 * (g.seg_y1(i) - cam_y)
		var y2: float = g.HORIZON_Y - s2 * (g.hy[i] - cam_y)
		g.pj_seg[n] = i
		g.pj_x1[n] = x1
		g.pj_y1[n] = y1
		g.pj_s1[n] = s1
		g.pj_x2[n] = x2
		g.pj_y2[n] = y2
		g.pj_s2[n] = s2
		g.pj_clip[n] = maxy
		last = n
		var qy1: float = snappedf(y1, g.PIX)
		var qy2: float = snappedf(y2, g.PIX)
		if qy2 >= qy1 or qy2 >= maxy:
			continue
		var w1: float = s1 * g.ROAD_W
		var w2: float = s2 * g.ROAD_W
		if qy1 > maxy:
			var tt: float = (maxy - qy2) / (qy1 - qy2)
			x1 = lerpf(x2, x1, tt)
			w1 = lerpf(w2, w1, tt)
			qy1 = maxy
		_segment(g, i, vl, vr, x1, qy1, w1, x2, qy2, w2)
		maxy = qy2
	return last


func _segment(g: Node, i: int, vl: float, vr: float, x1: float, y1: float, w1: float, x2: float, y2: float, w2: float) -> void:
	var z: int = g.zone[i]
	var pal: Array = GROUND[z]
	var alt: bool = (i / 3) % 2 == 0
	g.draw_rect(Rect2(vl, y2, vr - vl, y1 - y2), pal[0] if alt else pal[1])
	if z == 3:
		# Enseada de Botafogo : la plage puis l'eau, à gauche.
		var sand_a: float = 1.5
		var sea_a: float = 2.7
		var left: float = minf(vl, minf(x1 - w1 * sea_a, x2 - w2 * sea_a)) - 2.0
		_quad(g, Vector2(left, y1), Vector2(x1 - w1 * sea_a, y1), Vector2(x2 - w2 * sea_a, y2), Vector2(left, y2),
			Color(0.30, 0.50, 0.70) if alt else Color(0.33, 0.53, 0.72))
		_quad(g, Vector2(x1 - w1 * sea_a, y1), Vector2(x1 - w1 * sand_a, y1), Vector2(x2 - w2 * sand_a, y2), Vector2(x2 - w2 * sea_a, y2),
			Color(0.93, 0.86, 0.66) if alt else Color(0.90, 0.83, 0.63))
	elif z == 2:
		# Aterro : la baie loin derrière les jardins.
		var sea_b: float = 6.5
		var left2: float = minf(vl, minf(x1 - w1 * sea_b, x2 - w2 * sea_b)) - 2.0
		if maxf(x1 - w1 * sea_b, x2 - w2 * sea_b) > vl:
			_quad(g, Vector2(left2, y1), Vector2(x1 - w1 * sea_b, y1), Vector2(x2 - w2 * sea_b, y2), Vector2(left2, y2),
				Color(0.26, 0.52, 0.72) if alt else Color(0.29, 0.55, 0.74))
	elif z == 7:
		# Calçadas en pedra portuguesa : bandes noires et blanches.
		for side: float in [-1.0, 1.0]:
			_quad(g, Vector2(x1 + side * w1 * 1.12, y1), Vector2(x1 + side * w1 * 1.7, y1), Vector2(x2 + side * w2 * 1.7, y2), Vector2(x2 + side * w2 * 1.12, y2),
				Color(0.92, 0.91, 0.86) if alt else Color(0.24, 0.24, 0.26))
	var rw: float = g.RUMBLE_W
	_quad(g, Vector2(x1 - w1 * rw, y1), Vector2(x1 + w1 * rw, y1), Vector2(x2 + w2 * rw, y2), Vector2(x2 - w2 * rw, y2), pal[4] if alt else pal[5])
	var road: Color = pal[2] if alt else pal[3]
	if g.is_tunnel(z) and i % 4 < 2:
		road = road.lightened(0.07)  # flaque de lumière sous les néons
	if i == g.finish_seg or i == g.finish_seg + 1:
		# Damier d'arrivée.
		for c in 10:
			var fa: float = -1.0 + 0.2 * float(c)
			var dark: bool = (c + i) % 2 == 0
			_quad(g, Vector2(x1 + w1 * fa, y1), Vector2(x1 + w1 * (fa + 0.2), y1), Vector2(x2 + w2 * (fa + 0.2), y2), Vector2(x2 + w2 * fa, y2),
				INK if dark else LINE_COL)
		return
	_quad(g, Vector2(x1 - w1, y1), Vector2(x1 + w1, y1), Vector2(x2 + w2, y2), Vector2(x2 - w2, y2), road)
	if w2 > 5.0:
		# Lignes de rive continues, voies en pointillés.
		for e: float in [-0.95, 0.95]:
			_quad(g, Vector2(x1 + w1 * (e - 0.012), y1), Vector2(x1 + w1 * (e + 0.012), y1), Vector2(x2 + w2 * (e + 0.012), y2), Vector2(x2 + w2 * (e - 0.012), y2), LINE_COL)
		if alt:
			for e2: float in [-0.33, 0.33]:
				_quad(g, Vector2(x1 + w1 * (e2 - 0.014), y1), Vector2(x1 + w1 * (e2 + 0.014), y1), Vector2(x2 + w2 * (e2 + 0.014), y2), Vector2(x2 + w2 * (e2 - 0.014), y2), LINE_COL)


# --- Sprites, de l'horizon vers nous ---

func _sprites(g: Node, last: int) -> void:
	var buckets: Dictionary = {}
	for c in g.cars:
		var si: int = int(c.z / g.SEG_LEN)
		if not buckets.has(si):
			buckets[si] = []
		(buckets[si] as Array).append(c)
	var player_n: int = int((fposmod(g.dist, g.SEG_LEN) + g.PLAYER_Z) / g.SEG_LEN)
	var player_drawn: bool = false
	var first_valid: int = -1
	for n in last + 1:
		if g.pj_seg[n] >= 0:
			first_valid = n
			break
	for n in range(last, -1, -1):
		if n < player_n and not player_drawn:
			_player(g)
			player_drawn = true
		var i: int = g.pj_seg[n]
		if i < 0:
			continue
		var x1: float = g.pj_x1[n]
		var y1: float = g.pj_y1[n]
		var s1: float = g.pj_s1[n]
		var clip: float = g.pj_clip[n]
		var z: int = g.zone[i]
		if g.is_tunnel(z):
			# Les murs se dessinent en coordonnées d'écran : on efface la
			# transformation laissée par les sprites du segment précédent.
			g.draw_set_transform(Vector2.ZERO)
			_shell(g, i, x1, y1, s1, g.pj_x2[n], g.pj_y2[n], g.pj_s2[n])
			if n == first_valid:
				# Bouchon près de la caméra : les murs filent hors de l'écran.
				var s0: float = g.FOCAL / 30.0
				_shell(g, i - 1, g.CX + (x1 - g.CX) * s0 / s1, y1 + (s0 - s1) * g.CAM_H, s0, x1, y1, s1)
			if i > 0 and not g.is_tunnel(g.zone[i - 1]):
				g.draw_set_transform(Vector2(x1, y1), 0.0, Vector2(s1, s1))
				_portal(g, z)
				g.draw_set_transform(Vector2.ZERO)
		if g.gantries.has(i) and y1 - s1 * 2400.0 < clip:
			g.draw_set_transform(Vector2(x1, y1), 0.0, Vector2(s1, s1))
			_gantry(g, String(g.gantries[i]), i == g.finish_seg or i == 10)
		if g.props.has(i):
			for p: Array in g.props[i]:
				if y1 - s1 * 5000.0 >= clip or s1 * 5000.0 < 3.0:
					continue
				var off: float = p[1]
				# Miroir à gauche de la route, sauf ce qui porte une enseigne lisible.
				var flip: float = -1.0 if off < 0.0 and int(p[0]) != Prop.RIOSUL else 1.0
				g.draw_set_transform(Vector2(x1 + s1 * off * g.ROAD_W, y1), 0.0, Vector2(s1 * flip, s1))
				_prop(g, int(p[0]), int(p[2]), i)
		if buckets.has(i):
			for c in buckets[i]:
				var pct: float = fposmod(c.z, g.SEG_LEN) / g.SEG_LEN
				var s: float = lerpf(s1, g.pj_s2[n], pct)
				var bx: float = lerpf(x1, g.pj_x2[n], pct) + s * c.offset * g.ROAD_W
				var by: float = lerpf(y1, g.pj_y2[n], pct)
				if by - s * 500.0 >= clip or s * 600.0 < 2.0:
					continue
				g.draw_set_transform(Vector2(bx, by), 0.0, Vector2(s, s))
				_car(g, int(c.kind), c.color, false, false)
	if not player_drawn:
		_player(g)
	g.draw_set_transform(Vector2.ZERO)


func _player(g: Node) -> void:
	var s: float = g.FOCAL / g.PLAYER_Z
	var base: Vector2 = Vector2(g.CX, g.HORIZON_Y + g.FOCAL * g.CAM_H / g.PLAYER_Z) + g.shake
	g.draw_set_transform(base, g.lean, Vector2(s, s))
	_car(g, CarKind.RACER, g.player_color(), bool(g.braking), float(g.nitro_t) > 0.0)
	g.draw_set_transform(Vector2.ZERO)


# --- Tunnel : une tranche de galerie entre deux profils projetés ---

func _shell(g: Node, i: int, xa: float, ya: float, sa: float, xb: float, yb: float, sb: float) -> void:
	var w: float = g.WALL_X * g.ROAD_W
	var alt: bool = (i / 2) % 2 == 0
	var z: int = g.zone[clampi(i, 0, g.seg_count() - 1)]
	var tile: Color = Color(0.74, 0.76, 0.74) if alt else Color(0.68, 0.70, 0.68)
	var upper: Color = Color(0.24, 0.25, 0.28) if alt else Color(0.20, 0.21, 0.24)
	var ceil_c: Color = Color(0.13, 0.13, 0.16) if alt else Color(0.11, 0.11, 0.14)
	# Néons : blanc froid au Marcello Alencar (récent), sodium ailleurs.
	var lamp: Color = Color(0.86, 0.94, 1.0) if z == 1 else Color(1.0, 0.82, 0.45)
	if z != 1:
		tile = tile.lerp(Color(1.0, 0.85, 0.55), 0.25)
	for side: float in [-1.0, 1.0]:
		var a0: Vector2 = Vector2(xa + side * sa * w, ya)
		var b0: Vector2 = Vector2(xb + side * sb * w, yb)
		var a1: Vector2 = a0 - Vector2(0, sa * TILE_H)
		var b1: Vector2 = b0 - Vector2(0, sb * TILE_H)
		var a2: Vector2 = a0 - Vector2(0, sa * g.TUN_H)
		var b2: Vector2 = b0 - Vector2(0, sb * g.TUN_H)
		_quad(g, a0, b0, b1, a1, tile)
		_quad(g, a1, b1, b2, a2, upper)
		# Liseré lumineux au-dessus du carrelage.
		_quad(g, a1, b1, b1 - Vector2(0, sb * 70.0), a1 - Vector2(0, sa * 70.0), lamp.darkened(0.25))
	var ta: Vector2 = Vector2(xa, ya - sa * g.TUN_H)
	var tb: Vector2 = Vector2(xb, yb - sb * g.TUN_H)
	_quad(g, ta + Vector2(-sa * w, 0), tb + Vector2(-sb * w, 0), tb + Vector2(sb * w, 0), ta + Vector2(sa * w, 0), ceil_c)
	if i % 4 < 2:
		for lx: float in [-0.5, 0.5]:
			var la: float = sa * g.ROAD_W
			var lb: float = sb * g.ROAD_W
			_quad(g, ta + Vector2(la * (lx - 0.1), 0), tb + Vector2(lb * (lx - 0.1), 0), tb + Vector2(lb * (lx + 0.1), 0), ta + Vector2(la * (lx + 0.1), 0), lamp)


# Bouche du tunnel vue de dehors : morro ou béton, arche, plaque.
func _portal(g: Node, z: int) -> void:
	var w: float = g.WALL_X * g.ROAD_W
	var mass: Color = Color(0.58, 0.58, 0.56) if z == 1 else Color(0.20, 0.40, 0.26)
	g.draw_rect(Rect2(-22000, -9000, 22000 - w, 9000), mass)
	g.draw_rect(Rect2(w, -9000, 22000 - w, 9000), mass)
	g.draw_rect(Rect2(-w, -9000, 2.0 * w, 9000 - g.TUN_H), mass)
	if z != 1:
		# Roche à nu dans la mata.
		for r: Rect2 in [Rect2(-9000, -5200, 2600, 1500), Rect2(4200, -6400, 3200, 1800), Rect2(-4200, -7800, 2200, 1200)]:
			g.draw_rect(r, Color(0.44, 0.42, 0.42))
	var frame: Color = Color(0.82, 0.81, 0.78)
	g.draw_rect(Rect2(-w - 300, -g.TUN_H - 300, 300, g.TUN_H + 300), frame)
	g.draw_rect(Rect2(w, -g.TUN_H - 300, 300, g.TUN_H + 300), frame)
	g.draw_rect(Rect2(-w - 300, -g.TUN_H - 300, 2.0 * w + 600, 300), frame)
	g.draw_rect(Rect2(-w - 300, -g.TUN_H - 340, 2.0 * w + 600, 50), frame.darkened(0.25))
	g.draw_rect(Rect2(-1500, -g.TUN_H - 900, 3000, 480), Color(0.12, 0.36, 0.26))
	g.draw_rect(Rect2(-1500, -g.TUN_H - 900, 3000, 40), LINE_COL)
	var f: Font = g.font()
	if f:
		g.draw_string(f, Vector2(-1500, -g.TUN_H - 540), String(g.ZONE_NAMES[z]), HORIZONTAL_ALIGNMENT_CENTER, 3000, 200, LINE_COL)


# Portique : panneau vert de voie rapide, ou damier (départ, arrivée).
func _gantry(g: Node, text: String, checker: bool) -> void:
	var px: float = g.ROAD_W * 1.25
	var pole: Color = Color(0.62, 0.64, 0.66)
	g.draw_rect(Rect2(-px - 50.0, -2100, 100, 2100), pole)
	g.draw_rect(Rect2(px - 50.0, -2100, 100, 2100), pole)
	g.draw_rect(Rect2(-px - 50.0, -2180, 2.0 * px + 100.0, 90), pole.darkened(0.15))
	var w: float = 2.0 * px - 600.0
	g.draw_rect(Rect2(-w * 0.5, -2140, w, 520), INK if checker else Color(0.10, 0.38, 0.26))
	if checker:
		var cells: int = 24
		var cw: float = w / float(cells)
		for c in cells:
			g.draw_rect(Rect2(-w * 0.5 + float(c) * cw, -2140, cw, 60), LINE_COL if c % 2 == 0 else INK)
			g.draw_rect(Rect2(-w * 0.5 + float(c) * cw, -1680, cw, 60), INK if c % 2 == 0 else LINE_COL)
	else:
		g.draw_rect(Rect2(-w * 0.5 + 30.0, -2110, w - 60.0, 26), LINE_COL)
		g.draw_rect(Rect2(-w * 0.5 + 30.0, -1676, w - 60.0, 26), LINE_COL)
	var f: Font = g.font()
	if f:
		g.draw_string(f, Vector2(-w * 0.5, -1800), text, HORIZONTAL_ALIGNMENT_CENTER, w, 220, Color(1.0, 0.95, 0.70) if checker else LINE_COL)


# --- Décors (unités monde, origine au pied, x positif = loin de la route) ---

func _prop(g: Node, kind: int, v: int, i: int) -> void:
	match kind:
		Prop.PALM:
			var h: float = 1700.0 + float(v) * 160.0
			for k in 5:
				g.draw_rect(Rect2(-45.0 + float(k * k) * 9.0, -h * float(k + 1) / 5.0, 90.0 - float(k) * 8.0, h / 5.0 + 4.0),
					Color(0.55, 0.38, 0.22) if k % 2 == 0 else Color(0.45, 0.30, 0.17))
			var top: Vector2 = Vector2(150.0, -h)
			for a: float in [-3.0, -2.4, -1.8, -1.2, -0.6, -0.1, 0.4, 2.8]:
				var dir: Vector2 = Vector2.from_angle(a)
				var nrm: Vector2 = Vector2(-dir.y, dir.x) * 70.0
				var mid: Vector2 = top + dir * 380.0 + Vector2(0, -60)
				g.draw_colored_polygon(PackedVector2Array([top, mid + nrm, top + dir * 700.0 + Vector2(0, 260), mid - nrm]),
					Color(0.20, 0.55, 0.25) if dir.y < -0.2 else Color(0.14, 0.42, 0.20))
		Prop.LAMP:
			# v = 1 : les très hauts lampadaires de l'Aterro.
			var lh: float = 1500.0 if v == 0 else 2600.0
			g.draw_rect(Rect2(-22, -lh, 44, lh), Color(0.36, 0.38, 0.40))
			g.draw_rect(Rect2(-320, -lh, 320, 34), Color(0.36, 0.38, 0.40))
			g.draw_rect(Rect2(-340, -lh + 30, 130, 44), Color(1.0, 0.95, 0.72))
			if v == 1:
				g.draw_rect(Rect2(-200, -lh - 60, 400, 60), Color(0.30, 0.32, 0.34))
				g.draw_rect(Rect2(0, -lh + 30, 130, 44), Color(1.0, 0.95, 0.72))
		Prop.WAREHOUSE:
			# Armazém du port : pignon, grandes portes, fresque en aplats.
			g.draw_rect(Rect2(-1500, -1250, 3000, 1250), Color(0.86, 0.80, 0.68))
			g.draw_colored_polygon(PackedVector2Array([Vector2(-1560, -1250), Vector2(0, -1750), Vector2(1560, -1250)]), Color(0.66, 0.36, 0.26))
			g.draw_rect(Rect2(-1500, -1290, 3000, 50), Color(0.52, 0.28, 0.20))
			for k in 6:
				g.draw_rect(Rect2(-1400 + k * 470, -1150, 430, 760), MURAL[(k + v) % MURAL.size()])
				g.draw_rect(Rect2(-1320 + k * 470, -1000, 170, 300), MURAL[(k + v + 2) % MURAL.size()])
				g.draw_rect(Rect2(-1180 + k * 470, -640, 130, 200), Color(0.16, 0.14, 0.14))
			g.draw_rect(Rect2(-1500, -330, 3000, 60), Color(0.50, 0.46, 0.40))
		Prop.MUSEU:
			# Museu do Amanhã : longue coque blanche en porte-à-faux, arêtes en épi.
			var white: Color = Color(0.96, 0.96, 0.94)
			g.draw_colored_polygon(PackedVector2Array([Vector2(-3800, -380), Vector2(-2600, -900), Vector2(2600, -1050),
				Vector2(4400, -620), Vector2(2400, -380)]), white)
			g.draw_colored_polygon(PackedVector2Array([Vector2(-3800, -380), Vector2(2400, -380), Vector2(1600, -230), Vector2(-2400, -230)]), white.darkened(0.14))
			for k in 22:
				var fx: float = -2500.0 + float(k) * 235.0
				g.draw_colored_polygon(PackedVector2Array([Vector2(fx, -900 - float(k) * 7.0), Vector2(fx + 300, -1330 - float(k) * 9.0), Vector2(fx + 150, -900 - float(k) * 7.0)]), white)
				g.draw_rect(Rect2(fx, -880, 90, 420), Color(0.30, 0.42, 0.50))
			g.draw_rect(Rect2(-1700, -230, 3000, 230), Color(0.80, 0.80, 0.78))
			g.draw_rect(Rect2(-3000, -40, 6400, 40), Color(0.34, 0.56, 0.70))
		Prop.CRANE:
			var cr: Color = Color(0.85, 0.40, 0.18)
			g.draw_rect(Rect2(-90, -3200, 180, 3200), cr)
			g.draw_rect(Rect2(-1700, -3260, 2600, 130), cr)
			g.draw_rect(Rect2(-240, -3560, 480, 320), cr.darkened(0.2))
			g.draw_rect(Rect2(-1500, -3140, 20, 900), INK)
			g.draw_rect(Rect2(-1620, -2260, 260, 180), Color(0.20, 0.36, 0.62))
			g.draw_rect(Rect2(-500, -160, 1000, 160), cr.darkened(0.3))
		Prop.MAM:
			# MAM : la barre de béton de Reidy, portée par ses pórticos en V.
			var conc: Color = Color(0.80, 0.78, 0.74)
			g.draw_rect(Rect2(-3200, -1500, 6400, 620), conc)
			g.draw_rect(Rect2(-3200, -1500, 6400, 60), conc.lightened(0.12))
			g.draw_rect(Rect2(-3100, -1380, 6200, 300), Color(0.28, 0.36, 0.44))
			for k in 14:
				var rx: float = -3200.0 + float(k) * 492.0
				g.draw_colored_polygon(PackedVector2Array([Vector2(rx - 60, -1620), Vector2(rx + 60, -1620), Vector2(rx + 300, 0), Vector2(rx + 180, 0)]), conc.darkened(0.12))
				g.draw_colored_polygon(PackedVector2Array([Vector2(rx - 60, -880), Vector2(rx + 60, -880), Vector2(rx - 180, 0), Vector2(rx - 300, 0)]), conc.darkened(0.2))
			g.draw_rect(Rect2(-3300, -1640, 6600, 50), conc.darkened(0.25))
		Prop.TREE:
			var wide: float = 1.0 + float(v) * 0.14
			g.draw_rect(Rect2(-60, -700, 120, 700), Color(0.42, 0.28, 0.16))
			g.draw_rect(Rect2(-620 * wide, -1050, 1240 * wide, 300), Color(0.14, 0.42, 0.20))
			g.draw_rect(Rect2(-520 * wide, -1330, 1040 * wide, 300), Color(0.16, 0.46, 0.22))
			g.draw_rect(Rect2(-400 * wide, -1500, 800 * wide, 190), Color(0.22, 0.56, 0.26))
			g.draw_rect(Rect2(-380 * wide, -1240, 460 * wide, 130), Color(0.22, 0.56, 0.26))
		Prop.PRACINHAS:
			# Monumento aos Pracinhas : deux pylônes et la dalle haute.
			var st: Color = Color(0.86, 0.84, 0.78)
			g.draw_rect(Rect2(-1500, -260, 3000, 260), st.darkened(0.12))
			g.draw_rect(Rect2(-420, -3300, 260, 3040), st)
			g.draw_rect(Rect2(160, -3300, 260, 3040), st)
			g.draw_rect(Rect2(-700, -3440, 1400, 150), st.lightened(0.08))
			g.draw_rect(Rect2(-420, -3300, 60, 3040), st.darkened(0.18))
		Prop.BOAT:
			# Voilier au mouillage, qui danse sur l'eau.
			var bob: float = sin(g.t * 1.4 + float(i)) * 30.0
			g.draw_rect(Rect2(-380, -110 + bob, 760, 110), Color(0.96, 0.96, 0.94))
			g.draw_rect(Rect2(-380, -50 + bob, 760, 30), [Color(0.2, 0.4, 0.7), Color(0.8, 0.25, 0.2), Color(0.15, 0.5, 0.4)][v % 3])
			g.draw_rect(Rect2(-14, -1250 + bob, 28, 1150), Color(0.86, 0.84, 0.78))
			g.draw_colored_polygon(PackedVector2Array([Vector2(30, -1220 + bob), Vector2(30, -220 + bob), Vector2(520, -220 + bob)]), Color(0.98, 0.98, 0.96))
		Prop.BUILDING:
			var bw: float = 1500.0 + float(v % 3) * 260.0
			var bh: float = 2600.0 + float((v * 7 + i) % 5) * 520.0
			var col: Color = BUILD_COLS[v % BUILD_COLS.size()]
			g.draw_rect(Rect2(-bw * 0.5, -bh, bw, bh), col)
			g.draw_rect(Rect2(-bw * 0.5, -bh, 110, bh), col.darkened(0.14))
			var wy: float = -bh + 180.0
			while wy < -520.0:
				g.draw_rect(Rect2(-bw * 0.5 + 170.0, wy, bw - 280.0, 150), Color(0.30, 0.38, 0.48))
				g.draw_rect(Rect2(-bw * 0.5 + 170.0, wy + 150.0, bw - 280.0, 40), col.lightened(0.1))
				wy += 330.0
			g.draw_rect(Rect2(-bw * 0.5, -420, bw, 420), col.darkened(0.3))
			g.draw_rect(Rect2(-bw * 0.5 + 120.0, -360, bw - 240.0, 280), Color(0.20, 0.24, 0.30))
			g.draw_rect(Rect2(-bw * 0.5 - 40.0, -bh - 50.0, bw + 80.0, 60), col.darkened(0.2))
		Prop.RIOSUL:
			# Shopping Rio Sul : le socle du centre commercial (façade claire,
			# grande enseigne rouge, entrée vitrée, rampes du parking) et, plantée
			# dessus, la tour de bureaux en verre sombre.
			var glass: Color = Color(0.20, 0.26, 0.34)
			var f: Font = g.font()
			# La tour, en retrait.
			g.draw_rect(Rect2(300, -7600, 2100, 7600), glass)
			g.draw_rect(Rect2(300, -7600, 240, 7600), glass.darkened(0.25))
			var ry: float = -7400.0
			while ry < -2400.0:
				g.draw_rect(Rect2(560, ry, 1800, 40), Color(0.40, 0.50, 0.62))
				ry += 260.0
			for cx: float in [1000.0, 1500.0, 2000.0]:
				g.draw_rect(Rect2(cx, -7600, 30, 5300), Color(0.34, 0.42, 0.54))
			g.draw_rect(Rect2(800, -8100, 1100, 500), glass.lightened(0.1))
			g.draw_rect(Rect2(880, -8020, 940, 260), Color(0.78, 0.16, 0.16))
			if f:
				g.draw_string(f, Vector2(880, -7820), "RIOSUL", HORIZONTAL_ALIGNMENT_CENTER, 940, 180, LINE_COL)
			# Le socle : quatre niveaux de shopping.
			var wall: Color = Color(0.90, 0.88, 0.82)
			g.draw_rect(Rect2(-2700, -2300, 5400, 2300), wall)
			g.draw_rect(Rect2(-2700, -2300, 5400, 70), wall.lightened(0.1))
			g.draw_rect(Rect2(-2700, -2300, 200, 2300), wall.darkened(0.14))
			for lv in 3:
				g.draw_rect(Rect2(-2400, -2050 + lv * 420, 5000, 60), wall.darkened(0.18))
			# Rampes et niveaux du parking, à gauche.
			for lv2 in 4:
				g.draw_rect(Rect2(-2400, -1960 + lv2 * 420, 1400, 250), Color(0.24, 0.26, 0.30))
				g.draw_rect(Rect2(-2400, -1730 + lv2 * 420, 1400, 40), Color(0.98, 0.80, 0.20))
			# Grande enseigne rouge.
			g.draw_rect(Rect2(-700, -2180, 3100, 760), Color(0.80, 0.14, 0.14))
			g.draw_rect(Rect2(-700, -2180, 3100, 50), Color(0.95, 0.30, 0.26))
			if f:
				g.draw_string(f, Vector2(-700, -1600), "RIOSUL", HORIZONTAL_ALIGNMENT_CENTER, 3100, 560, LINE_COL)
			# Vitrines et entrée sous la marquise.
			g.draw_rect(Rect2(-800, -1250, 3300, 520), Color(0.30, 0.42, 0.54))
			for vx in 8:
				g.draw_rect(Rect2(-800 + vx * 412, -1250, 30, 520), wall.darkened(0.1))
			g.draw_rect(Rect2(-1000, -760, 3700, 110), Color(0.80, 0.14, 0.14))
			g.draw_rect(Rect2(-1000, -660, 3700, 40), Color(0.55, 0.10, 0.10))
			g.draw_rect(Rect2(-700, -640, 3100, 640), Color(0.16, 0.20, 0.26))
			for dx in 6:
				g.draw_rect(Rect2(-560 + dx * 500, -560, 380, 560), Color(0.42, 0.56, 0.68))
				g.draw_rect(Rect2(-380 + dx * 500, -560, 20, 560), Color(0.16, 0.20, 0.26))
			# Vasques de palmiers et fanions devant l'entrée.
			for px2: float in [-1400.0, -1900.0, 2900.0]:
				g.draw_rect(Rect2(px2 - 30.0, -900, 60, 900), Color(0.50, 0.36, 0.20))
				g.draw_rect(Rect2(px2 - 260.0, -1100, 520, 240), Color(0.18, 0.48, 0.22))
				g.draw_rect(Rect2(px2 - 180.0, -1240, 360, 160), Color(0.22, 0.56, 0.26))
		Prop.SOBRADO:
			# Sobrado de la zone portuaire : deux niveaux, platibanda, couleurs vives.
			var sc: Color = MURAL[v % MURAL.size()].lerp(Color(0.95, 0.92, 0.85), 0.45)
			g.draw_rect(Rect2(-800, -1500, 1600, 1500), sc)
			g.draw_rect(Rect2(-860, -1620, 1720, 130), Color(0.95, 0.93, 0.88))
			for k in 3:
				g.draw_rect(Rect2(-640 + k * 480, -1330, 320, 460), Color(0.24, 0.30, 0.36))
				g.draw_rect(Rect2(-640 + k * 480, -1380, 320, 50), Color(0.95, 0.93, 0.88))
				g.draw_rect(Rect2(-640 + k * 480, -640, 320, 640), Color(0.30, 0.22, 0.18))
			g.draw_rect(Rect2(-800, -760, 1600, 50), Color(0.95, 0.93, 0.88))


# --- Voitures vues de dos (origine au sol, au centre) ---

func _car(g: Node, kind: int, body: Color, brake: bool, nitro: bool) -> void:
	var tire: Color = Color(0.08, 0.08, 0.10)
	var glass: Color = Color(0.20, 0.28, 0.38)
	var red: Color = Color(1.0, 0.25, 0.18) if brake else Color(0.75, 0.12, 0.10)
	match kind:
		CarKind.RACER:
			g.draw_rect(Rect2(-360, -24, 720, 54), SHADOW)
			g.draw_rect(Rect2(-330, -120, 130, 120), tire)
			g.draw_rect(Rect2(200, -120, 130, 120), tire)
			g.draw_rect(Rect2(-320, -300, 640, 210), body)
			g.draw_rect(Rect2(-320, -300, 640, 40), body.lightened(0.18))
			g.draw_rect(Rect2(-250, -420, 500, 130), body.darkened(0.1))
			g.draw_rect(Rect2(-210, -400, 420, 90), glass)
			g.draw_rect(Rect2(-350, -470, 700, 34), INK)
			g.draw_rect(Rect2(-270, -440, 30, 60), INK)
			g.draw_rect(Rect2(240, -440, 30, 60), INK)
			g.draw_rect(Rect2(-310, -250, 130, 50), red)
			g.draw_rect(Rect2(180, -250, 130, 50), red)
			g.draw_rect(Rect2(-80, -190, 160, 56), LINE_COL)
			g.draw_rect(Rect2(-320, -110, 640, 30), body.darkened(0.35))
			g.draw_rect(Rect2(-210, -100, 70, 40), Color(0.45, 0.45, 0.48))
			g.draw_rect(Rect2(140, -100, 70, 40), Color(0.45, 0.45, 0.48))
			if nitro:
				for ex: float in [-175.0, 175.0]:
					g.draw_rect(Rect2(ex - 45.0, -110, 90, 70), Color(0.45, 0.75, 1.0))
					g.draw_rect(Rect2(ex - 25.0, -60, 50, 90), Color(0.85, 0.95, 1.0))
		CarKind.SEDAN, CarKind.TAXI:
			if kind == CarKind.TAXI:
				body = Color(0.98, 0.80, 0.12)
			g.draw_rect(Rect2(-340, -24, 680, 54), SHADOW)
			g.draw_rect(Rect2(-310, -120, 120, 120), tire)
			g.draw_rect(Rect2(190, -120, 120, 120), tire)
			g.draw_rect(Rect2(-310, -340, 620, 250), body)
			g.draw_rect(Rect2(-270, -530, 540, 200), body.darkened(0.08))
			g.draw_rect(Rect2(-230, -500, 460, 140), glass)
			g.draw_rect(Rect2(-300, -300, 120, 54), red)
			g.draw_rect(Rect2(180, -300, 120, 54), red)
			g.draw_rect(Rect2(-80, -210, 160, 56), LINE_COL)
			g.draw_rect(Rect2(-310, -120, 620, 34), INK.lightened(0.15))
			if kind == CarKind.TAXI:
				# Táxi carioca : jaune à faixa azul, luminoso sur le toit.
				g.draw_rect(Rect2(-310, -250, 620, 36), Color(0.12, 0.25, 0.62))
				g.draw_rect(Rect2(-70, -580, 140, 50), LINE_COL)
		CarKind.KOMBI:
			g.draw_rect(Rect2(-320, -24, 640, 54), SHADOW)
			g.draw_rect(Rect2(-290, -110, 110, 110), tire)
			g.draw_rect(Rect2(180, -110, 110, 110), tire)
			g.draw_rect(Rect2(-300, -700, 600, 620), Color(0.94, 0.94, 0.92))
			g.draw_rect(Rect2(-300, -380, 600, 300), body)
			g.draw_rect(Rect2(-240, -650, 480, 220), glass)
			g.draw_rect(Rect2(-12, -650, 24, 220), Color(0.94, 0.94, 0.92))
			g.draw_rect(Rect2(-290, -330, 90, 70), red)
			g.draw_rect(Rect2(200, -330, 90, 70), red)
			g.draw_rect(Rect2(-80, -200, 160, 56), LINE_COL)
		CarKind.BUS:
			g.draw_rect(Rect2(-460, -24, 920, 60), SHADOW)
			g.draw_rect(Rect2(-410, -130, 150, 130), tire)
			g.draw_rect(Rect2(260, -130, 150, 130), tire)
			g.draw_rect(Rect2(-430, -1060, 860, 960), Color(0.93, 0.93, 0.90))
			g.draw_rect(Rect2(-430, -520, 860, 150), body)
			g.draw_rect(Rect2(-430, -360, 860, 60), body.darkened(0.25))
			g.draw_rect(Rect2(-360, -960, 720, 360), glass)
			g.draw_rect(Rect2(-300, -1040, 600, 70), INK)
			g.draw_rect(Rect2(-250, -1028, 500, 46), Color(1.0, 0.72, 0.2))
			g.draw_rect(Rect2(-410, -300, 110, 80), red)
			g.draw_rect(Rect2(300, -300, 110, 80), red)
			g.draw_rect(Rect2(-80, -230, 160, 56), LINE_COL)
			g.draw_rect(Rect2(-430, -140, 860, 44), INK.lightened(0.15))
