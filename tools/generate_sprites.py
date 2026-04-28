#!/usr/bin/env python3
"""
Génère les sprites de NPCs via OpenAI gpt-image-1.

Deux modes :
  - DEFAULT : génère un sprite idle 1024x1024 par NPC → assets/sprites/npcs/<id>.png
  - --walk-sheets : utilise <id>.png comme référence et génère un sprite sheet 4x4
                    (4 directions × 4 frames de marche) → assets/sprites/npcs/<id>_walk.png

Usage :
    pip install openai Pillow
    export OPENAI_API_KEY=sk-...   # ou .env à la racine

    python tools/generate_sprites.py                       # idle de tous les NPCs
    python tools/generate_sprites.py --only seu_joao       # idle pour 1 NPC
    python tools/generate_sprites.py --walk-sheets         # sheets 4x4 de tous les NPCs (nécessite l'idle)
    python tools/generate_sprites.py --walk-sheets --only seu_joao
"""

import argparse
import base64
import os
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SPRITES_DIR = PROJECT_ROOT / "assets" / "sprites" / "npcs"


def _strip_background(img_bytes: bytes, tolerance: int = 30) -> bytes:
    """Rend transparente toute zone connectée aux 4 coins de couleur similaire à
    celle du coin (chroma key par flood-fill). Gère le cas où gpt-image-1 renvoie
    un fond non-pur malgré background="transparent".

    No-op si Pillow absent.
    """
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        return img_bytes
    from io import BytesIO
    img = Image.open(BytesIO(img_bytes)).convert("RGBA")
    w, h = img.size
    corners = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    for cx, cy in corners:
        c = img.getpixel((cx, cy))
        # Si le coin est déjà transparent on n'a rien à faire ici.
        if c[3] < 32:
            continue
        # Flood-fill avec du transparent depuis ce coin, tolérance fournie.
        ImageDraw.floodfill(img, (cx, cy), value=(0, 0, 0, 0), thresh=tolerance)
    out = BytesIO()
    img.save(out, format="PNG")
    return out.getvalue()


def _normalize_character(img_bytes: bytes, canvas_size: int, char_height: int) -> bytes:
    """Recadre le personnage au plus serré (bbox des pixels non transparents),
    le resize à `char_height` pixels de haut (en gardant l'aspect), puis le
    centre sur un canvas carré de `canvas_size`. Garantit une taille de
    personnage uniforme entre tous les sprites.

    No-op si Pillow n'est pas installé (renvoie l'image originale).
    """
    try:
        from PIL import Image
    except ImportError:
        return img_bytes
    from io import BytesIO
    img = Image.open(BytesIO(img_bytes)).convert("RGBA")
    bbox = img.getbbox()
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    if bbox is None:
        out = BytesIO()
        canvas.save(out, format="PNG")
        return out.getvalue()
    char = img.crop(bbox)
    cw, ch = char.size
    # Resize en gardant l'aspect ratio, hauteur = char_height.
    new_h = char_height
    new_w = max(1, int(round(cw * new_h / ch)))
    # Limite la largeur pour ne pas déborder du canvas.
    max_w = int(canvas_size * 0.92)
    if new_w > max_w:
        new_w = max_w
        new_h = max(1, int(round(ch * new_w / cw)))
    char = char.resize((new_w, new_h), Image.NEAREST)
    paste_x = (canvas_size - new_w) // 2
    # Pied du perso au 92% de la hauteur (laisse de l'air en bas, pour l'ombre).
    paste_y = int(canvas_size * 0.92) - new_h
    paste_y = max(0, paste_y)
    canvas.paste(char, (paste_x, paste_y), char)
    out = BytesIO()
    canvas.save(out, format="PNG")
    return out.getvalue()


def _pixelize(img_bytes: bytes, grid: int = 96) -> bytes:
    """Resize down (en gardant l'aspect ratio) puis remonte à la taille originale
    en nearest-neighbor pour forcer un look pixel art net. No-op si Pillow absent.
    """
    try:
        from PIL import Image
    except ImportError:
        return img_bytes
    from io import BytesIO
    img = Image.open(BytesIO(img_bytes)).convert("RGBA")
    w, h = img.size
    # On scale la grille selon le côté le plus court pour préserver l'aspect.
    if w >= h:
        gw = grid
        gh = max(1, int(round(grid * h / w)))
    else:
        gh = grid
        gw = max(1, int(round(grid * w / h)))
    small = img.resize((gw, gh), Image.NEAREST)
    big = small.resize((w, h), Image.NEAREST)
    out = BytesIO()
    big.save(out, format="PNG")
    return out.getvalue()


