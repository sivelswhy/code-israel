# Code Israël — apps iPhone et Mac (SwiftUI)

App native : SwiftUI, aucune page web. La logique (recherche, texte de loi, garde-fous de l’IA,
examen, progression) est dans le paquet `CodeIsraelKit`, testé pour donner exactement les mêmes
résultats que l’app web.

## Lancer l’app

1. Préparer les données (après toute modification de `public/data` ou des traductions) :
   `python3 -I scripts/build-ios-assets.py`
2. Générer le projet Xcode : `cd ios && xcodegen generate`
3. Ouvrir `ios/CodeIsrael.xcodeproj`, choisir votre équipe dans *Signing & Capabilities*,
   puis lancer sur l’iPhone.
   - Au premier build, Xcode demande d’autoriser les macros de `mlx-swift-lm` : « Trust & Enable ».
   - Le Qwen local n’est pas disponible dans le simulateur (MLX a besoin du GPU de l’iPhone).

## App Mac

Même code SwiftUI que l’iPhone, cible `CodeIsraelMac` (macOS 14 minimum). Dans Xcode, choisir le schéma
**CodeIsraelMac** et « My Mac ». Les différences entre iPhone et Mac sont réunies dans
`App/Sources/Views/Platform.swift` (images, couleurs, fenêtres modales, retour haptique).
Sur Mac, l’app est dans le bac à sable (`App/CodeIsraelMac.entitlements`) avec l’accès réseau sortant, utilisé
une seule fois pour télécharger le Qwen local.

Construire en ligne de commande demande le composant Metal Toolchain de Xcode (MLX compile ses shaders) :
`xcodebuild -downloadComponent MetalToolchain`.

## IA de l’assistant (toujours sur l’iPhone, gratuite)

1. **Apple Intelligence** (Foundation Models, iOS 26+, iPhone compatible) : rien à télécharger.
   Seul le modèle sur l’appareil est utilisé, jamais Private Cloud Compute.
2. Sinon **Qwen3.5 2B** (MLX, 1,75 Go, téléchargé une fois depuis Hugging Face) sur les iPhone
   d’au moins 6 Go de mémoire. L’entitlement `increased-memory-limit` est déclaré pour lui.
3. Sinon **mode recherche** : réponses composées directement à partir des textes officiels.

Dans tous les cas, une réponse de l’IA qui contient un chiffre, un article ou une affirmation
absents des sources est remplacée par la réponse composée à partir des textes officiels.

## Tests

`cd ios/CodeIsraelKit && swift test --scratch-path /tmp/codeisraelkit-build`

(`--scratch-path` hors du dossier Documents évite une erreur de signature due aux attributs
étendus de macOS.) Après une modification de `src/assistant/search.ts`, régénérer les références
de la version web, depuis la racine du dépôt :

```
npx esbuild src/assistant/search.ts --bundle --format=esm --outfile=/tmp/search.mjs
node scripts/ios-parity-fixtures.mjs /tmp/search.mjs
```
