class_name CharacterSpriteFactory

# Génère des sprites pixel-art procéduraux pour les personnages du jeu
# (NPCs scriptés + figurants décoratifs). Chaque sprite est une feuille
# 3 directions × 3 frames (16×24 px / cellule), composée à partir d'un
# Dictionary de config :
#
#   {
#     "skin": Color,          # teint de peau (3 options dans la palette)
#     "hair_color": Color,    # couleur des cheveux
#     "hair_style": String,   # "short", "medium", "long", "bun", "spiky", "bald"
#     "shirt_color": Color,
#     "shirt_pattern": String,# "solid", "stripe_h", "pocket"
#     "pants_color": Color,
#     "hat_style": String,    # "none", "cap", "fedora", "beret", "scarf"
#     "hat_color": Color,
#   }
#
# Une factory statique pour que tous les wanderers partagent un cache global
# de textures (clé = hash du config) — typiquement les 109 wanderers du jeu
# génèrent 30-50 textures uniques tout au plus.

# --- Palettes ---

const PALETTE_SKIN: Array[Color] = [
	Color(0.95, 0.82, 0.68, 1.0),   # clair (européen)
	Color(0.86, 0.70, 0.55, 1.0),   # médium-clair (latino)
	Color(0.65, 0.48, 0.32, 1.0),   # médium (mulato)
	Color(0.42, 0.28, 0.18, 1.0),   # foncé (afro-brésilien)
]

const PALETTE_HAIR_COLOR: Array[Color] = [
	Color(0.10, 0.08, 0.06, 1.0),   # noir
	Color(0.32, 0.20, 0.12, 1.0),   # brun foncé
	Color(0.55, 0.38, 0.22, 1.0),   # brun
	Color(0.85, 0.70, 0.42, 1.0),   # blond
	Color(0.78, 0.32, 0.12, 1.0),   # roux
	Color(0.65, 0.62, 0.58, 1.0),   # gris (âge)
]

const PALETTE_HAIR_STYLE: Array[String] = [
	"short", "medium", "long", "bun", "spiky", "bald",
]

const PALETTE_SHIRT_COLOR: Array[Color] = [
	Color(0.85, 0.55, 0.40, 1.0),   # rouge brique
	Color(0.40, 0.65, 0.95, 1.0),   # bleu ciel
	Color(0.55, 0.78, 0.55, 1.0),   # vert
	Color(0.95, 0.85, 0.40, 1.0),   # jaune
	Color(0.85, 0.78, 0.62, 1.0),   # beige
	Color(0.62, 0.42, 0.32, 1.0),   # marron
	Color(0.78, 0.42, 0.55, 1.0),   # rose
	Color(0.95, 0.95, 0.92, 1.0),   # blanc
	Color(0.22, 0.22, 0.28, 1.0),   # noir/sombre
]

const PALETTE_SHIRT_PATTERN: Array[String] = [
	"solid", "solid", "solid",   # solid plus probable (pondération naturelle)
	"stripe_h", "pocket",
]

const PALETTE_HAT_STYLE: Array[String] = [
	"none", "none", "none", "none",   # pas de chapeau dans la majorité
	"cap", "fedora", "beret", "scarf",
]

const PALETTE_HAT_COLOR: Array[Color] = [
	Color(0.18, 0.18, 0.22, 1.0),   # noir
	Color(0.42, 0.32, 0.22, 1.0),   # marron
	Color(0.92, 0.85, 0.55, 1.0),   # paille
	Color(0.85, 0.32, 0.32, 1.0),   # rouge
	Color(0.95, 0.95, 0.92, 1.0),   # blanc
]

const PALETTE_PANTS_COLOR: Array[Color] = [
	Color(0.30, 0.25, 0.20, 1.0),   # marron foncé
	Color(0.22, 0.30, 0.45, 1.0),   # bleu jean
	Color(0.18, 0.18, 0.22, 1.0),   # noir
	Color(0.50, 0.45, 0.40, 1.0),   # gris
	Color(0.85, 0.78, 0.62, 1.0),   # beige (short clair)
]

# --- Format sheet ---

const CELL_W: int = 64
const CELL_H: int = 96
const DIR_DOWN: int = 0
const DIR_UP: int = 1
const DIR_RIGHT: int = 2
const ROWS: int = 3
const COLS: int = 3   # idle, stepL, stepR

# Cache global ImageTexture par config-hash.
static var _cache: Dictionary = {}

