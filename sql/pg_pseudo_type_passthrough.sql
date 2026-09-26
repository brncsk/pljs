-- A value of a pseudo-type passes through Javascript as the datum it is.
-- pljs does not resolve the actual type of a polymorphic window function's
-- argument, and `anyelement` is declared 4 bytes wide and passed by value, so
-- only a type of that shape (int4, date) comes back intact; this is what the
-- conversion carried before a type without a case of its own went through its
-- I/O functions, and those functions do not exist for a pseudo-type.
CREATE FUNCTION pg_ptp_prev(arg anyelement) RETURNS anyelement AS $$
  const w = pljs.get_window_object();
  return w.get_func_arg_in_partition(0, -1, w.SEEK_CURRENT, false);
$$ LANGUAGE pljs WINDOW;
CREATE FUNCTION pg_ptp_prev_int(arg anyelement) RETURNS anyelement AS $$
  const w = pljs.get_window_object();
  return w.get_func_arg_in_partition(0, -1, w.SEEK_CURRENT, false);
$$ LANGUAGE pljs WINDOW;

CREATE TABLE pg_ptp (n int, d date);
INSERT INTO pg_ptp VALUES (1, '2026-01-01'), (2, '2026-02-01'), (3, '1999-12-31');

SELECT n, pg_ptp_prev(d) OVER w, lag(d) OVER w FROM pg_ptp WINDOW w AS (ORDER BY n) ORDER BY n;
SELECT n, pg_ptp_prev_int(n * 1000) OVER w, lag(n * 1000) OVER w FROM pg_ptp WINDOW w AS (ORDER BY n) ORDER BY n;

DROP TABLE pg_ptp;
DROP FUNCTION pg_ptp_prev(anyelement);
DROP FUNCTION pg_ptp_prev_int(anyelement);