def _load_dotenv() -> None:
    """Charge la clé API depuis .env si elle n'est pas déjà dans l'environnement."""
    if os.environ.get("OPENAI_API_KEY"):
        return
    env_path = PROJECT_ROOT / ".env"
    if not env_path.exists():
        return
    for line in env_path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and value and key not in os.environ:
            os.environ[key] = value

PREFIX = (
    "cute chibi pixel art character sprite in the style of Stardew Valley, "
    "big oversized head with voluminous spiky messy hair, small stocky chibi body with broad shoulders, "
    "short stubby legs, thick dark pixel outline around silhouette, "
    "flat saturated colors with simple two-tone shading, "
    "tiny round black dot eyes, no visible mouth or nose, minimal cute face, "
    "vibrant warm Rio de Janeiro palette,"
)
SUFFIX = (
    "facing the camera in idle pose, full body head to feet, single character centered, "
    "isolated on pure transparent background, alpha channel, no shadow on ground, "
    "no text, no logo, no watermark, no UI, no border, no background scenery, "
    "1:1 square composition, sharp crisp pixels, no anti-aliasing, no smooth gradients, "
    "matching the chibi RPG sprite aesthetic of Stardew Valley NPCs"
)

# Liste des 9 poses pour un walk sheet (3 cols × 3 rows).
# Chaque pose est générée par un appel API séparé, ce qui garantit que le modèle
# rend un personnage centré et complet à chaque fois (vs. une seule passe qui
# coupe ou tasse les cellules). Pillow assemble ensuite les 9 poses en grille.
WALK_FRAMES = [
    # (row, col, description de la pose)
    (0, 0, "facing the camera (front view), standing still in idle pose with both feet together"),
    (0, 1, "facing the camera (front view), mid-stride walking forward with LEFT foot forward"),
    (0, 2, "facing the camera (front view), mid-stride walking forward with RIGHT foot forward"),
    (1, 0, "back view (facing away from the camera), standing still in idle pose with both feet together"),
    (1, 1, "back view (facing away from the camera), mid-stride walking with LEFT foot forward"),
    (1, 2, "back view (facing away from the camera), mid-stride walking with RIGHT foot forward"),
    (2, 0, "profile view (side view) facing right, standing still in idle pose with both feet together"),
    (2, 1, "profile view (side view) facing right, mid-stride walking right with LEFT foot forward"),
    (2, 2, "profile view (side view) facing right, mid-stride walking right with RIGHT foot forward"),
]

WALK_SHEET_SIZE: int = 1024  # côté du sheet final (1024×1024)
WALK_SHEET_ROWS: int = 3
WALK_SHEET_COLS: int = 3

