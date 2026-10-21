# Verification — 21 October 2026

**Result: 54 automated local checks passed.** See `tests/verify.mjs`. Install Node.js 20+ and run `npm install` then `npm test` to repeat. No build is needed for the website. Test-only dependencies are not served by the included Pages workflow.

- Executed the original schema and upgrade SQL in PGlite (PostgreSQL compiled to WASM), including applying the upgrade twice. The fixture supplies Supabase-like Auth/Storage schemas, roles and default table grants; its `auth.uid()` reads a test claim. PGlite's built-in `gen_random_uuid` is used instead of loading pgcrypto. This is not a full hosted Supabase integration test.
- Checked price calculation, stock decrement, multi-line transaction rollback, retry idempotency, changed payload rejection, duplicate/malformed lines, last-unit exhaustion, completion and cancellation/restocking.
- Tested RLS against guest, authenticated non-admin and admin roles, including private data access, blocked direct checkout RPCs, stock mutation and photo upload policies.
- Tested natural size sorting, repository-specific basket storage, basket expiry/corruption, safe image URLs, announcement HTML escaping and the repository-specific Auth recovery URL.
- Transpiled the Edge Function and exercised its handler with mocked database, Gmail, Resend and Turnstile transports. Confirmed origin validation, input rejection, unconfigured/accepted/failed email reporting and replay without additional email calls. Mocked API success **does not establish real email delivery**.
- Gmail checks cover TLS port 465, fixed sender/account, app-password grouping-space removal, disabled protocol logging, both recipients, partial rejection, thrown connection errors, transport cleanup, precedence over Resend, no provider fallback after failure, and no resend on checkout replay. The local SMTP tests are mocked. A separate authorized live test subsequently authenticated to Gmail and received acceptance for both notifications; inbox delivery awaits user confirmation.
- Browser preview at `http://127.0.0.1:18742/uniform-shop/`: school logo, styling, storefront, empty live catalogue, announcement, basket navigation, admin sign-in/reset controls and recovery screen inspected. Assets work from a non-root path.
- Read-only live project probes: public catalogue returned HTTP 200. No catalogue items were present in the preview. A zero-row column probe confirmed `reservations.email_status` is not yet present: **the upgrade has since been applied and verified**. No customer records were requested.
- Source syntax and relative local asset links checked; no private key values included. ZIP contents, CRCs and per-file SHA-256 hashes verified after packaging.

## Not verified / not performed

The frontend, database upgrade and clean Edge Function v4 have been deployed. Live frontend files match the package. A transaction on the real database verified reservation, retry and admin cancellation/restocking, then rolled back all fixture rows. One authorized live test reservation and two notifications have since been submitted, as recorded below. Admin sign-in, password-reset email, Storage upload and PayPal payment have not been tested. No concurrent multi-client load test or mobile-device browser test. Turnstile configuration, Gmail credentials and email delivery, final Pages URL/redirect settings and admin permissions must be checked in the acceptance test in README.

Email `accepted` means SMTP/HTTP acceptance by the provider, not inbox delivery. Failed or pending notifications need manual follow-up; no automatic email retry queue is included. PayPal payments and cancellation of unpaid orders after three days remain manual.

## Direct Supabase verification

The connected project is ACTIVE_HEALTHY; reserve v4 is ACTIVE with guest checkout enabled by user approval. Retrieved function source matches the uploaded file, with the accidental browser starter template removed. The read-only readiness probe now reports checkout and reservation email configured, with anti-spam not configured. Anonymous calls cannot execute reserve_once or read private orders. Anonymous is_admin execution was revoked and verified; authenticated admin checks remain available.

Advisors now show only intentional closed tables (admins and checkout_requests have RLS and no browser policies), intentional authenticated functions with internal admin checks, and the project Auth setting for leaked-password protection disabled. References: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy ; https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable ; https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection .

## Authorized live Gmail test

On 21 October 2026, the user authorized one clearly labelled test reservation and both notification messages to spsptfa.useduniform@gmail.com. Checkout returned HTTP 200, total 0, and email_status accepted for reservation cf5ef2f2-71f9-4a77-8539-3362e74304ec. The function marks accepted only when Gmail accepts both recipients. This verifies Gmail authentication and SMTP acceptance, not inbox arrival. No payment is required for the test.

The saved order status was accepted, stock decremented from one to zero, and replaying checkout request 0c4842c1-0e4e-4e23-bd17-0842993f8722 returned the same saved receipt without taking the email-send branch. Afterwards the exact test item, stock, reservation, order lines and retry record were deleted; all five cleanup counts were verified as zero. The two sent messages remain in email. Inbox delivery awaits user confirmation.
