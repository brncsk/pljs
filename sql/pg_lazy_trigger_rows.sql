-- A trigger's NEW and OLD convert a column when the function first reads it.
-- What the function reads, writes, keeps and returns behaves as it did when
-- every column was converted before the call.
CREATE TABLE pg_ltr (id int, label text, doc jsonb, n numeric);
INSERT INTO pg_ltr VALUES (1, 'a', '{"x": 1, "y": [1, 2]}', 1.5);

-- A change inside a jsonb value stays: the value is converted once.
CREATE FUNCTION pg_ltr_nested() RETURNS trigger LANGUAGE pljs AS $$
  NEW.doc.x = NEW.doc.x + 1;
  NEW.doc.y.push(3);
  return NEW;
$$;
CREATE TRIGGER pg_ltr_t BEFORE UPDATE ON pg_ltr FOR EACH ROW EXECUTE FUNCTION pg_ltr_nested();
UPDATE pg_ltr SET label = 'b';
SELECT id, label, doc, n FROM pg_ltr;
DROP TRIGGER pg_ltr_t ON pg_ltr;

-- A column written, one deleted, and the rest as they were.
CREATE FUNCTION pg_ltr_write() RETURNS trigger LANGUAGE pljs AS $$
  NEW.label = NEW.label + '!';
  delete NEW.n;
  return NEW;
$$;
CREATE TRIGGER pg_ltr_t BEFORE UPDATE ON pg_ltr FOR EACH ROW EXECUTE FUNCTION pg_ltr_write();
UPDATE pg_ltr SET id = 2;
SELECT id, label, doc, n FROM pg_ltr;
DROP TRIGGER pg_ltr_t ON pg_ltr;

-- The row enumerates, spreads and prints every column, and has Object.prototype.
CREATE FUNCTION pg_ltr_shape() RETURNS trigger LANGUAGE pljs AS $$
  pljs.elog(NOTICE, Object.keys(NEW).join(','));
  pljs.elog(NOTICE, JSON.stringify(OLD));
  pljs.elog(NOTICE, NEW.hasOwnProperty('doc'), 'label' in NEW, typeof NEW.missing);
  return { ...NEW, label: 'spread' };
$$;
CREATE TRIGGER pg_ltr_t BEFORE UPDATE ON pg_ltr FOR EACH ROW EXECUTE FUNCTION pg_ltr_shape();
UPDATE pg_ltr SET n = 7;
SELECT id, label, doc, n FROM pg_ltr;
DROP TRIGGER pg_ltr_t ON pg_ltr;

-- Returning OLD keeps the old row.
CREATE FUNCTION pg_ltr_old() RETURNS trigger LANGUAGE pljs AS $$ return OLD; $$;
CREATE TRIGGER pg_ltr_t BEFORE UPDATE ON pg_ltr FOR EACH ROW EXECUTE FUNCTION pg_ltr_old();
UPDATE pg_ltr SET label = 'ignored', n = 0;
SELECT id, label, doc, n FROM pg_ltr;
DROP TRIGGER pg_ltr_t ON pg_ltr;

-- A row the function keeps reads the same after its call.
CREATE FUNCTION pg_ltr_keep() RETURNS trigger LANGUAGE pljs AS $$
  if (globalThis.kept === undefined) globalThis.kept = [];
  globalThis.kept.push(NEW);
  return NEW;
$$;
CREATE TRIGGER pg_ltr_t BEFORE UPDATE ON pg_ltr FOR EACH ROW EXECUTE FUNCTION pg_ltr_keep();
UPDATE pg_ltr SET label = 'kept';
DROP TRIGGER pg_ltr_t ON pg_ltr;
DO $$ const r = globalThis.kept[0]; pljs.elog(NOTICE, r.id, r.label, JSON.stringify(r.doc), r.n); $$ LANGUAGE pljs;

-- An AFTER trigger that returns NEW, and one that returns nothing, change nothing.
CREATE FUNCTION pg_ltr_after() RETURNS trigger LANGUAGE pljs AS $$ return NEW; $$;
CREATE TRIGGER pg_ltr_t AFTER UPDATE ON pg_ltr FOR EACH ROW EXECUTE FUNCTION pg_ltr_after();
UPDATE pg_ltr SET label = 'after';
SELECT id, label, doc, n FROM pg_ltr;
DROP TRIGGER pg_ltr_t ON pg_ltr;

-- An INSERT trigger that reads nothing returns the inserted row.
CREATE FUNCTION pg_ltr_pass() RETURNS trigger LANGUAGE pljs AS $$ return NEW; $$;
CREATE TRIGGER pg_ltr_t BEFORE INSERT ON pg_ltr FOR EACH ROW EXECUTE FUNCTION pg_ltr_pass();
INSERT INTO pg_ltr VALUES (3, 'c', '{"z": 0.30000000000000004}', 2.25);
SELECT id, label, doc, n FROM pg_ltr ORDER BY id;

DROP TABLE pg_ltr;
DROP FUNCTION pg_ltr_nested();
DROP FUNCTION pg_ltr_write();
DROP FUNCTION pg_ltr_shape();
DROP FUNCTION pg_ltr_old();
DROP FUNCTION pg_ltr_keep();
DROP FUNCTION pg_ltr_after();
DROP FUNCTION pg_ltr_pass();
