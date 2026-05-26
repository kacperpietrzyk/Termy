#!/usr/bin/env node
/**
 * convert.mjs — Fig spec → zsh assoc-array converter
 * Task 2 of the spec-highlight-spike.
 *
 * Usage: node convert.mjs <cmd>
 *   e.g. node convert.mjs git
 *
 * Reads src/<cmd>.ts from the pinned autocomplete clone, transpiles it
 * in-process via esbuild (no subprocess needed), then walks the static
 * spec tree and writes out/spec_<cmd>.zsh.
 *
 * Key-naming conventions for zsh variable names:
 *   - Command name sanitized: replace [^A-Za-z0-9] with _
 *   - Nested variable suffix also sanitized the same way
 *   - SUB values: 1 = has nested SUB/OPT data; 0 = leaf
 *   - OPT values: 1 = takes an arg; 0 = flag only
 */

import { createRequire } from 'module';
import { writeFileSync, mkdirSync, existsSync } from 'fs';
import { fileURLToPath } from 'url';
import path from 'path';

// Load esbuild from the spike's local node_modules
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const esbuild = require(path.join(__dirname, 'node_modules', 'esbuild'));

// ---- Config ------------------------------------------------------------------

const SPIKE_DIR = __dirname;
const AUTOCOMPLETE_DIR = path.join(SPIKE_DIR, 'autocomplete', 'src');
const OUT_DIR = path.join(SPIKE_DIR, 'out');

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
 * Uses a virtual-module plugin to stub out @fig/* and @withfig/* imports
 * so they don't fail at bundle time.
 * Returns the spec's default export.
 */
async function loadSpec(cmdName) {
  const tsPath = path.join(AUTOCOMPLETE_DIR, `${cmdName}.ts`);

  if (!existsSync(tsPath)) {
    throw new Error(`Spec file not found: ${tsPath}`);
  }

  // Virtual stub plugin: intercepts @fig/* and @withfig/* imports.
  // Exports a no-op for any named import (the spec may use), plus a default.
  const stubPlugin = {
    name: 'fig-stub',
    setup(build) {
      build.onResolve({ filter: /^@(?:fig|withfig)\// }, (args) => ({
        path: args.path,
        namespace: 'fig-stub',
      }));
      build.onLoad({ filter: /.*/, namespace: 'fig-stub' }, () => ({
        // Return an ES module that exports a Proxy as default and common
        // named exports as no-ops. Any named import not listed here would
        // cause a runtime undefined (not a build error) since we export
        // the namespace — but for safety we enumerate the known names.
        contents: `
          const noop = () => ({});
          export const ai = noop;
          export const filepaths = noop;
          export const keyValue = noop;
          export const valueList = noop;
          export const executeShellCommand = noop;
          export default {};
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
    // Suppress warnings about the stub's unused exports
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
    throw new Error(`Spec for "${cmdName}" has no valid default export`);
  }

  return spec;
}

// ---- Walker ------------------------------------------------------------------

/**
 * Recursively walk a Fig spec node (spec or subcommand) and emit
 * zsh assoc-array declarations into the lines array.
 *
 * @param node      - the spec/subcommand object
 * @param varPrefix - the variable name prefix, e.g. "TS_GIT" or "TS_GIT_commit"
 * @param lines     - output lines array (mutated)
 * @param depth     - recursion guard (max 10)
 */
function walkNode(node, varPrefix, lines, depth = 0) {
  if (depth > 10) return; // guard against pathological nesting

  const subEntries = [];   // for the SUB assoc array
  const optEntries = [];   // for the OPT assoc array

  // --- Walk subcommands ---
  if (Array.isArray(node.subcommands)) {
    for (const sub of node.subcommands) {
      if (!sub || !sub.name) continue;

      // Every alias gets a key in the parent's SUB array
      const aliases = nameArray(sub.name);
      const canonicalName = aliases[0]; // first alias = canonical for nested vars

      // Does this subcommand have child data we'll emit?
      const hasChildren =
        (Array.isArray(sub.subcommands) && sub.subcommands.length > 0) ||
        (Array.isArray(sub.options) && sub.options.length > 0);

      for (const alias of aliases) {
        subEntries.push(`[${JSON.stringify(alias)}]=${hasChildren ? 1 : 0}`);
      }

      // Recurse: emit nested SUB/OPT arrays for this subcommand
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

  // Emit the arrays (only if non-empty — keeps output lean)
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

// ---- Main -------------------------------------------------------------------

async function main() {
  const cmdName = process.argv[2];
  if (!cmdName) {
    console.error('Usage: node convert.mjs <cmd>');
    process.exit(1);
  }

  mkdirSync(OUT_DIR, { recursive: true });

  let spec;
  try {
    spec = await loadSpec(cmdName);
  } catch (err) {
    console.error(`[convert] ERROR loading spec for "${cmdName}": ${err.message}`);
    process.exitCode = 1;
    return;
  }

  const varPrefix = `TS_${sanitize(cmdName).toUpperCase()}`;
  const lines = [
    `# spec-highlight-spike: zsh assoc arrays for command "${cmdName}"`,
    `# Auto-generated from Fig spec — do not edit by hand`,
    `# Variable naming: ${varPrefix}_SUB / ${varPrefix}_OPT / nested ${varPrefix}_<sub>_SUB etc.`,
    `# SUB values: 1=has child data, 0=leaf  |  OPT values: 1=takes-arg, 0=flag`,
    '',
  ];

  walkNode(spec, varPrefix, lines, 0);

  lines.push(''); // trailing newline

  const outPath = path.join(OUT_DIR, `spec_${cmdName}.zsh`);
  writeFileSync(outPath, lines.join('\n'));
  console.log(`[convert] Wrote ${outPath} (${lines.join('\n').length} bytes)`);
}

main().catch((err) => {
  console.error(`[convert] Unhandled error: ${err.message}`);
  process.exit(1);
});
