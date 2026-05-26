#!/usr/bin/env node
/**
 * convert-fig-specs.mjs — Fig spec → zsh assoc-array converter (production)
 *
 * Node ≥18 required. This script is regeneration-time only (not bundled into the app).
 * Pinned Fig autocomplete SHA: aef52acff84c45edde61ae610cc2c964802b9a38
 *
 * Usage:
 *   node convert-fig-specs.mjs --clone <src-dir> --out <out-dir> [--list <file>]
 *
 *   --clone <dir>  Path to the withfig/autocomplete/src directory (the .ts files live here)
 *   --out <dir>    Output directory; spec_<cmd>.zsh files are written here
 *   --list <file>  Command list file (default: spec-commands.txt in same dir as this script)
 *
 * Adapted from script/spec-highlight-spike/convert.mjs. Changes:
 *   (a) Reads command names from --list file, loops over them
 *   (b) Writes spec_<cmd>.zsh into --out directory
 *   (c) Per-spec failures log to stderr and continue (partial DB is valid)
 *   (+) Exports convertSpecFile(tsPath) for unit testing
 *
 * Key-naming conventions for zsh variable names:
 *   - Command name sanitized: replace [^A-Za-z0-9] with _
 *   - Nested variable suffix also sanitized the same way
 *   - SUB values: 1 = has nested SUB/OPT data; 0 = leaf
 *   - OPT values: 1 = takes an arg; 0 = flag only
 */

