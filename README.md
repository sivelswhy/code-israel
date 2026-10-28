# Code Israël

Entraînement en français à l'examen théorique du permis de conduire israélien, à partir de la banque
de questions officielle du ministère des Transports (1 802 questions).

Application **non officielle**, sans publicité, sans compte, sans API externe : tout fonctionne sur
l'appareil.

## Ce que fait l'app

- Examen blanc au format officiel : 30 questions, 40 minutes, 4 erreurs maximum.
- Entraînement par thème, questions ratées, questions jamais vues, favoris.
- Revue des 20 derniers examens, question par question.
- Chaque question a une explication en français, reliée aux articles du règlement de la circulation.
- Lexique des panneaux avec leur signification.
- Assistant qui répond à partir des textes officiels, avec un modèle de langage local (WebLLM / Qwen sur le
  web ; Apple Foundation Models ou Qwen via MLX sur iPhone).
- Installable sur l'écran d'accueil et utilisable hors ligne (PWA).

## Lancer

```
npm install
npm run dev      # http://localhost:5173
npm run build    # site statique dans dist/, avec service worker
```

L'app iPhone (SwiftUI) est dans `ios/`, voir [ios/README.md](ios/README.md).

## Données

Les scripts de `scripts/` (Python, à lancer avec `python3 -I` depuis la racine) fabriquent les fichiers de
`public/data` :

- `build-data.py` : banque officielle (XML de data.gov.il) vers `data/official/`.
- `fetch-images.py` : images des questions.
- `translations/` : retraduction française depuis l'hébreu, explications et extraits de loi traduits.
- `merge-fr.py` : assemble le tout et refuse toute référence de loi introuvable.
- `build-signs.py`, `parse-law.py` : panneaux et texte de loi.

## Sources

- Questions et images : ministère des Transports d'Israël, via data.gov.il (CC BY).
- Règlement de la circulation et ordonnance : texte hébreu de Wikisource. Il n'existe pas de traduction
  officielle ; les extraits français sont des traductions de ce projet, **sans valeur juridique**.
- Panneaux : Wikimedia Commons et Wikipédia en hébreu.

La banque de questions est en retard sur la loi actuelle à certains endroits (par exemple les seuils de
poids de certains véhicules). Les explications indiquent la réponse attendue à l'examen, puis le texte en
vigueur.

Aucune licence n'est encore définie pour le code de ce dépôt.

## AltStore (iPhone)

L'app iPhone s'installe et se met à jour avec [AltStore](https://altstore.io). Dans AltStore, onglet **Sources** → **+**, puis collez :

```
https://raw.githubusercontent.com/sivelswhy/code-israel/main/altstore.json
```

Les mises à jour sont automatiques : dès qu'un changement du dossier `ios/` arrive sur `main`, le workflow **Version AltStore** s'exécute (ou lancez-le à la main depuis l'onglet **Actions** pour choisir le numéro de version). Le workflow construit l'IPA, la publie dans les *Releases* et ajoute la version au fichier `altstore.json` (à la racine du dépôt) : AltStore propose alors la mise à jour tout seul. `scripts/make-ipa.sh` construit l'IPA en local.

## Synchronisation entre appareils

Un code secret (`XXXX-XXXX-XXXX-XXXX`) garde la même progression sur le site, l'iPhone et le Mac : pas de compte, pas d'e-mail. Tout tourne dans le projet Vercel `code-israel-mail` (dossier `mail/`, plan gratuit) : `api/p.js` garde la progression de chacun sous l'empreinte (SHA-256) de son code, dans un espace de stockage Vercel Blob **privé**. Le serveur ne voit jamais le code, ni une adresse e-mail, ni un nom.

Mise en route, une seule fois (dans le tableau de bord Vercel) :

1. Projet `code-israel-mail` → onglet **Storage** → **Create** → **Blob** → accès **Private**, relié au projet (tous les environnements).
2. Redéployer le projet.
3. Les apps lisent l'adresse du serveur dans `public/sync.json` et `ios/App/Resources/Data/sync.json` (déjà présents) : tant qu'ils n'existent pas, la synchronisation reste masquée.

Tests : `cd mail && npm install && node --test send-code.test.mjs sync.test.mjs`.

### Envoyer le code par e-mail (facultatif)

`mail/api/send-code.js` envoie le code par e-mail avec un compte SMTP. Les identifiants ne sont jamais dans le dépôt : ils sont saisis dans les variables d'environnement du projet Vercel (*Settings → Environment Variables*) : `SMTP_HOST`, `SMTP_PORT` (465 ou 587), `SMTP_USER`, `SMTP_PASS`, `MAIL_FROM` (par exemple `Code Israël <toi@exemple.fr>`). `ALLOWED_RECIPIENTS` vaut `*` : chaque utilisateur reçoit son propre code.

La fonction n'envoie que le code d'une synchronisation qui existe, jamais un autre texte, au plus une fois par heure et par code, avec un plafond quotidien (`DAILY_MAIL_LIMIT`, 100 par défaut). Sans elle, les apps proposent un brouillon d'e-mail à envoyer soi-même.
