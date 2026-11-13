# N2b — минимальный Firebase dev bootstrap завершён, 2026-11-05

Cloud execution completed for recharge-dev-n2a01 /420479958348, only the approved private EUR billing account. Final successful source615c57a913b0947313c6f3bd9f86370c08c2c697; subsequent commit contains closeout/observed allowlist only. No push/merge, stage/prod or old-project mutations were requested/executed.

## Verified facts

Firebase ACTIVE. Firestore Native(default), STANDARD/eur3, PITR enabled, server deletion protection enabled. Exactly two private STANDARD buckets: dev-tfstate/EU/versioned and dev-media/europe-west1; recovery bucket disabled. Three planned deploy/runtime SAs, no explicit role grants to them, user-managed keys0 across five listed project SAs. WIF pool/github-dev provider/github-actions disabled, claim-referencing CEL `false && assertion.sub != ''`; effective trust false, no principal bindings, configured protected-main/workflow conditions untouched. This is infrastructure, not deployed application runtime.

Budget EUR5 monthly,50/75/90/100%, only dev project-number filter, agreed private email destination absent from Git. Test email received/acknowledged by owner; original probe produced no incident, one bounded retest succeeded. A real Cloud Billing budget PubSub message(currencyEUR,budget5,cost0) was validated/stored/acknowledged before receipt release. Ordinary resources began only after both criteria passed. First real50% threshold email remains pending actualEUR2.50 crossing; budget is notification, not hard cap.

State migrated once to gs://recharge-dev-n2a01-tfstate/terraform/bootstrap/dev/default.tfstate, no force-copy/state push. Private before/after snapshots retained. Lineage unchanged, all resources/outputs/check-result sets identical; serial37→38 is normal remote persistence metadata, check-result list reordered without semantic change. Initial overly strict equality check is preserved in evidence; pinned Terraform1.15.9 source explains serial increment.29 managed instances(27Google resource entries+2terraform_data), state object59319bytes,2versions. Final refresh plan against GCS detailed-exitcode0/No changes.

Smoke: Firestore collection IDs empty, missing synthetic doc404, anonymous request403 (narrow probe, not a full Rules audit); no VM/disks/reserved IP/networks/BQ datasets; AppEngine app404; Android/iOS/web Firebase apps0. No fixtures/data/runtime/Functions/build/auth provider deployment. Not performance/device/platform/security acceptance.

Google-created APIs and system identities are in observed allowlist, not manually created Terraform service entries. Firebase management audit proves creation of Firebase Admin SDK agent and its sdkAdminServiceAgent/TokenCreator bindings; Firebase Rules agent documented by Google. No non-owner basic roles and no roles on external/user-controlled application principals. Strong Google-agent roles are explicitly observed, not presented as no IAM grants anywhere.

Firebase onboarding also linked an Analytics property/account recorded in private execution evidence. This is observed outside Terraform; AddGoogleAnalytics appears in Firebase audit during owner console onboarding. No Analytics API operation was explicitly invoked by our scripts/Terraform config, apps0/BQ datasets0; no data streams/workloads/export deployments were created by this package. Link was not deleted or changed. No claim that Analytics is absent.

ADC kept only in private-gcloud under owner revised policy, no secrets copied/printed/Git. Final revoke2026-11-05T12:47:41.2429977Z exit0/Credentials revoked/file absent, before2026-11-08T23:59Z. Reserved UTC scheduler card was not confirmed active; earlier completion/revocation fulfilled deadline, no further activation needed.

## Scope/remaining gates

SLO/error-budget/burn-rate targets and kill-switch design in N1 remain runtime requirements; no eligible runtime traffic/SLO attainment or operational restore drill claimed. State versioning/PITR verified; restore/clone/data deletion/destroy are not authorized rollback tests. Incident rollback for this bootstrap is stop optional workload and retain budget/state/data, reconcile before any repair; no billing detach. Independent backup escalation, active protected-main deployment/WIF, iOS/other platform gates remain separate; owner RechargeN is sole operator contact.500synthetic-object worksheet estimatesEUR3.52/month using explicit rates/volume/tax/reserve assumptions, not tariff quote/cap; no data loaded.

Future ownership: only infra/terraform/bootstrap/dev owns these resources. backend.tf is locally materialized/ignored; do not apply envs/dev to this project/state or use consumed .void plans. Fresh execution records/credentials are required for future work outside completed N2b. Existing delivery receipt freshness is24h; future maintenance must review/retest or deliberately revise that bootstrap-only gate, not fake evidence or weaken it silently.

Source checks: Terraform validate/fmt; bootstrap mocks6/6 incl hard-deny WIF and failed delivery; checkpoint tests11/11; full three-root topology/mock checks passed. Earlier contract70/70 and Flutter analyze/2240pass83skip/boundary0 violations remain unchanged-code regression evidence; no cloud runtime/device inference.

User-facing detailed evidence is in task outputs: final drift, factual resources, migration, delivery proof, read-only smoke, observed IAM/APIs, final ADC revocation. Private state/plan/IAM/raw messages preserved outside Git. Legacy failed plans void; no same saved plan replayed. Technical repairs used new refresh plans under standing owner boundaries.
