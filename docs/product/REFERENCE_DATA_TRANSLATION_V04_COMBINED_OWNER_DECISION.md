# BCK-20 — Translation Governance v0.4 Combined-Owner Decision Record

- ID: **BCK20-OD02-V04-COMB-DEC-01**
- Version: **0.1**
- Date: **2026-09-17**
- Recorded at: **2026-09-17T16:41:10+03:00**
- Status: **Accepted design boundary with retained gates**
- Owner/signatory: **RechargeN / Product owner**
- Independence: **None — four roles are held by the same owner**
- Qualified Security/Privacy/Legal claim: **None**
- Review package: [BCK20-OD02-V04-COMB-REV-01 v0.1](REFERENCE_DATA_TRANSLATION_V04_COMBINED_OWNER_REVIEW.md)
- Exact workflow: [BCK20-OD02-L10N-01 v0.4](REFERENCE_DATA_TRANSLATION_GOVERNANCE_WORKFLOW.md)
- Product/Content revalidation: [BCK20-OD02-PC-REVAL-01 v0.1](REFERENCE_DATA_TRANSLATION_PRODUCT_CONTENT_V04_REVALIDATION.md)
- Mobile review: [BCK20-OD02-MOB-REV-01 v0.1](REFERENCE_DATA_TRANSLATION_MOBILE_OWNER_REVIEW.md)
- Security/Privacy review: [BCK20-OD02-SEC-REV-01 v0.1](REFERENCE_DATA_TRANSLATION_SECURITY_PRIVACY_OWNER_REVIEW.md)
- Runtime authority: **None**

---

## 1. Decision

The owner accepts four separately attributable design-boundary verdicts for
one exact workflow revision. The shared signatory is disclosed and does not
turn the four perspectives into independent review.

| Verdict ID | Perspective | Effective verdict | Exact scope |
|---|---|---|---|
| `BCK20-OD02-SIG-L10N` | Product Localization | Accept design boundary with retained gates | workflow v0.4 and Product/Content revalidation |
| `BCK20-OD02-SIG-CONTENT` | Content/source governance | Accept design boundary with retained gates | workflow v0.4 and Product/Content revalidation |
| `BCK20-OD02-SIG-MOBILE` | Mobile | Accept design boundary with retained gates | workflow v0.4 and Mobile review |
| `BCK20-OD02-SIG-SEC` | Security/Privacy technical boundary | Accept design boundary with retained gates | workflow v0.4 and Security/Privacy review |

This decision is a documentation design acceptance. It is not acceptance of
source values, a professional opinion, an implementation order, or a release
authorization.

## 2. Frozen evidence

Hashes are SHA-256 over UTF-8 bytes after CRLF-to-LF normalization.

| Artifact | Frozen version | SHA-256 |
|---|---|---|
| Workflow | `BCK20-OD02-L10N-01 v0.4` | `d7cad4f1531005b02ee7c46028af03839be58985cd3285750084daa8293d6975` |
| Combined review package | `BCK20-OD02-V04-COMB-REV-01 v0.1` | `33cf3205a497bee00a9cc684d62e7421acedf9209d27101d7f4a701e425ac41f` |
| Product/Content revalidation | `BCK20-OD02-PC-REVAL-01 v0.1` | `799d8bb0ebad2683a0f61b25f6f1b6abf49ebcd0e807710ed7c285bcf66bedcd` |
| Mobile review | `BCK20-OD02-MOB-REV-01 v0.1` | `d9f9b76302f1b57e03e4577005448a2a59be359174c1f61565b774ffce9bccf2` |
| Security/Privacy review | `BCK20-OD02-SEC-REV-01 v0.1` | `1b0db67df34e54af5433e1e3cfd172717c7e4911267a6d1ab094b07b89c435a7` |

Any content or normalized-hash change requires a new review and decision. A
later status annotation in a review document does not alter the frozen v0.1
evidence evaluated here.

## 3. Retained gates

The following remain unchanged:

