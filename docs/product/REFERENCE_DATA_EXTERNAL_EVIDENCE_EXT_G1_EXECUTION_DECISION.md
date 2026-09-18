# BCK-20 — EXT-G1 Batch EXT-A P1 Execution Decision

- ID: `BCK20-OD02-EXT-EV-G1-EXEC-DEC-01`
- Version: `0.1`
- Status: **Accepted with retained gates**
- Recorded at: `2026-09-18T20:56:03Z`
- Owner: RechargeN / Product owner
- Review artifact: `BCK20-OD02-EXT-EV-G1-EXEC-REV-01` v0.1
- Exact review normalized-LF SHA-256:
  `ec9acd16b3b1695d20fc891d49f4a2cb7287e6c15f285010e08d18422e5b15fd`
- Authorization instance: `aba31978-ab80-4ca5-9d57-c976e54ebcb2`

## 1. Decision

The owner accepts the exact EXT-A P1 execution evidence with the retained gates
defined by the reviewed artifact. This acceptance records `EXT-G1 Pass` only
for the two authorized landing-page requests under the exact authorization
instance. It does not approve either external source or open EXT-G2.

Temporary evidence remains retained in its exact authorization-specific OS
temporary directory until a later explicit disposition.

The owner authorizes preparation of a documentation-only follow-up P1
authorization package for exactly these preferred candidate URIs:

- `https://www.iana.org/assignments/language-subtag-registry`;
- `https://www.iana.org/time-zones/releases/2026d`.

Preparation authority grants no network access.

## 2. Owner wording retained

> Одобряю BCK20-OD02-EXT-EV-G1-EXEC-REV-01 v0.1:
> Accept EXT-A P1 execution evidence with retained gates для точного документа /
> SHA-256 ec9acd16b3b1695d20fc891d49f4a2cb7287e6c15f285010e08d18422e5b15fd.
> Временные evidence сохранить до следующего решения.
> Разрешаю подготовить docs-only follow-up P1 authorization package для двух
> предпочтительных candidate URI. Network, EXT-G2–G6, downloads, runtime,
> Firebase, deployment, push и merge не разрешаю.

## 3. Exact effects

- the reviewed P1 run is accepted as bounded metadata-discovery evidence;
- raw responses remain temporary and untracked;
- the language replacement-registry URI and TZDB 2026d URI remain candidates,
  not approved sources or artifacts;
- the old temporary evidence may not be deleted without a later exact owner
  disposition;
- one follow-up authorization request and its owner-review package may be
  prepared as documentation only;
- no network call, artifact/terms capture, download, parser, fixture, schema,
  runtime, Firebase, deployment, activation, push or merge is authorized.

## 4. Retained project state

- `SRC-IANA-LANG` and `SRC-IANA-TZDB` remain Pending;
- `EXT-G2`–`EXT-G6` remain closed;
- all markets remain disabled;
- `BCK20-OD-02` and `BCK20-OD-05` remain Open;
- `OD-10` remains Proposed;
- `BCK-20` remains Draft;
- `BCK20-OD-03` remains Deferred;
- no independent or qualified Security/Privacy/Legal claim exists.

## 5. Acceptance criteria

1. **BCK20-OD02-EXT-EV-G1-EXEC-DEC-AC-01:** the decision binds to the exact execution-review hash.
2. **BCK20-OD02-EXT-EV-G1-EXEC-DEC-AC-02:** EXT-G1 Pass is limited to the exact authorization instance and two completed landing requests.
3. **BCK20-OD02-EXT-EV-G1-EXEC-DEC-AC-03:** temporary evidence is retained untracked pending a later explicit disposition.
4. **BCK20-OD02-EXT-EV-G1-EXEC-DEC-AC-04:** preferred follow-up URIs remain candidates and receive no authority from this decision.
5. **BCK20-OD02-EXT-EV-G1-EXEC-DEC-AC-05:** only a documentation-only follow-up authorization package may be prepared.
6. **BCK20-OD02-EXT-EV-G1-EXEC-DEC-AC-06:** EXT-G2–G6, source approval, markets, runtime, Firebase, deployment, push and merge remain closed.

