# Backend cost response (Draft, not executed)

Status: **Draft.** Budgets are proposed by BCK05-OD-04 (dev EUR 25, stage EUR 75,
prod EUR 150 per month); no budget, channel or route exists yet.

## A budget alert is a notification, not a limiter

Provider budget alerts do not stop spending. There is **no automatic billing
detach**: it can destroy data. Thresholds 50 / 75 / 90 / 100 % and anomaly alerts
notify the named response owner (Finance owner role); an alert without a tested
route is not evidence.

## Response steps

1. Acknowledge and identify the driver (service, module, journey, environment).
2. Contain with **server-side** means only: the cost kill switch for new Booking
   creation (`booking.create.incidentDisable`), quotas and rate limits.
3. Decide with the owner whether to continue, reduce or pause; record it.
4. Manual billing action is the **last resort**, taken only with the explicit
   decision of the owner and a data-protection check.

## Never blocked by containment

Containment must not prevent: cancelling an existing Booking (so the cancel,
query and session-issue/rotate switches are not cost switches), and the mandatory
privacy operations (export, deletion, restriction). The execution-manifest
verifier fails a containment rule that would touch them.
