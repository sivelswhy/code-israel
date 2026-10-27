"""Build the app's data: French text revised from the Hebrew original (translations/fr/*.txt),
falling back to the official French translation for questions not yet revised, plus explanations
with legal references (translations/fr-explain/*.txt) resolved against the official law text.

The Hebrew bank is authoritative for the correct answer, pictures and license classes.
Usage: python3 -I scripts/merge-fr.py
"""
import glob, json, re, shutil, sys
sys.path.insert(0, 'scripts')
from lawlib import excerpt, label, law

he = {q['id']: q for q in json.load(open('data/official/questions.he.json'))}
fr = {q['id']: q for q in json.load(open('data/official/questions.fr.json'))}

def typo(s):
    """French typography: curly apostrophe, narrow no-break space before ? ! ; and no-break space before : and inside « »."""
    s = s.replace("'", '\u2019')
    s = re.sub(r'\s+([?!;])', ' \\1', s)
    s = re.sub(r'\s+:', ' :', s)
    s = re.sub(r'«\s*', '« ', s)
    return re.sub(r'\s*»', ' »', s)

revised, errors = {}, []
for path in sorted(glob.glob('translations/fr/*.txt')):
    for block in re.split(r'\n\s*\n', open(path).read().strip()):
        lines = [l for l in block.strip().splitlines() if l.strip()]
        qid = lines[0].lstrip('#').strip()
        fields = dict(l.split(': ', 1) for l in lines[1:])
        answers = [fields.get(str(i + 1)) for i in range(4)]
        if qid not in he or 'Q' not in fields or None in answers or len(fields) != 5:
            errors.append(f'{path}: {qid}')
            continue
        if qid in revised:
            errors.append(f'{path}: duplicate {qid}')
        revised[qid] = {'q': typo(fields['Q']), 'a': [typo(a) for a in answers]}

explained, cited = {}, {}
for path in sorted(glob.glob('translations/fr-explain/*.txt')):
    for block in re.split(r'\n\s*\n', open(path).read().strip()):
        lines = [l for l in block.strip().splitlines() if l.strip()]
        qid = lines[0].lstrip('#').strip()
        fields = dict(l.split(': ', 1) for l in lines[1:])
        if qid not in he or 'E' not in fields or set(fields) - {'E', 'R'}:
            errors.append(f'{path}: {qid}')
            continue
        refs = [r.strip() for r in fields.get('R', '').split(';') if r.strip()]
        for r in refs:
            try:
                sec, text = excerpt(r)
            except (KeyError, ValueError) as e:
                errors.append(f'{path}: {qid}: {e}')
                continue
            src = law()['sources'][r[0]]
            anchor = 'סעיף_' + sec['n']
            cited[r] = {'l': label(r), 't': sec['t'], 'x': text, 'src': src['name'], 'u': src['url'] + '#' + anchor}
        explained[qid] = {'e': typo(fields['E']), 'r': refs}

law_fr = {}
for path in sorted(glob.glob('translations/law-fr/*.txt')):
    for block in re.split(r'\n\s*\n(?=#)', open(path).read().strip()):
        head, _, body = block.partition('\nF: ')
        ref = head.lstrip('#').strip()
        if not body.strip():
            errors.append(f'{path}: {ref}: no F:')
            continue
        if ref not in cited:
            # An article no question cites, translated on its own so the assistant can find it.
            try:
                sec, text = excerpt(ref)
            except (KeyError, ValueError) as e:
                errors.append(f'{path}: {ref}: {e}')
                continue
            src = law()['sources'][ref[0]]
            cited[ref] = {'l': label(ref), 't': sec['t'], 'x': text, 'src': src['name'], 'u': src['url'] + '#סעיף_' + sec['n']}
        law_fr[ref] = body.strip()
for ref, f in law_fr.items():
    cited[ref]['f'] = f

out = []
for qid in sorted(set(he) | set(fr)):
    if qid in revised:
        q = {**he[qid], **revised[qid], 'rev': True}
    else:
        q = dict(fr[qid])
    out.append({**q, **explained.get(qid, {})})
json.dump(cited, open('public/data/law.json', 'w'), ensure_ascii=False, separators=(',', ':'))

json.dump(out, open('public/data/questions.fr.json', 'w'), ensure_ascii=False, separators=(',', ':'))
shutil.copy('data/official/questions.he.json', 'public/data/questions.he.json')
print(f'{len(revised)}/{len(he)} revised, {len(explained)} explained, {len(cited)} legal excerpts ({len(law_fr)} translated), {len(out)} total')
if errors:
    raise SystemExit('Invalid blocks:\n' + '\n'.join(errors))