# Configs explicites des NPCs scriptés majeurs. Chaque entrée fait que le
# personnage soit reconnaissable visuellement (Tito en chemise rouge favela,
# Ramos en uniforme PM, Contessa en long blond élégant, etc.). Pour tout
# NPC absent, on retombe sur random_config basé sur le hash de l'id.
const NAMED_NPC_CONFIGS: Dictionary = {
	# --- Famille / proches ---
	"seu_joao": {
		"skin": Color(0.86, 0.70, 0.55, 1.0),          # médium-clair, ridé
		"hair_color": Color(0.65, 0.62, 0.58, 1.0),    # gris
		"hair_style": "short",
		"shirt_color": Color(0.62, 0.42, 0.32, 1.0),   # marron usé
		"shirt_pattern": "solid",
		"pants_color": Color(0.30, 0.25, 0.20, 1.0),   # marron foncé
		"hat_style": "none",
		"hat_color": Color(0.42, 0.32, 0.22, 1.0),
	},
	"vovo": {
		"skin": Color(0.86, 0.70, 0.55, 1.0),
		"hair_color": Color(0.85, 0.85, 0.85, 1.0),    # blanc cheveux âgés
		"hair_style": "bun",
		"shirt_color": Color(0.42, 0.32, 0.42, 1.0),   # mauve sombre
		"shirt_pattern": "solid",
		"pants_color": Color(0.30, 0.25, 0.20, 1.0),
		"hat_style": "scarf",
		"hat_color": Color(0.55, 0.42, 0.55, 1.0),
	},
	"mae": {
		"skin": Color(0.86, 0.70, 0.55, 1.0),
		"hair_color": Color(0.32, 0.20, 0.12, 1.0),
		"hair_style": "long",
		"shirt_color": Color(0.95, 0.85, 0.40, 1.0),   # tablier jaune
		"shirt_pattern": "stripe_h",
		"pants_color": Color(0.42, 0.32, 0.22, 1.0),
		"hat_style": "none",
		"hat_color": Color(0.42, 0.32, 0.22, 1.0),
	},
	# --- Autorité ---
	"ramos": {
		"skin": Color(0.86, 0.70, 0.55, 1.0),
		"hair_color": Color(0.10, 0.08, 0.06, 1.0),
		"hair_style": "short",
		"shirt_color": Color(0.30, 0.42, 0.65, 1.0),   # bleu PM
		"shirt_pattern": "solid",
		"pants_color": Color(0.18, 0.22, 0.42, 1.0),
		"hat_style": "cap",
		"hat_color": Color(0.18, 0.22, 0.42, 1.0),
	},
	"pm": {
		"skin": Color(0.86, 0.70, 0.55, 1.0),
		"hair_color": Color(0.10, 0.08, 0.06, 1.0),
		"hair_style": "short",
		"shirt_color": Color(0.30, 0.42, 0.65, 1.0),
		"shirt_pattern": "solid",
		"pants_color": Color(0.18, 0.22, 0.42, 1.0),
		"hat_style": "cap",
		"hat_color": Color(0.18, 0.22, 0.42, 1.0),
	},
	"policier": {
		"skin": Color(0.65, 0.48, 0.32, 1.0),
		"hair_color": Color(0.10, 0.08, 0.06, 1.0),
		"hair_style": "short",
		"shirt_color": Color(0.30, 0.42, 0.65, 1.0),
		"shirt_pattern": "solid",
		"pants_color": Color(0.18, 0.22, 0.42, 1.0),
		"hat_style": "cap",
		"hat_color": Color(0.18, 0.22, 0.42, 1.0),
	},
	# --- Tráfico / favela ---
	"tito": {
		"skin": Color(0.42, 0.28, 0.18, 1.0),          # foncé
		"hair_color": Color(0.10, 0.08, 0.06, 1.0),
		"hair_style": "short",
		"shirt_color": Color(0.85, 0.32, 0.22, 1.0),   # rouge bandana favela
		"shirt_pattern": "solid",
		"pants_color": Color(0.22, 0.30, 0.45, 1.0),   # jean
		"hat_style": "scarf",
		"hat_color": Color(0.85, 0.32, 0.22, 1.0),
	},
	"miguel": {
		"skin": Color(0.42, 0.28, 0.18, 1.0),
		"hair_color": Color(0.10, 0.08, 0.06, 1.0),
		"hair_style": "spiky",
		"shirt_color": Color(0.85, 0.78, 0.62, 1.0),   # beige discret
		"shirt_pattern": "pocket",
		"pants_color": Color(0.22, 0.30, 0.45, 1.0),
		"hat_style": "cap",
		"hat_color": Color(0.42, 0.32, 0.22, 1.0),
	},
	# --- Consortium / luxe ---
	"consortium": {
		"skin": Color(0.86, 0.70, 0.55, 1.0),
		"hair_color": Color(0.55, 0.38, 0.22, 1.0),
		"hair_style": "short",
		"shirt_color": Color(0.95, 0.95, 0.92, 1.0),   # chemise blanche costume
		"shirt_pattern": "solid",
		"pants_color": Color(0.18, 0.18, 0.22, 1.0),
		"hat_style": "fedora",
		"hat_color": Color(0.18, 0.18, 0.22, 1.0),
	},
	"jorge": {
		"skin": Color(0.42, 0.28, 0.18, 1.0),
		"hair_color": Color(0.10, 0.08, 0.06, 1.0),
		"hair_style": "bald",
		"shirt_color": Color(0.18, 0.18, 0.22, 1.0),
		"shirt_pattern": "solid",
		"pants_color": Color(0.18, 0.18, 0.22, 1.0),
		"hat_style": "none",
		"hat_color": Color(0.18, 0.18, 0.22, 1.0),
	},
	# --- Commerce / quartier ---
	"carlos": {
		"skin": Color(0.65, 0.48, 0.32, 1.0),
		"hair_color": Color(0.32, 0.20, 0.12, 1.0),
		"hair_style": "short",
		"shirt_color": Color(0.85, 0.78, 0.62, 1.0),   # tablier beige café
		"shirt_pattern": "solid",
		"pants_color": Color(0.22, 0.30, 0.45, 1.0),
		"hat_style": "none",
		"hat_color": Color(0.42, 0.32, 0.22, 1.0),
	},
	"padeiro": {
		"skin": Color(0.86, 0.70, 0.55, 1.0),
		"hair_color": Color(0.78, 0.32, 0.12, 1.0),    # roux
		"hair_style": "medium",
		"shirt_color": Color(0.95, 0.95, 0.92, 1.0),   # blanc boulanger
		"shirt_pattern": "stripe_h",
		"pants_color": Color(0.50, 0.45, 0.40, 1.0),   # gris
		"hat_style": "scarf",
		"hat_color": Color(0.95, 0.95, 0.92, 1.0),
	},
	"chef_restaurant": {
		"skin": Color(0.95, 0.82, 0.68, 1.0),
		"hair_color": Color(0.10, 0.08, 0.06, 1.0),
		"hair_style": "short",
		"shirt_color": Color(0.95, 0.95, 0.92, 1.0),
		"shirt_pattern": "solid",
		"pants_color": Color(0.18, 0.18, 0.22, 1.0),
		"hat_style": "scarf",                          # toque-like
		"hat_color": Color(0.95, 0.95, 0.92, 1.0),
	},
	"farmaceutico": {
		"skin": Color(0.95, 0.82, 0.68, 1.0),
		"hair_color": Color(0.55, 0.38, 0.22, 1.0),
		"hair_style": "long",
		"shirt_color": Color(0.95, 0.95, 0.92, 1.0),
		"shirt_pattern": "solid",
		"pants_color": Color(0.18, 0.22, 0.42, 1.0),
		"hat_style": "none",
		"hat_color": Color(0.42, 0.32, 0.22, 1.0),
	},
	"vendeuse_boutique": {
		"skin": Color(0.86, 0.70, 0.55, 1.0),
		"hair_color": Color(0.32, 0.20, 0.12, 1.0),
		"hair_style": "long",
		"shirt_color": Color(0.78, 0.42, 0.55, 1.0),   # rose élégant
		"shirt_pattern": "solid",
		"pants_color": Color(0.55, 0.22, 0.42, 1.0),
		"hat_style": "none",
		"hat_color": Color(0.85, 0.55, 0.40, 1.0),
	},
	"otavio": {
		"skin": Color(0.95, 0.82, 0.68, 1.0),
		"hair_color": Color(0.10, 0.08, 0.06, 1.0),
		"hair_style": "short",
		"shirt_color": Color(0.55, 0.32, 0.18, 1.0),   # uniforme bordeaux palace
		"shirt_pattern": "solid",
		"pants_color": Color(0.18, 0.14, 0.10, 1.0),
		"hat_style": "cap",
		"hat_color": Color(0.55, 0.32, 0.18, 1.0),
	},
	"concierge": {
		# C'est tio Zé en disguise — même couleurs que seu_joao mais en uniforme.
		"skin": Color(0.86, 0.70, 0.55, 1.0),
		"hair_color": Color(0.65, 0.62, 0.58, 1.0),    # gris
		"hair_style": "short",
		"shirt_color": Color(0.55, 0.32, 0.18, 1.0),   # uniforme palace
		"shirt_pattern": "solid",
		"pants_color": Color(0.18, 0.14, 0.10, 1.0),
		"hat_style": "cap",
		"hat_color": Color(0.55, 0.32, 0.18, 1.0),
	},
	"bar_patrao": {
		"skin": Color(0.65, 0.48, 0.32, 1.0),
		"hair_color": Color(0.10, 0.08, 0.06, 1.0),
		"hair_style": "short",
		"shirt_color": Color(0.95, 0.95, 0.92, 1.0),
		"shirt_pattern": "solid",
		"pants_color": Color(0.30, 0.25, 0.20, 1.0),
		"hat_style": "none",
		"hat_color": Color(0.42, 0.32, 0.22, 1.0),
	},
	"ze_bar": {
		"skin": Color(0.65, 0.48, 0.32, 1.0),
		"hair_color": Color(0.10, 0.08, 0.06, 1.0),
		"hair_style": "short",
		"shirt_color": Color(0.95, 0.95, 0.92, 1.0),
		"shirt_pattern": "solid",
		"pants_color": Color(0.30, 0.25, 0.20, 1.0),
		"hat_style": "none",
		"hat_color": Color(0.42, 0.32, 0.22, 1.0),
	},
	# --- Religion / culture ---
	"padre": {
		"skin": Color(0.95, 0.82, 0.68, 1.0),
		"hair_color": Color(0.65, 0.62, 0.58, 1.0),
		"hair_style": "bald",
		"shirt_color": Color(0.18, 0.18, 0.22, 1.0),   # robe noire
		"shirt_pattern": "solid",
		"pants_color": Color(0.18, 0.18, 0.22, 1.0),
		"hat_style": "none",
		"hat_color": Color(0.18, 0.18, 0.22, 1.0),
	},
	"musicien": {
		"skin": Color(0.42, 0.28, 0.18, 1.0),
		"hair_color": Color(0.10, 0.08, 0.06, 1.0),
		"hair_style": "long",
		"shirt_color": Color(0.85, 0.55, 0.40, 1.0),
		"shirt_pattern": "stripe_h",
		"pants_color": Color(0.22, 0.30, 0.45, 1.0),
		"hat_style": "fedora",
		"hat_color": Color(0.42, 0.32, 0.22, 1.0),
	},
	# --- Étrangers / luxe ---
	"contessa": {
		"skin": Color(0.95, 0.82, 0.68, 1.0),
		"hair_color": Color(0.85, 0.70, 0.42, 1.0),    # blond
		"hair_style": "long",
		"shirt_color": Color(0.85, 0.32, 0.55, 1.0),   # rose élégant
		"shirt_pattern": "solid",
		"pants_color": Color(0.55, 0.22, 0.42, 1.0),
		"hat_style": "none",
		"hat_color": Color(0.95, 0.95, 0.92, 1.0),
	},
	"tourist_vip": {
		"skin": Color(0.95, 0.82, 0.68, 1.0),
		"hair_color": Color(0.85, 0.70, 0.42, 1.0),
		"hair_style": "short",
		"shirt_color": Color(0.40, 0.65, 0.95, 1.0),   # chemise hawaïenne bleue
		"shirt_pattern": "stripe_h",
		"pants_color": Color(0.85, 0.78, 0.62, 1.0),   # short clair
		"hat_style": "cap",
		"hat_color": Color(0.95, 0.95, 0.92, 1.0),
	},
	"customer_tourist": {
		"skin": Color(0.95, 0.82, 0.68, 1.0),
		"hair_color": Color(0.55, 0.38, 0.22, 1.0),
		"hair_style": "short",
		"shirt_color": Color(0.95, 0.85, 0.40, 1.0),
		"shirt_pattern": "solid",
		"pants_color": Color(0.85, 0.78, 0.62, 1.0),
		"hat_style": "cap",
		"hat_color": Color(0.95, 0.85, 0.40, 1.0),
	},
	"customer_local": {
		"skin": Color(0.65, 0.48, 0.32, 1.0),
		"hair_color": Color(0.10, 0.08, 0.06, 1.0),
		"hair_style": "short",
		"shirt_color": Color(0.55, 0.78, 0.55, 1.0),
		"shirt_pattern": "solid",
		"pants_color": Color(0.22, 0.30, 0.45, 1.0),
		"hat_style": "none",
		"hat_color": Color(0.42, 0.32, 0.22, 1.0),
	},
	"customer_kid": {
		"skin": Color(0.86, 0.70, 0.55, 1.0),
		"hair_color": Color(0.32, 0.20, 0.12, 1.0),
		"hair_style": "spiky",
		"shirt_color": Color(0.95, 0.85, 0.40, 1.0),
		"shirt_pattern": "stripe_h",
		"pants_color": Color(0.85, 0.78, 0.62, 1.0),
		"hat_style": "none",
		"hat_color": Color(0.85, 0.85, 0.40, 1.0),
	},
	# --- Pêche / mer ---
	"pecheur": {
		"skin": Color(0.65, 0.48, 0.32, 1.0),
		"hair_color": Color(0.65, 0.62, 0.58, 1.0),
		"hair_style": "short",
		"shirt_color": Color(0.40, 0.65, 0.95, 1.0),
		"shirt_pattern": "stripe_h",
		"pants_color": Color(0.42, 0.32, 0.22, 1.0),
		"hat_style": "scarf",
		"hat_color": Color(0.42, 0.32, 0.22, 1.0),
	},
	"coconut_vendor": {
		"skin": Color(0.42, 0.28, 0.18, 1.0),
		"hair_color": Color(0.10, 0.08, 0.06, 1.0),
		"hair_style": "short",
		"shirt_color": Color(0.55, 0.78, 0.55, 1.0),
		"shirt_pattern": "solid",
		"pants_color": Color(0.85, 0.78, 0.62, 1.0),
		"hat_style": "scarf",
		"hat_color": Color(0.95, 0.95, 0.92, 1.0),
	},
	# --- Autres ---
	"joggeur": {
		"skin": Color(0.86, 0.70, 0.55, 1.0),
		"hair_color": Color(0.32, 0.20, 0.12, 1.0),
		"hair_style": "short",
		"shirt_color": Color(0.55, 0.78, 0.55, 1.0),   # tank vert sport
		"shirt_pattern": "solid",
		"pants_color": Color(0.22, 0.30, 0.45, 1.0),
		"hat_style": "none",
		"hat_color": Color(0.85, 0.55, 0.40, 1.0),
	},
	"dona_irene": {
		"skin": Color(0.95, 0.82, 0.68, 1.0),
		"hair_color": Color(0.85, 0.85, 0.85, 1.0),
		"hair_style": "bun",
		"shirt_color": Color(0.78, 0.42, 0.55, 1.0),
		"shirt_pattern": "solid",
		"pants_color": Color(0.42, 0.32, 0.42, 1.0),
		"hat_style": "scarf",
		"hat_color": Color(0.85, 0.55, 0.40, 1.0),
	},
}

