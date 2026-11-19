import re,sys,csv,pickle,collections,json
files=pickle.load(open(sys.argv[1],'rb')); repo=sys.argv[2]; out=sys.argv[3]
cols=collections.defaultdict(set)
for r in csv.DictReader(open(repo+'/schema/columns.csv',encoding='utf-8'),delimiter=';'): cols[r['TABLE_NAME']].add(r['COLUMN_NAME'])
KW=set('WHERE ON JOIN LEFT RIGHT INNER OUTER FULL CROSS GROUP ORDER UNION SET AND OR SELECT FROM HAVING CONNECT START MINUS INTERSECT NATURAL USING PARTITION FOR INTO VALUES WITH'.split())
def strip(t):
  t=re.sub(r'/\*.*?\*/',' ',t,flags=re.S); t=re.sub(r'--[^\n]*',' ',t); return t
filt=collections.defaultdict(lambda: collections.defaultdict(set)); sums=collections.defaultdict(set)
for path,t in files:
  s=strip(t).upper()
  for st in re.split(r';|\n\s*/\s*\n',s):
    amap=collections.defaultdict(set)
    for m in re.finditer(r'\b(?:[A-Z_][A-Z0-9_$]*\.)?(T\d{3}[A-Z0-9_]*)\b(?:\s+(?:AS\s+)?([A-Z_][A-Z0-9_$]*))?',st):
      tb,al=m.group(1),m.group(2)
      if tb not in cols: continue
      amap[tb].add(tb)
      if al and al not in KW and not re.match(r'T\d{3}',al): amap[al].add(tb)
    alltabs=set().union(*amap.values()) if amap else set()
    def res(q):
      if q is None: return next(iter(alltabs)) if len(alltabs)==1 else None
      return next(iter(amap[q])) if len(amap.get(q,()))==1 else None
    # qualifizierte Spalte = Literal / IN (Literale) / <> Literal
    for m in re.finditer(r"(?:([A-Z_][A-Z0-9_$]*)\.)?([A-Z_][A-Z0-9_$]*)\s*(=|<>|!=|NOT\s+IN|IN)\s*(\(\s*(?:'[^']*'|-?\d+(?:\.\d+)?)(?:\s*,\s*(?:'[^']*'|-?\d+(?:\.\d+)?))*\s*\)|'[^']*'|-?\d+(?:\.\d+)?)(?![\.\w])",st):
      q,c,op,v=m.groups(); tb=res(q)
      if not tb or c not in cols[tb] or c in ('MANR',): continue
      op=re.sub(r'\s+',' ',op).replace('!=','<>')
      filt[(tb,c)][op+' '+re.sub(r'\s+','',v)].add(path)
    for m in re.finditer(r'\bSUM\s*\(((?:[^()]|\([^()]*\))*)\)',st):
      e=m.group(1)
      def rep(mm):
        tb=res(mm.group(1)); return (tb+'.' if tb else '?.')+mm.group(2)
      e=re.sub(r'\b([A-Z_][A-Z0-9_$]*)\.([A-Z_][A-Z0-9_$]*)',rep,e); e=re.sub(r'\s+',' ',e).strip()
      if re.search(r'T\d{3}',e): sums[e].add(path)
res=[]
for (tb,c),vals in filt.items():
  n=len(set().union(*vals.values()))
  res.append(dict(t=tb,c=c,n=n,vals=sorted(((k,len(v)) for k,v in vals.items()),key=lambda x:-x[1])[:8]))
res.sort(key=lambda r:-r['n'])
json.dump(dict(filters=res,sums=sorted(((k,len(v)) for k,v in sums.items()),key=lambda x:-x[1])[:150]),open(out,'w'))
for r in res[:45]: print(f"{r['n']:4d} {r['t']}.{r['c']}: "+', '.join(f'{k} ({n})' for k,n in r['vals'][:6]))
print('--- SUM-Ausdruecke')
for k,n in sorted(((k,len(v)) for k,v in sums.items()),key=lambda x:-x[1])[:40]: print(f'{n:4d} SUM({k})')
