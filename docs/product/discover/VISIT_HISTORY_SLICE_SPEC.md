# Visit History — VIS-HIST-01

Status: **Approved**
Version: 1.0
Date: 2026-07-31

## 1. Product meaning

Visit History is the user's private record of physical places they say they
visited. It is not inferred from a Details view, Favorite, CTA, booking intent,
route construction, or GPS proximity.

The first slice is local/mock and place-only. It adds no Firebase, network,
paid service, background location, or production attendance verification.

## 2. Source of truth

VIS-HIST-01 accepts one evidence source:

- `selfReported`: the authenticated user explicitly selects
  **Mark as visited** on a Discover object whose explicit object kind is
  `place`, and chooses today or an earlier calendar date.

The schema reserves `attendanceConfirmed` for a future server-authoritative
integration. A self-reported visit must never unlock a verified-review badge
or be presented as externally confirmed attendance.

## 3. Record contract

Each record has a permanent client-generated ULID/UUID `id`, owner `userId`,
ID-only relation `placeId`, local calendar value `visitedOn` (`YYYY-MM-DD`),
IANA `timezoneId`, `evidence`, `recordedAtUtc`, and a presentation snapshot
(`title`, `subtitle`, `city`, `category`, optional `coverImageUrl`).

Rules:

1. The owner and place id are mandatory.
2. Future dates are rejected.
3. One owner + place + local calendar day is idempotent.
4. The same place can be recorded on different days.
5. The user can remove an individual record.
6. Records are ordered by visit day descending, then recording time.
7. Relations use ids; snapshot text is never used as identity.

## 4. Discover contract

Discover data exposes an explicit `DiscoverObjectKind`. The visit action is
available only for `place`; category, opening hours, title, or CTA are not used
to infer object kind.

The Details action opens a date picker, defaults to today, forbids future
dates, and writes only after explicit confirmation. Repeating the same
place/day action returns the existing record without creating a duplicate.

## 5. Persistence and migration

Local secure storage uses owner-namespaced schema v2. Missing or corrupt data
returns an empty history and invalid records fail closed independently.

Legacy `visited_places_v1_*` contains seeded demonstration data and is ignored.
It is not migrated to v2, because doing so would convert fabricated examples
into user history. The old key may remain on device for rollback safety.

## 6. UI

- Profile and the dedicated screen use the product label **Visit history**.
- Empty state explains that explicitly marked places will appear there.
- Each row shows the selected visit date and `Self-reported`.
- An individual history record can be removed with confirmation.
- Details viewing, Favorite, CTA, booking, map opening, and route/scenario
  actions never create a visit.

## 7. Acceptance criteria

- Explicit place kind gates the Details action.
- Today/past record creation, future rejection, same-day idempotency,
  different-day history, and removal are covered by tests.
- Fresh v2 storage is empty; v1 seeded data is not read or migrated.
- v2 round-trip and corrupt-record behavior are covered by tests.
- Existing Discover and profile flows remain usable.
- `flutter analyze`, `flutter test`, boundary check, and diff check are run;
  the slice remains `Review` while any global gate is red.
