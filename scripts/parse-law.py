"""Index Israeli traffic law (Hebrew Wikisource / Open Law Book wikitext) into JSON by section.

Laws and regulations are not subject to copyright in Israel (Copyright Act 2007, s. 6).
Usage: python3 -I scripts/parse-law.py   (reads data/law/*.wiki, writes data/law/index.json)
"""
import json, re

SOURCES = {
    'T': ('data/law/takanot.wiki', 'תקנות התעבורה, תשכ״א–1961', 'https://he.wikisource.org/wiki/תקנות_התעבורה'),
    'P': ('data/law/pkuda.wiki', 'פקודת התעבורה [נוסח חדש]', 'https://he.wikisource.org/wiki/פקודת_התעבורה'),
}

def flatten_tables(s):
    """Render HTML tables as one line per row: 'row label — column: value · column: value'."""
    def cell(c):
        return re.sub(r'\s+', ' ', plain(c)).strip()
    def table(m):
        rows = [re.findall(r'<t([dh])[^>]*>(.*?)</t[dh]>', r, re.S) for r in re.findall(r'<tr[^>]*>(.*?)</tr>', m.group(0), re.S)]
        heads = max(([cell(c) for k, c in r] for r in rows if r and all(k == 'h' for k, _ in r)), key=len, default=[])
        out = []
        for r in rows:
            if not r or all(k == 'h' for k, _ in r):
                continue
            vals = [cell(c) for _, c in r]
            if not any(vals[1:]):
                continue
            if len(vals) - 1 == len(heads):
                out.append(vals[0] + ' — ' + ' · '.join(f'{h}: {v}' for h, v in zip(heads, vals[1:]) if v))
            else:
                out.append(' | '.join(v for v in vals if v))
        return '\n'.join(out)
    return re.sub(r'<table.*?</table>', table, s, flags=re.S)

def plain(s):
    # {{ח:חיצוני|target|label}} / {{ח:פנימי|target|label}} -> label
    s = re.sub(r'\{\{ח:(?:חיצוני|פנימי)\|[^|{}]*\|([^{}]*)\}\}', r'\1', s)
    s = re.sub(r'\{\{ח:(?:חיצוני|פנימי)\|([^|{}]*)\}\}', r'\1', s)
    s = re.sub(r'\{\{ח:הערה\|([^{}]*)\}\}', r'(\1)', s)
    # Sub-clause markers keep their label, prefixed by one tab per nesting level (used to cut excerpts).
    s = re.sub(r'\{\{ח:(ת+)\|([^{}]*)\}\}', lambda m: '\t' * len(m.group(1)) + m.group(2), s)
    s = re.sub(r'\{\{ח:(ת+)\}\}', lambda m: '\t' * len(m.group(1)), s)
    s = re.sub(r'\{\{[^{}]*\}\}', '', s)
    s = re.sub(r"'''?", '', s)
    s = re.sub(r'<[^>]+>', '', s).replace('&nbsp;', ' ')
    s = s.replace('סוג=הגדרה ', '')
    return '\n'.join(l.rstrip().lstrip(' ') for l in s.splitlines() if l.strip())

index = {}
for key, (path, name, url) in SOURCES.items():
    text = open(path).read()
    end = text.find('{{ח:סוף}}')
    text = text[:end if end > 0 else None]
    parts = re.split(r'(\{\{ח:סעיף\*?\|[^}]*\}\})', text)
    for head, body in zip(parts[1::2], parts[2::2]):
        f = head.strip('{}').split('|')
        num, title = f[1].strip(), (f[2].strip() if len(f) > 2 else '')
        body = re.split(r'\{\{ח:קטע\d', body)[0]
        sid = f'{key}{num}'
        if sid in index or not num:
            continue
        index[sid] = {'src': key, 'n': num, 't': plain(title), 'x': plain(flatten_tables(body))}
json.dump({'sources': {k: {'name': v[1], 'url': v[2]} for k, v in SOURCES.items()}, 'sections': index},
          open('data/law/index.json', 'w'), ensure_ascii=False, indent=0)
print(len(index), 'sections', sum(1 for k in index if k[0] == 'T'), 'T')
