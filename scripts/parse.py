"""Parse the official Israeli Ministry of Transport theory-test RSS/XML into JSON."""
import json, re, sys, html
import xml.etree.ElementTree as ET

def parse(path):
    root = ET.parse(path).getroot()
    out = []
    for item in root.iter('item'):
        title = (item.findtext('title') or '').strip()
        m = re.match(r'^\s*(\d+)\s*[.\-]\s*(.*)$', title, re.S)
        if not m:
            continue
        qid, text = m.group(1), m.group(2)
        desc = item.findtext('description') or ''
        lis = re.findall(r'<li>(.*?)</li>', desc, re.S)
        answers, correct = [], None
        for i, li in enumerate(lis):
            if 'correctAnswer' in li:
                correct = i
            answers.append(html.unescape(re.sub(r'<[^>]+>', '', li)).strip())
        img = re.search(r'<img[^>]+src="([^"]+)"', desc)
        lic = re.search(r'<span>\s*(\|.*?)</span>', desc, re.S)
        licenses = []
        if lic:
            licenses = [x.strip().strip('«»').replace('В', 'B') for x in lic.group(1).split('|') if x.strip()]
        out.append({
            'id': qid.zfill(4),
            'q': re.sub(r'\s+', ' ', html.unescape(text)).strip(),
            'a': [re.sub(r'\s+', ' ', a) for a in answers],
            'c': correct,
            'img': img.group(1) if img else None,
            'lic': licenses,
            'cat': (item.findtext('category') or '').strip(),
        })
    return out

if __name__ == '__main__':
    data = parse(sys.argv[1])
    json.dump(data, open(sys.argv[2], 'w'), ensure_ascii=False, indent=0)
    print(len(data), 'questions')
