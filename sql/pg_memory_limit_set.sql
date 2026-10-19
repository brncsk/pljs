-- Regression: SET pljs.memory_limit at runtime must re-apply the cap to the
-- live QuickJS runtime.
--
-- pljs.memory_limit was only consulted in _PG_init when the runtime was first
-- created, so a plain SET after pljs had been used updated the GUC but not the
-- interpreter -- you could not tighten (or loosen) the JS heap cap of a running
-- backend.  An assign hook now re-applies JS_SetMemoryLimit() on every change.
CREATE EXTENSION IF NOT EXISTS pljs;

-- Set the cap *before* the first pljs execution so the runtime is created at
-- 300MB regardless of any cluster-wide default; this makes the runtime SETs
-- below unambiguous.
SET pljs.memory_limit = 300;

-- QuickJS-ng raises "out of memory" as an InternalError, which JavaScript
-- cannot catch, so the error reaches SQL.  The call that fails uses terse
-- verbosity: the stack trace in DETAIL is not part of what this test checks.
CREATE FUNCTION alloc_mb(mb int) RETURNS text LANGUAGE pljs AS $$
  var a = new ArrayBuffer(mb * 1024 * 1024); return "ok:" + a.byteLength;
$$;

-- 200MB fits under the 300MB load-time cap.
SELECT alloc_mb(200) AS at_300_cap;

-- Lowering the cap at runtime must now bite: 200MB no longer fits under 64MB.
-- (Before the fix the runtime stayed at 300MB and this returned "ok".)
SET pljs.memory_limit = 64;
\set VERBOSITY terse
SELECT alloc_mb(200) AS at_64_cap;
\set VERBOSITY default

-- Raising the cap at runtime lets the same allocation succeed again.
SET pljs.memory_limit = 512;
SELECT alloc_mb(200) AS at_512_cap;

RESET pljs.memory_limit;
DROP FUNCTION alloc_mb(int);
