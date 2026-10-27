"""Download official question images from gov.il (the legacy tqpic.mot.gov.il host no longer resolves).

Usage: python3 -I scripts/fetch-images.py <images.txt> <out_dir>
"""
import os, sys, urllib.request
from concurrent.futures import ThreadPoolExecutor

FOLDERS = ['tq_pic_01', 'tq_pic_02', 'tq_pic_03', 'tq_pic_04', 'tq_pic_05']
ids, out = open(sys.argv[1]).read().split(), sys.argv[2]
os.makedirs(out, exist_ok=True)

def fetch(n):
    dest = os.path.join(out, f'{n}.jpg')
    if os.path.exists(dest) and os.path.getsize(dest):
        return None
    for f in FOLDERS:
        req = urllib.request.Request(f'https://www.gov.il/BlobFolder/generalpage/{f}/he/TQ_PIC_{n}.jpg', headers={'User-Agent': 'Mozilla/5.0'})
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                if r.headers.get_content_type().startswith('image/'):
                    open(dest, 'wb').write(r.read())
                    return None
        except Exception:
            pass
    return n

missing = [n for n in ThreadPoolExecutor(3).map(fetch, ids) if n]
print('missing:', missing)
