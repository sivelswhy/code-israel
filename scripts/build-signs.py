"""Build the sign lexicon: French meaning (translations/fr-signs.txt), Hebrew official wording
(Hebrew Wikipedia, which reproduces the official sign chart) and SVG images from Wikimedia Commons
with their license and author.

Usage: python3 -I scripts/build-signs.py   (writes public/signs/*.svg and public/data/signs.json)
"""
import json, os, re, time, urllib.error, urllib.parse, urllib.request

UA = {'User-Agent': 'code-israel-study-app/0.1'}

def fetch(url):
    for attempt in range(6):
        try:
            return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60).read()
        except urllib.error.HTTPError as e:
            if e.code != 429:
                raise
            time.sleep(60 * (attempt + 1))  # Wikimedia rate limit
    raise RuntimeError(f'rate limited: {url}')

def api(**p):
    p['format'] = 'json'
    url = 'https://commons.wikimedia.org/w/api.php?' + urllib.parse.urlencode(p)
    return json.loads(fetch(url))

he = {}
wiki = open('data/signs/wikipedia-he.wiki').read()
for _, n, t in re.findall(r'קובץ:([^|\n]+)\|\s*תמרור\s*([0-9]+[א-ת]?)\s*[-–]\s*([^\n]+)', wiki):
    he.setdefault(n, re.sub(r'\[\[(?:[^|\]]*\|)?([^\]]*)\]\]', r'\1', t).strip())

signs = {}
for line in open('translations/fr-signs.txt'):
    if line.startswith('#') or not line.strip():
        continue
    n, cat, fr = [x.strip() for x in line.split('|', 2)]
    signs[n] = {'cat': cat, 'fr': fr, 'he': he.get(n)}

files = {re.sub(r'^Israel_road_sign_|\.svg$', '', f): f for f in json.load(open('data/signs/commons-files.json'))}
files.setdefault('112', files.get('112R'))
os.makedirs('public/signs', exist_ok=True)
wanted = {n: files[n] for n in signs if files.get(n)}
names = list(wanted.items())
for i in range(0, len(names), 40):
    chunk = dict(names[i:i + 40])
    r = api(action='query', titles='|'.join('File:' + f for f in chunk.values()), prop='imageinfo', iiprop='url|extmetadata')
    by_title = {p['title'].replace(' ', '_'): p for p in r['query']['pages'].values()}
    for n, f in chunk.items():
        info = by_title.get('File:' + f, {}).get('imageinfo', [{}])[0]
        meta = info.get('extmetadata', {})
        clean = lambda k: re.sub(r'<[^>]+>', '', meta.get(k, {}).get('value', '')).strip()
        if not info.get('url'):
            continue
        dest = f'public/signs/{n}.svg'
        if not os.path.exists(dest):
            open(dest, 'wb').write(fetch(info['url'].split('?')[0]))
            time.sleep(10)
        signs[n]['img'] = f'/signs/{n}.svg'
        signs[n]['credit'] = f"{clean('Artist') or 'Wikimedia Commons'} — {clean('LicenseShortName')}"
        signs[n]['src'] = 'https://commons.wikimedia.org/wiki/File:' + f
json.dump(signs, open('public/data/signs.json', 'w'), ensure_ascii=False, separators=(',', ':'))
print(len(signs), 'signs,', sum('img' in s for s in signs.values()), 'with image')
