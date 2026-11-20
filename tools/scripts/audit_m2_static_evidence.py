"""Read-only reproducible scope/import/historical-budget evidence for M2."""
from pathlib import Path
import argparse, json, re, subprocess
ROOT = Path(__file__).resolve().parents[2]
BASE = '78d6a38672927c6fa9872e7f3041bd11bc63db44'
def git(*args):
    return subprocess.check_output(['git','-c','core.safecrlf=false',*args],cwd=ROOT,text=True,stderr=subprocess.DEVNULL)
def quiet(*args):
    return subprocess.run(['git','diff','--quiet',BASE,'--',*args],cwd=ROOT).returncode == 0
def run(output):
    changed = git('diff','--name-only',BASE).splitlines()
    forbidden = [p for p in changed if p.startswith(('apps/backend/','infra/','packages/api_contracts/')) or p=='AGENTS.md']
    shared, geo, identity = [], [], []
    for path in (ROOT/'apps/mobile/lib/shared/primitives').rglob('*.dart'):
        for i,line in enumerate(path.read_text(encoding='utf-8').splitlines(),1):
            if re.match(r'\s*(import|export)',line) and re.search(r"package:(flutter|uuid|timezone)/|['\"](?:.*?/)?(?:features|app|core)/",line):
                shared.append({'file':path.relative_to(ROOT).as_posix(),'line':i,'code':line})
    for path in (ROOT/'apps/mobile/lib/features').rglob('*.dart'):
        name=path.relative_to(ROOT).as_posix()
        if '/domain/' not in name:continue
        for i,line in enumerate(path.read_text(encoding='utf-8').splitlines(),1):
            if not re.match(r'\s*(import|export)',line):continue
            if re.search(r'core/geo/|discover/domain/entities/geo_point.dart',line):geo.append({'file':name,'line':i,'code':line})
            if '/identity/domain/' in name and re.search(r'package:flutter|account_experience.dart',line):identity.append({'file':name,'line':i,'code':line})
    old=json.loads(git('show','6f00b2f8^:tools/scripts/boundary-exceptions.json'))
    after=json.loads(git('show','6f00b2f8:tools/scripts/boundary-exceptions.json'))
    removed=sorted({e['id'] for e in old['exceptions']}-{e['id'] for e in after['exceptions']})
    expected=[f'BND-LEGACY-{n:04d}' for n in range(60,95)]
    registry=json.loads((ROOT/'tools/scripts/boundary-exceptions.json').read_text())
    def unrelated(text):
        return [line for line in text.splitlines() if not (line.startswith('|') and len(line.split('|'))>2 and (line.split('|')[1].strip().startswith('MOB-ARCH-M2-') or line.split('|')[1].strip() in {'IDP-03A','IDP-04A','IDP-05A'}))]
    launch_ok=unrelated(git('show',BASE+':docs/architecture/LAUNCH_STATUS.md'))==unrelated((ROOT/'docs/architecture/LAUNCH_STATUS.md').read_text(encoding='utf-8'))
    result={'base':BASE,'head':git('rev-parse','HEAD').strip(),'forbiddenScopeChanges':forbidden,'sharedFrameworkInfrastructureImports':shared,'domainLegacyGeoImports':geo,'identityDomainPresentationImports':identity,'m2aCommit':'6f00b2f8','m2aRemovedExceptionIds':removed,'m2aExactlyExpected35':removed==expected,'m2aBudgetBefore':old['baselineBudget'],'m2aBudgetAfter':after['baselineBudget'],'currentBudget':registry['baselineBudget'],'currentExceptionCount':len(registry['exceptions']),'registryUnchangedFromMain':quiet('tools/scripts/boundary-exceptions.json'),'unrelatedLaunchRowsUnchanged':launch_ok,'idInterfaceImports':re.findall(r'^(?:import|export).*$',(ROOT/'apps/mobile/lib/shared/primitives/id/id_generator.dart').read_text(),re.M),'uuidUlidImplementationRetained':all(name in (ROOT/'apps/mobile/lib/core/id/id_generator.dart').read_text() for name in ['class UuidV4IdGenerator','class UlidIdGenerator']),'legacyMoneyReaderRetained':(ROOT/'apps/mobile/lib/core/parsing/money_legacy_adapter.dart').exists()}
    assert not forbidden and not shared and not geo and not identity and removed==expected and result['registryUnchangedFromMain'] and launch_ok
    target=ROOT/output;target.parent.mkdir(parents=True,exist_ok=True);target.write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({k:result[k] for k in ['head','forbiddenScopeChanges','sharedFrameworkInfrastructureImports','domainLegacyGeoImports','identityDomainPresentationImports','m2aExactlyExpected35','currentExceptionCount','currentBudget','registryUnchangedFromMain','unrelatedLaunchRowsUnchanged']}))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',default='outputs/IDP-M2-ONMAIN-2026-11-20/CP5-static-evidence.json');run(p.parse_args().output)
