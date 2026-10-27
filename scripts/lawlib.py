"""Resolve law references like 'T47(ד)', 'T21(ב)(3)', 'P10' or 'T1:חניה' to official text excerpts."""
import json, re

HEB = 'אבגדהוזחטיכלמנסעפצקרשת'
LAT = 'ABCDEFGHIJKLMNOPQRSTU'
_law = None

def law():
    global _law
    if _law is None:
        _law = json.load(open('data/law/index.json'))
    return _law

def parse_ref(ref):
    m = re.fullmatch(r'([TP])([0-9]+[א-ת0-9]*)((?:\([^)]+\))*)(?::(.+))?', ref.strip())
    if not m:
        raise ValueError(f'bad ref {ref!r}')
    return m.group(1) + m.group(2), re.findall(r'\(([^)]+)\)', m.group(3)), m.group(4)

def _is_marker(line, kind):
    m = re.match(r'\(([^)]+)\)', line)
    if not m:
        return False
    v = m.group(1)
    return v.isdigit() if kind == 'num' else bool(re.fullmatch(r'[א-ת]{1,2}\d?', v))

def _depth(line):
    return len(line) - len(line.lstrip('\t'))

def _text(lines):
    return '\n'.join(l.lstrip('\t') for l in lines)

def excerpt(ref):
    """Return (section, text) for a reference; raises KeyError/ValueError if it cannot be resolved."""
    sid, path, term = parse_ref(ref)
    sec = law()['sections'][sid]
    lines = sec['x'].splitlines()
    if term:
        heads = [i for i, l in enumerate(lines) if l.lstrip('\t').startswith('”') and term in re.findall(r'”([^“]+)“', l.split(' – ')[0])]
        if not heads:
            raise KeyError(f'{ref}: definition not found')
        # keep the definition's numbered sub-items, up to the next definition
        i = heads[0]; out = [lines[i]]
        for l in lines[i + 1:]:
            if l.lstrip('\t').startswith('”'):
                break
            out.append(l)
        return sec, _text(out)
    for p in path:
        # Prefer the shallowest matching marker: lettered sub-items may also exist deeper inside numbered ones.
        cands = [i for i, l in enumerate(lines) if l.lstrip('\t').startswith(f'({p})')]
        if not cands:
            raise KeyError(f'{ref}: ({p}) not found')
        start = min(cands, key=lambda i: (_depth(lines[i]), i))
        d = _depth(lines[start])
        end = next((j for j in range(start + 1, len(lines)) if _depth(lines[j]) <= d), len(lines))
        lines = lines[start:end]
    return sec, _text(lines)

def label(ref):
    """French-readable label: 'Règlement de la circulation, art. 47(d)'."""
    sid, path, term = parse_ref(ref)
    src, num = sid[0], sid[1:]
    num = re.sub(r'[א-ת]+', lambda m: ''.join(LAT[HEB.index(c)] for c in m.group(0)), num)
    sub = ''.join('(' + ''.join(c if c.isdigit() else LAT[HEB.index(c)].lower() for c in p if c.isdigit() or c in HEB) + ')' for p in path)
    name = 'Règlement de la circulation' if src == 'T' else 'Ordonnance de la circulation'
    return f'{name}, art. {num}{sub}' + (' (définitions)' if term else '')
