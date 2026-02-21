# API invariants

This document defines hard guarantees for `agent-watch` API behavior.

## 1) Surface area invariants

- `v1` intentionally exposes only:
  - `GET /v1/healthz`
  - `GET /v1/status`
  - `GET /v1/search`
- New endpoints are rare and must have strong justification.
- Existing endpoint semantics do not break across patch/minor releases.

## 2) Time invariants

- All stored timestamps are UTC.
- Incoming timestamps (`since`, `until`) must include timezone offset or `Z`.
- Naive timestamps are rejected with `INVALID_TIME`.
- `last` and `since` are mutually exclusive.
- If no explicit window is provided, server defaults to `last=24h`.
- If `until` is omitted, server uses request receive time (`now_utc`).

## 3) Ordering and pagination invariants

- Search ordering is deterministic: `ts_utc DESC, id DESC`.
- Cursor pagination is stable for a given query fingerprint.
- Cursor tokens are opaque and tamper-resistant.
- Invalid or stale cursors return `INVALID_CURSOR`.
- Offset-based pagination is not supported.

## 4) Filtering invariants

- `app` is an exact normalized match (case-folded, trimmed).
- `source` accepts only known enum values.
- Unknown filters are rejected (not ignored silently).
- `limit` default is `50`; max is `200`; above max returns `INVALID_LIMIT`.

## 5) Response shape invariants

- Every response includes `x-request-id` header.
- Error payload shape is always:

```json
{
  "error": {
    "code": "...",
    "message": "...",
    "details": "... or null",
    "request_id": "..."
  }
}
```

- `search.meta.capture_freshness_ms` is always present.
- `search.meta.next_cursor` is either string or null.
- `search.results` is always an array.

## 6) Freshness invariants

- `status` exposes `latest_capture_at_utc` and `capture_freshness_ms`.
- `degraded=true` when freshness exceeds policy threshold.
- Freshness is measured against server time in UTC.

## 7) Compatibility invariants

- Additive fields are allowed.
- Field removals or meaning changes require `/v2`.
- Enum expansions are additive and documented in release notes.

## 8) Performance invariants

- Target p50 search latency: < 40ms under normal local dataset.
- Target p95 search latency: < 150ms for default window/limit.
- Requests above defined limits fail fast instead of degrading service.
