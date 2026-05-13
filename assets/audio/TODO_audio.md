# Audio à sourcer — checklist

Tous les hooks audio sont câblés côté code (`scripts/audio/AudioManager.gd`) :
les SFX et boucles ambient se déclenchent dès qu'un fichier `.ogg` existe au bon
chemin. Si un fichier est absent, le SFX est silencieusement ignoré (pas de
crash). Format cible : **`.ogg` mono ou stéréo, 44.1 kHz, qualité Vorbis ~6**.

Sources libres recommandées :
- **freesound.org** — large catalogue, filtrer CC0 ou CC-BY
- **opengameart.org** — orienté jeux, beaucoup de SFX courts
- **pixabay.com/sound-effects** — CC0 par défaut
- **soundbible.com** — SFX classiques (téléphone, cling, etc.)

Pour la musique de district, on peut générer via **Suno**, **Udio**, ou utiliser
**incompetech.com** (Kevin MacLeod, CC-BY). 60–90 sec en loop suffisent — Godot
boucle proprement si la fin et le début matchent.

---

## SFX (`assets/audio/sfx/`)

### Feedback UI & interaction (priorité ★★★)
| Fichier | Description | Durée | Recherche |
|---|---|---|---|
| `prompt_chime.ogg` | Cling très bref quand un prompt "E pour parler" apparaît | 0.15–0.25s | `prompt`, `notification`, `pop`, `hover` |
| `dialogue.ogg` | Tap court à chaque ligne de dialogue (texte qui apparaît) | 0.05–0.10s | `text tick`, `bleep`, `typewriter` |
| `coin.ogg` | Tintement quand le joueur gagne de l'argent | 0.20–0.40s | `coin pickup`, `cash`, `cling small` |

### Quêtes & narration (★★)
| Fichier | Description | Durée |
|---|---|---|
| `quest_accepted.ogg` | Cling positif quand une quête démarre | 0.5–0.8s |
| `quest_complete.ogg` | Fanfare brève quand une quête est terminée | 0.8–1.5s |
| `quest_failed.ogg` | Bonk grave / accord mineur | 0.5–0.8s |
| `act_stinger.ogg` | Stinger orchestral / percussion pour les transitions d'acte | 1.5–3s |

### Inventaire & commerce (★★)
| Fichier | Description |
|---|---|
| `item_pickup.ogg` | Petit cling quand un objet entre en inventaire |
| `customer_cling.ogg` | Cash register / cling de caisse |
| `debt_paid.ogg` | Cascade de pièces, ~1s |
| `cart_lift.ogg` | Bois grinçant + clic, on prend la charrette de milho |
| `cart_drop.ogg` | Bois posé au sol |

### Pas du joueur (★★)
| Fichier | Description |
|---|---|
| `step_sand.ogg` | Pas étouffé dans le sable, ~0.15s |
| `step_road.ogg` | Pas net sur asphalte / béton |
| `step_grass.ogg` | Pas dans l'herbe / terre |
| `step_wood.ogg` | Pas sur bois (calçadão / pontons) |

Le `PlayerController` appelle `AudioManager.notify_player_position(pos, surface)`
chaque frame. La surface est devinée selon le district (`sand` pour
copa/zona_sul/cagarras, `grass` pour corcovado/aterro, `road` ailleurs).
AudioManager joue un step toutes les ~24 px de déplacement.

### Mini-jeux (★)
| Fichier | Description |
|---|---|
| `minigame_win.ogg` | Victoire générique (déjà câblé) |
| `minigame_lose.ogg` | Échec |
| `basket_swish.ogg` | Filet de basket (Aterro Flamengo) |
| `paddle.ogg` | Pagaie qui frappe l'eau (Cagarras SUP) |
| `carnaval_drum.ogg` | Roulement de tambour (Sambódromo) |
| `whistle.ogg` | Sifflet PM / fin de match |

---

## Ambient par district (`assets/audio/sfx/ambient_*.ogg`)

Boucles longues (60–120s), volume bas (-14 dB par défaut), crossfade auto sur
changement de district. Fichier absent = fallback `waves.ogg`.

| Fichier | District | Description |
|---|---|---|
| `waves.ogg` | copa / zona_sul / cagarras (et fallback) | Vagues régulières + mouettes lointaines |
| `ambient_park.ogg` | aterro_flamengo | Brise dans les feuilles, oiseaux, voix lointaines |
| `ambient_city.ogg` | botafogo_flamengo | Trafic léger, klaxons épars |
| `ambient_favela.ogg` | favela_morro | Radio lointaine, chiens, voix |
| `ambient_forest.ogg` | corcovado | Forêt humide, oiseaux exotiques |
| `ambient_wind_high.ogg` | pao_acucar | Vent en altitude, lointain |
| `ambient_stadium.ogg` | maracana | Foule, écho, chants |
| `ambient_airport.ogg` | santos_dumont | Bruit de fond aéroport, annonces lointaines |
| `ambient_carnaval_distant.ogg` | sambodromo | Tambours lointains, foule en attente |

Astuce : pour éviter les coupures audibles, exporter avec **fade in/out de
50–100ms** aux extrémités, ou s'assurer que la fin matche le début bit-à-bit.

---

## Musique de district (`assets/audio/music/`)

Boucles 60–120s, volume principal (-10 dB), crossfade 1.2s.

| Fichier | District | Style |
|---|---|---|
| `beach.ogg` | copacabana | Samba lounge, guitare douce |
| `ipanema.ogg` | zona_sul | Bossa nova, "Garota de Ipanema"-esque |
| `corcovado.ogg` | corcovado | Ambient mystique, choeurs lointains |
| `sunset.ogg` | pao_acucar | Bossa contemplative |
| `torcida.ogg` | maracana | Percussion + voix, foule |
| `airport.ogg` | santos_dumont | Lounge jazz, anonyme |
| `aterro.ogg` | aterro_flamengo | MPB acoustique |
| `sea.ogg` | cagarras | Ambient marin, peu de mélodie |
| `carnaval.ogg` | sambodromo | Samba carnaval rapide |
| `favela.ogg` | favela_morro | Funk carioca + forró lent |

---

## Priorités d'attaque

1. **Pack "Feedback UI"** (★★★) : `coin`, `dialogue`, `prompt_chime`, `quest_accepted`,
   `quest_complete`. Cinq fichiers pour transformer la sensation de moins
   "prototype". 5–10 min de chasse sur freesound.
2. **Pack "Pas"** (★★) : 4 fichiers `step_*`, courts (0.15s). Important pour
   l'incarnation du joueur. Une "step pack" générique sur freesound suffit
   (chercher `footstep pack`).
3. **Ambient principal** : juste `waves.ogg` (déjà référencé partout par
   fallback). Une seule boucle de vagues 60s, et 3 districts deviennent
   immersifs d'un coup.
4. **Musique d'un district phare** : `beach.ogg` ou `ipanema.ogg`. Donne une
   identité immédiate au lieu où le joueur passe le plus de temps.
5. Le reste s'ajoute au fur et à mesure — chaque fichier nouveau s'auto-active.

---

## Test rapide

Pour vérifier qu'un nouveau fichier est bien pris : démarrer le jeu, surveiller
la console. Aucune erreur = le fichier a été chargé. Si tu entends le son
attendu lors de l'action, c'est OK.

Pour debug, dans la console GDScript :
```
AudioManager.play("coin")           # tester un SFX
AudioManager._swap_ambient("corcovado")  # forcer un ambient
AudioManager._swap_music("zona_sul")     # forcer une musique
```
