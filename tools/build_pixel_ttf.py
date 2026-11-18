#!/usr/bin/env python3
"""Construit assets/fonts/RioPixel.ttf à partir des glyphes de PixelFont.gd.

La police du jeu est dessinée en code (5×7, cellule de 11 px). Ce script en
fait une vraie police vectorielle (un rectangle par suite de pixels) pour que
TOUTE l'interface l'utilise à n'importe quelle taille : nette aux multiples de
11 (22 = ×2, 33 = ×3), proprement lissée entre deux.

    godot --headless --path . -s tools/dump_pixel_glyphs.gd -- /tmp/glyphs.json
    python3 tools/build_pixel_ttf.py /tmp/glyphs.json assets/fonts/RioPixel.ttf

Dépendance : fonttools (pip install fonttools).
"""
import json
import sys

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

U = 100          # unités par pixel natif
CELL = 11        # hauteur de cellule (9 au-dessus de la ligne de base, 2 dessous)
ASCENT = 9
SPACE = 3


def glyph(rows):
    pen = TTGlyphPen(None)
    for ry, row in enumerate(rows):
        x = 0
        while x < len(row):
            if row[x] != "#":
                x += 1
                continue
            x0 = x
            while x < len(row) and row[x] == "#":
                x += 1
            top = (ASCENT - ry) * U
            bot = top - U
            # Sens horaire (contour plein en TrueType).
            pen.moveTo((x0 * U, bot))
            pen.lineTo((x0 * U, top))
            pen.lineTo((x * U, top))
            pen.lineTo((x * U, bot))
            pen.closePath()
    return pen.glyph()


def main():
    src, dst = sys.argv[1], sys.argv[2]
    data = json.load(open(src, encoding="utf-8"))
    order = [".notdef", "space"]
    cmap = {0x20: "space", 0xA0: "space"}
    glyphs = {".notdef": TTGlyphPen(None).glyph(), "space": TTGlyphPen(None).glyph()}
    metrics = {".notdef": (6 * U, 0), "space": (SPACE * U, 0)}
    for ch in sorted(data):
        name = "u%04X" % ord(ch)
        order.append(name)
        cmap[ord(ch)] = name
        glyphs[name] = glyph(data[ch]["rows"])
        metrics[name] = (data[ch]["advance"] * U, 0)
    fb = FontBuilder(CELL * U, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=ASCENT * U, descent=-(CELL - ASCENT) * U, lineGap=U)
    fb.setupNameTable({"familyName": "Rio Pixel", "styleName": "Regular"})
    fb.setupOS2(sTypoAscender=ASCENT * U, sTypoDescender=-(CELL - ASCENT) * U, sTypoLineGap=U,
                usWinAscent=ASCENT * U, usWinDescent=(CELL - ASCENT) * U)
    fb.setupPost()
    fb.save(dst)
    print("%d glyphes -> %s" % (len(order), dst))


if __name__ == "__main__":
    main()
