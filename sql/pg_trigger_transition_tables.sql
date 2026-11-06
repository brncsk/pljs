-- A trigger must be able to read its transition tables.
--
-- A trigger that declares REFERENCING NEW TABLE AS ... / OLD TABLE AS ... gets
-- the rows of the statement as two tables, under the names it gives them.  The
-- language handler has to register them with SPI (SPI_register_trigger_data),
-- as PL/pgSQL does; call_trigger() never did, so every query that named one
-- failed with "relation does not exist".  A statement-level trigger reads the
-- rows of the whole statement in one query this way, instead of one call per
-- row.
CREATE EXTENSION IF NOT EXISTS pljs;

CREATE TABLE tt_t (id int PRIMARY KEY, v int);
CREATE TABLE tt_log (what text, n int, total int);

-- An insert: the new rows, read with pljs.execute().
CREATE FUNCTION tt_inserted() RETURNS trigger LANGUAGE pljs AS $$
  const [r] = pljs.execute("SELECT count(*)::int AS n, sum(v)::int AS total FROM new_rows");
  pljs.execute("INSERT INTO tt_log VALUES ('insert', $1, $2)", [r.n, r.total]);
  return null;
$$;
CREATE TRIGGER tt_insert AFTER INSERT ON tt_t
  REFERENCING NEW TABLE AS new_rows
  FOR EACH STATEMENT EXECUTE FUNCTION tt_inserted();
INSERT INTO tt_t VALUES (1, 10), (2, 20), (3, 30);

-- An update: both tables, joined, through a prepared plan.
CREATE FUNCTION tt_updated() RETURNS trigger LANGUAGE pljs AS $$
  const plan = pljs.prepare(
    "SELECT count(*)::int AS n, sum(n.v - o.v)::int AS total FROM new_rows n JOIN old_rows o USING (id) WHERE n.v <> o.v"
  );
  const [r] = plan.execute();
  plan.free();
  pljs.execute("INSERT INTO tt_log VALUES ('update', $1, $2)", [r.n, r.total]);
  return null;
$$;
CREATE TRIGGER tt_update AFTER UPDATE ON tt_t
  REFERENCING NEW TABLE AS new_rows OLD TABLE AS old_rows
  FOR EACH STATEMENT EXECUTE FUNCTION tt_updated();
UPDATE tt_t SET v = v + 1 WHERE id <= 2;

-- A delete: the old rows.
CREATE FUNCTION tt_deleted() RETURNS trigger LANGUAGE pljs AS $$
  const [r] = pljs.execute("SELECT count(*)::int AS n, sum(v)::int AS total FROM old_rows");
  pljs.execute("INSERT INTO tt_log VALUES ('delete', $1, $2)", [r.n, r.total]);
  return null;
$$;
CREATE TRIGGER tt_delete AFTER DELETE ON tt_t
  REFERENCING OLD TABLE AS old_rows
  FOR EACH STATEMENT EXECUTE FUNCTION tt_deleted();
DELETE FROM tt_t WHERE id = 3;

-- A statement that touches no row still fires the trigger, over empty tables.
UPDATE tt_t SET v = v WHERE id = 99;

SELECT what, n, total FROM tt_log ORDER BY what, n DESC;

DROP TABLE tt_t;
DROP TABLE tt_log;
DROP FUNCTION tt_inserted();
DROP FUNCTION tt_updated();
DROP FUNCTION tt_deleted();
