-- A Javascript number becomes numeric through its shortest round-trip text,
-- as Javascript prints it, not through 15 significant digits.
CREATE FUNCTION pg_nst_echo(j jsonb) RETURNS jsonb LANGUAGE pljs AS $$ return j; $$;
SELECT pg_nst_echo('{"sum": 0.30000000000000004, "big": 9007199254740992, "long": 1.2345678901234567, "int": 120, "neg": -0.5, "exp": 1e21}');

CREATE FUNCTION pg_nst_numeric() RETURNS numeric LANGUAGE pljs AS $$ return 0.1 + 0.2; $$;
SELECT pg_nst_numeric();

CREATE FUNCTION pg_nst_computed() RETURNS jsonb LANGUAGE pljs AS $$ return { sum: 0.1 + 0.2, big: 2 ** 53 + 2, third: 1 / 3 }; $$;
SELECT pg_nst_computed();

-- A trigger that returns NEW leaves the numbers of a jsonb column it did not change as they were.
CREATE TABLE pg_nst_rows (id int, label text, doc jsonb);
CREATE FUNCTION pg_nst_pass() RETURNS trigger LANGUAGE pljs AS $$ return NEW; $$;
CREATE TRIGGER pg_nst_pass BEFORE UPDATE ON pg_nst_rows FOR EACH ROW EXECUTE FUNCTION pg_nst_pass();
INSERT INTO pg_nst_rows VALUES (1, 'a', '{"angle": 12.345678901234567, "area": 101.12345678901234}');
UPDATE pg_nst_rows SET label = 'b';
SELECT label, doc FROM pg_nst_rows;

DROP TABLE pg_nst_rows;
DROP FUNCTION pg_nst_pass();
DROP FUNCTION pg_nst_echo(jsonb);
DROP FUNCTION pg_nst_numeric();
DROP FUNCTION pg_nst_computed();
