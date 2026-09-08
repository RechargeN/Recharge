# Recharge Backend — API Security & Privacy Boundary Review

- ID: **BCK03-SEC-REV-01**
- Version: **0.1**
- Date: **2026-09-08**
- Status: **Draft recommendation — owner verdict required**
- Recommended result: **Accept with required amendments**
- Reviewer independence: **not evidenced**
- Target: [BCK-03 v0.3.10](BACKEND_API_CONTRACT_STANDARD.md)
- Security/privacy baseline: [BCK-04 v0.4.19](BACKEND_SECURITY_PRIVACY_SPEC.md)
- Coverage baseline: [BCK-04-PRE v0.3.19](BACKEND_SECURITY_PRIVACY_COVERAGE_MATRIX.md)
- Threat-model input: [BCK04-OD01-TM-01 v0.1](BACKEND_SECURITY_THREAT_MODEL.md)
- Runtime effect: **none**

## 1. Scope

This review checks only the BCK-03 API boundary against BCK-04 security and
privacy requirements. It does not approve BCK-03, BCK-04, the threat model,
OD-09, OD-11, Legal conclusions, runtime, Firebase or deployment.

The review is a combined-owner documentation assessment. It is not an
independent Security/Privacy review and does not claim professional Legal
qualification.

## 2. Boundary matrix

| Area | Result | Evidence / preserved gate |
|---|---|---|
| Server-resolved authority | Pass with amendment | Client role/capability claims are ignored; market, policy and resource scope need an explicit resolution order |
| Revocation | Pass | Every authoritative mutation rechecks current server-owned access; cached mobile state is UX only |
| Idempotent replay | Gap — amendment required | Mutation dedupe is correct, but replay disclosure after access revocation is not explicit |
| Anti-enumeration | Pass with amendment | Stable error mapping exists; response metadata, cursor, revision and timing must follow the same profile |
| Data classification | Pass with amendment | Five classes match BCK-04; schema-level declaration and mixed-payload classification need enforcement |
| Error privacy | Pass | Arbitrary debug details, secrets, paths, provider payloads and sensitive field values are prohibited |
| Logging/telemetry | Pass with amendment | Redaction rules exist; client-controlled identifiers must be treated as untrusted structured values |
| Payload and query abuse | Pass | Bounds, opaque cursors, server-side cost caps and typed rate outcomes are defined |
| App Check | Pass | It is a signal/layer and never a replacement for AuthN/AuthZ/rate controls |
| Webhook and outbound access | Pass with amendment | BCK-04 defines authenticity/replay/SSRF controls; the API registry must declare applicability per surface |
| Direct database access | Pass | Direct Firestore access is not an authoritative API profile |
| Minimum-client emergency action | Pass with amendment | Security tightening is allowed, but owner, expiry, client outcome and rollback evidence must be explicit |
| Events | Gated | OD-09 remains Proposed; data minimization, retention and replay evidence remain required before effects |
| Legal/DSR/age policy | Not decided here | OD-11, Legal bases, retention and rights-request decisions remain in BCK-04/qualified review |
| Production readiness | Not evaluated | G1, R1, cloud resources, deployment and product runtime remain blocked/Absent |

## 3. Findings and required amendments

No conflict requires rejecting the BCK-03 direction. Before BCK-03 can leave
Draft, these amendments are mandatory:

1. **Reauthorize idempotent replay disclosure.** A same-key/same-hash retry may
   return the original semantic result only after current session, actor,
   resource and disclosure authorization are checked. Revocation must not
   re-execute the mutation, but it may replace the protected replay body with a
   stable anti-enumerating failure.
2. **Define one ingress decision order per surface.** Apply transport byte and
   content-type bounds before expensive work, then required authenticity/App
   Check checks, schema normalization and current authorization before domain
   execution. Error precedence must be stable and must not reveal resource
   existence or security-control details.
3. **Bind all client context server-side.** `marketId`, locale, client metadata,
   request ID and payload references are untrusted inputs. The handler resolves
   the current principal, account/session, capability, workspace/resource,
   market status and policy revisions; unknown or stale authority fails closed.
4. **Register anti-enumeration profiles.** Each protected resource family must
   declare whether unavailable and unauthorized are indistinguishable. The
   profile covers code, domain code, details, revision, cursor, latency class
   and telemetry—not only `permission_denied` versus `not_found`.
