# Supabase Transition Note

## Current decision

- Do not migrate to Supabase in Phase 30.
- First make visible pages clean and pilot-ready.
- Supabase will be considered after the local/desktop pilot flow is coherent.

## Why not now

- Business modules are not complete yet.
- Visible pages still need cleanup.
- Moving online now could increase complexity without solving the core product problem.

## Future single-customer Supabase path

1. Supabase schema design.
2. Auth for one owner account.
3. Row Level Security.
4. Online database for core entities.
5. Read-only mobile dashboard.
6. Later transaction support.

## Security note

- Do not put secret keys in client code.
- Use publishable key only on client apps.
- Use RLS policies to protect data.
- Put sensitive server-side logic in controlled backend/Edge Functions later if needed.
- Web/mobile frontend code cannot be treated as fully hidden; protect data and sensitive logic instead.