# Renvoie la config explicite pour un NPC scénarisé connu, sinon une config
# aléatoire stable (basée sur le hash de l'id) — toujours déterministe pour
# qu'un NPC ait toujours la même apparence.
static func config_for_npc(npc_id: String) -> Dictionary:
	if NAMED_NPC_CONFIGS.has(npc_id):
		return NAMED_NPC_CONFIGS[npc_id]
	return random_config(npc_id.hash())

# Tire une config aléatoire reproductible à partir d'une seed (typiquement
# `node.name.hash()` pour stabilité entre runs). Garantit que le même NPC
# garde la même apparence si on relance le jeu, sans avoir à sérialiser.
static func random_config(seed_value: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return {
		"skin": _pick(rng, PALETTE_SKIN),
		"hair_color": _pick(rng, PALETTE_HAIR_COLOR),
		"hair_style": _pick(rng, PALETTE_HAIR_STYLE),
		"shirt_color": _pick(rng, PALETTE_SHIRT_COLOR),
		"shirt_pattern": _pick(rng, PALETTE_SHIRT_PATTERN),
		"pants_color": _pick(rng, PALETTE_PANTS_COLOR),
		"hat_style": _pick(rng, PALETTE_HAT_STYLE),
		"hat_color": _pick(rng, PALETTE_HAT_COLOR),
	}

static func _pick(rng: RandomNumberGenerator, arr: Array) -> Variant:
	return arr[rng.randi() % arr.size()]

# --- Couche éditeur (création de perso joueur) ---
#
# L'éditeur manipule des INDICES (int) dans des listes propres, pas des Color :
# ça se sérialise trivialement en JSON et reste lisible dans la save. Les
# listes EDITOR_* sont dédupliquées (les PALETTE_* portaient des doublons de
# pondération pour le random — inadaptés à un cycle UI).

const EDITOR_SHIRT_PATTERNS: Array[String] = ["solid", "stripe_h", "pocket"]
const EDITOR_HAT_STYLES: Array[String] = ["none", "cap", "fedora", "beret", "scarf"]

# Ordre d'affichage des attributs dans l'éditeur.
const ATTRIBUTES: Array[String] = [
	"skin", "hair_style", "hair_color",
	"shirt_color", "shirt_pattern",
	"pants_color", "hat_style", "hat_color",
]

const ATTRIBUTE_LABELS: Dictionary = {
	"skin": "Pele",
	"hair_style": "Cabelo",
	"hair_color": "Cor do cabelo",
	"shirt_color": "Camisa",
	"shirt_pattern": "Estampa",
	"pants_color": "Calça",
	"hat_style": "Chapéu",
	"hat_color": "Cor do chapéu",
}

# Libellés FR/PT-BR par valeur, alignés sur l'ordre des PALETTE_* / EDITOR_*.
const VALUE_LABELS: Dictionary = {
	"skin": ["Clara", "Morena clara", "Morena", "Negra"],
	"hair_color": ["Preto", "Castanho escuro", "Castanho", "Loiro", "Ruivo", "Grisalho"],
	"hair_style": ["Curto", "Médio", "Longo", "Coque", "Espetado", "Careca"],
	"shirt_color": ["Vermelho", "Azul", "Verde", "Amarelo", "Bege", "Marrom", "Rosa", "Branco", "Preto"],
	"shirt_pattern": ["Liso", "Listrado", "Bolso"],
	"pants_color": ["Marrom", "Jeans", "Preto", "Cinza", "Bege"],
	"hat_style": ["Nenhum", "Boné", "Fedora", "Boina", "Lenço"],
	"hat_color": ["Preto", "Marrom", "Palha", "Vermelho", "Branco"],
}

# Apparence par défaut du joueur (sobrinho carioca lambda) — indices.
const DEFAULT_INDICES: Dictionary = {
	"skin": 1,           # morena clara
	"hair_style": 0,     # curto
	"hair_color": 1,     # castanho escuro
	"shirt_color": 1,    # azul
	"shirt_pattern": 0,  # liso
	"pants_color": 1,    # jeans
	"hat_style": 0,      # nenhum
	"hat_color": 0,      # preto
}

# Nombre d'options sélectionnables pour un attribut donné.
static func option_count(attr: String) -> int:
	match attr:
		"skin":          return PALETTE_SKIN.size()
		"hair_color":    return PALETTE_HAIR_COLOR.size()
		"hair_style":    return PALETTE_HAIR_STYLE.size()
		"shirt_color":   return PALETTE_SHIRT_COLOR.size()
		"shirt_pattern": return EDITOR_SHIRT_PATTERNS.size()
		"pants_color":   return PALETTE_PANTS_COLOR.size()
		"hat_style":     return EDITOR_HAT_STYLES.size()
		"hat_color":     return PALETTE_HAT_COLOR.size()
	return 1

# Renvoie une copie des indices par défaut.
static func default_indices() -> Dictionary:
	return DEFAULT_INDICES.duplicate(true)

# Nettoie un dict d'indices : remplit les clés manquantes avec le défaut et
# borne chaque valeur dans [0, option_count). Résilient aux saves partielles.
static func sanitize_indices(idx: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for attr in ATTRIBUTES:
		var n: int = option_count(attr)
		var v: int = int(idx.get(attr, DEFAULT_INDICES.get(attr, 0)))
		out[attr] = clampi(v, 0, n - 1)
	return out

# Construit une config factory (Color/String) à partir d'indices.
static func config_from_indices(idx: Dictionary) -> Dictionary:
	var s: Dictionary = sanitize_indices(idx)
	return {
		"skin": PALETTE_SKIN[s["skin"]],
		"hair_color": PALETTE_HAIR_COLOR[s["hair_color"]],
		"hair_style": PALETTE_HAIR_STYLE[s["hair_style"]],
		"shirt_color": PALETTE_SHIRT_COLOR[s["shirt_color"]],
		"shirt_pattern": EDITOR_SHIRT_PATTERNS[s["shirt_pattern"]],
		"pants_color": PALETTE_PANTS_COLOR[s["pants_color"]],
		"hat_style": EDITOR_HAT_STYLES[s["hat_style"]],
		"hat_color": PALETTE_HAT_COLOR[s["hat_color"]],
	}

# Libellé lisible d'une valeur d'attribut (pour l'UI de l'éditeur).
static func value_label(attr: String, i: int) -> String:
	var labels: Array = VALUE_LABELS.get(attr, [])
	if i >= 0 and i < labels.size():
		return String(labels[i])
	return str(i)

# Tire des indices aléatoires (pour le bouton « Aleatório » de l'éditeur).
static func random_indices(seed_value: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Dictionary = {}
	for attr in ATTRIBUTES:
		out[attr] = rng.randi() % option_count(attr)
	return out

# Construit (ou récupère du cache) une feuille 3×3 pour la config donnée.
static func build_sheet(config: Dictionary) -> ImageTexture:
	var key: int = _config_hash(config)
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create(CELL_W * COLS, CELL_H * ROWS, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for dir in ROWS:
		for frame in COLS:
			_draw_cell(img, frame * CELL_W, dir * CELL_H, dir, frame, config)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

static func _config_hash(config: Dictionary) -> int:
	# Concat texte stable + hash. Suffisant pour ~30-50 combos uniques.
	var parts: Array = []
	for k in ["skin", "hair_color", "hair_style", "shirt_color",
			"shirt_pattern", "pants_color", "hat_style", "hat_color"]:
		parts.append(str(config.get(k, "")))
	return "|".join(parts).hash()

# Dessine une cellule 64×96 à l'offset (ox, oy) pour la direction `dir`
# (0=DOWN, 1=UP, 2=RIGHT) et le frame de marche `frame` (0=idle, 1=pas G,
# 2=pas D). Silhouette arrondie (ellipses / rects à coins ronds), ombrage
# multi-tons (lumière haut-gauche + occlusion aux jonctions), contour doux —
# pensé pour un affichage filtré LINEAR (rendu illustré, non pixelisé).
# Repère vertical (sur 96 px) : 8..46 tête · 44..52 cou · 50..76 torse ·
# 74..94 jambes.
static func _draw_cell(img: Image, ox: int, oy: int, dir: int, frame: int, c: Dictionary) -> void:
	var skin: Color = c.get("skin", Color(0.92, 0.78, 0.62))
	var hair_color: Color = c.get("hair_color", Color(0.18, 0.12, 0.08))
	var hair_style: String = c.get("hair_style", "short")
	var shirt: Color = c.get("shirt_color", Color(0.85, 0.55, 0.4))
	var shirt_pattern: String = c.get("shirt_pattern", "solid")
	var pants: Color = c.get("pants_color", Color(0.30, 0.25, 0.20))
	var hat_style: String = c.get("hat_style", "none")
	var hat_color: Color = c.get("hat_color", Color(0.18, 0.18, 0.22))

	var line: Color = Color(0.10, 0.07, 0.10, 1.0)
	var skin_sh: Color = skin.darkened(0.15)
	var skin_sh2: Color = skin.darkened(0.30)
	var skin_hi: Color = skin.lightened(0.12)
	var shirt_sh: Color = shirt.darkened(0.18)
	var shirt_sh2: Color = shirt.darkened(0.34)
	var shirt_hi: Color = shirt.lightened(0.12)
	var pants_sh: Color = pants.darkened(0.20)
	var pants_sh2: Color = pants.darkened(0.36)
	var face_visible: bool = (dir != DIR_UP)

	# Marche : une jambe levée/avancée, léger contre-balancement de buste.
	var lift_l: int = 0
	var lift_r: int = 0
	var bob: int = 0
	if frame == 1:
		lift_l = 4
		bob = 1
	elif frame == 2:
		lift_r = 4
		bob = 1

	# --- Jambes (sous le torse) ---
	_rrect_o(img, ox + 24, oy + 74 - bob, 7, 21 - lift_l, pants, line, 2)
	_fill_rect(img, ox + 28, oy + 76 - bob, 2, 16 - lift_l, pants_sh)
	_rrect_o(img, ox + 33, oy + 74 - bob, 7, 21 - lift_r, pants, line, 2)
	_fill_rect(img, ox + 37, oy + 76 - bob, 2, 16 - lift_r, pants_sh)
	# chaussures (plus larges, sombres)
	_rrect_o(img, ox + 22, oy + 92 - lift_l, 10, 4, pants_sh2, line, 2)
	_rrect_o(img, ox + 33, oy + 92 - lift_r, 10, 4, pants_sh2, line, 2)

	# --- Bras (derrière le torse) + mains ---
	var swing: int = 0
	if frame == 1: swing = 1
	elif frame == 2: swing = -1
	_rrect_o(img, ox + 12, oy + 50 - bob + swing, 8, 22, shirt_sh, line, 3)
	_rrect_o(img, ox + 44, oy + 50 - bob - swing, 8, 22, shirt_sh, line, 3)
	_disc_o(img, ox + 16, oy + 73 - bob + swing, 4, 4, skin, line)
	_disc_o(img, ox + 48, oy + 73 - bob - swing, 4, 4, skin_sh, line)

	# --- Torse / chemise (épaules larges, taille resserrée) ---
	_rrect_o(img, ox + 17, oy + 49 - bob, 30, 28, shirt, line, 7)
	_fill_rect(img, ox + 40, oy + 52 - bob, 5, 22, shirt_sh)    # flanc droit
	_fill_rect(img, ox + 19, oy + 52 - bob, 2, 22, shirt_hi)    # bord gauche
	_fill_rect(img, ox + 22, oy + 49 - bob, 20, 3, shirt_sh2)   # occlusion col
	_draw_shirt_pattern(img, ox, oy - bob, shirt_pattern, shirt)

	# --- Cou ---
	if face_visible:
		_rrect_o(img, ox + 26, oy + 40, 12, 11, skin, line, 2)
		_fill_rect(img, ox + 26, oy + 47, 12, 3, skin_sh2)  # ombre portée menton

	# --- Tête (ellipse arrondie, 3 tons) ---
	var head_main: Color = skin if face_visible else hair_color
	var hcx: int = ox + 32
	var hcy: int = oy + 27
	_disc_o(img, hcx, hcy, 16, 19, head_main, line)
	if face_visible:
		# modelé : flanc droit ombré, joue gauche éclairée, occlusion bas.
		_disc(img, hcx + 6, hcy + 1, 9, 17, skin_sh)
		_disc(img, hcx + 9, hcy + 2, 6, 15, skin_sh2)
		_disc(img, hcx - 8, hcy - 2, 5, 12, skin_hi)
		_disc(img, hcx, hcy + 14, 12, 6, skin_sh)   # mâchoire ombrée
		# oreilles
		_disc_o(img, hcx - 16, hcy + 2, 3, 4, skin, line)
		_disc_o(img, hcx + 16, hcy + 2, 3, 4, skin_sh, line)

	# --- Visage ---
	var white: Color = Color(0.97, 0.97, 0.94)
	var iris: Color = Color(0.28, 0.20, 0.14)
	var mouth: Color = skin.darkened(0.42)
	if dir == DIR_DOWN:
		# yeux
		_disc(img, hcx - 7, hcy - 1, 4, 3, white)
		_disc(img, hcx + 7, hcy - 1, 4, 3, white)
		_disc(img, hcx - 6, hcy - 1, 2, 2, iris)
		_disc(img, hcx + 8, hcy - 1, 2, 2, iris)
		img.set_pixel(hcx - 7, hcy - 2, white)        # éclat
		img.set_pixel(hcx + 7, hcy - 2, white)
		# sourcils
		_fill_rect(img, hcx - 10, hcy - 7, 7, 2, hair_color)
		_fill_rect(img, hcx + 4, hcy - 7, 7, 2, hair_color)
		# nez (arête claire + ombre droite)
		_fill_rect(img, hcx - 1, hcy + 1, 2, 7, skin_hi)
		_fill_rect(img, hcx + 1, hcy + 3, 2, 5, skin_sh2)
		# bouche (léger sourire) + lèvre éclairée dessous
		_fill_rect(img, hcx - 6, hcy + 11, 12, 2, mouth)
		img.set_pixel(hcx - 7, hcy + 10, mouth)
		img.set_pixel(hcx + 6, hcy + 10, mouth)
		_fill_rect(img, hcx - 5, hcy + 13, 10, 1, skin_hi)
	elif dir == DIR_RIGHT:
		# profil tourné vers +x : nez saillant, un œil, bouche courte
		_disc(img, hcx + 13, hcy + 2, 4, 6, skin)        # bombé du nez/joue
		_fill_rect(img, hcx + 16, hcy + 1, 3, 3, skin)   # pointe du nez
		img.set_pixel(hcx + 18, hcy + 3, line)
		_disc(img, hcx + 5, hcy - 1, 3, 3, white)
		_disc(img, hcx + 6, hcy - 1, 2, 2, iris)
		_fill_rect(img, hcx + 2, hcy - 7, 7, 2, hair_color)
		_fill_rect(img, hcx + 8, hcy + 11, 7, 2, mouth)
		_disc_o(img, hcx - 11, hcy + 2, 3, 4, skin_sh, line)  # oreille arrière

	# --- Cheveux (par-dessus la tête) ---
	_draw_hair(img, ox, oy, dir, hair_style, hair_color)

	# --- Chapeau ---
	_draw_hat(img, ox, oy, dir, hat_style, hat_color, line)

# --- Helpers de dessin ---

static func _fill_rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and xx < img.get_width() and yy >= 0 and yy < img.get_height():
				img.set_pixel(xx, yy, c)

# Ellipse pleine centrée (cx, cy), demi-axes (rx, ry).
static func _disc(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	if rx <= 0 or ry <= 0:
		return
	for yy in range(cy - ry, cy + ry + 1):
		var ny: float = float(yy - cy) / float(ry)
		if absf(ny) > 1.0:
			continue
		var hw: int = int(round(sqrt(maxf(0.0, 1.0 - ny * ny)) * float(rx)))
		_fill_rect(img, cx - hw, yy, hw * 2 + 1, 1, c)

# Ellipse `fill` avec contour 1 px `line` (dessine la ligne légèrement plus
# large puis le remplissage par-dessus).
static func _disc_o(img: Image, cx: int, cy: int, rx: int, ry: int, fill: Color, line: Color) -> void:
	_disc(img, cx, cy, rx + 1, ry + 1, line)
	_disc(img, cx, cy, rx, ry, fill)

# Rectangle à coins arrondis (rayon r).
static func _rrect(img: Image, x: int, y: int, w: int, h: int, c: Color, r: int) -> void:
	if w <= 0 or h <= 0:
		return
	r = clampi(r, 0, mini(w, h) / 2)
	for yy in range(h):
		for xx in range(w):
			var dx: int = 0
			var dy: int = 0
			if xx < r: dx = r - xx
			elif xx >= w - r: dx = xx - (w - r - 1)
			if yy < r: dy = r - yy
			elif yy >= h - r: dy = yy - (h - r - 1)
			if dx * dx + dy * dy <= r * r:
				var px: int = x + xx
				var py: int = y + yy
				if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
					img.set_pixel(px, py, c)

# Rect arrondi `fill` + contour 1 px `line`.
static func _rrect_o(img: Image, x: int, y: int, w: int, h: int, fill: Color, line: Color, r: int) -> void:
	if w <= 0 or h <= 0:
		return
	_rrect(img, x, y, w, h, line, r)
	if w > 2 and h > 2:
		_rrect(img, x + 1, y + 1, w - 2, h - 2, fill, maxi(1, r - 1))

# Calotte de cheveux : ellipse remplie mais bornée à `max_y` (les rangées
# sous le front ne sont PAS peintes → le visage reste visible). Aucun
# effacement transparent : on ne peint que des pixels opaques.
static func _hair_cap(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color, max_y: int) -> void:
	if rx <= 0 or ry <= 0:
		return
	for yy in range(cy - ry, mini(cy + ry, max_y) + 1):
		var ny: float = float(yy - cy) / float(ry)
		if absf(ny) > 1.0:
			continue
		var hw: int = int(round(sqrt(maxf(0.0, 1.0 - ny * ny)) * float(rx)))
		_fill_rect(img, cx - hw, yy, hw * 2 + 1, 1, c)

# Cheveux posés PAR-DESSUS la tête. Tête centrée x≈32 (cy≈oy+27), sourcils
# à y≈oy+20, yeux à y≈oy+26. La calotte est bornée au front (FH) : elle ne
# descend jamais sur le visage. Les mèches latérales longent les tempes
# (x16..20 / x44..48), hors de la zone des yeux (x25..43).
static func _draw_hair(img: Image, ox: int, oy: int, dir: int, style: String, c: Color) -> void:
	if style == "bald":
		return
	var hi: Color = c.lightened(0.26)
	var sh: Color = c.darkened(0.26)
	var cx: int = ox + 32
	var fh: int = oy + 19  # ligne de front (bas de la calotte, au-dessus des sourcils)

	if dir == DIR_UP:
		# De dos : tout le crâne est chevelu, pas de visage à préserver.
		_disc(img, cx, oy + 27, 18, 21, c)
		_disc(img, cx + 7, oy + 28, 9, 16, sh)
		_disc(img, cx - 7, oy + 18, 6, 9, hi)
	elif style != "spiky":
		_hair_cap(img, cx, oy + 26, 18, 20, c, fh)
		_hair_cap(img, cx - 6, oy + 20, 8, 12, hi, fh - 4)   # reflet
		_hair_cap(img, cx + 9, oy + 22, 6, 12, sh, fh)       # ombre droite

	var side_bot: int = oy + 22
	match style:
		"short":
			side_bot = oy + 27
		"medium":
			side_bot = oy + 42
		"long":
			side_bot = oy + 60
			if dir == DIR_UP:
				_disc(img, cx, oy + 50, 17, 16, c)   # masse dans la nuque
				_disc(img, cx + 6, oy + 52, 9, 12, sh)
		"bun":
			_disc_o(img, cx, oy + 5, 7, 6, c, sh)    # chignon au sommet
			_disc(img, cx - 2, oy + 3, 3, 3, hi)
			side_bot = oy + 24
		"spiky":
			if dir != DIR_UP:
				_hair_cap(img, cx, oy + 26, 17, 18, c, fh)  # base
				for sx in [-14, -8, -2, 4, 10, 15]:
					_fill_rect(img, cx + sx - 1, oy + 2, 4, 15, c)
				_fill_rect(img, cx - 12, oy + 6, 3, 7, hi)
			side_bot = oy + 24
	# Mèches latérales (cadrent le visage) — uniquement de face/profil.
	if dir != DIR_UP:
		var sh_h: int = side_bot - (oy + 16)
		if sh_h > 0:
			_fill_rect(img, ox + 16, oy + 16, 4, sh_h, c)
			_fill_rect(img, ox + 44, oy + 16, 4, sh_h, c)
			_fill_rect(img, ox + 45, oy + 16, 2, sh_h, sh)

# Chapeau : posé sur le sommet du crâne. Ne descend jamais sous y≈oy+22
# (au-dessus des yeux oy+26). Aucun effacement transparent.
static func _draw_hat(img: Image, ox: int, oy: int, _dir: int, style: String, c: Color, line: Color) -> void:
	var sh: Color = c.darkened(0.26)
	var hi: Color = c.lightened(0.18)
	var cx: int = ox + 32
	match style:
		"none":
			pass
		"cap":
			# Casquette : couronne bombée (bornée au front) + visière avant.
			_hair_cap(img, cx, oy + 22, 18, 18, c, oy + 19)
			_hair_cap(img, cx - 6, oy + 16, 7, 8, hi, oy + 16)
			_hair_cap(img, cx + 8, oy + 18, 6, 9, sh, oy + 19)
			_rrect_o(img, ox + 30, oy + 17, 26, 5, c, line, 2)  # visière
		"fedora":
			_rrect_o(img, ox + 22, oy + 2, 20, 15, c, line, 6)  # couronne
			_fill_rect(img, ox + 23, oy + 12, 18, 2, sh)        # ruban
			_disc_o(img, cx, oy + 17, 26, 4, c, line)           # bord large
			_disc(img, cx - 8, oy + 7, 4, 4, hi)
		"beret":
			_disc_o(img, cx - 1, oy + 11, 17, 8, c, line)
			_disc(img, cx - 7, oy + 8, 5, 4, hi)
			_disc(img, cx + 8, oy + 13, 5, 4, sh)
			_fill_rect(img, ox + 46, oy + 5, 3, 3, c)            # petit pic
		"scarf":
			# Foulard : épouse le crâne (borné un peu plus bas) + pans latéraux.
			_hair_cap(img, cx, oy + 24, 18, 19, c, oy + 22)
			_hair_cap(img, cx + 8, oy + 22, 6, 10, sh, oy + 22)
			_hair_cap(img, cx - 7, oy + 16, 5, 6, hi, oy + 16)
			_fill_rect(img, ox + 16, oy + 20, 4, 14, c)          # pan gauche
			_fill_rect(img, ox + 44, oy + 20, 4, 14, c)          # pan droit

static func _draw_shirt_pattern(img: Image, ox: int, oy: int, pattern: String, base: Color) -> void:
	match pattern:
		"solid":
			pass
		"stripe_h":
			# Bandes horizontales alternées (un peu plus claires).
			var lighter: Color = base.lightened(0.18)
			for sy in [54, 60, 66, 72]:
				_fill_rect(img, ox + 19, oy + sy, 26, 3, lighter)
		"pocket":
			# Poche cousue à coins ronds sur le côté droit du torse.
			var darker: Color = base.darkened(0.22)
			_rrect_o(img, ox + 35, oy + 58, 9, 11, darker, base.darkened(0.4), 2)
			_fill_rect(img, ox + 36, oy + 60, 7, 1, base.lightened(0.1))
