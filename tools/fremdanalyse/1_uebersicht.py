import os,re,sys,csv,hashlib,collections,pickle
root,repo,out=sys.argv[1],sys.argv[2],sys.argv[3]
tabs={r['TABLE_NAME']:r for r in csv.DictReader(open(repo+'/schema/tables.csv',encoding='utf-8'),delimiter=';')}
files=[];seen=set();dups=0;skipped=collections.Counter()
for dp,dn,fs in os.walk(root):
  for f in fs:
    ext=f.rsplit('.',1)[-1] if '.' in f else ''
    if ext.lower()!='sql': skipped[ext.lower()]+=1; continue
    if 'backup' in dp.lower(): skipped['backup-ordner']+=1; continue
    p=os.path.join(dp,f); b=open(p,'rb').read()
    try: t=b.decode('utf-8')
    except UnicodeDecodeError: t=b.decode('cp1252','replace')
    h=hashlib.md5(re.sub(r'\s+',' ',t.lower()).encode()).hexdigest()
    if h in seen: dups+=1; continue
    seen.add(h); files.append((os.path.relpath(p,root),t))
print('eindeutige .sql-Dateien:',len(files),'Duplikate:',dups); print('uebersprungen:',skipped.most_common(12))
cred=[p for p,t in files if re.search(r'\b\w+/[^\s@/]+@\w+|identified\s+by|password\s*=',t,re.I)]
print('Dateien mit moegl. Zugangsdaten:',len(cred))
def strip(t):
  t=re.sub(r'/\*.*?\*/',' ',t,flags=re.S); t=re.sub(r'--[^\n]*',' ',t); t=re.sub(r"'(?:[^']|'')*'","'?'",t); return t
kinds=collections.Counter(); fkind=collections.Counter()
ref=collections.Counter(); schemas=collections.Counter()
for p,t in files:
  s=strip(t)
  k=set(m.group(1).lower() for m in re.finditer(r'(?:^|;|\n)\s*(select|insert|update|delete|create|drop|alter|merge|begin|declare|with)\b',s,re.I))
  for x in k: kinds[x]+=1
  fkind['nur SELECT/WITH' if k and k<= {'select','with'} else ('mit DML/DDL/PLSQL' if k else 'leer/unklar')]+=1
  ts=set()
  for m in re.finditer(r'\b(?:([a-z_][a-z0-9_$]*)\.)?(t\d{3}[a-z0-9_]*)\b',s,re.I):
    ts.add(m.group(2).upper())
    if m.group(1): schemas[m.group(1).lower()]+=1
  for x in ts: ref[x]+=1
print('Dateien je Typ:',dict(fkind)); print('Statement-Arten (Dateien):',kinds.most_common())
print('Schema-Praefixe:',schemas.most_common(15))
ex={x:c for x,c in ref.items() if x in tabs}; nex={x:c for x,c in ref.items() if x not in tabs}
print('T-Tabellen referenziert:',len(ref),'in SHC vorhanden:',len(ex),'fehlen:',len(nex))
print('Top 40 vorhanden:',sorted(ex.items(),key=lambda x:-x[1])[:40])
print('Top 25 fehlend:',sorted(nex.items(),key=lambda x:-x[1])[:25])
pickle.dump(files,open(out,'wb'))
