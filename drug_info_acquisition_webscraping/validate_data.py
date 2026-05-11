import json

with open('outputs/medicamentos_infomed.json', encoding='utf-8') as f:
    data = json.load(f)

print(f'Total records: {len(data)}')
print('Sample records:')
for r in data[:5]:
    cnp = r.get('cnpem', '')[:8]
    nome = r.get('nomeComercial', '')[:30]
    subs = r.get('substanciaAtiva', '')[:25]
    dos = r.get('dosagem', '')[:20]
    print(f'  {cnp:>8} | {nome:30} | {subs:25} | {dos}')

# Stats
with_fi = sum(1 for r in data if r.get('fiUrl'))
print(f'\nRecords with FI PDF link: {with_fi}/{len(data)}')
unique_dci = len(set(r.get('substanciaAtiva', '') for r in data))
print(f'Unique active substances: {unique_dci}')
