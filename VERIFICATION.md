# Verification — 21 October 2026

**Result: 42 automated local checks passed.** See `tests/verify.mjs`. Install Node.js 20+ and run `npm install` then `npm test` to repeat. No build is needed for the website. Test-only dependencies are not served by the included Pages workflow.

- Executed the original schema and upgrade SQL in PGlite (PostgreSQL compiled to WASM), including applying the upgrade twice. The fixture supplies Supabase-like Auth/Storage schemas, roles and default table grants; its `auth.uid()` reads a test claim. PGlite's built-in `gen_random_uuid` is used instead of loading pgcrypto. This is not a full hosted Supabase integration test.
- Checked price calculation, stock decrement, multi-line transaction rollback, retry idempotency, changed payload rejection, duplicate/malformed lines, last-unit exhaustion, completion and cancellation/restocking.
- Tested RLS against guest, authenticated non-admin and admin roles, including private data access, blocked direct checkout RPCs, stock mutation and photo upload policies.
- Tested natural size sorting, repository-specific basket storage, basket expiry/corruption, safe image URLs, announcement HTML escaping and the repository-specific Auth recovery URL.
- Transpiled the Edge Function and exercised its handler with mocked database, Resend and Turnstile transports. Confirmed origin validation, input rejection, unconfigured/accepted/failed email reporting and replay without additional email calls. Mocked API success **does not establish real email delivery**.
- Browser preview at `http://127.0.0.1:18742/uniform-shop/`: school logo, styling, storefront, empty live catalogue, announcement, basket navigation, admin sign-in/reset controls and recovery screen inspected. Assets work from a non-root path.
- Read-only live project probes: public catalogue returned HTTP 200. No catalogue items were present in the preview. A zero-row column probe confirmed `reservations.email_status` is not yet present: **run `supabase/upgrade.sql`** before using the updated checkout. No customer records were requested.
- Source syntax and relative local asset links checked; no private key values included. ZIP contents, CRCs and per-file SHA-256 hashes verified after packaging.

## Not verified / not performed

No deployment or live schema changes. No real reservation, admin sign-in, password-reset email, Storage upload, PayPal payment or email delivery was attempted. No concurrent multi-client load test or mobile-device browser test. Turnstile configuration, sender-domain verification, email delivery, final Pages URL/redirect settings and admin permissions must be checked in the acceptance test in README.

Email `accepted` means HTTP acceptance by the provider, not inbox delivery. Failed or pending notifications need manual follow-up; no automatic email retry queue is included. PayPal payments and cancellation of unpaid orders after three days remain manual.
