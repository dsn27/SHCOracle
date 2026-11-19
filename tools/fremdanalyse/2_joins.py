import re,sys,csv,pickle,collections,json
files=pickle.load(open(sys.argv[1],'rb')); repo=sys.argv[2]; out=sys.argv[3]
cols=collections.defaultdict(set)
for r in csv.DictReader(open(repo+'/schema/columns.csv',encoding='utf-8'),delimiter=';'): cols[r['TABLE_NAME']].add(r['COLUMN_NAME'])
KW=set('where on join left right inner outer full cross group order union set and or select from having connect start minus intersect natural using partition model fetch for into values natural with'.split())
def strip(t):
  t=re.sub(r'/\*.*?\*/',' ',t,flags=re.S); t=re.sub(r'--[^\n]*',' ',t); t=re.sub(r"'(?:[^']|'')*'","'?'",t); return t
pairfiles=collections.defaultdict(set)     # (T1,c1,T2,c2) -> files
sigfiles=collections.defaultdict(set)      # (T1,T2,frozenset(pairs)) -> files
amb=0
for path,t in files:
  s=strip(t).upper()
  for st in re.split(r';|\n\s*/\s*\n',s):
    if 'SELECT' not in st and 'UPDATE' not in st: continue
    amap=collections.defaultdict(set)
    for m in re.finditer(r'\b(?:[A-Z_][A-Z0-9_$]*\.)?(T\d{3}[A-Z0-9_]*)\b(?:\s+(?:AS\s+)?([A-Z_][A-Z0-9_$]*))?',st):
      tb,al=m.group(1),m.group(2)
      if tb not in cols: continue
      amap[tb].add(tb)
      if al and al.lower() not in KW and not re.match(r'T\d{3}',al): amap[al].add(tb)
    res=lambda q: next(iter(amap[q])) if len(amap.get(q,()))==1 else None
    per=collections.defaultdict(set)
    for m in re.finditer(r'([A-Z_][A-Z0-9_$]*(?:\.[A-Z_][A-Z0-9_$]*){1,2})\s*(?:\(\+\))?\s*=\s*([A-Z_][A-Z0-9_$]*(?:\.[A-Z_][A-Z0-9_$]*){1,2})\s*(?:\(\+\))?',st):
      a=m.group(1).split('.')[-2:]; b=m.group(2).split('.')[-2:]
      ta,tb_=res(a[0]),res(b[0])
      if not ta or not tb_: amb+=1; continue
      if ta==tb_: continue
      if a[1] not in cols[ta] or b[1] not in cols[tb_]: continue
      x=(ta,a[1],tb_,b[1]) if ta<tb_ else (tb_,b[1],ta,a[1])
      pairfiles[x].add(path); per[(x[0],x[2])].add((x[1],x[3]))
    for (t1,t2),ps in per.items(): sigfiles[(t1,t2,frozenset(ps))].add(path)
# Ergebnis: je Tabellenpaar die haeufigste vollstaendige Signatur
bypair=collections.defaultdict(list)
for (t1,t2,ps),fs in sigfiles.items(): bypair[(t1,t2)].append((len(fs),sorted(ps)))
rows=[]
for (t1,t2),lst in bypair.items():
  lst.sort(key=lambda x:-x[0]); tot=sum(n for n,_ in lst)
  rows.append(dict(t1=t1,t2=t2,files_total=len(set().union(*[sigfiles[(t1,t2,frozenset(map(tuple,p)))] for _,p in lst])),best_n=lst[0][0],best=lst[0][1],variants=len(lst),alts=lst[1:4]))
rows.sort(key=lambda r:-r['files_total'])
json.dump(rows,open(out,'w'),default=list)
print('Tabellenpaare mit Joins:',len(rows),'| nicht aufloesbare Vergleiche:',amb)
for r in rows[:45]:
  print(f"{r['files_total']:4d} {r['t1']:10s} {r['t2']:10s} [{r['best_n']}x] "+' AND '.join(f'{a}={b}' for a,b in r['best'])+(f"  (+{r['variants']-1} Var.)" if r['variants']>1 else ''))
