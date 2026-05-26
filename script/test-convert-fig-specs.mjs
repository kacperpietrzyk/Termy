// test-convert-fig-specs.mjs — self-test for convert-fig-specs.mjs
// Regex notes:
//   - Spike emits quoted-key form via JSON.stringify: ["-m"]=1, ["--amend"]=0, etc.
//   - SUB assertions use \b word-boundary which matches at "rm" inside `["rm"]`.
//   - OPT assertions explicitly include quotes to match the spike-consistent emit format.
import assert from "node:assert/strict";
import { convertSpecFile } from "./convert-fig-specs.mjs";

const z = await convertSpecFile(new URL("./fixtures/sample-spec.ts", import.meta.url).pathname);

// subcommands + aliases: both "rm" and "remove" present, plus "remote"
assert.match(z, /TS_SAMPLE_SUB=\([^)]*\brm\b[^)]*\bremove\b[^)]*\bremote\b/, "subcommands + alias");

// nested subcommand "remote add" emitted
assert.match(z, /TS_SAMPLE_remote_SUB=\([^)]*\badd\b/, "nested subcommand");

// OPT entries use quoted-key form: ["-m"]=1, ["--message"]=1, ["--amend"]=0, ["-C"]=1
assert.match(z, /TS_SAMPLE_OPT=\([^)]*\["-m"\]=1[^)]*\["--message"\]=1[^)]*\["--amend"\]=0[^)]*\["-C"\]=1/, "alias+takes-arg");

// generators and descriptions must not appear in output
assert.doesNotMatch(z, /filepaths|generator|description/i, "generators+descriptions dropped");

console.log("convert self-test: PASS");
