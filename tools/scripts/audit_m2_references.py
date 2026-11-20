"""Read-only M2 reference inventory. Never grants permission to delete wrappers."""
from pathlib import Path
import argparse,collections,hashlib,json,re,subprocess,zipfile
ROOT=Path(__file__).resolve().parents[2]
SYMBOLS=['EventMoneyDraft','ScenarioMoneyDraft','RentalMoneyDraft','SessionMoneyDraft','ActivityContributionAmountDraft','ScenarioLocalDateDraft','ScenarioTransitLocalDate','SessionLocalDate','ScenarioGeoPointDraft']
LEGACY=['core/geo/'+n+'.dart' for n in ['geo_point','geo_bounds','geo_distance','geometry_encoding','geometry_hash']]+['features/discover/domain/entities/geo_point.dart','features/discover/domain/entities/local_date.dart','core/id/id_generator.dart']
TOK=re.compile(r"//[^\n]*|/\*[\s\S]*?\*/|r?(?:'''[\s\S]*?'''|\"\"\"[\s\S]*?\"\"\"|'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\")|[A-Za-z_$][\w$]*|[^\s]",re.M)
def tokens(s):return [(m.group(),m.start(),m.end()) for m in TOK.finditer(s) if not m.group().startswith(('//','/*'))]
def end_block(s,start):
 stack=[]
 for t,a,b in tokens(s):
  if a<start:continue
  if t in ['(','[','{']:stack.append(t)
  elif t in [')',']','}']:
   stack.pop()
   if not stack:return b
 raise ValueError('Unclosed Dart delimiter')
def separate_definitions(s):
 defs={};spans=[]
 for name in SYMBOLS:
  for m in re.finditer(r'\bclass\s+'+name+r'\b',s):
   a=m.start();b=end_block(s,s.index('{',m.end()));defs[name]=s[a:b];spans.append((a,b))
 m=re.search(r'\btypedef SessionLocalDate\s*=\s*LocalDate\s*;',s)
 if m:defs['SessionLocalDate']=m.group();spans.append(m.span())
 clean=s
 for a,b in sorted(spans,reverse=True):clean=clean[:a]+''.join('\n' if x=='\n' else ' ' for x in clean[a:b])+clean[b:]
 return clean,defs

def directive_strings(s):
 ts=tokens(s);result=[];i=0
 while i<len(ts):
  if ts[i][0] not in ['import','export','part']:i+=1;continue
  kind,a,_=ts[i];j=i+1;quoted=[]
  while j<len(ts) and ts[j][0]!=';':
   m=re.fullmatch(r"r?(['\"])(.*?)\1",ts[j][0],re.S)
   if m and m[2].endswith('.dart'):quoted.append(m[2])
   j+=1
  for uri in quoted:result.append((kind,uri,a,' '.join(t for t,_,_ in ts[i:j])))
  i=j+1
 return result

def scope(path):
 if '/test/' in path or path.startswith('test/'):return 'tests'
 if path.startswith('tools/'):return 'tooling'
 return 'production'

def self_test():
 s="// import 'core/geo/geo_point.dart';\nconst note = \"import 'core/geo/geo_bounds.dart';\";\nimport 'modern.dart' if (dart.library.io) 'core/geo/geo_point.dart';\nexport 'core/geo/geometry_hash.dart';"
 d=directive_strings(s);assert [x[1] for x in d]==['modern.dart','core/geo/geo_point.dart','core/geo/geometry_hash.dart']
 clean,defs=separate_definitions('class ScenarioMoneyDraft { final int minorUnits = 0; }\nScenarioMoneyDraft? value;')
 assert len(defs)==1 and sum(t=='ScenarioMoneyDraft' for t,_,_ in tokens(clean))==1
 clean,defs=separate_definitions('typedef SessionLocalDate = LocalDate;\nSessionLocalDate value;')
 assert len(defs)==1 and sum(t=='SessionLocalDate' for t,_,_ in tokens(clean))==1
 assert not any(t in SYMBOLS for t,_,_ in tokens("const note = 'EventMoneyDraft'; // SessionLocalDate"))
 print('M2 reference audit self-test: PASS (comments, strings, conditional imports, exports, definitions, alias).')

def run(label,snapshot=None):
 names=set(subprocess.check_output(['git','ls-files','--','*.dart'],cwd=ROOT,text=True).splitlines())
 names.update(p.relative_to(ROOT).as_posix() for folder in ['apps/mobile/lib','apps/mobile/test','packages'] for p in (ROOT/folder).rglob('*.dart') if not any(x in p.parts for x in ['build','.dart_tool']))
 archive=zipfile.ZipFile(ROOT/snapshot) if snapshot else None
 archived=set(archive.namelist()) if archive else set()
 refs=[];directives=[];definitions=[];aliases=[];hashes={}
 for name in sorted(names):
  p=ROOT/name
  s=(archive.read(name).decode('utf-8') if name in archived else p.read_text(encoding='utf-8')).replace('\r\n','\n')
  hashes[name]=hashlib.sha256(s.encode()).hexdigest();clean,defs=separate_definitions(s)
  for symbol,body in defs.items():definitions.append({'file':name,'symbol':symbol,'tokenFingerprint':hashlib.sha256(json.dumps([t for t,_,_ in tokens(body)]).encode()).hexdigest()})
  for t,a,b in tokens(clean):
   if t in SYMBOLS:refs.append({'file':name,'line':clean[:a].count('\n')+1,'symbol':t,'scope':scope(name)})
   if t=='_LocalDate':aliases.append({'file':name,'line':clean[:a].count('\n')+1,'symbol':t,'scope':scope(name)})
  for kind,uri,a,directive in directive_strings(s):
   if uri.startswith('package:recharge/'):target=uri[len('package:recharge/'):]
   elif ':' in uri:continue
   else:
    try:target=(p.parent/uri).resolve().relative_to((ROOT/'apps/mobile/lib').resolve()).as_posix()
    except ValueError:continue
   if target in LEGACY:
    impl_only=target=='core/id/id_generator.dart' and re.search(r'\bshow UuidV4IdGenerator\s*$',directive) is not None
    directives.append({'file':name,'line':s[:a].count('\n')+1,'kind':kind,'target':target,'scope':'exports' if kind=='export' else scope(name),'implementationOnly':impl_only,'forwardingReliance':not impl_only})
 if archive:archive.close()
 result={'label':label,'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'sourceCount':len(names),'snapshot':snapshot,'contentFingerprint':hashlib.sha256(json.dumps(hashes,sort_keys=True).encode()).hexdigest(),'consumerCounts':dict(collections.Counter(x['symbol'] for x in refs)),'scopeCounts':dict(collections.Counter(x['scope'] for x in refs)),'consumers':refs,'directives':directives,'legacyForwardingRelianceCount':sum(x['forwardingReliance'] for x in directives),'retainedDefinitions':definitions,'privateSharedAliases':aliases,'combinedTreeProof':False,'deletionPermitted':False}
 assert re.fullmatch(r'[A-Za-z0-9_-]+',label), 'Invalid output label'
 out=ROOT/'outputs/M2-DE-2026-11-19'/(label+'-complete-references.json');out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(result,indent=2),encoding='utf-8')
 print(json.dumps({k:result[k] for k in ['sourceCount','consumerCounts','scopeCounts','legacyForwardingRelianceCount','combinedTreeProof','deletionPermitted']}))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--label',default='final');p.add_argument('--snapshot');p.add_argument('--self-test',action='store_true');a=p.parse_args()
 if a.self_test:self_test()
 else:run(a.label,a.snapshot)
