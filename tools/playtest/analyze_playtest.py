#!/usr/bin/env python3
"""Analyse du journal JSON produit par PlaytestBot : rythme, temps par état,
frictions, courbe d'argent/dette, dialogues. Usage : analyze_playtest.py out.json"""
import json, sys, collections

def fmt(s):
    s = int(s); return f"{s//60:d}:{s%60:02d}"

def main(path):
    d = json.load(open(path))
    S, T = d["summary"], d["timeline"]
    total = S["game_time_s"]
    print(f"# Playtest — {fmt(total)} de jeu ({S['wall_ms']/1000:.0f}s réels) · fin : {S['reason']}")
    print(f"acte {S['act']} · dette payée {S['debt_paid']} · cash {S['money']} · jour {S['day']} · marche {S['dist_walked_px']/1000:.1f} k px · taxi {S['taxi_spent']} R$")
    print("\n## Temps par état")
    tbs = S["time_by_state"]
    for k, v in sorted(tbs.items(), key=lambda kv: -kv[1]):
        print(f"  {k:12s} {fmt(v):>7s}  {100*v/total:5.1f}%")
    by = collections.defaultdict(list)
    for e in T: by[e["k"]].append(e)
    print("\n## Compteurs")
    for k in ["dialogue","interact","quest_accepted","quest_completed","objective_done","mission_accepted","mission_completed","mission_expired","minigame_sim","taxi","travel_walk","exit_locked","stuck","unreachable","no_prompt","no_path","wander","chase_started","act_card","toast"]:
        if by.get(k): print(f"  {k:18s} {len(by[k])}")
    # Dialogues
    dl = by.get("dialogue", [])
    chars = sum(e["chars"] for e in dl); read = sum(e["read"] for e in dl)
    knots = collections.Counter(e["knot"] for e in dl)
    print(f"\n## Dialogues : {len(dl)} répliques, {chars} caractères (~{chars//6} mots), {fmt(read)} de lecture")
    print("  knots les plus répétés :", ", ".join(f"{k}×{n}" for k, n in knots.most_common(8) if n > 1))
    ellipsis = [e for e in dl if e.get("choice_text","").strip() in ("…","...")]
    print(f"  répliques « … » (spots muets) : {len(ellipsis)}")
    # Actes
    print("\n## Jalons")
    acts = {1: 0.0}
    for e in by.get("act_changed", []): acts[e["act"]] = e["t"]
    for a, t in sorted(acts.items()): print(f"  acte {a} à {fmt(t)}")
    for e in by.get("quest_completed", []):
        print(f"  {fmt(e['t'])} ✓ {'MAIN ' if e.get('main') else 'side '}{e['q']}")
    # Argent
    print("\n## Argent (gains par source)")
    gains = collections.Counter(); losses = collections.Counter()
    last_kind = None
    for e in T:
        if e["k"] == "money":
            # attribue au dernier événement non-money
            src = last_kind or "?"
            (gains if e["delta"] > 0 else losses)[src] += e["delta"]
        else:
            last_kind = e["k"] if e["k"] not in ("guidance","rep","toast","objective_done","quest_updated") else last_kind
    for k, v in gains.most_common(): print(f"  +{v:5d}  après {k}")
    for k, v in losses.most_common(): print(f"  {v:6d}  après {k}")
    # Tunnels sans récompense
    print("\n## Tunnels (plus longs intervalles sans progrès visible)")
    marks = [0.0] + [e["t"] for e in T if e["k"] in ("quest_accepted","objective_done","quest_completed","act_changed","mission_completed","debt_paid") or (e["k"]=="money" and e["delta"]>0)] + [total]
    gaps = sorted(((b-a, a, b) for a, b in zip(marks, marks[1:])), reverse=True)[:6]
    for g, a, b in gaps: print(f"  {fmt(g)} entre {fmt(a)} et {fmt(b)}")
    # Guidage
    print("\n## Guidage (texte → durée cumulée, kind 0=sans position)")
    g = by.get("guidance", [])
    dur = collections.Counter(); kinds = {}
    for e, nxt in zip(g, g[1:] + [{"t": total}]):
        dur[e["text"]] += nxt["t"] - e["t"]; kinds[e["text"]] = e["kind"]
    for txt, v in dur.most_common(14): print(f"  {fmt(v):>7s} k{kinds[txt]} {txt[:90]}")
    # Frictions
    print("\n## Frictions")
    for k in ["exit_locked","stuck","unreachable","no_prompt","walk_timeout","taxi_broke","mission_expired","quest_failed","ui_closed"]:
        for e in by.get(k, [])[:6]:
            print(f"  {fmt(e['t'])} {k} {json.dumps({x:y for x,y in e.items() if x not in ('t','k','money','debt','act')}, ensure_ascii=False)[:120]}")
    # Chrono / toasts
    print("\n## Toasts")
    for e in by.get("toast", [])[:25]: print(f"  {fmt(e['t'])} {e['text'][:100]}")

main(sys.argv[1])
