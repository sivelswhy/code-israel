"""Builds the LoRA training set for the on-device assistant: same prompt layout as src/assistant
(SYSTEM + SOURCES + QUESTION), answers written only from the verified explanations and law references.
Usage: python3 -I scripts/build-ft-data.py  ->  ft/data/{train,valid}.jsonl
"""
import json, math, random, re, unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
random.seed(7)
Q = json.loads((ROOT / 'public/data/questions.fr.json').read_text())
LAW = json.loads((ROOT / 'public/data/law.json').read_text())
SIGNS = json.loads((ROOT / 'public/data/signs.json').read_text())
LLM = (ROOT / 'src/assistant/llm.ts').read_text()
SYSTEM = re.search(r'SYSTEM = `(.*?)`', LLM, re.S).group(1)

STOP = set("""le la les un une des de du d l au aux et ou en a à est sont il elle on je tu vous nous ce cet cette ces que qui quoi
quel quelle quels quelles dans sur sous pour par avec sans ne pas plus moins se sa son ses leur leurs y si mais
comme quand comment pourquoi est-ce faut peut doit dois puis-je ai as avez être avoir fait faire très tout tous""".split())

def tokens(t):
    t = unicodedata.normalize('NFD', t)
    t = re.sub('[̀-ͯ]', '', t).lower().replace('’', ' ').replace("'", ' ')
    out = []
    for w in re.split(r'[^a-z0-9]+', t):
        if len(w) > 1 and w not in STOP:
            out.append(re.sub(r'(es|s|x)$', '', w) if len(w) > 4 else w)
    return out

docs = []
df = {}
for q in Q:
    tk = tokens(f"{q['q']} {q['a'][q['c']]} {q.get('e', '')}")
    tf = {}
    for t in tk: tf[t] = tf.get(t, 0) + 1
    for t in tf: df[t] = df.get(t, 0) + 1
    docs.append((q, tf, len(tk)))
avg = sum(d[2] for d in docs) / len(docs)

def search(text, limit=4):
    terms = set(tokens(text)); n = len(docs); hits = []
    for q, tf, ln in docs:
        s = 0
        for t in terms:
            f = tf.get(t)
            if not f: continue
            idf = math.log(1 + (n - df[t] + .5) / (df[t] + .5))
            s += idf * f * 2.2 / (f + 1.2 * (.25 + .75 * ln / avg))
        if s > 0: hits.append((s * (1.25 if q.get('e') else 1), q))
    hits.sort(key=lambda h: -h[0])
    return [q for _, q in hits[:limit]], (hits[0][0] if hits else 0)

def block(q, detailed):
    L = [f"[Question officielle n° {q['id']}] {q['q']}"]
    if detailed: L.append('Réponses proposées : ' + ' | '.join(f"{'ABCD'[i]}) {a}" for i, a in enumerate(q['a'])))
    L.append(f"Bonne réponse : {q['a'][q['c']]}")
    if q.get('e'): L.append(f"Explication : {q['e']}")
    if detailed:
        nums = list(dict.fromkeys(re.findall(r'\b\d{3}\b', ' '.join([q['q']] + q['a']))))
        for n in nums:
            if n in SIGNS and (q['cat'] == 'signs' or re.search('panneau', q['q'], re.I)):
                L.append(f"Panneau {n} : {SIGNS[n]['fr']}")
    for r in q.get('r') or []:
        ex = LAW.get(r)
        if ex: L.append(f"{ex['l']} : {ex['x'][:350]}" if detailed else f"Référence : {ex['l']}")
    return '\n'.join(L)

def sources(hits, focus=None):
    rest = [h for h in hits if not focus or h['id'] != focus['id']][: 2 if focus else 3]
    return '\n\n'.join(([block(focus, True)] if focus else []) + [block(q, not focus) for q in rest])

def ref_label(q):
    for r in q.get('r') or []:
        if r in LAW: return LAW[r]['l']
    return None

def good_answer(q, lead):
    parts = [f"{lead}« {q['a'][q['c']].rstrip('.')} »."]
    e = q['e'].strip()
    parts.append(e if e.endswith(('.', '!', '?')) else e + '.')
    lab = ref_label(q)
    if lab: parts.append(f"Référence : {lab}.")
    return ' '.join(parts)

def ex(user, assistant): return {'messages': [{'role': 'system', 'content': SYSTEM}, {'role': 'user', 'content': user}, {'role': 'assistant', 'content': assistant}]}

def user_msg(src, question, ctx=''): return f"SOURCES :\n{src}\n\nQUESTION DE L'ÉLÈVE :\n{question}{ctx}"

data = []
cand = [q for q in Q if q.get('e')]
for q in cand:
    hits, _ = search(q['q'])
    shown = [q] + [h for h in hits if h['id'] != q['id']]
    shown = shown[:4]
    src = sources(shown, q)
    right = q['a'][q['c']]
    if random.random() < .5:
        data.append(ex(user_msg(src, f"Pourquoi la bonne réponse est-elle « {right} » ?"), good_answer(q, 'La bonne réponse est ')))
    else:
        w = random.choice([i for i in range(4) if i != q['c']])
        data.append(ex(user_msg(src, f"Pourquoi ma réponse « {q['a'][w]} » est-elle fausse ?", f"\n(L'élève avait répondu : « {q['a'][w]} ».)"),
                       good_answer(q, f"Ta réponse « {q['a'][w].rstrip('.')} » est fausse. La bonne réponse est ")))
    if random.random() < .35:
        first = re.split(r'(?<=[.!?])\s', q['e'].strip())[0]
        data.append(ex(user_msg(src, 'Donne-moi un moyen simple de retenir cette règle.'), f"À retenir : {first}" + (f" Référence : {ref_label(q)}." if ref_label(q) else '')))
    # free question, no focus: the student's own words, sources come from search
    if q['cat'] != 'signs' and random.random() < .7:
        question = q['q'].rstrip(' :?').strip() + ' ?'
        hits, _ = search(question)
        if q['id'] not in [h['id'] for h in hits[:3]]: hits = [q] + hits[:2]
        data.append(ex(user_msg(sources(hits[:3]), question), good_answer(q, 'Bonne réponse : ')))

OFF = ['Quelle est la capitale de la France ?', 'Donne-moi une recette de crêpes.', 'Qui a gagné la dernière Coupe du monde ?',
       'Comment installer Windows ?', 'Quel est le meilleur téléphone ?', 'Écris-moi un poème.', 'Combien coûte un billet de train ?',
       'Quelle est la météo demain ?', 'Peux-tu traduire ce texte en anglais ?', 'Comment obtenir un visa pour les États-Unis ?']
NOANS = "Les sources fournies ne permettent pas de répondre à cette question. Pose-moi une question sur le code de la route israélien ou reformule-la, et je chercherai dans les questions officielles."
for _ in range(150):
    off = random.choice(OFF)
    pool = random.sample(cand, 3)
    data.append(ex(user_msg(sources(pool), off), NOANS))

random.shuffle(data)
n_valid = max(60, len(data) // 20)
out = ROOT / 'ft/data'; out.mkdir(parents=True, exist_ok=True)
for name, rows in (('valid', data[:n_valid]), ('train', data[n_valid:])):
    (out / f'{name}.jsonl').write_text('\n'.join(json.dumps(r, ensure_ascii=False) for r in rows) + '\n')
print(len(data) - n_valid, 'train /', n_valid, 'valid')
