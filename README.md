# SPS PTFA Used Uniform Shop — GitHub Pages package

Prepared from the supplied **new** `sps-ptfa-free-shop.zip` on 21 October 2026. The shop is now deployed at https://prodigyai-app.github.io/sps-ptfa-uniform-shop/. The database upgrade and clean checkout function v4 are deployed. One user-authorized test reservation was submitted: Gmail accepted both notification messages, and all test database records were removed. Inbox delivery still awaits confirmation. Earlier database transaction checks were rolled back. See DEPLOYMENT-STATUS.txt for remaining setup.

The public project URL and publishable key are already set in `site/config.js` for `jouszfcpbhhvmwubluqu`. This is the project base URL, without `/rest/v1/`. The public key is intended for browser use; all privileged credentials stay in Supabase Function secrets.

## Deploy

1. **Database:** your project already responds to public catalogue reads. Run **`supabase/upgrade.sql`** in its SQL Editor. It is repeatable and preserves existing admins, stock and orders. Do **not** rerun `schema.sql` on the existing database: that original file is for a fresh installation only. For a fresh project, run `schema.sql` then `upgrade.sql`.
2. **GitHub Pages:** put the entire contents of this folder in the root of your repository, with `site/`, `supabase/` and `.github/` alongside this README. Use branch `main`. In **Settings → Pages → Source**, choose **GitHub Actions**, then run the included **Deploy static shop to GitHub Pages** workflow (or push to `main`). It publishes only `site/`. Your URL will be `https://OWNER.github.io/REPOSITORY/`. Keep the trailing slash. The included workflow has been run and the live assets have been checked against this package.
3. **Supabase Auth:** in **Authentication → URL Configuration**, set Site URL to that full Pages URL, including `/REPOSITORY/`. Add the exact redirect URL `https://OWNER.github.io/REPOSITORY/?recovery=1`. Retain the existing admin account. If needed, create a confirmed user in Auth and add its UUID using `insert into public.admins(user_id) values ('AUTH-USER-UUID') on conflict do nothing;`. Disable public sign-ups if unnecessary. Password reset uses Supabase Auth email settings, separately from reservation email settings.
4. **Checkout:** install the [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started), then run these from this folder:

   ```sh
   supabase login
   supabase link --project-ref jouszfcpbhhvmwubluqu
   supabase secrets set SHOP_ORIGIN=https://OWNER.github.io
   supabase functions deploy reserve --no-verify-jwt
   ```

   `SHOP_ORIGIN` is the origin only, without a repository path or trailing slash. Guest checkout is intentionally public; the function validates origin and inputs and calls the service-only SQL transaction. `--no-verify-jwt` is also recorded in `supabase/config.toml`. The publishable key is sent in `apikey`, never as a bearer JWT. There is no direct browser-to-database checkout fallback. **Deploy the updated function after running the upgrade.**
