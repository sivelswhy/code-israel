"""Print one batch of questions (Hebrew original + English reference) to translate.

Usage: python3 -I scripts/dump-batch.py <batch_number> [size]
"""
import json, sys

n, size = int(sys.argv[1]), int(sys.argv[2]) if len(sys.argv) > 2 else 60
he = json.load(open('data/official/questions.he.json'))
en = {q['id']: q for q in json.load(open('data/official/questions.en.json'))}
for q in he[n * size:(n + 1) * size]:
    e = en.get(q['id'])
    print(f"#{q['id']} [{q['cat']}]{' img' if q['img'] else ''}")
    print('HE:', q['q'])
    for i, a in enumerate(q['a']):
        print(f"  {i + 1}{'*' if i == q['c'] else ' '} {a}")
    if e:
        print('EN:', e['q'], '|', ' / '.join(('*' if i == e['c'] else '') + a for i, a in enumerate(e['a'])))
