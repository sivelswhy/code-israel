"""Build per-language JSON (into data/official) for the app from the official data.gov.il theory-test XML files.

Source: Israeli Ministry of Transport, data.gov.il (Creative Commons Attribution).
Usage: python3 -I scripts/build-data.py <raw_dir> <out_dir>
"""
import json, os, re, sys, html
import xml.etree.ElementTree as ET

CATS = {
    'Code de la route': 'rules', 'Sécurité': 'safety', 'Panneaux': 'signs', 'Connaissance du véhicule': 'vehicle',
    'חוקי התנועה': 'rules', 'בטיחות': 'safety', 'תמרורים': 'signs', 'הכרת הרכב': 'vehicle',
    'Rules and Regulations': 'rules', 'Safety': 'safety', 'Traffic Signs': 'signs', 'Know Your Vehicle': 'vehicle',
}
LICENSES = ['B', 'A', '1', 'C1', 'C', 'D']

def clean(s):
    s = html.unescape(re.sub(r'<[^>]+>', '', s))
    return re.sub(r'\s+', ' ', s).strip()

def fix_mojibake(s):
    try:
        return s.encode('latin-1').decode('utf-8')
    except (UnicodeEncodeError, UnicodeDecodeError):
        return s

def parse(path):
    out = {}
    for item in ET.parse(path).getroot().iter('item'):
        m = re.match(r'^\s*(\d+)\s*[.\-]\s*(.*)$', item.findtext('title') or '', re.S)
        if not m:
            continue
        qid = m.group(1).zfill(4)
        desc = item.findtext('description') or ''
        lis = re.findall(r'<li>(.*?)</li>', desc, re.S)
        correct = next(i for i, li in enumerate(lis) if 'correctAnswer' in li)
        img = re.search(r'<img[^>]+alt="([^"]+)"', desc) or re.search(r'<img[^>]+src="[^"]*?(\d+)\.\w+"', desc)
        lic = [l.replace('В', 'B') for l in re.findall(r'«([^»]+)»', desc)]
        out[qid] = {
            'id': qid,
            'q': clean(m.group(2)),
            'a': [clean(li) for li in lis],
            'c': correct,
            'img': img.group(1) if img else None,
            'lic': [l for l in LICENSES if l in lic],
            'cat': CATS[fix_mojibake((item.findtext('category') or '').strip())],
        }
    return out

raw, out_dir = sys.argv[1], sys.argv[2]
os.makedirs(out_dir, exist_ok=True)
images = set()
for lang in ['fr', 'he', 'en']:
    qs = sorted(parse(os.path.join(raw, lang + '.xml')).values(), key=lambda q: q['id'])
    images |= {q['img'] for q in qs if q['img']}
    with open(os.path.join(out_dir, f'questions.{lang}.json'), 'w') as f:
        json.dump(qs, f, ensure_ascii=False, separators=(',', ':'))
    print(lang, len(qs))
with open(os.path.join(raw, 'images.txt'), 'w') as f:
    f.write('\n'.join(sorted(images)))
print('images', len(images))
