"""Copy the app data into the iOS project: question banks, law excerpts (as an ordered list, so the
search engine sees them in the same order as the web app), sign meanings, question pictures and the
sign SVGs as vector image sets of the asset catalog.

Usage: python3 -I scripts/build-ios-assets.py   (run after merge-fr.py / build-signs.py)
"""
import json, os, shutil

APP = 'ios/App'
DATA = f'{APP}/Resources/Data'
IMAGES = f'{APP}/Resources/Images'
SIGNS = f'{APP}/Assets.xcassets/Signs'

os.makedirs(DATA, exist_ok=True)
for name in ('questions.fr.json', 'questions.he.json'):
    shutil.copy(f'public/data/{name}', f'{DATA}/{name}')

law = json.load(open('public/data/law.json'))
json.dump([{'ref': ref, **e} for ref, e in law.items()], open(f'{DATA}/law.json', 'w'), ensure_ascii=False, separators=(',', ':'))

signs = json.load(open('public/data/signs.json'))
svgs = {f[:-4] for f in os.listdir('public/signs') if f.endswith('.svg')}
# Every sign with an SVG on disk gets a picture, even if signs.json has no `img` for it yet.
out = [{'n': n, **{k: v for k, v in s.items() if k != 'img'}, 'asset': f'sign-{n.encode().hex()}' if n in svgs else None} for n, s in signs.items()]
json.dump(out, open(f'{DATA}/signs.json', 'w'), ensure_ascii=False, separators=(',', ':'))

shutil.rmtree(IMAGES, ignore_errors=True)
shutil.copytree('public/img', IMAGES)

shutil.rmtree(SIGNS, ignore_errors=True)
os.makedirs(SIGNS)
json.dump({'info': {'author': 'xcode', 'version': 1}, 'properties': {'provides-namespace': False}}, open(f'{SIGNS}/Contents.json', 'w'), indent=2)
for s in out:
    if not s['asset']:
        continue
    folder = f"{SIGNS}/{s['asset']}.imageset"
    os.makedirs(folder)
    shutil.copy(f"public/signs/{s['n']}.svg", f'{folder}/sign.svg')
    json.dump({
        'images': [{'filename': 'sign.svg', 'idiom': 'universal'}],
        'info': {'author': 'xcode', 'version': 1},
        'properties': {'preserves-vector-representation': True},
    }, open(f'{folder}/Contents.json', 'w'), indent=2)

print(f"{len(out)} signs ({sum(1 for s in out if s['asset'])} with picture), {len(law)} law excerpts, "
      f"{len(os.listdir(IMAGES))} pictures")