# id (= nom de fichier .png) -> identité narrative à insérer dans le prompt
PROMPTS = {
    "seu_joao": "65-year-old carioca grandfather, deep tan, kind weathered face, salt-and-pepper mustache, faded white tank top, tan shorts, leather sandals, holding a small ear of grilled corn, soft smile",
    "ramos": "40-year-old Brazilian Military Police captain, very muscular, buzzcut, smug confident expression, dark blue PM tank top with badge, black tactical pants, mirrored aviator sunglasses, gold watch, flexing slightly",
    "tito": "32-year-old favela leader, lean and athletic, gold chain necklace, white tank top with red palm trees, denim shorts, white snapback cap worn backwards, neck tattoo, watchful sharp eyes",
    "padre": "65-year-old Brazilian Catholic priest, soft round face, kind smile, full black cassock with white collar, wooden rosary necklace, grey hair combed back, gentle posture, hands clasped",
    "farmaceutico": "55-year-old Brazilian woman pharmacist, warm motherly face, round wire glasses, short curly black hair, crisp white lab coat over a green blouse, small green cross brooch, holding a prescription paper",
    "vendeuse_boutique": "26-year-old fashionable carioca woman, light brown skin, long wavy dark hair, bright coral mini-dress, gold hoop earrings, big confident smile, holding a folded shirt",
    "carlos": "35-year-old Brazilian café owner, neat black beard, square glasses, brown apron over a beige polo, holding a small espresso cup, slightly tired but friendly smile",
    "chef_restaurant": "45-year-old Brazilian chef, big black mustache, double-breasted white chef coat, white chef hat, red checkered scarf at neck, warm cheeks, holding a wooden spoon",
    "concierge": "65-year-old man, well-groomed grey hair and trimmed mustache, formal navy concierge uniform with gold buttons and epaulets, white gloves, polite professional posture, but slightly knowing eyes hinting at a secret",
    "contessa": "42-year-old elegant Italian socialite on holiday, platinum blonde chignon, oversized white sunglasses on her hair, pearl necklace, flowing peach silk beach dress, holding a small glass of Aperol, theatrical posture",
    "miguel": "26-year-old shifty Brazilian young man, hoodie pulled half over head, athletic build, faded grey hoodie, dark cargo pants, sneakers, glancing sideways, hands in pockets",
    "otavio": "38-year-old hotel valet captain, tall, neat short black hair, black tailored uniform with red piping and small Copa Palace crest, white gloves, professional posture, holding a single car key",
    "bar_patrao": "52-year-old jovial bar boss, beer belly, salt-and-pepper goatee, faded red t-shirt with a cocktail glass logo, denim shorts, big welcoming arms-open gesture, gold chain on hairy chest",
    "padeiro": "58-year-old Brazilian baker, kindly round face, neat white apron dusted with flour, white short baker cap, sleeves rolled up showing flour-coated forearms, warm smile, holding a small pao de queijo",
    "dona_irene": "72-year-old gentle Brazilian grandmother, white curly hair, woven straw sun hat, light blue floral summer dress, small reading glasses on a beaded chain, holding a red dog leash, soft smile",
    "pecheur": "56-year-old weathered Bahian fisherman, deeply tanned, salt-grey beard, faded green plaid short-sleeve shirt, rolled khaki pants, bare feet, holding a small wooden fishing rod, tired squinting smile",
    "coconut_vendor": "50-year-old Brazilian beach vendor, warm brown skin, colorful tied bandana, bright yellow apron over a turquoise dress, holding a green coconut with a straw and a small machete, big laughing smile",
    "tourist_vip": "45-year-old American tourist man, very pale skin with sunburned nose, oversized straw hat, Hawaiian shirt with hibiscus pattern, beige shorts, sandals with white socks, expensive camera around neck, awkward smile",
    "joggeur": "33-year-old fit carioca runner, sweat-soaked black tank top, neon orange running shorts, white sneakers, sweatband, panting expression, athletic muscular build",
    "musicien": "60-year-old samba musician, dark skin, white beret, faded burgundy bowling shirt, beige trousers, holding a violao acoustic guitar by the neck, wise tired eyes, white goatee",
    "military_pm": "30-year-old Brazilian military police soldier, dark green camouflage uniform, beret, holstered pistol, alert serious expression, standing at attention, light skin, short brown hair",
    "consortium": "55-year-old Brazilian crime boss, slicked-back grey hair, rumpled white linen suit, open shirt collar with a thick gold chain, large pinky ring, smug confident smirk, smoking a thin cigar",
    "policier": "35-year-old Brazilian female police officer, tied-back dark hair, sharp jawline, dark blue PM uniform, badge, holstered pistol, holding a brown paper file folder, professional neutral expression",
    "jorge": "34-year-old massive Brazilian bouncer, shaved head, thick neck, tight short-sleeve black shirt straining against muscles, dark sunglasses, arms crossed, neutral imposing expression",
    "ze_bar": "42-year-old jolly kiosk owner, tan skin, faded green tank top with palm tree, board shorts, flip-flops, holding a beer in each hand, big mustache, laughing",
    "pm_patrol": "32-year-old Brazilian Military Police patrol officer, alert serious face, dark navy blue PM uniform with shoulder patch, beret tilted on side, black tactical belt with holstered pistol and walkie-talkie, black leather boots, hands resting on belt, watchful but not aggressive",
    "customer_tourist": "30-year-old gringo tourist on the beach, peeling sunburned face, white visor cap, neon yellow tank top, oversized cargo shorts, fanny pack around waist, oversized DSLR camera around neck, slightly lost confused expression",
    "customer_local": "35-year-old casual carioca local, beach-tan skin, plain blue tank top, denim shorts, simple flip-flops, hands on hips, relaxed neutral expression, short black hair",
    "customer_kid": "9-year-old Brazilian beach kid, barefoot, shaggy sun-bleached brown hair, oversized faded yellow t-shirt, baggy red beach shorts, big toothy grin, holding a small football under his arm",
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", help="liste d'IDs séparés par virgule (ex: seu_joao,ramos)")
    parser.add_argument("--force", action="store_true", help="écrase les fichiers existants")
    parser.add_argument("--dry-run", action="store_true", help="affiche les prompts sans appel API")
    parser.add_argument(
        "--no-pixelize",
        action="store_true",
        help="désactive le post-traitement pixelize (garde l'output OpenAI brut)",
    )
    parser.add_argument(
        "--pixel-grid",
        type=int,
        default=80,
        help="taille du grid de pixelisation (par défaut 80 — proche de la résolution du sprite joueur)",
    )
    parser.add_argument(
        "--walk-sheets",
        action="store_true",
        help="génère un sprite-sheet 3x3 frame-par-frame (9 appels API par NPC) avec normalisation Pillow. Nécessite que <id>.png existe déjà.",
    )
    parser.add_argument(
        "--char-ratio",
        type=float,
        default=0.78,
        help="ratio hauteur character / hauteur canvas (0.5–0.95, défaut 0.78). Ajuste la taille uniforme des personnages dans les sprites.",
    )
    parser.add_argument(
        "--bg-tolerance",
        type=int,
        default=30,
        help="tolérance du chroma key qui supprime le fond résiduel depuis les coins (0 = strict, 60 = agressif, défaut 30). Mets 0 pour désactiver.",
    )
    args = parser.parse_args()

    SPRITES_DIR.mkdir(parents=True, exist_ok=True)

    targets = list(PROMPTS.keys())
    if args.only:
        wanted = {x.strip() for x in args.only.split(",") if x.strip()}
        unknown = wanted - set(PROMPTS.keys())
        if unknown:
            print(f"ID(s) inconnu(s) : {', '.join(sorted(unknown))}", file=sys.stderr)
            print(f"IDs valides : {', '.join(sorted(PROMPTS.keys()))}", file=sys.stderr)
            return 2
        targets = [t for t in targets if t in wanted]

    if args.dry_run:
        for npc_id in targets:
            print(f"--- {npc_id} ---")
            print(f"{PREFIX} {PROMPTS[npc_id]}, {SUFFIX}\n")
        return 0

    _load_dotenv()
    if not os.environ.get("OPENAI_API_KEY"):
        print(
            "OPENAI_API_KEY n'est pas défini.\n"
            "Trois options :\n"
            "  1. export OPENAI_API_KEY=sk-... && relance\n"
            "  2. echo 'OPENAI_API_KEY=sk-...' > .env  (à la racine du projet)\n"
            "  3. echo 'export OPENAI_API_KEY=sk-...' >> ~/.zshrc && source ~/.zshrc",
            file=sys.stderr,
        )
        return 1

    try:
        from openai import OpenAI
    except ImportError:
        print("Le package 'openai' n'est pas installé. Lance: pip install openai", file=sys.stderr)
        return 1

    client = OpenAI()
    generated, skipped, failed = 0, 0, 0

    for npc_id in targets:
        if args.walk_sheets:
            ok = _gen_walk_sheet(client, npc_id, args)
        else:
            ok = _gen_idle(client, npc_id, args)
        if ok == "skip":
            skipped += 1
        elif ok == "ok":
            generated += 1
        else:
            failed += 1

    print(f"\nRésumé : {generated} générés · {skipped} skippés · {failed} échecs")
    return 0 if failed == 0 else 1


def _gen_idle(client, npc_id: str, args) -> str:
    out_path = SPRITES_DIR / f"{npc_id}.png"
    if out_path.exists() and not args.force:
        print(f"  [skip] {npc_id} idle (existe déjà — --force pour écraser)")
        return "skip"
    prompt = f"{PREFIX} {PROMPTS[npc_id]}, {SUFFIX}"
    print(f"  [gen]  {npc_id} idle…", end=" ", flush=True)
    try:
        result = client.images.generate(
            model="gpt-image-1",
            prompt=prompt,
            size="1024x1024",
            background="transparent",
            output_format="png",
            n=1,
        )
        img_bytes = base64.b64decode(result.data[0].b64_json)
        if not args.no_pixelize:
            img_bytes = _pixelize(img_bytes, grid=args.pixel_grid)
        if args.bg_tolerance > 0:
            img_bytes = _strip_background(img_bytes, tolerance=args.bg_tolerance)
        # Normalise pour que le character occupe exactement char_ratio de la hauteur.
        char_h = int(round(1024 * args.char_ratio))
        img_bytes = _normalize_character(img_bytes, canvas_size=1024, char_height=char_h)
        out_path.write_bytes(img_bytes)
        print(f"OK → {out_path.relative_to(PROJECT_ROOT)} (char {char_h}px)")
        return "ok"
    except Exception as e:
        print(f"ÉCHEC ({e})")
        return "fail"


def _gen_walk_sheet(client, npc_id: str, args) -> str:
    """Génère un sheet 3×3 frame par frame (9 appels API), assemble avec Pillow.
    Beaucoup plus fiable qu'une seule passe — le modèle ne coupe plus de cellules.
    """
    idle_path = SPRITES_DIR / f"{npc_id}.png"
    out_path = SPRITES_DIR / f"{npc_id}_walk.png"
    if not idle_path.exists():
        print(f"  [skip] {npc_id} walk (pas d'idle — génère-le d'abord)")
        return "skip"
    if out_path.exists() and not args.force:
        print(f"  [skip] {npc_id} walk (existe déjà — --force pour écraser)")
        return "skip"
    try:
        from PIL import Image
    except ImportError:
        print(f"  [fail] {npc_id} walk : Pillow requis (pip install Pillow)")
        return "fail"
    from io import BytesIO

    cell = WALK_SHEET_SIZE // WALK_SHEET_COLS
    cell_char_h = int(round(cell * args.char_ratio))
    print(f"  [gen]  {npc_id} walk-sheet (9 frames, char {cell_char_h}px)…")

    sheet = Image.new("RGBA", (WALK_SHEET_SIZE, WALK_SHEET_SIZE), (0, 0, 0, 0))
    for (row, col, pose) in WALK_FRAMES:
        prompt = (
            f"{PREFIX} {PROMPTS[npc_id]}, {pose}, "
            f"matching the exact same character design as the input reference image, "
            f"{SUFFIX}"
        )
        print(f"     [{row},{col}]…", end=" ", flush=True)
        try:
            with open(idle_path, "rb") as f:
                result = client.images.edit(
                    model="gpt-image-1",
                    image=f,
                    prompt=prompt,
                    size="1024x1024",
                    background="transparent",
                    n=1,
                )
            frame_bytes = base64.b64decode(result.data[0].b64_json)
            if not args.no_pixelize:
                frame_bytes = _pixelize(frame_bytes, grid=args.pixel_grid)
            if args.bg_tolerance > 0:
                frame_bytes = _strip_background(frame_bytes, tolerance=args.bg_tolerance)
            # Normalise la frame à la taille de cellule + char_height contrôlée.
            cell_bytes = _normalize_character(frame_bytes, canvas_size=cell, char_height=cell_char_h)
            cell_img = Image.open(BytesIO(cell_bytes)).convert("RGBA")
            sheet.paste(cell_img, (col * cell, row * cell), cell_img)
            print("OK")
        except Exception as e:
            print(f"ÉCHEC ({e})")
            return "fail"

    out = BytesIO()
    sheet.save(out, format="PNG")
    out_path.write_bytes(out.getvalue())
    print(f"  → assemblé : {out_path.relative_to(PROJECT_ROOT)}")
    return "ok"


if __name__ == "__main__":
    sys.exit(main())
