# Reservation checkout update - 7 November 2026

106 automated local checks pass. Added regression checks for autofill-safe spam fields, cached legacy forms, clear failure/payment instructions, amount-specific GBP PayPal links and escaped manual payment details. Browser preview confirmed the four-field checkout and successful confirmation screen; its backend and emails were mocked. A live deliberately invalid spam-check request returned ANTI_SPAM_CHECK without creating an order or sending mail. The private payment-column upgrade was applied successfully; customer records remain protected by existing RLS. A separate private transaction check verified nine-line manual entry, stock changes and duplicate-run safety.

Payment is checked manually by the PTFA. The consistent payment deadline is 2 days. The honeypot fix does not add CAPTCHA or rate limiting; existing optional Turnstile validation remains unchanged.

## Earlier verification history

# Verification — updated 27 October 2026

**Result: 74 automated local checks passed.** See `tests/verify.mjs`. Install Node.js 20+ and run `npm install` then `npm test` to repeat. No build is needed for the website. Test-only dependencies are not served by the included Pages workflow.

- Executed the original schema and upgrade SQL in PGlite (PostgreSQL compiled to WASM), including applying the upgrade twice. The fixture supplies Supabase-like Auth/Storage schemas, roles and default table grants; its `auth.uid()` reads a test claim. PGlite's built-in `gen_random_uuid` is used instead of loading pgcrypto. This is not a full hosted Supabase integration test.
- Checked price calculation, stock decrement, multi-line transaction rollback, retry idempotency, changed payload rejection, duplicate/malformed lines, last-unit exhaustion, completion and cancellation/restocking.
- Tested RLS against guest, authenticated non-admin and admin roles, including private data access, blocked direct checkout RPCs, stock mutation and photo upload policies.
- Tested natural size sorting, repository-specific basket storage, basket expiry/corruption, safe image URLs, announcement HTML escaping and the repository-specific Auth recovery URL.
- Transpiled the Edge Function and exercised its handler with mocked database, Gmail, Resend and Turnstile transports. Confirmed origin validation, input rejection, unconfigured/accepted/failed email reporting and replay without additional email calls. Mocked API success **does not establish real email delivery**.
- Gmail checks cover TLS port 465, fixed sender/account, app-password grouping-space removal, disabled protocol logging, both recipients, partial rejection, thrown connection errors, transport cleanup, precedence over Resend, no provider fallback after failure, and no resend on checkout replay. The local SMTP tests are mocked. A separate authorized live test subsequently authenticated to Gmail and received acceptance for both notifications; the user confirmed both messages arrived in the PTFA Gmail account.
- Browser preview at `http://127.0.0.1:18742/uniform-shop/`: school logo, styling, storefront, empty live catalogue, announcement, basket navigation, admin sign-in/reset controls and recovery screen inspected. Assets work from a non-root path.
- Read-only live project probes: public catalogue returned HTTP 200. No catalogue items were present in the preview. A zero-row column probe confirmed `reservations.email_status` is not yet present: **the upgrade has since been applied and verified**. No customer records were requested.
- Source syntax and relative local asset links checked; no private key values included. ZIP contents, CRCs and per-file SHA-256 hashes verified after packaging.

## Not verified / not performed

The frontend, database upgrade and clean Edge Function v4 have been deployed. Live frontend files match the package. A transaction on the real database verified reservation, retry and admin cancellation/restocking, then rolled back all fixture rows. One authorized live test reservation and two notifications have since been submitted, as recorded below. Admin sign-in, password-reset email, Storage upload and PayPal payment have not been tested. No concurrent multi-client load test or mobile-device browser test. Turnstile configuration, Gmail credentials and email delivery, final Pages URL/redirect settings and admin permissions must be checked in the acceptance test in README.

Email `accepted` means SMTP/HTTP acceptance by the provider, not inbox delivery. Failed or pending notifications need manual follow-up; no automatic email retry queue is included. PayPal payments and cancellation of unpaid orders after two days remain manual.

## Direct Supabase verification

The connected project is ACTIVE_HEALTHY; reserve v4 is ACTIVE with guest checkout enabled by user approval. Retrieved function source matches the uploaded file, with the accidental browser starter template removed. The read-only readiness probe now reports checkout and reservation email configured, with anti-spam not configured. Anonymous calls cannot execute reserve_once or read private orders. Anonymous is_admin execution was revoked and verified; authenticated admin checks remain available.

Advisors at initial setup showed only intentional closed tables (admins and checkout_requests have RLS and no browser policies), intentional authenticated functions with internal admin checks, and the project Auth setting for leaked-password protection disabled. References: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy ; https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable ; https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection .

## Authorized live Gmail test

On 21 October 2026, the user authorized one clearly labelled test reservation and both notification messages to spsptfa.useduniform@gmail.com. Checkout returned HTTP 200, total 0, and email_status accepted for reservation cf5ef2f2-71f9-4a77-8539-3362e74304ec. The function marks accepted only when Gmail accepts both recipients. This verifies Gmail authentication and SMTP acceptance. The user subsequently confirmed both messages arrived in the PTFA Gmail account; a subsequent authorized test to a separate parent email address was also confirmed received. No payment is required for the test.