5. **Make classification enforceable.** Every schema field or explicitly
   inherited field group declares one of the five BCK-04 classes, purpose and
   allowed consumers/sinks. A mixed event/result uses the most restrictive
   applicable handling across its fields; ambiguous combinations are split or
   fail closed. A producer cannot lower classification with `dataClass`.
6. **Treat tracing values as untrusted.** Client-generated `requestId` and other
   metadata are bounded and validated before structured logging, never
   concatenated into log text, metric names, resource paths or authorization
   keys. Logs retain only the approved allowlist and correlation references.
7. **Declare external-boundary controls in the registry.** Webhook/callback
   entries state authenticity, freshness, replay/dedupe and size rules;
   outbound-fetch entries state provider allowlist, redirect, IP/metadata,
   timeout and response-size policy. Missing declarations keep the surface
   disabled.
8. **Bound emergency compatibility changes.** A security-driven input-bound or
   minimum-client tightening requires named owner, reason, affected consumers,
   stable typed failure, effective/expiry times, rollback and post-event review.
9. Keep OD-09 Proposed and do not enable event workers/effects before BCK-04
   data-classification, retention, deletion and audit evidence is accepted.
10. Obtain the Mobile boundary verdict and an independent Security/Privacy
    assessment separately. Qualified Legal/Privacy conclusions remain separate
    wherever BCK-04 requires them.

## 4. Preserved decisions and non-decisions

- BCK-03 and BCK-04 remain **Draft**.
- BCK04-OD-01 and BCK04-OD-09 remain **Proposed**.
- OD-09 remains **Proposed**; OD-11 remains **Open**.
- D1-SIG-API and bounded D1-SIG-OPS remain recorded as already decided.
- D1-SIG-SEC remains **Pending** until an explicit owner verdict is recorded.
- D1-SIG-LEGAL remains **Pending**; qualification is not inferred.
- No schema, fixture, runtime, Firebase, deployment, push or merge is authorized.

## 5. Recommended owner verdict

```text
Approve D1-SIG-SEC for the BCK-03 boundary as Accept with required amendments.
This is a combined-owner documentation verdict; independent Security/Privacy
and qualified Legal evidence remain absent. BCK-03 and BCK-04 remain Draft.
OD-09 remains Proposed and OD-11 remains Open. Runtime, Firebase, deployment,
push and merge are not authorized.
```

This text is a recommendation only. It must not be copied into the sign-off
ledger as an owner verdict until the Product owner explicitly approves it.

## 6. Acceptance criteria

1. **BCK03-SEC-AC-01:** client authority claims never grant access.
2. **BCK03-SEC-AC-02:** current authorization is rechecked before protected
   replay disclosure without re-executing the mutation.
3. **BCK03-SEC-AC-03:** ingress ordering is bounded, stable and fail-closed.
4. **BCK03-SEC-AC-04:** client market/context values never become policy or
   authorization authority.
5. **BCK03-SEC-AC-05:** anti-enumeration covers the complete observable
   response profile.
6. **BCK03-SEC-AC-06:** all contract data uses the five BCK-04 classes.
7. **BCK03-SEC-AC-07:** mixed payloads use the most restrictive applicable
   handling and cannot understate classification.
8. **BCK03-SEC-AC-08:** tracing values cannot inject logs, metrics or paths.
9. **BCK03-SEC-AC-09:** webhook/outbound controls are registry-declared and
   fail closed when absent.
10. **BCK03-SEC-AC-10:** App Check never replaces AuthN/AuthZ or abuse controls.
11. **BCK03-SEC-AC-11:** security emergency compatibility changes are bounded,
    auditable and reversible.
12. **BCK03-SEC-AC-12:** OD-09/OD-11 and BCK04-OD-01/09 statuses are preserved.
13. **BCK03-SEC-AC-13:** combined review is not called independent or Legal.
14. **BCK03-SEC-AC-14:** D1-SIG-SEC remains Pending before explicit approval.
15. **BCK03-SEC-AC-15:** no runtime, Firebase, deployment, push or merge
    authority is created.

## 7. Next action

Request the exact owner verdict from §5. Only after explicit approval may the
required amendments be integrated into BCK-03 and reconciled through the D1
ledger and canonical status documents.
