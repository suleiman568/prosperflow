# Applying the schema to a live project

`supabase/schema.sql` carries three things the client already expects: the
`server_updated_at` watermark and its trigger, which every delta pull keys on;
the `stock_adjustments` table that stock is now derived from; and the cursor
indexes that make paging correct rather than merely fast.

Against an unmigrated project the failure is quiet rather than loud. A pulling
client sits in the restoring state — "Restoring your data" on Products,
skeletons where the dashboard figures go, Reports waiting — until its first pull
fails into the retry backoff. A trader would see an app that never finishes
starting up.

| | |
|---|---|
| Applies | `supabase/schema.sql` (246 lines) |
| Safe to re-run | Yes, as a whole |
| Needs | Project owner access |

## Two things to know first

**Run the file whole, not statement by statement.** Every statement is
`if not exists`, `or replace`, or a `drop … if exists` followed by a create, so
the file is safe to run and re-run. But two of the steps are `do $$ … $$`
blocks, and the block that adds `server_updated_at` to `stock_adjustments`
relies on the block above it having created that table. Pasting selected
statements is how this goes wrong.

**`supabase db push` is not an option here**, despite what the file's own
header comment says. The repository has no `supabase/config.toml` and no
`migrations/` directory, so the CLI has nothing to link or push. Use the SQL
editor or `psql`.

## 1. Before you touch anything: will the legacy rename fire?

The first block in the file renames `products`, `sales`, `expenses` or
`credits` to `<name>_legacy` if the table exists *without* a `trader_id`
column — leftovers from a discarded prototype that keyed on `user_id`. Data is
preserved, but the app then creates a fresh empty table and the old rows become
invisible to it.

This is the only step in the file that is not purely additive, so learn what it
will do before it does it.

```sql
select t.table_name,
       exists (
         select from information_schema.columns c
         where c.table_schema = 'public'
           and c.table_name = t.table_name
           and c.column_name = 'trader_id'
       ) as has_trader_id
from information_schema.tables t
where t.table_schema = 'public'
  and t.table_name in
      ('products', 'sales', 'expenses', 'credits', 'stock_adjustments')
order by t.table_name;
```

- **Expect** no rows on a clean project — nothing is renamed. Or rows all
  reading `has_trader_id = true`, meaning the tables are already the current
  shape and nothing is renamed.
- **Stop if** any row reads `false`. That table *will* be renamed. Decide what
  you want to happen to its data first.

## 2. Run the whole file

Supabase dashboard → SQL Editor → paste the entire contents of
`supabase/schema.sql` → Run. Or, with a connection string for the project:

```sh
psql "$DATABASE_URL" -f supabase/schema.sql
```

- **Expect** success with no rows returned. Re-running changes nothing, so if
  you are unsure whether it completed, run it again rather than picking through
  it.
- **Symptom** an error naming a table that does not exist means the file was run
  in pieces. Start over with the full file.

## 3. Verify: the watermark column and trigger exist on all five tables

This is what every pull cursor reads. The trigger count matters as much as the
column: the reason this column exists at all is that `received_at` was a column
default, and Postgres has no `on update` for defaults, so it fired on insert
only and silently missed every edit.

```sql
select c.table_name,
       (select count(*)
          from information_schema.triggers g
         where g.event_object_schema = 'public'
           and g.event_object_table = c.table_name
           and g.trigger_name =
               c.table_name || '_touch_server_updated_at') as trigger_rows
from information_schema.columns c
where c.table_schema = 'public'
  and c.column_name = 'server_updated_at'
order by c.table_name;
```

- **Expect** exactly five rows — `credits`, `expenses`, `products`, `sales`,
  `stock_adjustments` — each with `trigger_rows = 2`. Two because
  `information_schema` lists one row per event, and the trigger fires
  `before insert or update`.
- **Symptom** `trigger_rows = 1` is the dangerous result: the watermark would
  move on insert and not on edit, which is exactly the bug this column
  replaced. Fewer than five rows means the `do $$` block did not complete.

## 4. Verify: the trigger actually fires on an update

Existing and firing are different claims, and only the second one matters. This
runs inside a transaction that is rolled back, so it keeps nothing. Run it as
the project owner in the SQL editor, where row-level security is bypassed. Skip
it if the project has no rows yet — step 7 covers that case from the device
instead.

```sql
begin;

create temporary table probe on commit drop as
select id, server_updated_at as before_update
from public.products
limit 1;

update public.products p
   set name = p.name
 where p.id = (select id from probe);

select p.server_updated_at > probe.before_update as trigger_fired,
       probe.before_update,
       p.server_updated_at as after_update
from public.products p
join probe on probe.id = p.id;

rollback;
```

