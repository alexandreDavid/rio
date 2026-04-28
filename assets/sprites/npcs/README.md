# Sprites individuels par NPC

Dépose ici **un PNG par personnage**, nommé exactement `<id>.png`. Le jeu charge automatiquement le PNG s'il existe, sinon retombe sur la région de l'atlas `characters_ai.png`.

## Convention

- **Fichier** : `assets/sprites/npcs/<id>.png`
- **Taille recommandée** : 1024×1024 (sortie standard d'OpenAI gpt-image-1). Le jeu redimensionne automatiquement à 48 px de haut à l'écran (cf `NPC.SPRITE_TARGET_HEIGHT`) — même proportion que le sprite du joueur.
- **Style** : pixel art chibi style Stardew Valley (grosse tête volumineuse, petit corps, contour foncé, dot eyes), aligné sur le joueur.
- **Fond** : transparent. Avec OpenAI, passe `background: "transparent"` à l'API et `format: "png"`.

## Liste des IDs (à utiliser comme nom de fichier)

| ID | Personnage |
|---|---|
| `seu_joao` | Seu João (oncle âgé, charrette de milho) |
| `ramos` | Capitão Ramos (PM gym-rat) |
| `tito` | Tito (tráfico, favela) |
| `padre` | Padre Anselmo (curé) |
| `farmaceutico` | Dona Carmen (pharmacienne) |
| `vendeuse_boutique` | Beatriz (Rio Style) |
| `carlos` | Carlos (Café ISSIMO) |
| `chef_restaurant` | Chef (Cantinho Carioca) |
| `concierge` | Concierge / tio Zé déguisé (Palace) |
| `contessa` | Contessa Bianchi (italienne en vacances) |
| `miguel` | Miguel (passeur) |
| `otavio` | Otávio (chef-valet du Copa) |
| `bar_patrao` | Patrão (Bar do Policial) |
| `padeiro` | Seu Tonio (boulanger) |
| `dona_irene` | Dona Irene (chien Bingo) |
| `pecheur` | Seu Pedro (pêcheur) |
| `coconut_vendor` | Dona Lúcia (vendeuse de cocos) |
| `tourist_vip` | Touriste VIP gringo |
| `joggeur` | Joggeur |
| `musicien` | Ronaldo (samba/violão) |
| `military_pm` | PM gardien du Forte |
| `consortium` | Dom Nilton (boss consortium) |
| `policier` | Agente Silva |
| `jorge` | Jorge (videur du bar) |
| `ze_bar` | Zé (kiosque du calçadão) |

## Workflow OpenAI

```python
from openai import OpenAI
import base64
client = OpenAI()

# Exemple Seu João
result = client.images.generate(
    model="gpt-image-1",
    prompt=PROMPT_SEU_JOAO,  # cf prompts fournis
    size="1024x1024",
    background="transparent",
    output_format="png",
    n=1,
)
image_b64 = result.data[0].b64_json
with open("seu_joao.png", "wb") as f:
    f.write(base64.b64decode(image_b64))
```

Lance la même boucle pour les 25 IDs et dépose les fichiers ici.

## Vérification

Au prochain démarrage du jeu, chaque NPC qui a son PNG l'affichera. Les autres restent sur l'atlas. Aucun montage à faire.

## Variables d'ajustement (NPC.gd)

- `SPRITE_TARGET_HEIGHT = 48.0` — hauteur en pixels du sprite à l'écran. Même valeur que le joueur (256 × 0.1875 = 48).
- Le `modulate` défini dans la `.tscn` reste appliqué — pratique pour teinter sans regénérer. Mets `Color(1, 1, 1, 1)` si tu veux le PNG sans teinte.