import { createRequire } from 'module';
import { writeFileSync, mkdirSync, existsSync, readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import path from 'path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
// Load esbuild from this script's own node_modules
const esbuild = require(path.join(__dirname, 'node_modules', 'esbuild'));

// ---- Helpers -----------------------------------------------------------------

/** Sanitize a string to a valid zsh variable-name fragment */
function sanitize(s) {
  return s.replace(/[^A-Za-z0-9]/g, '_');
}

/** Normalize a subcommand/option name field to an array of strings */
function nameArray(name) {
  return Array.isArray(name) ? name : [name];
}

/** Returns true if the option has an args property (takes an argument) */
function optTakesArg(opt) {
  return opt.args !== undefined && opt.args !== null;
}

// ---- Transpile + load spec ---------------------------------------------------

/**
 * Build the given TS file in-process with esbuild.
 * Uses a virtual-module plugin to stub out @fig/* and @withfig/* imports.
 * Returns the spec's default export.
 */
async function loadSpecFromPath(tsPath) {
  if (!existsSync(tsPath)) {
    throw new Error(`Spec file not found: ${tsPath}`);
  }

  // Virtual stub plugin: intercepts @fig/* and @withfig/* imports
  // (covers @fig/autocomplete-generators, @fig/autocomplete-helpers, @withfig/*)
  // plus the external `strip-json-comments` dep used by deno's generators.
  const stubPlugin = {
    name: 'fig-stub',
    setup(build) {
      build.onResolve({ filter: /^(?:@(?:fig|withfig)\/|strip-json-comments$)/ }, (args) => ({
        path: args.path,
        namespace: 'fig-stub',
      }));
      build.onLoad({ filter: /.*/, namespace: 'fig-stub' }, () => ({
        // Catch-all module: a Proxy default so ANY unknown named import resolves
        // to a noop, plus explicit named exports for the helpers actually used.
        // These are only invoked inside generator/runtime function bodies, never
        // during static spec construction, so noops are safe.
        //
        // NOTE: createVersionedSpec is NOT relied upon to produce real specs.
        // Versioned (directory) specs are resolved by resolveSpecPath() to their
        // concrete <cmd>/<latest>.ts entry, which has a plain `export default`.
        // We keep a harmless stub here only as defense-in-depth.
        contents: `
          const noop = () => ({});
          export default new Proxy({}, { get: () => noop });
          export const ai = noop, filepaths = noop, keyValue = noop, keyValueList = noop,
            valueList = noop, executeShellCommand = noop, getSuggestions = noop;
          export const createVersionedSpec = () => ({});
        `,
        loader: 'js',
      }));
    },
  };

  // Bundle to a single ESM string (in-memory, no file write)
  const result = await esbuild.build({
    entryPoints: [tsPath],
    bundle: true,
    write: false,
    format: 'esm',
    platform: 'node',
    target: 'node20',
    plugins: [stubPlugin],
    logLevel: 'silent',
  });

  if (result.errors && result.errors.length > 0) {
    throw new Error(`esbuild errors: ${JSON.stringify(result.errors)}`);
  }

  const code = result.outputFiles[0].text;

  // Import the bundled code via a data: URL (no temp files needed)
  const dataUrl = `data:text/javascript;base64,${Buffer.from(code).toString('base64')}`;
  const mod = await import(dataUrl);
  const spec = mod.default;

  if (!spec || typeof spec !== 'object') {
    throw new Error(`Spec has no valid default export`);
  }

  return spec;
}

// ---- Walker ------------------------------------------------------------------

/**
 * Recursively walk a Fig spec node and emit zsh assoc-array declarations.
 *
 * @param node      - the spec/subcommand object
 * @param varPrefix - the variable name prefix, e.g. "TS_GIT" or "TS_GIT_commit"
 * @param lines     - output lines array (mutated)
 * @param depth     - recursion guard (max 10)
 */
function walkNode(node, varPrefix, lines, depth = 0) {
  if (depth > 10) return;

  const subEntries = [];
  const optEntries = [];

  // --- Walk subcommands ---
  if (Array.isArray(node.subcommands)) {
    for (const sub of node.subcommands) {
      if (!sub || !sub.name) continue;

      const aliases = nameArray(sub.name);
      const canonicalName = aliases[0];

      const hasChildren =
        (Array.isArray(sub.subcommands) && sub.subcommands.length > 0) ||
        (Array.isArray(sub.options) && sub.options.length > 0);

      for (const alias of aliases) {
        subEntries.push(`[${JSON.stringify(alias)}]=${hasChildren ? 1 : 0}`);
      }

      if (hasChildren) {
        const childPrefix = `${varPrefix}_${sanitize(canonicalName)}`;
        walkNode(sub, childPrefix, lines, depth + 1);
      }
    }
  }

  // --- Walk options ---
  if (Array.isArray(node.options)) {
    for (const opt of node.options) {
      if (!opt || !opt.name) continue;

      const aliases = nameArray(opt.name);
      const takes = optTakesArg(opt) ? 1 : 0;

      for (const alias of aliases) {
        optEntries.push(`[${JSON.stringify(alias)}]=${takes}`);
      }
    }
  }

  // Emit the arrays (only if non-empty)
  if (subEntries.length > 0) {
    lines.push(`typeset -gA ${varPrefix}_SUB=( ${subEntries.join(' ')} )`);
  }
  if (optEntries.length > 0) {
    lines.push(`typeset -gA ${varPrefix}_OPT=( ${optEntries.join(' ')} )`);
  }

  // Top-level positional args (informational — just record presence)
  if (Array.isArray(node.args) && node.args.length > 0) {
    const argNames = node.args
      .map((a) => (a && a.name ? sanitize(a.name) : 'arg'))
      .join(' ');
    lines.push(`# ${varPrefix} positional args: ${argNames}`);
  } else if (node.args && typeof node.args === 'object' && node.args.name) {
    lines.push(`# ${varPrefix} positional args: ${sanitize(node.args.name)}`);
  }
}

// ---- Core: convert a spec object to zsh text --------------------------------

/**
 * Convert a loaded Fig spec to zsh assoc-array text.
 * @param spec    - the spec's default export (plain object)
 * @param cmdName - the command name to use for variable prefixes
 * @returns zsh source text
 */
function convertSpec(spec, cmdName) {
  const varPrefix = `TS_${sanitize(cmdName).toUpperCase()}`;
  const lines = [
    `# Termy spec-highlight: zsh assoc arrays for command "${cmdName}"`,
    `# Auto-generated from Fig spec — do not edit by hand`,
    `# Variable naming: ${varPrefix}_SUB / ${varPrefix}_OPT / nested ${varPrefix}_<sub>_SUB etc.`,
    `# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag`,
    '',
  ];

  walkNode(spec, varPrefix, lines, 0);
  lines.push(''); // trailing newline
  return lines.join('\n');
}

// ---- Public API (used by tests) ---------------------------------------------

/**
 * Load a Fig spec TypeScript file and return the emitted zsh text.
 * cmdName is derived from the spec's `name` field (first alias if array).
 *
 * @param tsPath - absolute path to the .ts spec file
 * @returns zsh source text
 */
export async function convertSpecFile(tsPath) {
  const spec = await loadSpecFromPath(tsPath);
  // Derive cmdName from spec.name (first alias), not from filename
  const rawName = Array.isArray(spec.name) ? spec.name[0] : spec.name;
  if (!rawName || typeof rawName !== 'string') {
    throw new Error(`Spec at "${tsPath}" has no valid name field`);
  }
  return convertSpec(spec, rawName);
}

// ---- Parse command list file ------------------------------------------------

/**
 * Read a command list file: one command per line, # comments, blank lines ignored.
 * @param listPath - path to the file
 * @returns array of command name strings
 */
function readCommandList(listPath) {
  const text = readFileSync(listPath, 'utf8');
  return text
    .split('\n')
    .map((line) => line.replace(/#.*$/, '').trim())
    .filter((line) => line.length > 0);
}

// ---- Spec entry resolution --------------------------------------------------

/**
 * Resolve the .ts entry file for a command, handling two upstream layouts:
 *   1. flat:        <clone>/<cmd>.ts
 *   2. versioned:   <clone>/<cmd>/index.ts  (calls createVersionedSpec at runtime)
 *
 * For the versioned layout we bypass index.ts (which does FS dynamic-import
 * dispatch we can't replicate synchronously) and load the LATEST concrete
 * version subspec directly — e.g. az/2.53.0.ts, heroku/8.6.0.ts — which carry
 * a plain `export default <Fig.Spec>`.
 *
 * @param cloneDir - the autocomplete/src directory
 * @param cmd      - command name
 * @returns absolute path to the .ts entry file
 * @throws if no entry can be found
 */
function resolveSpecPath(cloneDir, cmd) {
  const direct = path.join(cloneDir, `${cmd}.ts`);
  if (existsSync(direct)) return direct;

  const indexPath = path.join(cloneDir, cmd, 'index.ts');
  if (existsSync(indexPath)) {
    const src = readFileSync(indexPath, 'utf8');
    const m = src.match(/versionFiles\s*=\s*\[\s*((?:"[^"]+"\s*,?\s*)+)\]/);
    if (m) {
      const versions = [...m[1].matchAll(/"([^"]+)"/g)].map((x) => x[1]);
      const latest = versions[versions.length - 1];
      if (latest) {
        const versioned = path.join(cloneDir, cmd, `${latest}.ts`);
        if (existsSync(versioned)) return versioned;
      }
    }
  }

  throw new Error(`Spec entry not found for: ${cmd}`);
}

// ---- CLI main ---------------------------------------------------------------

async function main() {
  const args = process.argv.slice(2);

  // Parse --clone, --out, --list flags
  let cloneDir = null;
  let outDir = null;
  let listFile = path.join(__dirname, 'spec-commands.txt');

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--clone' && args[i + 1]) {
      cloneDir = args[++i];
    } else if (args[i] === '--out' && args[i + 1]) {
      outDir = args[++i];
    } else if (args[i] === '--list' && args[i + 1]) {
      listFile = args[++i];
    }
  }

  if (!cloneDir || !outDir) {
    console.error('Usage: node convert-fig-specs.mjs --clone <src-dir> --out <out-dir> [--list <file>]');
    process.exit(1);
  }

  if (!existsSync(listFile)) {
    console.error(`[convert] ERROR: list file not found: ${listFile}`);
    process.exit(1);
  }

  mkdirSync(outDir, { recursive: true });

  const commands = readCommandList(listFile);
  console.log(`[convert] Processing ${commands.length} commands from ${listFile}`);

  let converted = 0;
  const skipped = [];

  for (const cmd of commands) {
    try {
      const tsPath = resolveSpecPath(cloneDir, cmd);
      const spec = await loadSpecFromPath(tsPath);
      // Use the CLI command name (not spec.name) for the zsh variable prefix
      // so spec_git.zsh always has TS_GIT_* regardless of what spec.name says
      const zshText = convertSpec(spec, cmd);
      const outPath = path.join(outDir, `spec_${cmd}.zsh`);
      writeFileSync(outPath, zshText);
      console.log(`[convert] OK  ${cmd} (${zshText.length} bytes)`);
      converted++;
    } catch (err) {
      console.error(`[convert] SKIP ${cmd}: ${err.message}`);
      skipped.push(cmd);
    }
  }

  console.log(`\n[convert] Done: ${converted} converted, ${skipped.length} skipped`);
  if (skipped.length > 0) {
    console.log(`[convert] Skipped: ${skipped.join(', ')}`);
  }
}

// Only run main() when invoked as a script (not when imported as a module)
if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  main().catch((err) => {
    console.error(`[convert] Unhandled error: ${err.message}`);
    process.exit(1);
  });
}