- `BCK20-OD-02` and `BCK20-OD-05` are **Open**;
- `OD-10` is **Proposed** and `BCK-20` is **Draft**;
- `BCK20-OD-03` is **Deferred**;
- source-authority content is **Pending** and absent values fail closed;
- independent Security/Privacy evidence is **Pending**;
- applicable qualified Legal evidence is **Pending**;
- provider selection, schema, IAM/runtime, Firebase, deployment and activation
  remain unauthorized;
- push and merge are outside this decision.

The exact-v0.4 verdicts may be cited as combined-owner technical/design
evidence only. They do not satisfy any gate that explicitly requires an
independent or qualified reviewer.

## 4. Verbatim owner instruction

> Одобряю BCK20-OD02-V04-COMB-REV-01 v0.1:
> принимаю четыре раздельных verdict — BCK20-OD02-SIG-L10N,
> BCK20-OD02-SIG-CONTENT, BCK20-OD02-SIG-MOBILE и BCK20-OD02-SIG-SEC — как
> Accept design boundary with retained gates для точного
> BCK20-OD02-L10N-01 v0.4 / SHA-256
> d7cad4f1531005b02ee7c46028af03839be58985cd3285750084daa8293d6975.
> Подтверждаю совмещение ролей RechargeN / Product owner, отсутствие independent
> review и отсутствие qualified Security/Privacy/Legal claim.
> BCK20-OD-02 и BCK20-OD-05 остаются Open; OD-10 остаётся Proposed; BCK-20
> остаётся Draft; BCK20-OD-03 остаётся Deferred. Source-authority content,
> independent Security/Privacy и applicable qualified Legal evidence остаются
> Pending. Provider selection, schema, IAM/runtime, Firebase, deployment,
> activation, push и merge не разрешаю.

## 5. Effect and rollback

Effective immediately for documentation reconciliation:

1. the four verdict IDs above are recorded separately against the frozen
   workflow v0.4 hash;
2. the earlier v0.3 Product/Content decision remains immutable historical
   evidence and is no longer the current workflow target;
3. canonical BCK-20 and D1 records may describe the four exact-v0.4 verdicts
   as recorded, with zero independence and all retained gates visible;
4. no executable artifact or external system changes.

Rollback is a superseding owner decision and atomic reconciliation of the
canonical documentation. Deleting this record or silently restoring a prior
status is not rollback.

## 6. Acceptance criteria

1. **BCK20-OD02-V04-COMB-DEC-AC-01:** the decision freezes the exact workflow v0.4 identity and hash.
2. **BCK20-OD02-V04-COMB-DEC-AC-02:** the review package and three review inputs are frozen by version and hash.
3. **BCK20-OD02-V04-COMB-DEC-AC-03:** four verdict IDs remain separately attributable.
4. **BCK20-OD02-V04-COMB-DEC-AC-04:** the shared owner and zero independence are explicit.
5. **BCK20-OD02-V04-COMB-DEC-AC-05:** no qualified Security/Privacy/Legal claim is created.
6. **BCK20-OD02-V04-COMB-DEC-AC-06:** BCK20-OD-02 and BCK20-OD-05 remain Open.
7. **BCK20-OD02-V04-COMB-DEC-AC-07:** OD-10 remains Proposed and BCK-20 remains Draft.
8. **BCK20-OD02-V04-COMB-DEC-AC-08:** BCK20-OD-03 remains Deferred.
9. **BCK20-OD02-V04-COMB-DEC-AC-09:** source-authority content remains Pending and fail-closed.
10. **BCK20-OD02-V04-COMB-DEC-AC-10:** independent Security/Privacy and applicable qualified Legal evidence remain Pending.
11. **BCK20-OD02-V04-COMB-DEC-AC-11:** prior v0.3 evidence remains immutable history.
12. **BCK20-OD02-V04-COMB-DEC-AC-12:** an artifact/hash change invalidates applicability of the verdicts to the changed artifact.
13. **BCK20-OD02-V04-COMB-DEC-AC-13:** provider, schema, IAM/runtime, Firebase, deployment and activation remain unauthorized.
14. **BCK20-OD02-V04-COMB-DEC-AC-14:** this record authorizes no push or merge.
15. **BCK20-OD02-V04-COMB-DEC-AC-15:** rollback requires an explicit superseding decision and atomic documentation reconciliation.