The saved order status was accepted, stock decremented from one to zero, and replaying checkout request 0c4842c1-0e4e-4e23-bd17-0842993f8722 returned the same saved receipt without taking the email-send branch. Afterwards the exact test item, stock, reservation, order lines and retry record were deleted; all five cleanup counts were verified as zero. The two sent messages remain in email. The user confirmed both test messages arrived in the PTFA Gmail account. A separate authorized test to a different parent mailbox was subsequently confirmed received.

## Separate parent-mailbox test

A second user-authorized zero-value test reservation was submitted on 21 October 2026 using a different parent email address. Checkout returned HTTP 200 and accepted for both notifications. The user confirmed the parent confirmation arrived. The exact temporary item, stock, reservation, lines and retry record were removed and all five cleanup counts verified as zero. The catalogue before and after remained eight items with photo URLs and zero stock rows. The personal test email address is intentionally omitted from this public package.

This establishes delivery for the two tested Gmail mailboxes; delivery to every future recipient is not guaranteed. Add stock variants (size, condition, price, quantity) before accepting orders. The previously noted empty catalogue reflects the earlier check; it has since been populated by the user.

## Christmas jumper category update - 27 October 2026

74 automated local checks pass. New checks cover category defaults and constraints, separate storefront filters, admin/non-admin category permissions, moving an item without changing stock, shared basket/Auth path scope, and a mixed-category reservation with server-calculated prices. The repeatable upgrade is applied twice in the local PostgreSQL test.

Edge browser preview at a GitHub Pages-style subpath verified the promotion link, real uniform catalogue, seasonal empty state, and mobile promotion layout. Local-only browser fixtures verified adding a Christmas item and stock variant, category changes retaining stock, All categories, automatic selection of a newly added item, natural size order, exclusion from the uniform catalogue, and a mixed uniform/jumper basket totalling correctly across page navigation. Fixture pages were served only by the local QA server, with no production data or email writes. These fixture scripts are not shipped to GitHub Pages.

The live category update was applied using the signed-in Supabase dashboard after the connector denied project access. All eight existing items remain in Uniform with all eight photo URLs retained. No donated jumper records were invented, and no new live test reservation or email was sent for this change. Existing checkout function and email configuration are unchanged. New HTML pages and assets are verified after GitHub Pages publication.

## One-off Christmas cards - 1 November 2026

74 local automated checks pass. Additional tests execute the actual product-card rendering and click handlers with a local DOM fixture: visible size/price, no Christmas select or quantity input, adding one unit directly, rejecting repeated clicks for quantity-one stock, safe escaped text and display-only photo rotation, ordinary uniform selection unchanged, and no Add button when stock is unavailable. No new live reservation or email is sent.

Browser access was initially disabled and the Supabase connector denied project access. Browser access subsequently became available, and the verified complete SQL was applied through the signed-in Edge dashboard. All 28 listings are now live with their agreed £2 suggested donation. Original photos are included in the GitHub Pages source and their hashes are verified.

The import script was executed twice against the local PostgreSQL fixture: exactly 28 items and stock rows were created; a deliberately reserved stock row remained at zero; and a manually edited price was retained. All 28 copied photo files match the original attachments by SHA-256; no GPS metadata was found. Photo display rotation is encoded in the URL fragment and does not alter the originals. Publicly hosted photo availability is verified after deployment. A subsequent live Edge browser review confirmed all 28 cards, upright photographs, visible sizes, £2 suggested donation labels and direct Add buttons.

## Completed live import - 1 November 2026

The SQL Editor returned 28 rows after the import. Independent public Data API reads verified every supplied image URL against the local manifest, one matching item per photo, the expected item name/category and exactly one stock row with the labelled size, price_pence 200 and quantity one. Eight normal uniform items remain intact. No security policies or account permissions were changed by the import.

The live Christmas page displayed all 28 item cards. A browser basket check added one item and confirmed the basket remained at one unit after repeated Add clicks, then removed the test basket line. No reservation or email was submitted for this check. The shared checkout and email function are unchanged. A live screenshot is supplied separately as christmas-stock-live.png.


## 4 November 2026 checkout/admin verification

- 94 automated checks pass, including separate child storage, idempotent retries, service-only RPC permissions, private child data, legacy checkout compatibility and escaped child details in both mocked emails.
- Local browser exercised four-field checkout, separate total row, clear notification text, Stock/Order management navigation, free-text conditions and 390px mobile layout without horizontal overflow.
- Supabase database assertions verify separate child details, stock decremented once on retry, RPC permissions and reservation RLS. Test changes are rolled back; no email is sent by these SQL checks.
- New email content is tested with mocked transports. No new end-to-end email delivery test is claimed.
