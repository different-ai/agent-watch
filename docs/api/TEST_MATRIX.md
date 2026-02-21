# API test matrix

This matrix defines contract tests for `v1` API.

## Legend

- Priority: `P0` (must-pass), `P1` (high-value), `P2` (nice-to-have)
- Type: `contract`, `integration`, `performance`

## Health and status

| ID | Priority | Type | Scenario | Input | Expected |
|---|---|---|---|---|---|
| H1 | P0 | contract | healthz returns liveness payload | `GET /v1/healthz` | `200`, `ok=true`, `service=agent-watch`, `x-request-id` present |
| S1 | P0 | contract | status shape baseline | `GET /v1/status` | `200`, required fields present, `capture_freshness_ms>=0` |
| S2 | P1 | integration | status degrades when stale | old/no captures | `degraded=true` once threshold exceeded |

## Time semantics

| ID | Priority | Type | Scenario | Input | Expected |
|---|---|---|---|---|---|
| T1 | P0 | contract | strict ISO8601 accepted (UTC) | `since=...Z` | `200` |
| T2 | P0 | contract | strict ISO8601 accepted (offset) | `since=...-08:00` | `200` |
| T3 | P0 | contract | naive timestamp rejected | `since=2026-02-21T13:00:00` | `400`, `INVALID_TIME` |
| T4 | P0 | contract | `last` and `since` conflict | `last=2m&since=...` | `400`, `LAST_SINCE_CONFLICT` |
| T5 | P1 | contract | invalid `last` format rejected | `last=2minutes` | `400`, `INVALID_TIME` |
| T6 | P1 | contract | invalid timezone rejected | `tz=Not/AZone` | `400`, `INVALID_TZ` |
| T7 | P1 | contract | default window applied | no time params | `200`, `meta.window_*` reflect server default |

## Search contract

| ID | Priority | Type | Scenario | Input | Expected |
|---|---|---|---|---|---|
| Q1 | P0 | contract | empty query allowed for browsing | `GET /v1/search?last=2m` | `200`, `results` array |
| Q2 | P0 | contract | full-text query returns matching captures | `q=token` | `count>0` for seeded token |
| Q3 | P0 | contract | deterministic sort | seeded same-second rows | sorted by `ts_utc DESC, id DESC` |
| Q4 | P0 | contract | source filter accepts enum only | `source=ocr` | `200`; unknown source -> `400 INVALID_FILTER` |
| Q5 | P1 | contract | app filter repeat semantics | `app=Arc&app=Safari` | returns union set for both apps |
| Q6 | P1 | contract | limit bounds enforced | `limit=0`, `limit=201` | `400 INVALID_LIMIT` |

## Pagination

| ID | Priority | Type | Scenario | Input | Expected |
|---|---|---|---|---|---|
| P1 | P0 | contract | first page contains cursor | `limit=10` on >10 rows | `meta.next_cursor` non-null |
| P2 | P0 | contract | second page is non-overlapping | `cursor=<next_cursor>` | no duplicate IDs across adjacent pages |
| P3 | P0 | contract | invalid cursor handling | `cursor=garbage` | `400 INVALID_CURSOR` |
| P4 | P1 | contract | cursor tied to query fingerprint | reuse cursor with different filters | `400 INVALID_CURSOR` |

## Error envelope

| ID | Priority | Type | Scenario | Input | Expected |
|---|---|---|---|---|---|
| E1 | P0 | contract | bad request shape | invalid params | envelope includes `code`, `message`, `details`, `request_id` |
| E2 | P0 | contract | all error responses include request id header | any `4xx/5xx` | `x-request-id` header present |
| E3 | P1 | integration | internal error consistency | force DB failure | `500 INTERNAL_ERROR` with envelope shape |

## Freshness and observability

| ID | Priority | Type | Scenario | Input | Expected |
|---|---|---|---|---|---|
| F1 | P0 | integration | freshness decreases after new capture | insert capture then query status | `capture_freshness_ms` drops |
| F2 | P1 | contract | search meta includes freshness | `GET /v1/search` | `meta.capture_freshness_ms` present |
| F3 | P1 | contract | top_apps shape stability | seeded mixed apps | array items include `app`, `count` |

## Performance budget checks

| ID | Priority | Type | Scenario | Input | Expected |
|---|---|---|---|---|---|
| PERF1 | P1 | performance | small window, default limit | `last=2m&limit=50` | p50 < 40ms |
| PERF2 | P1 | performance | larger window, bounded limit | `last=24h&limit=200` | p95 < 150ms |
| PERF3 | P2 | performance | concurrent read load | 20 parallel search clients | no contract violations; bounded tail latency |
