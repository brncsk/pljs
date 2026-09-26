-- pljs.subtransaction_aborts() counts the subtransactions the backend rolled
-- back: a savepoint rolled back, a statement that failed inside one, and a
-- pljs.execute() whose error the function caught. A released savepoint does
-- not count.
CREATE FUNCTION pg_sta() RETURNS float8 LANGUAGE pljs AS $$ return pljs.subtransaction_aborts(); $$;
CREATE TEMP TABLE pg_sta_base AS SELECT pg_sta() AS n;
BEGIN;
SAVEPOINT a;
RELEASE SAVEPOINT a;
SELECT pg_sta() - n AS after_a_release FROM pg_sta_base;
SAVEPOINT b;
ROLLBACK TO SAVEPOINT b;
SELECT pg_sta() - n AS after_a_rollback FROM pg_sta_base;
SAVEPOINT c;
SELECT 1 / 0;
ROLLBACK TO SAVEPOINT c;
SELECT pg_sta() - n AS after_a_failed_statement FROM pg_sta_base;
COMMIT;
DO $$
  const before = pljs.subtransaction_aborts();
  try { pljs.execute('SELECT 1 / 0'); } catch (e) {}
  pljs.elog(NOTICE, 'after a caught error:', pljs.subtransaction_aborts() - before);
$$ LANGUAGE pljs;
DROP FUNCTION pg_sta();
