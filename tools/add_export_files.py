"""Add res:// paths to the explicit export file list of every preset in export_presets.cfg (idempotent).
usage: python3 tools/add_export_files.py res://path/a.gd res://path/b.png ...
       python3 tools/add_export_files.py --include "assets/levels/*.json"   (adds an include_filter pattern)
The list is one huge line: never grep it with broad patterns; use this script."""
import re, sys
p = 'export_presets.cfg'
s = open(p).read()
args = sys.argv[1:]
if args and args[0] == '--include':
    pat = args[1]
    def inc(m):
        cur = m.group(1)
        parts = [x.strip() for x in cur.split(',') if x.strip()]
        if pat not in parts:
            parts.append(pat)
        return 'include_filter="%s"' % ', '.join(parts)
    s = re.sub(r'include_filter="([^"]*)"', inc, s)
else:
    def add(m):
        body = m.group(1)
        have = set(re.findall(r'"([^"]+)"', body))
        new = [a for a in args if a not in have]
        if not new:
            return m.group(0)
        return 'export_files=PackedStringArray(%s, %s)' % (body, ', '.join('"%s"' % a for a in new))
    s = re.sub(r'export_files=PackedStringArray\((.*?)\)', add, s)
open(p, 'w').write(s)
for m in re.finditer(r'export_files=PackedStringArray\((.*?)\)', s):
    print('preset files:', len(re.findall(r'"([^"]+)"', m.group(1))))
for m in re.finditer(r'include_filter="([^"]*)"', s):
    print('include_filter:', m.group(1))
