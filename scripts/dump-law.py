"""Print batch N (30 legal excerpts) of public/data/law.json, plus any refs already translated skipped.

Usage: python3 -I scripts/dump-law.py N
Each ref is translated into translations/law-fr/NN.txt as:
  #<ref>
  F: <French rendering of the excerpt>
"""
import glob, json, re, sys

BATCH = 30
law = json.load(open('public/data/law.json'))
done = set()
for path in glob.glob('translations/law-fr/*.txt'):
    done |= set(re.findall(r'^#(.+)$', open(path).read(), re.M))
todo = [r for r in law if r not in done]
n = int(sys.argv[1]) if len(sys.argv) > 1 else 0
print(f'{len(done)} done, {len(todo)} left')
for ref in todo[:BATCH]:
    e = law[ref]
    print(f"\n#{ref}  [{e['l']}] {e['t']}\n{e['x']}")
