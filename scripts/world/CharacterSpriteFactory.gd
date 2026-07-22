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
	"short", "medium", "long", "bun", "spiky", "bald", "afro", "curly",
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

# --- Peintre pixel-art (style Pokémon GBA) ---
#
# Chaque cellule 64×96 est dessinée en résolution NATIVE 21×32 puis upscalée
# ×3 au pixel près (63×96) : contour sombre auto-généré, ombrage 2-3 tons par
# matière, petits yeux 2 px, silhouette trapue à grosse tête. À afficher en
# TEXTURE_FILTER_NEAREST (pixel-art net), plus jamais en LINEAR.
# Repère natif (y) : 1..7 cheveux · 5..13 tête · 14 cou · 15..22 torse ·
# 23..28 jambes · 29..30 pieds.

const NAT_W: int = 21
const NAT_H: int = 32
const SCALE: int = 3
const LINE_COLOR: Color = Color(0.13, 0.10, 0.12, 1.0)

static func _draw_cell(img: Image, ox: int, oy: int, dir: int, frame: int, c: Dictionary) -> void:
	var n: Image = Image.create(NAT_W, NAT_H, false, Image.FORMAT_RGBA8)
	n.fill(Color(0, 0, 0, 0))
	_paint_native(n, dir, frame, c)
	_auto_outline(n)
	for y in NAT_H:
		for x in NAT_W:
			var col: Color = n.get_pixel(x, y)
			if col.a <= 0.01:
				continue
			for dy in SCALE:
				for dx in SCALE:
					img.set_pixel(ox + x * SCALE + dx, oy + y * SCALE + dy, col)

# Contour : tout pixel vide voisin (4-connexité) d'un pixel plein devient ligne.
static func _auto_outline(n: Image) -> void:
	var edges: Array = []
	for y in NAT_H:
		for x in NAT_W:
			if n.get_pixel(x, y).a > 0.01:
				continue
			var touch: bool = false
			for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var px: int = x + off.x
				var py: int = y + off.y
				if px < 0 or py < 0 or px >= NAT_W or py >= NAT_H:
					continue
				var neigh: Color = n.get_pixel(px, py)
				if neigh.a > 0.01 and neigh != LINE_COLOR:
					touch = true
					break
			if touch:
				edges.append(Vector2i(x, y))
	for e in edges:
		n.set_pixel(e.x, e.y, LINE_COLOR)

