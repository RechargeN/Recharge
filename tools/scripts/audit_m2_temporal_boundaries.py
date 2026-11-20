"""Read-only inventory of mobile time readers and configuration fallback boundaries."""
from pathlib import Path
import argparse, hashlib, json, re, subprocess
ROOT = Path(__file__).resolve().parents[2]

def inventory():
    rows = []
    for path in sorted((ROOT / 'apps/mobile/lib').rglob('*.dart')):
        name = path.relative_to(ROOT).as_posix()
        lines = path.read_text(encoding='utf-8').splitlines()
        for index, line in enumerate(lines):
            kind = None
            if re.search(r'\bUtcInstant\.(parse|tryParse)\(', line):
                kind, decision = 'utc_reader', 'Shared strict UTC: explicit Z, real calendar, at most microsecond precision; invalid data is rejected or isolated by the existing record contract.'
            elif 'recordedIdentityText(' in line:
                kind, decision = 'recorded_identity_context', 'Only absent nested market/timezone may inherit the explicit recorded parent. Present null/empty remains unknown, present non-text raises FormatException; no active config lookup.'
            elif 'MoneyLegacyAdapter.recordedCurrency(' in line:
                kind, decision = 'recorded_currency_context', 'Absent nested currency may inherit the explicit recorded envelope context; present null/invalid currency never falls back. Legacy adapter preserves exact amount and validates currency when money exists.'
            elif 'catalogMarketIdFor(' in line:
                kind, decision = 'catalog_market_binding', 'Explicit registry bridge riga/rezekne to Catalog v1 LV; unknown market is a FormatException, never inferred from locale/currency/country display metadata.'
            elif '_gpxInstant(value)' in line:
                kind, decision = 'external_gpx_reader', 'GPX permits explicit Z or numeric offset; shared UTC calendar validation precedes offset arithmetic. Zoneless/impossible input records gpx_timestamp_invalid without rejecting safe geometry.'
            elif re.search(r'\bDateTime\.(parse|tryParse)\(', line):
                kind, decision = 'permissive_reader', 'UNRESOLVED: requires migration or a documented explicit external timestamp contract.'
            elif re.search(r'\bLocalDate\.(parse|tryParse)\(', line):
                kind, decision = 'calendar_reader', 'Shared Gregorian calendar date; not an instant; no device timezone conversion.'
            elif re.search(r'(market|currency|timezone|timeZone|locale)', line, re.I) and ('??' in line or re.search(r"= '(EUR|Europe/Riga|UTC|riga)'", line) or '_string(' in line or '_zone(' in line or "read('timezone_id'" in line):
                kind = 'configuration_fallback'
                if 'this.' in line:
                    decision = 'copyWith retains the same recorded value when no edit is requested; no active workspace/config lookup.'
                elif 'money_parser.dart' in name or 'money_formatter.dart' in name:
                    decision = 'Explicit supported currency metadata registry; does not choose a currency identity.'
                elif 'discover_query_model.dart' in name:
                    decision = 'Versioned Discover preference compatibility: v1 automatic Rezekne search area migration only; legacy currency context applies only before schema 3. Current monetary records require explicit currency.'
                elif '/data/models/' in name:
                    decision = 'Restore uses the same recorded envelope context or an empty/unknown value, not active market/locale. Present malformed monetary currency is refused by the currency reader; current UTC fields use strict shared parser.'
                elif 'discover_feed_controller.dart' in name:
                    decision = 'New filter command defaults to explicitly composed market timezone; existing time window zone has precedence. Persisted reads do not call this command.'
                elif '/application/' in name:
                    decision = 'Explicit new/edit command defaults from the owning draft/context; does not rewrite an already persisted snapshot during restore.'
                elif '/presentation/' in name:
                    decision = 'Display/edit fallback uses the same draft amount/zone or unknown marker; no persisted identity or authority is inferred.'
                elif '/domain/entities/' in name:
                    decision = 'New draft factory default only; stored mapper supplies recorded/empty identities. Not a stored-data migration.'
                else:
                    decision = 'Explicit composition/default metadata; inspect the attached context before claiming a storage migration.'
            if kind:
                rows.append({'file': name, 'line': index + 1, 'kind': kind, 'code': line.strip(), 'decision': decision, 'context': '\n'.join(lines[max(0,index-2):index+3])})
    return rows

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    rows = inventory()
    result = {'head': subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(), 'rows': rows, 'unresolvedReaders': [r for r in rows if r['kind']=='permissive_reader'], 'scope': 'all apps/mobile/lib Dart files; configuration rows are a policy classification, not production acceptance'}
    result['fingerprint'] = hashlib.sha256(json.dumps(rows,sort_keys=True).encode()).hexdigest()
    target = ROOT / args.output
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({'rows': len(rows), 'unresolvedReaders': len(result['unresolvedReaders']), 'fingerprint': result['fingerprint']}))
if __name__ == '__main__':
    main()
