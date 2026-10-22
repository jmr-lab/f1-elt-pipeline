#!/usr/bin/env python3
import json

c = json.load(open('target/catalog.json'))

print("=== Column types from catalog ===")
for name in ['lap', 'session_entry', 'round', 'session']:
    for k, v in c['nodes'].items():
        if '.' + name in k or k.endswith(name):
            print('---', name, '---')
            for col, d in v.get('columns', {}).items():
                col_type = d.get('type', 'MISSING')
                print(f'  {col}: {repr(col_type)}')
            break

print("\n=== ERD snippet from index.html ===")
html = open('dbt/target/index.html').read()
if 'erDiagram' in html:
    idx = html.index('erDiagram')
    print(html[idx:idx+1500])
else:
    print("No erDiagram found in index.html")