5. **Reservation emails (Gmail):** sign into **spsptfa.useduniform@gmail.com** and use [Google App passwords](https://myaccount.google.com/apppasswords) to create a password for this shop (2-Step Verification required). An existing app-password entry does not reveal its password again; create a new one if the old value is unavailable. In Supabase **Edge Functions → Secrets → Add or replace secrets**, set **`GMAIL_APP_PASSWORD`** to that app password. Do not use the ordinary Google login password. The function sends from this fixed Gmail account using `smtp.gmail.com:465` with implicit TLS, to the PTFA and the parent. It strips the displayed grouping spaces. No Resend account, custom domain, `EMAIL_FROM` or additional username secret is needed for Gmail. Never put the password in GitHub, `site/config.js` or chat. Supabase supplies its service-role key automatically. Gmail account limits and security checks apply; a real delivery test is required. Until credentials are configured, reservations can save but email status is `not_configured`. If a Google password change revokes the app password, replace the Supabase secret.

   Optional alternative: the original Resend integration remains available through `RESEND_API_KEY` and a verified-domain `EMAIL_FROM`. When `GMAIL_APP_PASSWORD` is present, Gmail takes precedence. A failed Gmail attempt does not automatically switch providers or resend; check the saved order and contact the parent manually.
6. **Anti-spam:** before public launch, configure Cloudflare Turnstile for `OWNER.github.io`; put its public site key in `site/config.js`, and its matching `TURNSTILE_SECRET_KEY` in Supabase Function secrets. Both halves must match. Without the secret, checkout remains public with validation and a honeypot, but no CAPTCHA or rate limiter. CORS alone does not prevent automated abuse. Add monitoring/rate limiting if needed.
7. **Acceptance test before sharing:** sign in as admin; add a test product, image and two units of stock. In a separate signed-out browser, reserve one using a real test email. Check the receipt/reference, stock decrement, admin order, **both delivered emails**, and PayPal.Me destination. Cancel the order and verify stock returns exactly once. Test password recovery, mobile layout, and your final Pages repository URL. A live test reservation, stock decrement, saved receipt and retry were verified, and Gmail accepted both test messages. All test records were removed. Inbox arrival and the remaining acceptance checks are still pending.

Alternative without Actions: publish the **contents** of `site/` at your repository root and choose Pages → Deploy from a branch → `main` → `/ (root)`. Keep the Supabase folder separately for CLI deployment. Never upload only the containing folder when using this option.

## Preserved behaviour

- Shop and admin, announcements, item/stock editing and cancellation/restocking.
- Natural size order (5–6, 9–10, 10–11, then S, M, L, XL).
- Ten-minute browser basket; stock is held only after successful reservation.
- Public product photo bucket `uniform-images`, admin-only uploads, 5 MB maximum, JPEG/PNG/WebP/GIF. Upgrade configures this bucket without deleting existing photos. Bundled reference photos remain in `site/assets/`; no old stock/orders are imported or invented.
- Reservation emails to PTFA and parent; full reference and honest email status on receipt/admin.
- Payment link: **https://www.paypal.com/paypalme/spptfa**. Payment is checked manually; checkout does not process or verify PayPal payments. The payment request is within 3 days; unpaid orders are cancelled/restocked manually by an admin, with no automatic expiry job.

## Changes and verification

- Configured the supplied Supabase URL/public key. All assets use relative paths and the Supabase browser library is bundled locally at pinned version 2.57.4 with its MIT licence.
- Added repository-specific basket/Auth storage and password recovery that returns to the same repository subpath. No server rewrite routes are needed.
- Added service-only `reserve_once` SQL with a checkout UUID, payload matching and an advisory transaction lock. Retrying unchanged details in the same basket reuses the receipt and does not decrement stock/send email twice. Keep the reference if a connection fails; contact PTFA before starting a different basket if uncertain.
- Added origin validation, bounded input, explicit grants, photo limits, safe announcement links and admin-visible email status. Frontend contains no service-role, email or Turnstile secret values.
- Email provider acceptance (Gmail SMTP or Resend HTTP) is shown as `accepted`, **not proof of inbox delivery**. Failures preserve the order. `pending`/`unknown` needs manual checking; no automatic email retry queue is included. Admins see the newest 200 orders and their paginated order lines.
- Gmail uses pinned `nodemailer@10.1.7`; protocol/debug logging is disabled, sender/account are fixed, and email content cannot load local files or remote URLs. Credentials are only read server-side. Both messages must be accepted for `accepted` status. SMTP has no provider idempotency guarantee; database checkout replay prevents repeat sends, but failures/pending status require manual review.
- The checkout GET endpoint returns only configuration booleans (no secret values), allowing setup checks without placing an order.
- See `VERIFICATION.md` and `tests/` for the local checks and their limits.

## Data care and references

Names, email addresses and child/class details are private admin-only data. `checkout_requests` stores the same contact payload for retry protection and has no browser access. Include it in the PTFA retention/deletion policy; deleting it removes retry protection for the associated request. Public Storage is for product photographs only. Publish an appropriate PTFA privacy notice before live orders. Check provider plans/quotas and hosting terms for your use.

Official references: [Supabase keys](https://supabase.com/docs/guides/getting-started/api-keys), [Auth redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls), [Edge Function auth](https://supabase.com/docs/guides/functions/auth), [GitHub Pages workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages), [Google app passwords](https://support.google.com/mail/answer/185833?hl=en), [SMTP transport](https://nodemailer.com/smtp), [Supabase SMTP port limits](https://supabase.com/docs/guides/functions/limits), [Resend idempotency](https://resend.com/changelog/idempotency-keys).
