# Security

## Authentication

- Supabase Auth (email + password, min 8 characters in the app). Sessions are persisted by `supabase_flutter`.
- Password reset sends an email link; the app handles the `passwordRecovery` event and routes to the
  "choose a new password" screen. Mobile deep link: `com.equilense.equilense://auth-callback`.
- Router guards: every non-public route redirects to `/login` without a session.

## Database security

- RLS on all public tables; owner-only policies on all user data (`(select auth.uid()) = user_id`).
- Composite foreign keys `(id, user_id)` make cross-user references impossible even for a malicious client.
- Reference tables are read-only to clients. `anon` has no table privileges.
- The only RPC (`save_analysis_results`) is `SECURITY INVOKER` with `search_path = ''`, so RLS applies.
- `handle_new_user` is `SECURITY DEFINER` with `search_path = ''` and is not executable by clients.
- Supabase security advisor: no findings after migration.

## Storage security

- Private bucket `financial-documents`; 25 MB limit; PDF and XLSX MIME types only.
- Object paths start with the user's id; policies only allow access to one's own folder.
- No public URLs; previews use signed URLs valid for 5 minutes.

## Credential management

- The app contains only the Supabase URL and the **publishable** key (safe to ship; RLS enforces access).
  Both can be overridden with `--dart-define`.
- No service-role / secret keys anywhere in the repository or app.
- Local preferences (theme, onboarding flag) use SharedPreferences; no credentials are stored there.

## Not in scope / follow-ups

- Configure custom SMTP and enable leaked-password protection and MFA in the Supabase dashboard before launch.
- Consider rate limiting / CAPTCHA on sign-up (Supabase Auth settings).
