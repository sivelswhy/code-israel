"""Search / show sections of the indexed traffic law.

Usage: python3 -I scripts/law.py search <regex> [more regexes...]   (all must match the same line)
       python3 -I scripts/law.py show <ref> [<ref>...]               (e.g. T21, T47(ד), P1, T1:חניה)
"""
import re, sys
sys.path.insert(0, 'scripts')
from lawlib import law, excerpt, label

cmd, args = sys.argv[1], sys.argv[2:]
if cmd == 'search':
    n = 0
    for sid, sec in law()['sections'].items():
        for line in [sec['t']] + [l.lstrip('\t') for l in sec['x'].splitlines()]:
            if all(re.search(a, line) for a in args) and n < 8:
                print(f'{sid} [{sec["t"]}] {line[:170]}'); n += 1
else:
    for ref in args:
        sec, text = excerpt(ref)
        print(f'== {ref} = {label(ref)} [{sec["t"]}]\n{text[:2500]}')