- **Expect** one row, `trigger_fired = true`. Note that the update sets `name`
  to itself — the trigger must fire on an update that changes nothing, because
  a soft delete or a re-push looks exactly like that.
- **Symptom** `false`, or the two timestamps equal. The trigger is not attached
  to `update`. Re-run the file; if it persists, check for an older trigger of a
  different name on the table shadowing it.

## 5. Verify: the cursor indexes are on the pair, in that order

Pulls page on `(server_updated_at, primary key)` because `now()` is transaction
time: recording one sale stamps the sale, the product and the credit
identically, and a cursor on the timestamp alone either skips the rest of a tied
group at a page boundary or fetches it forever. The primary key is in the index
as a tie-breaker, so column order is the thing to check.

```sql
select tablename, indexdef
from pg_indexes
where schemaname = 'public'
  and indexname like '%trader_server_updated_idx'
order by tablename;
```

- **Expect** five rows. Four read `(trader_id, server_updated_at, id)`;
  `credits` reads `(trader_id, server_updated_at, sale_id)`, because credits are
  keyed on the sale they belong to.
- **Symptom** a two-column index, or the columns in another order. Pulls will
  still return rows, so nothing looks broken — they will drop rows at page
  boundaries under load, which is the hardest class of bug to notice later.

## 6. Verify: row-level security is on, and refusing

The client depends on refusal being *loud*. An update that matches no row
returns `204` exactly like a successful one, so the app asks for the affected
rows back and treats an empty result as an error rather than dropping the
mutation from its outbox. That only protects anyone if the policies are in
place.

```sql
select t.tablename, t.rowsecurity, p.policyname, p.cmd, p.roles
from pg_tables t
left join pg_policies p
       on p.schemaname = t.schemaname and p.tablename = t.tablename
where t.schemaname = 'public'
  and t.tablename in
      ('products', 'sales', 'expenses', 'credits', 'stock_adjustments')
order by t.tablename;
```

- **Expect** five rows, every `rowsecurity` true, each with one policy for
  `cmd = ALL` and `roles = {authenticated}`.
- **Symptom** `rowsecurity = false` on any table means every trader's rows are
  readable by every other signed-in trader. A null `policyname` with security
  enabled is the opposite failure: nothing is readable and every push fails.

## 7. Verify end to end: watch a second device restore

The last check is the only one that exercises the whole path, and the restoring
state makes it observable rather than guesswork.

1. On a phone that already holds data, record a sale. The dashboard sync row
   should settle from **1 sale waiting to sync** to **Backed up just now**.
2. Sign in as the same trader on a second device, or reinstall. Products should
   read **Restoring your data** with a climbing item count, then fill in.
3. While it runs, the dashboard figures should be skeletons and Reports should
   be waiting. Both are deliberate — they are what stops a half-arrived ledger
   being quoted as fact.
4. When it finishes, check that the stock figure for a product you have sold
   matches on both devices. That is the event-derived stock doing its job.

| What you see | What it means | Where to look |
|---|---|---|
| Restoring never finishes | The pull is erroring, and the retry backoff is hiding it | Steps 3 and 5; then the project's API logs |
| "No products yet" on a device that should have data | The pull succeeded and returned nothing | Step 6 — policies, or a different `trader_id` |
| Sales stay "waiting to sync" | A push is failing on every retry | A missing column: `unit_cost`, `list_price` |
| Stock disagrees between two devices | Adjustments are not arriving | `stock_adjustments` exists, and its policy |

## Ordering constraint

Apply this **before** shipping any client that pulls. The file says so in three
separate comments, and they are not interchangeable warnings: `unit_cost` and
`list_price` block pushes, while `server_updated_at` and the indexes block
pulls. A client released ahead of the migration does not fail cleanly — it
retries with backoff behind a restoring screen that never clears.

## If you need to go back

Everything the file does is additive except the legacy rename, so there is
little to undo and one thing that needs care.

- **The legacy rename is reversible.** Drop the new empty table and rename the
  old one back: `alter table public.expenses_legacy rename to expenses;`
- **Do not drop `server_updated_at`, the triggers, or the cursor indexes** while
  any client in the field pulls. That is not a rollback, it is the outage this
  document exists to prevent.
- **Leave `products.stock` alone.** It is dead by design — derived on the device
  now, never written by a client. Its `default 0` is what lets inserts omit it,
  so removing the default breaks every product insert.
- **The `_legacy` tables can be dropped** once you are satisfied nothing needs
  them. Nothing in the app reads them.

---

Written against `supabase/schema.sql` as of the pull, stock-events and
first-restore work. Every query here is read-only apart from step 4, which
rolls itself back.