static func _px(n: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < NAT_W and y < NAT_H:
		n.set_pixel(x, y, c)

static func _hrow(n: Image, x0: int, x1: int, y: int, c: Color) -> void:
	for x in range(x0, x1 + 1):
		_px(n, x, y, c)

static func _vcol(n: Image, x: int, y0: int, y1: int, c: Color) -> void:
	for y in range(y0, y1 + 1):
		_px(n, x, y, c)

static func _box(n: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1 + 1):
		_hrow(n, x0, x1, y, c)

static func _paint_native(n: Image, dir: int, frame: int, c: Dictionary) -> void:
	var skin: Color = c.get("skin", Color(0.92, 0.78, 0.62))
	var hair_color: Color = c.get("hair_color", Color(0.18, 0.12, 0.08))
	var hair_style: String = c.get("hair_style", "short")
	var shirt: Color = c.get("shirt_color", Color(0.85, 0.55, 0.4))
	var shirt_pattern: String = c.get("shirt_pattern", "solid")
	var pants: Color = c.get("pants_color", Color(0.30, 0.25, 0.20))
	var hat_style: String = c.get("hat_style", "none")
	var hat_color: Color = c.get("hat_color", Color(0.18, 0.18, 0.22))

	var skin_sh: Color = skin.darkened(0.22)
	var hair_sh: Color = hair_color.darkened(0.28)
	var hair_hi: Color = hair_color.lightened(0.22)
	var shirt_sh: Color = shirt.darkened(0.24)
	var pants_sh: Color = pants.darkened(0.26)
	var eye: Color = Color(0.10, 0.09, 0.11, 1.0)
	var sandal: Color = Color(0.28, 0.20, 0.14, 1.0)
	# Pantalon long si la couleur est sombre (costume, PM) ; bermuda sinon (Rio).
	var long_pants: bool = pants.v < 0.4

	if dir == DIR_RIGHT:
		_paint_side(n, frame, skin, skin_sh, hair_color, hair_sh, hair_hi, hair_style,
			shirt, shirt_sh, shirt_pattern, pants, pants_sh, long_pants,
			hat_style, hat_color, eye, sandal)
	else:
		_paint_front(n, dir, frame, skin, skin_sh, hair_color, hair_sh, hair_hi, hair_style,
			shirt, shirt_sh, shirt_pattern, pants, pants_sh, long_pants,
			hat_style, hat_color, eye, sandal)

# --- Vue de face (DOWN) et de dos (UP) ---

static func _paint_front(n: Image, dir: int, frame: int,
		skin: Color, skin_sh: Color,
		hair: Color, hair_sh: Color, hair_hi: Color, hair_style: String,
		shirt: Color, shirt_sh: Color, shirt_pattern: String,
		pants: Color, pants_sh: Color, long_pants: bool,
		hat_style: String, hat_color: Color, eye: Color, sandal: Color) -> void:
	var back: bool = dir == DIR_UP
	# Tête (crâne skin ; les cheveux repassent dessus).
	_hrow(n, 6, 14, 5, skin)
	_box(n, 5, 6, 15, 12, skin)
	_hrow(n, 6, 14, 13, skin)
	# Modelé du visage : ombre sous la mâchoire + côté gauche.
	_vcol(n, 5, 8, 12, skin_sh)
	_hrow(n, 6, 14, 13, skin_sh)
	if not back:
		# Yeux 2×2 + oreilles.
		_box(n, 7, 9, 8, 10, eye)
		_box(n, 12, 9, 13, 10, eye)
		_px(n, 7, 9, eye.lightened(0.45))
		_px(n, 12, 9, eye.lightened(0.45))
		_px(n, 4, 9, skin)
		_px(n, 16, 9, skin)
		_px(n, 4, 10, skin_sh)
		_px(n, 16, 10, skin_sh)
	# Cheveux.
	_paint_hair_front(n, back, hair, hair_sh, hair_hi, hair_style)
	# Chapeau par-dessus.
	_paint_hat_front(n, back, hat_style, hat_color)
	# Cou.
	_hrow(n, 9, 11, 14, skin_sh)
	# Torse (manches incluses) + bras qui balancent d'1 px en marchant.
	var arm_l: int = 0
	var arm_r: int = 0
	if frame == 1:
		arm_l = 1
		arm_r = -1
	elif frame == 2:
		arm_l = -1
		arm_r = 1
	_box(n, 6, 15, 14, 22, shirt)
	_hrow(n, 6, 14, 22, shirt_sh)
	_vcol(n, 6, 15, 22, shirt_sh)
	# Manches + avant-bras/mains.
	_vcol(n, 4, 15 + arm_l, 17 + arm_l, shirt)
	_vcol(n, 5, 15 + arm_l, 17 + arm_l, shirt_sh)
	_vcol(n, 16, 15 + arm_r, 17 + arm_r, shirt)
	_vcol(n, 15, 15 + arm_r, 17 + arm_r, shirt)
	_vcol(n, 4, 18 + arm_l, 20 + arm_l, skin)
	_vcol(n, 16, 18 + arm_r, 20 + arm_r, skin)
	_px(n, 4, 21 + arm_l, skin_sh)
	_px(n, 16, 21 + arm_r, skin_sh)
	if not back:
		_paint_shirt_pattern_front(n, shirt_pattern, shirt, shirt_sh)
	# Bermuda / pantalon + jambes. Frames : une jambe levée.
	var lift_l: int = 1 if frame == 1 else 0
	var lift_r: int = 1 if frame == 2 else 0
	var hem: int = 26 if not long_pants else 28
	_box(n, 6, 23, 9, hem - lift_l, pants)
	_box(n, 11, 23, 14, hem - lift_r, pants)
	_hrow(n, 6, 14, 23, pants_sh)
	_vcol(n, 6, 23, hem - lift_l, pants_sh)
	_vcol(n, 11, 23, hem - lift_r, pants_sh)
	if not long_pants:
		_box(n, 7, 27 - lift_l, 9, 28 - lift_l, skin)
		_box(n, 11, 27 - lift_r, 13, 28 - lift_r, skin)
	# Pieds (chinelos).
	_box(n, 6, 29 - lift_l, 9, 30 - lift_l, sandal)
	_box(n, 11, 29 - lift_r, 14, 30 - lift_r, sandal)

# --- Vue de profil (RIGHT) ---

static func _paint_side(n: Image, frame: int,
		skin: Color, skin_sh: Color,
		hair: Color, hair_sh: Color, hair_hi: Color, hair_style: String,
		shirt: Color, shirt_sh: Color, _shirt_pattern: String,
		pants: Color, pants_sh: Color, long_pants: bool,
		hat_style: String, hat_color: Color, eye: Color, sandal: Color) -> void:
	# Tête profil (le visage regarde +x).
	_hrow(n, 7, 14, 5, skin)
	_box(n, 6, 6, 15, 12, skin)
	_hrow(n, 7, 14, 13, skin)
	_vcol(n, 6, 7, 12, skin_sh)
	_hrow(n, 7, 13, 13, skin_sh)
	# Œil unique + nez.
	_box(n, 12, 9, 13, 10, eye)
	_px(n, 12, 9, eye.lightened(0.45))
	_px(n, 15, 10, skin_sh)
	# Cheveux profil : la masse couvre l'arrière du crâne.
	_paint_hair_side(n, hair, hair_sh, hair_hi, hair_style)
	_paint_hat_side(n, hat_style, hat_color)
	# Cou.
	_hrow(n, 9, 11, 14, skin_sh)
	# Torse profil, plus étroit.
	_box(n, 7, 15, 13, 22, shirt)
	_hrow(n, 7, 13, 22, shirt_sh)
	_vcol(n, 7, 15, 22, shirt_sh)
	# Bras visible côté avant du torse (manche + main qui balance).
	var arm: int = 0
	if frame == 1:
		arm = 1
	elif frame == 2:
		arm = -1
	_vcol(n, 13, 15, 17, shirt_sh)
	_vcol(n, 13, 18 + arm, 20 + arm, skin)
	_px(n, 13, 21 + arm, skin_sh)
	# Jambes profil : foulée.
	var hem: int = 26 if not long_pants else 28
	if frame == 0:
		_box(n, 8, 23, 12, hem, pants)
		_vcol(n, 8, 23, hem, pants_sh)
		if not long_pants:
			_box(n, 9, 27, 12, 28, skin)
		_box(n, 8, 29, 13, 30, sandal)
	else:
		var front_x: int = 11 if frame == 1 else 9
		var back_x: int = 7 if frame == 1 else 9
		_box(n, back_x, 23, back_x + 2, hem - 1, pants_sh)
		_box(n, front_x, 23, front_x + 2, hem, pants)
		if not long_pants:
			_box(n, back_x, 27, back_x + 2, 27, skin_sh)
			_box(n, front_x, 27, front_x + 2, 28, skin)
		_box(n, back_x - 1, 28, back_x + 2, 29, sandal)
		_box(n, front_x, 29, front_x + 3, 30, sandal)

# --- Cheveux ---

static func _paint_hair_front(n: Image, back: bool, hair: Color, hair_sh: Color,
		hair_hi: Color, style: String) -> void:
	if style == "bald":
		return  # crâne nu : le skin déjà peint suffit (face comme dos)
	match style:
		"short", "curly":
			_hrow(n, 6, 14, 3, hair)
			_box(n, 5, 4, 15, 6, hair)
			_vcol(n, 5, 7, 8, hair)
			_vcol(n, 15, 7, 8, hair)
			if style == "curly":
				for x in [6, 9, 12]:
					_px(n, x, 2, hair)
				_px(n, 4, 5, hair)
				_px(n, 16, 5, hair)
		"medium":
			_hrow(n, 6, 14, 2, hair)
			_box(n, 5, 3, 15, 6, hair)
			_vcol(n, 4, 5, 10, hair)
			_vcol(n, 5, 7, 10, hair)
			_vcol(n, 15, 7, 10, hair)
			_vcol(n, 16, 5, 10, hair)
		"long":
			_hrow(n, 6, 14, 2, hair)
			_box(n, 5, 3, 15, 6, hair)
			_vcol(n, 4, 4, 16, hair)
			_vcol(n, 5, 7, 16, hair)
			_vcol(n, 15, 7, 16, hair)
			_vcol(n, 16, 4, 16, hair)
		"bun":
			_hrow(n, 6, 14, 3, hair)
			_box(n, 5, 4, 15, 5, hair)
			_box(n, 8, 1, 12, 2, hair)
			_px(n, 9, 0, hair_sh)
		"spiky":
			for x in [5, 7, 9, 11, 13, 15]:
				_px(n, x, 2, hair)
			_hrow(n, 5, 15, 3, hair)
			_box(n, 5, 4, 15, 5, hair)
		"afro":
			_hrow(n, 6, 14, 1, hair)
			_box(n, 4, 2, 16, 6, hair)
			_vcol(n, 3, 3, 7, hair)
			_vcol(n, 17, 3, 7, hair)
			_vcol(n, 4, 7, 9, hair)
			_vcol(n, 16, 7, 9, hair)
	if back:
		# De dos : la chevelure couvre tout l'arrière du crâne.
		var depth: int = 12
		if style == "short" or style == "curly" or style == "spiky":
			depth = 10
		_box(n, 5, 6, 15, depth, hair)
		_vcol(n, 5, 6, depth, hair_sh)
		if style == "long":
			_box(n, 5, 12, 15, 17, hair)
			_hrow(n, 5, 15, 17, hair_sh)
		if style == "bun":
			_box(n, 8, 6, 12, 8, hair_sh)
	else:
		# Éclat en haut à droite + ombre sous la frange.
		_hrow(n, 10, 13, 3, hair_hi)
		_hrow(n, 5, 15, 6, hair_sh)

static func _paint_hair_side(n: Image, hair: Color, hair_sh: Color, hair_hi: Color,
		style: String) -> void:
	if style == "bald":
		return
	# Base commune : calotte + arrière du crâne.
	_hrow(n, 7, 14, 3, hair)
	_box(n, 6, 4, 14, 6, hair)
	_vcol(n, 6, 7, 10, hair)
	_vcol(n, 7, 7, 9, hair)
	match style:
		"medium":
			_vcol(n, 6, 7, 12, hair)
			_vcol(n, 7, 7, 11, hair)
		"long":
			_box(n, 5, 6, 7, 16, hair)
			_vcol(n, 5, 6, 16, hair_sh)
		"bun":
			_box(n, 4, 6, 6, 8, hair)
			_px(n, 4, 5, hair_sh)
		"spiky":
			for x in [7, 9, 11, 13]:
				_px(n, x, 2, hair)
		"afro":
			_box(n, 4, 2, 15, 7, hair)
			_vcol(n, 3, 3, 8, hair)
			_vcol(n, 4, 7, 10, hair)
		"curly":
			for x in [8, 11, 14]:
				_px(n, x, 2, hair)
	_hrow(n, 10, 13, 3, hair_hi)
	_hrow(n, 8, 14, 6, hair_sh)

# --- Chapeaux ---

static func _paint_hat_front(n: Image, back: bool, style: String, hat: Color) -> void:
	var hat_sh: Color = hat.darkened(0.25)
	match style:
		"cap":
			_hrow(n, 6, 14, 2, hat)
			_box(n, 5, 3, 15, 5, hat)
			if not back:
				_hrow(n, 5, 15, 6, hat_sh)
			else:
				_px(n, 10, 3, hat_sh)  # bouton arrière
		"fedora":
			_hrow(n, 7, 13, 1, hat)
			_box(n, 6, 2, 14, 4, hat)
			_hrow(n, 6, 14, 4, hat_sh)
			_hrow(n, 4, 16, 5, hat)
		"beret":
			_box(n, 5, 2, 13, 4, hat)
			_px(n, 9, 1, hat_sh)
			_hrow(n, 5, 13, 4, hat_sh)
		"scarf":
			_hrow(n, 6, 14, 2, hat)
			_box(n, 5, 3, 15, 6, hat)
			_hrow(n, 5, 15, 6, hat_sh)
			_px(n, 16, 7, hat)
			_px(n, 16, 8, hat_sh)

static func _paint_hat_side(n: Image, style: String, hat: Color) -> void:
	var hat_sh: Color = hat.darkened(0.25)
	match style:
		"cap":
			_hrow(n, 7, 14, 2, hat)
			_box(n, 6, 3, 14, 5, hat)
			_hrow(n, 14, 18, 5, hat)    # visière vers l'avant
			_hrow(n, 14, 18, 6, hat_sh)
		"fedora":
			_hrow(n, 8, 13, 1, hat)
			_box(n, 7, 2, 14, 4, hat)
			_hrow(n, 7, 14, 4, hat_sh)
			_hrow(n, 5, 17, 5, hat)
		"beret":
			_box(n, 6, 2, 13, 4, hat)
			_hrow(n, 6, 13, 4, hat_sh)
		"scarf":
			_hrow(n, 7, 14, 2, hat)
			_box(n, 6, 3, 14, 6, hat)
			_px(n, 5, 7, hat)
			_px(n, 5, 8, hat_sh)

# --- Motifs de t-shirt (face uniquement) ---

static func _paint_shirt_pattern_front(n: Image, pattern: String, shirt: Color,
		shirt_sh: Color) -> void:
	var accent: Color = shirt.lightened(0.35) if shirt.v < 0.6 else shirt_sh.darkened(0.1)
	match pattern:
		"stripe_h":
			_hrow(n, 7, 14, 17, accent)
			_hrow(n, 7, 14, 20, accent)
		"pocket":
			_box(n, 11, 17, 13, 19, accent)
