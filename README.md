# Tenant isolation lab: from finding to retested fix

LAB DEMONSTRATION. Everything here is a fictional app with made-up data, built by Secvura to show how we prepare and retest a fix. It is not taken from any client engagement, and no real system was tested.

Never run this lab against a production or shared database. It deliberately installs insecure access rules.

## The finding (fictional)
"Customer data is not isolated between tenants." In a multi-tenant app on Supabase (Postgres row level security), a signed-in user of one customer can read, change, delete and create records belonging to another customer, and can add themselves to another customer's team. A visitor who is not signed in can read stored file records, and can create and rename customer records.

## What is in the lab
- `sql/00_supabase_shim.sql`: a minimal local stand-in for Supabase's `anon` and `authenticated` roles and its `auth.uid()` and `auth.jwt()` functions, following Supabase's own definitions. Skip this file on a local Supabase stack, where these roles and functions already exist.
- `sql/01_schema.sql`: two fictional customers (tenant A, tenant B), one user in each, invoices and attachments.
- `sql/02_vulnerable_policies.sql`: four deliberate mistakes:
  1. The tenant is read from `user_metadata`, which the user can edit themselves. Supabase's documentation says not to use it for authorisation.
  2. Any signed-in user can insert rows for any tenant.
  3. A "join team" policy lets a user add themselves to any tenant.
  4. Row level security is never turned on for two tables: attachments and tenants.
- `sql/03_fixed_policies.sql`: the fix. The tenant comes only from a memberships table that users cannot write to, through a `security definer` function with an empty `search_path` in a non-exposed schema. Every table has row level security, and inserts and updates are checked as well as reads.
- `sql/04_tests.sql`: the two-account retest, 19 checks. It first confirms the seed data is exactly what `01_schema.sql` inserts, so a blocked result cannot come from missing rows. Each check runs as the real API role with real JWT claims, inside a subtransaction that is always rolled back. Allowed cases (a user working on their own data) are tested alongside blocked cases, so a fix that blocks everyone does not pass.

## Results (18 Nov 2026)
- Plain PostgreSQL 16.16 with the shim: vulnerable 8 PASS, 11 FAIL; fixed 19 PASS, 0 FAIL
- Local Supabase stack (CLI 3.2.0, PostgreSQL 17.12) without the shim: vulnerable 8 PASS, 11 FAIL; fixed 19 PASS, 0 FAIL

## Run it
Create two empty PostgreSQL databases, then:
```
psql -v ON_ERROR_STOP=1 -d lab_vulnerable -f sql/00_supabase_shim.sql -f sql/01_schema.sql -f sql/02_vulnerable_policies.sql -f sql/04_tests.sql
psql -v ON_ERROR_STOP=1 -d lab_fixed -f sql/00_supabase_shim.sql -f sql/01_schema.sql -f sql/02_vulnerable_policies.sql -f sql/03_fixed_policies.sql -f sql/04_tests.sql
```

## Run it on a local Supabase stack
This runs Supabase locally in Docker and is not connected to any cloud project. Do not run `supabase link` or `supabase db push`. Skip `sql/00_supabase_shim.sql`, because the real roles and auth functions already exist here. From an empty scratch folder:
```
supabase init
supabase start
psql -v ON_ERROR_STOP=1 postgresql://postgres:postgres@127.0.0.1:54322/postgres -f sql/01_schema.sql -f sql/02_vulnerable_policies.sql -f sql/04_tests.sql
supabase db reset
psql -v ON_ERROR_STOP=1 postgresql://postgres:postgres@127.0.0.1:54322/postgres -f sql/01_schema.sql -f sql/02_vulnerable_policies.sql -f sql/03_fixed_policies.sql -f sql/04_tests.sql
supabase stop --no-backup
```
Adjust the `sql/` paths to point at this folder. `--no-backup` deletes the local database when the stack stops; without it, the next `supabase start` in a folder of the same name brings the old tables back and `01_schema.sql` fails.

## What a passing retest shows, and what it does not
It shows that, on the tested database and build, these 19 specific checks behave as expected for these two test users. It does not show that the whole app is secure. It does not cover the API layer, server-side code that uses the service role key (which bypasses row level security), storage buckets, edge functions, or tables that are not in the test. A fix is only "retested" once the client has deployed it and the checks pass against the deployed build. Before then its status is "fix prepared, deployment pending".

It also does not test two common ways round row level security in Supabase. A view reads its tables with its owner's rights by default, so it can skip the rules unless it is created with `security_invoker = true` (PostgreSQL 15 and later). A `security definer` function in an exposed schema also runs with its owner's rights. Either can undo a correct fix.

Do not paste `sql/03_fixed_policies.sql` into your own project. It is written for this lab's four tables, and your tables, roles and existing rules will differ. Use it as a pattern, then test your own build with your own allowed and blocked cases.

## Who we are
Secvura is a UK firm that reviews web and SaaS apps for small software companies, prepares fixes with their team, and retests each fix after it is deployed. Where you need an accredited test, use a CREST or CHECK firm. secvura.com
