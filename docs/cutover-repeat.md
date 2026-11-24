# Repeating the dump and restore at cutover (checklist 2.4, DIC-3122)

First copy: 2026-11-24 (2.1 to 2.3). This is the plan for checking, and if needed repeating, that copy just before consumers switch from `db-dice` to the new database.

## What to expect

Nobody normally writes to the parcel schemas on `db-dice`: the last change to `geo.parcel_geometry` was 2026-07-15, the yearly load is manual (around March), and `walter` is unused. So **the repeat is most likely a check that finds nothing to copy.** Only copy again if the check finds a difference.

## The one rule

**Point of no return: the first write to the new database** (a yearly load command, an API write, any edit). From then on the new database is the newer one, and a restore from `db-dice` would destroy that work. Never restore over a database that has had a write. Do the last check and any repeat **before** the first consumer switches (checklist 6.2 to 6.5), and do not run the yearly load against the new database until every consumer is on it. If the March load comes first, load into the new database only, and treat `db-dice` as stale from then on.

## 1. Open the database (about $0.07/hour while running)

In `tofu/cloud-sql`: `tofu apply -var public_ip_enabled=true -var activation_policy=ALWAYS`, then
`cloud-sql-proxy parcel-data-api:us-central1:parcel-data-api-pg --port 5433` and
`cloud-sql-proxy core-db-475718:us-central1:db-dice --port 5434` in the background.
Passwords stay in Secret Manager (`cloud-sql-postgres-password` in `parcel-data-api`, `DB_PASSWORD` in `core-db-475718`); pass them in-process (`PGPASSWORD="$(gcloud secrets versions access ...)"`).

## 2. Check for drift

1. **Write counters on `db-dice`** (cheap, no copy): `select schemaname, relname, n_tup_ins, n_tup_upd, n_tup_del from pg_stat_user_tables where schemaname in ('geo','assessing')` and compare with the baseline below. Any increase means something wrote. If `stats_reset` on `pg_stat_database` changed or the instance crashed, the counters are not comparable; use step 2.
2. **Content check** (the real proof): run `scripts/verify-parcel-copy.sql` on both databases and diff the outputs. Run `ANALYZE` on the new database first. **No differences = done; skip to step 6.**

Baseline taken 2026-11-24 from `db-dice` (`stats_reset` 2025-10-20, instance started 2026-08-28; `parcel_geometry` latest `updated_at` 2026-07-15, all rows `source='migration'`):

| table | ins | upd | del |
|---|---|---|---|
| assessing.cass_parcels | 36272 | 36266 | 0 |
| assessing.vbc_parcels | 94870 | 0 | 0 |
| geo.address_points | 61944 | 42318 | 0 |
| geo.drains | 1058 | 1058 | 0 |
| geo.parcel_geometry | 132465 | 50955 | 24 |
| geo.parcel_ledger_events | 12 | 0 | 12 |
| geo.parcel_points | 51321 | 51321 | 0 |
| geo.plss_corners | 4102 | 2902 | 0 |
| geo.plss_section_lines | 640 | 0 | 0 |
| geo.plss_sections | 640 | 640 | 0 |
| geo.reference_layers | 6723 | 0 | 0 |
| geo.road_centerlines | 19047 | 5576 | 0 |
| geo.section_centers | 640 | 640 | 0 |
| geo.subdivisions | 352 | 352 | 0 |

## 3. If there is a difference: first make sure nothing on the new side is newer

Look for writes on the new database (`pg_stat_user_tables` on the same tables, `max(updated_at)`). If the new side has writes you did not expect, **stop and decide with Maria** which side is right; do not restore.

## 4. Repeat the copy

Before touching anything, take an on-demand backup of the new instance: `gcloud sql backups create --instance parcel-data-api-pg --project parcel-data-api`, and note its id on the ticket.

Dump from `db-dice` exactly as in 2.1, as `postgres`, read-only:
`pg_dump -Fc -n geo -n assessing -T geo.locations -T geo.org_locations -T geo.parcels_backup -f <file>`
Keep this dump in R2 as a record: `s3://parcel-data-api-dumps/cutover/<date>/` (write credentials: Secret Manager `r2-dump-write-credentials`).

Then one of two cases, depending on whether Phase 3 has happened:

**A. Before Phase 3 (schemas still built by Sqitch): replace the schemas.** With Maria's go-ahead (this drops data on the new database):
1. `DROP SCHEMA geo CASCADE; DROP SCHEMA assessing CASCADE;` as `postgres` on the new instance.
2. `pg_restore -d <new> --no-owner --no-acl --exit-on-error -1 <file>` (took 12 seconds on 2026-11-24).
3. Grants: in `tofu/cloud-sql-grants` run `tofu plan` (it should show the grants as to be created, since the schemas were dropped; check that it does), show it, then `tofu apply`. This recreates them from code. Needs the proxy on 5433 and `PGPASSWORD` set.

**B. After Phase 3 (Django owns the schema, baseline marked applied): reload the data only.** The schema must still match (checklist 3.4 proves it). Not yet tried; **rehearse it once on the new database before relying on it** (no consumer is on it yet, so a rehearsal is safe), including these points:
1. Disable the trigger so loading does not write ledger events: `ALTER TABLE geo.parcel_geometry DISABLE TRIGGER parcel_geometry_before_write_trg;` (the owner can; no superuser needed).
2. `TRUNCATE` the 14 copied tables in one statement (the foreign key `parcel_ledger_events -> parcel_geometry` means they go together).
3. `pg_restore --data-only --no-owner --no-acl --exit-on-error -1`; this also resets the sequences.
4. Re-enable the trigger. Grants are untouched by this path.

## 5. Verify the repeat

`ANALYZE`, then step 2.2 again (`scripts/verify-parcel-copy.sql` on both, diff): no differences. Log in as `martin_ro` and `steward_app` and read a table (the grants are still working).

## 6. Close the database and record it

Close in two applies in `tofu/cloud-sql` (first `-var activation_policy=ALWAYS` with the IP off, then a plain `tofu apply`; Cloud SQL refuses IP changes while stopped), stop both proxies, check with `gcloud sql instances describe` and a clean `tofu plan -detailed-exitcode`. Comment the result, the backup id and the R2 path on DIC-3122 and in the checklist.

## Rollback

Until the point of no return the new database is a copy: consumers revert their URL setting to the old source (checklist, Verification, Phase 6) and nothing is lost. After a repeat that went wrong, restore the on-demand backup from step 4 (or repeat the copy).

## Time and cost

About 30 to 45 minutes with the database open (a restore is seconds; most of the time is the checks), roughly $0.05 to $0.10 in instance time.
