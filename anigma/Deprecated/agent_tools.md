# Agent Toolset Reference

The following sections document every custom tool under `.opencode/tool` plus the enforcement plugin so agents understand what each helper does, what receipts it emits, and what `nextTool` guidance it returns. All code below is verbatim.

---

## `_ledger.ts`
**Summary:** Shared receipt, hashing, and ordering helpers that every governance tool uses to append/read JSONL receipts.
```ts
import { createHash } from "node:crypto";
import { mkdirSync, appendFileSync, readFileSync, existsSync } from "node:fs";
import { dirname } from "node:path";

export type ToolMeta = { agent: string; sessionID: string; messageID: string };
export type ReceiptKind =
  | "inspection"
  | "generation"
  | "proposal"
  | "validation"
  | "apply_attempt"
  | "apply_result"
  | "quarantine"
  | "rollback"
  | "diagnosis";

export type Receipt = {
  kind: ReceiptKind;
  ts: string;
  meta: ToolMeta;
  patchHash?: string;
  headSHA?: string;
  touched?: string[];
  ok?: boolean;
  detail?: any;
};

export function sha256(text: string) {
  return createHash("sha256").update(text, "utf8").digest("hex");
}

export function appendReceipt(path: string, rec: Receipt) {
  mkdirSync(dirname(path), { recursive: true });
  appendFileSync(path, JSON.stringify(rec) + "\n", "utf8");
}

export function readReceipts(path: string): Receipt[] {
  if (!existsSync(path)) return [];
  const raw = readFileSync(path, "utf8").trim();
  if (!raw) return [];
  const out: Receipt[] = [];
  for (const line of raw.split("\n")) {
    try {
      out.push(JSON.parse(line));
    } catch {
      // ignore corrupted lines; you can make this fatal if you prefer
    }
  }
  return out;
}

export function isoNow() {
  return new Date().toISOString();
}

export function requireInOrder(receipts: Receipt[], kinds: ReceiptKind[]) {
  const idx: number[] = [];
  for (const k of kinds) {
    const i = receipts.findIndex((r) => r.kind === k);
    if (i < 0) throw new Error(`Missing required receipt: ${k}`);
    idx.push(i);
  }
  for (let i = 1; i < idx.length; i++) {
    if (idx[i] <= idx[i - 1]) throw new Error(`Receipt order violated: ${kinds[i - 1]} must precede ${kinds[i]}`);
  }
}
```

## `anigma.ts`
**Summary:** Governance gate wrappers (Swift6, type authority, dependency, escape hatch, macro, and combined ci_all checks) that return structured JSON for agents.
```ts
import { tool } from "@opencode-ai/plugin";

type RunResult = { ok: boolean; stdout: string; stderr: string; code?: number };

async function run(cmd: string): Promise<RunResult> {
  // Use node:child_process with proper working directory
  const { execSync } = require('child_process');
  
  try {
    const stdout = execSync(cmd, { 
      encoding: 'utf8', 
      cwd: '/Users/user/Developer/GitHub/Anigma',
      timeout: 120000,
      maxBuffer: 1024 * 1024 * 10 // 10MB buffer
    });
    return { ok: true, stdout, stderr: '', code: 0 };
  } catch (error: any) {
    return { 
      ok: false, 
      stdout: error.stdout || '', 
      stderr: error.stderr || error.message, 
      code: error.status || error.code || 1 
    };
  }
}

function json(result: unknown) {
  return JSON.stringify(result, null, 2);
}

/**
 * Strict Swift 6 compliance gate.
 * Calls your existing script(s) and returns structured output.
 */
export const swift6_check = tool({
  description: "Run Swift 6 compliance gates (strict concurrency, @preconcurrency rules, tests parity) and return JSON output.",
  args: {
    target: tool.schema.string().optional().describe("Optional SwiftPM target name to scope the check.")
  },
  async execute(args, context) {
    const meta = { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID };
    const cmd = args.target
      ? `./Scripts/verify_swift6_compliance.sh --target ${args.target}`
      : `./Scripts/verify_swift6_compliance.sh`;

    const r = await run(cmd);
    return json({ tool: "swift6_check", meta, ...r });
  }
});

/**
 * Type authority gate (your map-driven checker).
 */
export const type_authority_check = tool({
  description: "Validate type authority boundaries using Docs/governance/type-authority-map.json and fail on shadow authorities.",
  args: {},
  async execute(_, context) {
    const meta = { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID };
    const r = await run(`./Scripts/verify_type_authority.sh`);
    return json({ tool: "type_authority_check", meta, ...r });
  }
});

/**
 * Dependency boundary gate (core vs capability, forbidden imports, version-range sanity).
 */
export const deps_check = tool({
  description: "Validate dependency boundaries (Core insulated from Capability churn) and fail on forbidden imports/version conflicts.",
  args: {},
  async execute(_, context) {
    const meta = { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID };
    const r = await run(`./Scripts/verify_dependency_boundaries.sh`);
    return json({ tool: "deps_check", meta, ...r });
  }
});

/**
 * Escape hatch audit gate (expiry + approvals).
 */
export const escape_hatches_check = tool({
  description: "Fail if any escape hatch is missing approval metadata or is past expiry; emits ledger-ready JSON.",
  args: {
    db: tool.schema.string().default("harmonia_harness.sqlite").describe("Path to the harness DB storing escape hatch records.")
  },
  async execute(args, context) {
    const meta = { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID };
    const r = await run(`swift ./Scripts/escape-hatch-expiry.swift ${args.db} check`);
    return json({ tool: "escape_hatches_check", meta, ...r });
  }
});

/**
 * Macro expansion gate (post-expansion inspection).
 */
export const macro_expansion_check = tool({
  description: "Run macro expansion analysis and fail if expanded output contains forbidden constructs.",
  args: {},
  async execute(_, context) {
    const meta = { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID };
    const r = await run(`swift ./Scripts/macro-expansion-checker.swift Sources/`);
    return json({ tool: "macro_expansion_check", meta, ...r });
  }
});

/**
 * Drift report, non-blocking by design (you decide whether to fail builds on it).
 */
export const mainactor_drift_report = tool({
  description: "Generate MainActor drift report (trend analysis) for governance review; returns JSON report.",
  args: {
    db: tool.schema.string().default("harmonia_harness.sqlite").describe("Path to DB storing drift metrics over time.")
  },
  async execute(args, context) {
    const meta = { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID };
    const r = await run(`swift ./Scripts/mainactor-drift-tracker.swift ${args.db} report`);
    return json({ tool: "mainactor_drift_report", meta, ...r });
  }
});

/**
 * The “one button” leash: runs everything, returns a single structured blob.
 */
export const ci_all = tool({
  description: "Run all governance gates (Swift6, type authority, deps, escape hatches, macro expansion) and return a single JSON summary.",
  args: {},
  async execute(_, context) {
    const meta = { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID };

    const steps = {
      swift6: await run(`./Scripts/verify_swift6_compliance.sh`),
      typeAuthority: await run(`./Scripts/verify_type_authority.sh`),
      deps: await run(`./Scripts/verify_dependency_boundaries.sh`),
      escapeHatches: await run(`swift ./Scripts/escape-hatch-expiry.swift harmonia_harness.sqlite check`),
      macroExpansion: await run(`swift ./Scripts/macro-expansion-checker.swift Sources/`)
    };

    const ok = Object.values(steps).every(s => s.ok);
    return json({ tool: "ci_all", meta, ok, steps });
  }
});
```

## `apply_patch.ts`
**Summary:** Applies only a validated normalized patchHash after verifying the inspection→generation→proposal→validation receipts, re-checking base hashes, and enforcing allow/deny path rules.
```ts
import { tool } from "@opencode-ai/plugin";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { appendReceipt, isoNow, readReceipts, requireInOrder, sha256 } from "./_ledger";
import {
  ALLOW_PATH_PREFIXES,
  DENY_PATH_PREFIXES,
  extractTouched,
  verifyBaseHashes,
  validateTouchedPaths,
} from "./_patch_utils";

const execFileAsync = promisify(execFile);

type ExecResult = { ok: boolean; code: number; stdout: string; stderr: string };

async function run(cmd: string, argv: string[], cwd: string) {
  try {
    const { stdout, stderr } = await execFileAsync(cmd, argv, { cwd, maxBuffer: 20 * 1024 * 1024 });
    return { ok: true, code: 0, stdout: stdout ?? "", stderr: stderr ?? "" };
  } catch (e: any) {
    return {
      ok: false,
      code: typeof e?.code === "number" ? e.code : 1,
      stdout: e?.stdout?.toString?.() ?? "",
      stderr: e?.stderr?.toString?.() ?? e?.message ?? String(e),
    };
  }
}

export default tool({
  description: "Apply a validated patch artifact (only the normalized patchHash accepted) after inspection→generation→proposal→validation receipts succeed.",
  args: {
    patchHash: tool.schema.string().min(16),
    dryRun: tool.schema.boolean().default(false),
    ledgerPath: tool.schema.string().default(".opencode/ledger/workflow.jsonl"),
  },
  async execute(args, context) {
    const cwd = process.cwd();
    const meta = { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID };

    const attempt = {
      kind: "apply_attempt" as const,
      ts: isoNow(),
      meta,
      patchHash: args.patchHash,
      ok: false,
      detail: { dryRun: args.dryRun },
    };
    appendReceipt(args.ledgerPath, attempt);

    const patchPath = resolve(cwd, `.opencode/generated/${args.patchHash}.diff`);
    if (!existsSync(patchPath)) throw new Error(`Unknown patchHash; run generate_patch first: ${args.patchHash}`);

    const patch = readFileSync(patchPath, "utf8");
    const actual = sha256(patch);
    if (actual !== args.patchHash) throw new Error("Patch hash mismatch (generated file corrupted or tampered).");

    const all = readReceipts(args.ledgerPath);
    const scoped = all.filter(
      (r) => r.meta?.sessionID === context.sessionID && r.patchHash === args.patchHash
    );

    requireInOrder(scoped, ["inspection", "generation", "proposal", "validation"]);

    const validation = scoped.filter((r) => r.kind === "validation").slice(-1)[0];
    if (!validation?.ok) throw new Error("Latest validation receipt is not ok. Run validate_patch until it is green.");

    const baseHashes = validation.detail?.baseHashes ?? {};
    if (Object.keys(baseHashes).length) {
      verifyBaseHashes(cwd, baseHashes);
    }

    const touched = extractTouched(patch);
    if (!touched.length) throw new Error("Patch touches zero files (unexpected).");
    validateTouchedPaths(touched, { allowPrefixes: ALLOW_PATH_PREFIXES, denyPrefixes: DENY_PATH_PREFIXES });

    const check = await run("git", ["apply", "--check", "--whitespace=nowarn", patchPath], cwd);
    if (!check.ok) throw new Error(`git apply --check failed at apply-time:\n${check.stderr || check.stdout}`);

    if (args.dryRun) {
      const rec = {
        kind: "apply_result" as const,
        ts: isoNow(),
        meta,
        patchHash: args.patchHash,
        ok: true,
        detail: {
          dryRun: true,
          check,
          touched,
          baseHashes,
        },
      };
      appendReceipt(args.ledgerPath, rec);
      return JSON.stringify(rec, null, 2);
    }

    const apply = await run("git", ["apply", "--whitespace=nowarn", patchPath], cwd);
    const ok = apply.ok;

    const rec = {
      kind: ok ? "apply_result" as const : ("apply_result" as const),
      ts: isoNow(),
      meta,
      patchHash: args.patchHash,
      ok,
      detail: {
        check,
        apply,
        touched,
        baseHashes,
      },
    };

    appendReceipt(args.ledgerPath, rec);
    if (!ok) throw new Error(`git apply failed:\n${apply.stderr || apply.stdout}`);
    return JSON.stringify(rec, null, 2);
  },
});
```

## `binary_build_preflight.ts`
**Summary:** Dry-run a SwiftPM release build to prove the artifact will succeed before requesting a stable binary.
```ts
import { tool } from "@opencode-ai/plugin";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { dirname, resolve } from "node:path";
import { mkdirSync, writeFileSync } from "node:fs";

const execFileAsync = promisify(execFile);

async function run(cmd: string, argv: string[], cwd: string) {
  try {
    const r = await execFileAsync(cmd, argv, { cwd, maxBuffer: 80 * 1024 * 1024 });
    return { ok: true, stdout: r.stdout?.toString?.() ?? "", stderr: r.stderr?.toString?.() ?? "" };
  } catch (e: any) {
    return {
      ok: false,
      stdout: e?.stdout?.toString?.() ?? "",
      stderr: e?.stderr?.toString?.() ?? e?.message ?? String(e),
    };
  }
}

function tail(text: string, maxChars: number) {
  return text.length <= maxChars ? text : text.slice(text.length - maxChars);
}

export default tool({
  description: "Dry-run the release build for a product to confirm a future artifact build will succeed.",
  args: {
    product: tool.schema.string().min(1).describe("SwiftPM product to verify."),
    strictConcurrency: tool.schema.boolean().default(true),
    extraSwiftcFlags: tool.schema.array(tool.schema.string()).default([]),
    logDir: tool.schema.string().default(".opencode/logs"),
    maxReturnChars: tool.schema.number().int().positive().default(2000),
  },
  async execute(args, context) {
    const cwd = process.cwd();
    const logDir = resolve(cwd, args.logDir);
    mkdirSync(logDir, { recursive: true });

    const buildArgv: string[] = ["build", "-c", "release", "--product", args.product];
    if (args.strictConcurrency) buildArgv.push("-Xswiftc", "-strict-concurrency=complete");
    for (const flag of args.extraSwiftcFlags) buildArgv.push("-Xswiftc", flag);

    const build = await run("swift", buildArgv, cwd);
    const combined = (build.stdout + "\n" + build.stderr).trim();
    const logName = `binary-preflight-${args.product}-${Date.now()}.log`;
    const logPath = resolve(logDir, logName);
    writeFileSync(logPath, combined + "\n", "utf8");

    return JSON.stringify(
      {
        tool: "binary_build_preflight",
        product: args.product,
        ok: build.ok,
        code: build.ok ? 0 : 1,
        logPath: `${args.logDir}/${logName}`,
        outputTail: tail(combined, args.maxReturnChars),
        meta: { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID },
        ts: new Date().toISOString(),
      },
      null,
      2
    );
  },
});
```

## `build_binary.ts`
**Summary:** Performs a release SwiftPM build, copies the artifact to Artifacts/bin, optionally codesigns it, and records SHA256 metadata.
```ts
import { tool } from "@opencode-ai/plugin";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdirSync, copyFileSync, statSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const execFileAsync = promisify(execFile);

async function run(cmd: string, argv: string[], cwd: string) {
  try {
    const r = await execFileAsync(cmd, argv, { cwd, maxBuffer: 80 * 1024 * 1024 });
    return { ok: true, code: 0, stdout: r.stdout?.toString?.() ?? "", stderr: r.stderr?.toString?.() ?? "" };
  } catch (e: any) {
    return {
      ok: false,
      code: typeof e?.code === "number" ? e.code : 1,
      stdout: e?.stdout?.toString?.() ?? "",
      stderr: e?.stderr?.toString?.() ?? e?.message ?? String(e),
    };
  }
}

function mustExistFile(path: string) {
  const st = statSync(path, { throwIfNoEntry: false } as any);
  if (!st || !st.isFile()) throw new Error(`Expected file not found: ${path}`);
}

export default tool({
  description: "Build a release product, export a stable artifact, compute SHA256, optionally ad-hoc codesign.",
  args: {
    product: tool.schema.string().min(1).describe("SwiftPM product name to build."),
    clean: tool.schema.boolean().default(true),
    resolveDeps: tool.schema.boolean().default(true),
    strictConcurrency: tool.schema.boolean().default(true),
    outputDir: tool.schema.string().default("Artifacts/bin"),
    codesignAdhoc: tool.schema.boolean().default(false),
    extraSwiftcFlags: tool.schema.array(tool.schema.string()).default([])
  },
  async execute(args, context) {
    const cwd = process.cwd();

    const head = await run("git", ["rev-parse", "HEAD"], cwd);
    if (!head.ok) throw new Error(`git rev-parse failed: ${head.stderr || head.stdout}`);
    const sha = head.stdout.trim().slice(0, 12);

    if (args.resolveDeps) {
      const r = await run("swift", ["package", "resolve"], cwd);
      if (!r.ok) throw new Error(`swift package resolve failed:\n${r.stderr || r.stdout}`);
    }

    if (args.clean) {
      const r = await run("swift", ["package", "clean"], cwd);
      if (!r.ok) throw new Error(`swift package clean failed:\n${r.stderr || r.stdout}`);
    }

    const buildArgv: string[] = ["build", "-c", "release", "--product", args.product];
    if (args.strictConcurrency) buildArgv.push("-Xswiftc", "-strict-concurrency=complete");
    for (const f of args.extraSwiftcFlags) buildArgv.push("-Xswiftc", f);

    const build = await run("swift", buildArgv, cwd);
    if (!build.ok) throw new Error(`swift build failed:\n${build.stderr || build.stdout}`);

    const builtPath = resolve(cwd, ".build", "release", args.product);
    mustExistFile(builtPath);

    const outDirAbs = resolve(cwd, args.outputDir);
    mkdirSync(outDirAbs, { recursive: true });
    const outBinName = `${args.product}-${sha}`;
    const outBinPath = resolve(outDirAbs, outBinName);

    copyFileSync(builtPath, outBinPath);

    let codesign: any = null;
    if (args.codesignAdhoc) {
      codesign = await run("codesign", ["--force", "--sign", "-", outBinPath], cwd);
      if (!codesign.ok) throw new Error(`codesign failed:\n${codesign.stderr || codesign.stdout}`);
    }

    const shasum = await run("shasum", ["-a", "256", outBinPath], cwd);
    if (!shasum.ok) throw new Error(`shasum failed:\n${shasum.stderr || shasum.stdout}`);

    const sumLine = shasum.stdout.trim();
    const sumPath = resolve(outDirAbs, `${outBinName}.sha256`);
    writeFileSync(sumPath, sumLine + "\n", "utf8");

    return JSON.stringify(
      {
        tool: "build_binary",
        ok: true,
        product: args.product,
        gitSHA: sha,
        builtPath: `.build/release/${args.product}`,
        artifactPath: `${args.outputDir}/${outBinName}`,
        sha256Path: `${args.outputDir}/${outBinName}.sha256`,
        sha256: sumLine.split(/\s+/)[0] ?? null,
        codesign,
        meta: { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID },
        ts: new Date().toISOString()
      },
      null,
      2
    );
  }
});
```

## `commit_changes.ts`
**Summary:** Integrator-only commit helper that ensures clean state, forbidden paths untouched, gates green, and receipts exist before committing.
```ts
import { tool } from "@opencode-ai/plugin";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

async function run(cmd: string, argv: string[], cwd: string) {
  try {
    const r = await execFileAsync(cmd, argv, { cwd, maxBuffer: 80 * 1024 * 1024 });
    return { ok: true, code: 0, stdout: r.stdout?.toString?.() ?? "", stderr: r.stderr?.toString?.() ?? "" };
  } catch (e: any) {
    return {
      ok: false,
      code: typeof e?.code === "number" ? e.code : 1,
      stdout: e?.stdout?.toString?.() ?? "",
      stderr: e?.stderr?.toString?.() ?? e?.message ?? String(e),
    };
  }
}

function forbiddenTouched(statusPorcelain: string, denyPrefixes: string[]) {
  const lines = statusPorcelain.split("\n").map((l) => l.trim()).filter(Boolean);
  const paths = lines.map((l) => l.slice(3)).filter(Boolean);
  const bad = paths.filter((p) => denyPrefixes.some((d) => p === d || p.startsWith(d.endsWith("/") ? d : d + "/")));
  return { bad, paths };
}

export default tool({
  description: "Stage + commit changes only if gates are green and forbidden paths are untouched.",
  args: {
    message: tool.schema.string().min(10).describe("Commit message."),
    gatesCommand: tool.schema.string().default("./Scripts/ci_all"),
    requireGreenGates: tool.schema.boolean().default(true),
    allowEmpty: tool.schema.boolean().default(false),
  },
  async execute(args, context) {
    const cwd = process.cwd();

    const status = await run("git", ["status", "--porcelain=v1"], cwd);
    if (!status.ok) throw new Error(`git status failed:\n${status.stderr || status.stdout}`);

    const denyPrefixes = [".opencode/", "Docs/governance/"];
    const { bad, paths } = forbiddenTouched(status.stdout, denyPrefixes);
    if (bad.length) throw new Error(`Refusing commit: forbidden paths modified:\n${bad.join("\n")}`);

    if (!paths.length && !args.allowEmpty) throw new Error("No changes to commit.");

    if (args.requireGreenGates) {
      const gates = await run("bash", ["-lc", args.gatesCommand], cwd);
      if (!gates.ok) throw new Error(`Gates failed, refusing commit:\n${gates.stderr || gates.stdout}`);
    }

    const add = await run("git", ["add", "-A", "--", "."], cwd);
    if (!add.ok) throw new Error(`git add failed:\n${add.stderr || add.stdout}`);

    const commit = await run("git", ["commit", "-m", args.message], cwd);
    if (!commit.ok) throw new Error(`git commit failed:\n${commit.stderr || commit.stdout}`);

    const head = await run("git", ["rev-parse", "HEAD"], cwd);

    return JSON.stringify(
      {
        tool: "commit_changes",
        ok: true,
        head: head.ok ? head.stdout.trim() : null,
        message: args.message,
        meta: { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID },
        ts: new Date().toISOString()
      },
      null,
      2
    );
  }
});
```

## `docs_patch.ts`
**Summary:** Regenerates docs in a detached worktree, captures the diff, stores it as a generated patch, and emits a generation receipt.
```ts
import { tool } from "@opencode-ai/plugin";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { createHash } from "node:crypto";
import { appendReceipt, isoNow, sha256 } from "./_ledger";

const execFileAsync = promisify(execFile);

async function run(cmd: string, argv: string[], cwd: string) {
  try {
    const r = await execFileAsync(cmd, argv, { cwd, maxBuffer: 120 * 1024 * 1024 });
    return { ok: true, code: 0, stdout: r.stdout?.toString?.() ?? "", stderr: r.stderr?.toString?.() ?? "" };
  } catch (e: any) {
    return {
      ok: false,
      code: typeof e?.code === "number" ? e.code : 1,
      stdout: e?.stdout?.toString?.() ?? "",
      stderr: e?.stderr?.toString?.() ?? e?.message ?? String(e),
    };
  }
}

function shortHash(s: string) {
  return createHash("sha256").update(s, "utf8").digest("hex").slice(0, 12);
}

function ensureDiffLooksReal(patch: string) {
  return patch.includes("\n--- ") && patch.includes("\n+++ ") && patch.includes("\n@@");
}

export default tool({
  description: "Run docs regeneration in a temporary git worktree and emit a unified diff patch + generation receipt (no direct mutation).",
  args: {
    docsCommand: tool.schema.string().default("./Scripts/docs_sync.sh"),
    ledgerPath: tool.schema.string().default(".opencode/ledger/workflow.jsonl"),
  },
  async execute(args, context) {
    const cwd = process.cwd();
    const meta = { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID };

    const head = await run("git", ["rev-parse", "HEAD"], cwd);
    if (!head.ok) throw new Error(`git rev-parse failed: ${head.stderr || head.stdout}`);
    const headSHA = head.stdout.trim();

    const wtName = `docs-wt-${shortHash(headSHA + context.sessionID)}`;
    const wtPath = resolve(cwd, ".opencode", ".tmp", wtName);
    mkdirSync(dirname(wtPath), { recursive: true });

    const addWT = await run("git", ["worktree", "add", "--detach", wtPath, headSHA], cwd);
    if (!addWT.ok) throw new Error(`git worktree add failed:\n${addWT.stderr || addWT.stdout}`);

    try {
      const docs = await run("bash", ["-lc", args.docsCommand], wtPath);
      if (!docs.ok) throw new Error(`Docs command failed:\n${docs.stderr || docs.stdout}`);

      const diff = await run("git", ["diff"], wtPath);
      const patchText = diff.stdout;

      if (!patchText.trim()) {
        const rec = {
          kind: "generation" as const,
          ts: isoNow(),
          meta,
          patchHash: null,
          ok: true,
          detail: { docsCommand: args.docsCommand, note: "No doc changes produced." },
        };
        appendReceipt(args.ledgerPath, rec);
        return JSON.stringify(rec, null, 2);
      }

      if (!ensureDiffLooksReal(patchText)) throw new Error("Docs diff did not look like a unified diff.");

      const patchHash = sha256(patchText);
      const outPath = resolve(cwd, ".opencode", "generated", `${patchHash}.diff`);
      mkdirSync(dirname(outPath), { recursive: true });
      writeFileSync(outPath, patchText, "utf8");

      const rec = {
        kind: "generation" as const,
        ts: isoNow(),
        meta,
        patchHash,
        ok: true,
        detail: { docsCommand: args.docsCommand, storedAt: `.opencode/generated/${patchHash}.diff` },
      };
      appendReceipt(args.ledgerPath, rec);

      return JSON.stringify(
        {
          ...rec,
          patchPreviewBytes: Buffer.byteLength(patchText, "utf8"),
        },
        null,
        2
      );
    } finally {
      await run("git", ["worktree", "remove", "--force", wtPath], cwd);
    }
  },
});
```

## `embeddings.ts`
**Summary:** Simple wrappers for embed/embedMany that return embedding vectors plus metadata.
```ts
import { tool } from "@opencode-ai/plugin";
import { embed, embedMany } from "ai";

export const single = tool({
  description: "Generate an embedding for a single string and return JSON.",
  args: {
    model: tool.schema.string().default("openai/text-embedding-3-small"),
    value: tool.schema.string(),
  },
  async execute(args, context) {
    const { embedding } = await embed({ model: args.model, value: args.value });
    return JSON.stringify(
      {
        tool: "embeddings_single",
        ok: true,
        model: args.model,
        dims: embedding.length,
        embedding,
        meta: { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID },
        ts: new Date().toISOString(),
      },
      null,
      2
    );
  },
});

export const many = tool({
  description: "Generate embeddings for many strings and return JSON (AI SDK auto-chunks if needed).",
  args: {
    model: tool.schema.string().default("openai/text-embedding-3-small"),
    values: tool.schema.array(tool.schema.string()).min(1),
  },
  async execute(args, context) {
    const { embeddings } = await embedMany({ model: args.model, values: args.values });
    return JSON.stringify(
      {
        tool: "embeddings_many",
        ok: true,
        model: args.model,
        count: embeddings.length,
        dims: embeddings[0]?.length ?? 0,
        embeddings,
        meta: { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID },
        ts: new Date().toISOString(),
      },
      null,
      2
    );
  },
});
```

## `format_suggest.ts`
**Summary:** Formats files in a temp workspace, diffs against originals, and returns a suggestion patch without mutating the repo.
```ts
import { tool } from "@opencode-ai/plugin";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { cpSync, mkdirSync, rmSync, statSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { tmpdir } from "node:os";
import { randomUUID } from "node:crypto";

const execFileAsync = promisify(execFile);

async function run(cmd: string, args: string[], cwd: string) {
  try {
    const { stdout, stderr } = await execFileAsync(cmd, args, { cwd, maxBuffer: 20 * 1024 * 1024 });
    return { ok: true, code: 0, stdout: stdout ?? "", stderr: stderr ?? "" };
  } catch (e: any) {
    return {
      ok: false,
      code: typeof e?.code === "number" ? e.code : 1,
      stdout: e?.stdout?.toString?.() ?? "",
      stderr: e?.stderr?.toString?.() ?? e?.message ?? String(e),
    };
  }
}

function assertFilesExist(paths: string[]) {
  for (const p of paths) {
    const st = statSync(p, { throwIfNoEntry: false } as any);
    if (!st) throw new Error(`Path not found: ${p}`);
    if (st.isDirectory()) throw new Error(`Expected file, got directory: ${p}`);
  }
}

export default tool({
  description: "Generate a formatting patch (no mutation). Formats in a temp dir and returns a unified diff to apply via apply_patch.",
  args: {
    files: tool.schema.array(tool.schema.string()).min(1).describe("Files to format (relative paths)."),
    formatter: tool.schema.enum(["swift-format", "swiftformat", "auto"]).default("auto"),
    maxDiffChars: tool.schema.number().int().positive().default(120_000),
  },
  async execute(args, context) {
    const cwd = process.cwd();
    const meta = { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID };

    assertFilesExist(args.files);

    const work = resolve(tmpdir(), `opencode-format-${randomUUID()}`);
    const orig = resolve(work, "orig");
    const fmt = resolve(work, "fmt");
    mkdirSync(dirname(orig), { recursive: true });
    mkdirSync(dirname(fmt), { recursive: true });
    mkdirSync(orig, { recursive: true });
    mkdirSync(fmt, { recursive: true });

    try {
      for (const f of args.files) {
        const src = resolve(cwd, f);
        const dst1 = resolve(orig, f);
        const dst2 = resolve(fmt, f);
        mkdirSync(dirname(dst1), { recursive: true });
        mkdirSync(dirname(dst2), { recursive: true });
        cpSync(src, dst1);
        cpSync(src, dst2);
      }

      let formatter = args.formatter;
      if (formatter === "auto") {
        const a = await run("swift-format", ["--version"], cwd);
        formatter = a.ok ? "swift-format" : "swiftformat";
      }

      if (formatter === "swift-format") {
        for (const f of args.files) {
          const p = resolve(fmt, f);
          const r = await run("swift-format", ["format", "--in-place", p], cwd);
          if (!r.ok) throw new Error(`swift-format failed for ${f}: ${r.stderr}`);
        }
      } else {
        for (const f of args.files) {
          const p = resolve(fmt, f);
          const r = await run("swiftformat", [p], cwd);
          if (!r.ok) throw new Error(`swiftformat failed for ${f}: ${r.stderr}`);
        }
      }

      const diff = await run("git", ["diff", "--no-index", "--", orig, fmt], cwd);
      const out = diff.stdout.length > args.maxDiffChars ? diff.stdout.slice(0, args.maxDiffChars) + "\n\n[truncated]\n" : diff.stdout;

      const hasPatch = out.includes("\n--- ") && out.includes("\n+++ ") && out.includes("\n@@");
      return JSON.stringify(
        {
          tool: "format_suggest",
          ok: diff.ok || hasPatch, // git diff --no-index returns 1 when differences exist
          formatter,
          files: args.files,
          patch: out,
          meta,
          ts: new Date().toISOString(),
        },
        null,
      );
    } finally {
      rmSync(work, { recursive: true, force: true });
    }
  },
});
```

## `gates.ts`
**Summary:** Runs governance scripts (ci_all or sub-suites) and returns structured JSON instead of raw shell output.
```ts
import { tool } from "@opencode-ai/plugin";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

type ExecResult = { ok: boolean; code: number; stdout: string; stderr: string };

async function run(cmd: string, args: string[], cwd: string): Promise<ExecResult> {
  try {
    const { stdout, stderr } = await execFileAsync(cmd, args, { cwd, maxBuffer: 20 * 1024 * 1024 });
    return { ok: true, code: 0, stdout: stdout ?? "", stderr: stderr ?? "" };
  } catch (e: any) {
    return {
      ok: false,
      code: typeof e?.code === "number" ? e.code : 1,
      stdout: e?.stdout?.toString?.() ?? "",
      stderr: e?.stderr?.toString?.() ?? e?.message ?? String(e),
    };
  }
}

export default tool({
  description: "Run governance gates (your scripts) and return structured JSON. No freeform shell.",
  args: {
    suite: tool.schema
      .enum(["all", "swift6", "typeAuthority", "deps", "macroExpansion", "escapeHatches"])
      .default("all"),
    target: tool.schema.string().optional().describe("Optional SwiftPM target for swift6 suite (if your script supports it)."),
  },
  async execute(args, context) {
    const cwd = process.cwd();
    const meta = { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID };

    const commands: Record<string, { cmd: string; argv: string[] }> = {
      all: { cmd: "bash", argv: ["-lc", "./Scripts/ci_all"] },
      swift6: { cmd: "bash", argv: ["-lc", args.target ? `./Scripts/verify_swift6_compliance.sh --target ${args.target}` : "./Scripts/verify_swift6_compliance.sh"] },
      typeAuthority: { cmd: "bash", argv: ["-lc", "./Scripts/verify_type_authority.sh"] },
      deps: { cmd: "bash", argv: ["-lc", "./Scripts/verify_dependency_boundaries.sh"] },
      macroExpansion: { cmd: "bash", argv: ["-lc", "swift ./Scripts/macro-expansion-checker.swift Sources/"] },
      escapeHatches: { cmd: "bash", argv: ["-lc", "swift ./Scripts/escape-hatch-expiry.swift harmonia_harness.sqlite check"] },
    };

    const spec = commands[args.suite];
    const r = await run(spec.cmd, spec.argv, cwd);

    return JSON.stringify(
      {
        tool: "gates",
        suite: args.suite,
        ok: r.ok,
        code: r.code,
        stdout: r.stdout,
        stderr: r.stderr,
        meta,
        ts: new Date().toISOString(),
      },
      null,
      2
    );
  },
});
```

## `generate_patch.ts`
**Summary:** Normalizes a unified diff, stores it as a generated patch, emits a generation receipt, and points agents to propose_patch next.
```ts
import { tool } from "@opencode-ai/plugin";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { appendReceipt, isoNow, sha256 } from "./_ledger";
import {
  ensureUnifiedDiffLooksReal,
  normalizeUnifiedDiff,
  NORMALIZATION_HINTS,
  extractTouched,
} from "./_patch_utils";

export default tool({
  description: "Store a unified diff patch without mutating repo; emits a generation receipt.",
  args: {
    patch: tool.schema.string().describe("Unified diff to store."),
    purpose: tool.schema.string().min(5).describe("What this patch is intended to do."),
    receiptPath: tool.schema.string().default(".opencode/ledger/workflow.jsonl"),
  },
  async execute(args, context) {
    const meta = { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID };
    const normalizedPatch = normalizeUnifiedDiff(args.patch);
    try {
      ensureUnifiedDiffLooksReal(normalizedPatch);
    } catch (err: any) {
      const failure = {
        tool: "generate_patch",
        ok: false,
        nextTool: "generate_patch",
        error: err?.message ?? "Normalized patch did not look like a unified diff.",
        hints: NORMALIZATION_HINTS,
        normalizedPreview: normalizedPatch.slice(0, 1200),
        meta,
        ts: isoNow(),
      };
      return JSON.stringify(failure, null, 2);
    }

    const patchHash = sha256(normalizedPatch);
    const touched = extractTouched(normalizedPatch);

    const outPath = resolve(process.cwd(), `.opencode/generated/${patchHash}.diff`);
    mkdirSync(dirname(outPath), { recursive: true });
    writeFileSync(outPath, normalizedPatch, "utf8");

    const rec = {
      kind: "generation" as const,
      ts: isoNow(),
      meta,
      patchHash,
      touched,
      ok: true,
      detail: {
        purpose: args.purpose,
        storedAt: `.opencode/generated/${patchHash}.diff`,
        diffHash: patchHash,
        normalizedDiff: normalizedPatch,
      },
    };

    appendReceipt(args.receiptPath, rec);
    return JSON.stringify(
      {
        ...rec,
        nextTool: "propose_patch",
        detail: { ...rec.detail, patchPreviewBytes: Buffer.byteLength(normalizedPatch, "utf8") },
      },
      null,
      2
    );
  },
});
```

## `diagnose_patch_failure.ts`
**Summary:** Reads validation receipts and the stored patchHash to explain why validation/apply failed and to point the agent to the right next tool.
```ts
import { tool } from "@opencode-ai/plugin";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { appendReceipt, isoNow, readReceipts, sha256 } from "./_ledger";
import {
  ensureUnifiedDiffLooksReal,
  normalizeUnifiedDiff,
  NORMALIZATION_HINTS,
  extractTouched,
  gatherBasePaths,
  computeBaseHashes,
  validateTouchedPaths,
  readGeneratedPatch,
  ALLOW_PATH_PREFIXES,
  DENY_PATH_PREFIXES,
} from "./_patch_utils";

const execFileAsync = promisify(execFile);
async function run(cmd: string, args: string[], cwd: string) {
  try {
    const { stdout, stderr } = await execFileAsync(cmd, args, { cwd, maxBuffer: 20 * 1024 * 1024 });
    return { ok: true, code: 0, stdout: stdout ?? "", stderr: stderr ?? "" };
  } catch (e: any) {
    return {
      ok: false,
      code: typeof e?.code === "number" ? e.code : 1,
      stdout: e?.stdout?.toString?.() ?? "",
      stderr: e?.stderr?.toString?.() ?? e?.message ?? String(e),
    };
  }
}

type DiagnosisReason =
  | "missing_patch_file"
  | "missing_receipts"
  | "missing_validation"
  | "validation_failed"
  | "patch_hash_mismatch"
  | "malformed_diff"
  | "forbidden_path"
  | "stale_base"
  | "git_apply_check_failed"
  | null;

const NEXT_TOOL_MAP: Record<Exclude<DiagnosisReason, null>, string> = {
  missing_patch_file: "generate_patch",
  missing_receipts: "inspect_repo",
  missing_validation: "validate_patch",
  validation_failed: "validate_patch",
  patch_hash_mismatch: "generate_patch",
  malformed_diff: "generate_patch",
  forbidden_path: "generate_patch",
  stale_base: "inspect_repo",
  git_apply_check_failed: "inspect_repo",
};

export default tool({
  description: "Diagnose why a patch failed validation or apply and point the agent back to the correct tool.",
  args: {
    patchHash: tool.schema.string().min(16).optional(),
    patch: tool.schema.string().optional(),
    receiptPath: tool.schema.string().default(".opencode/ledger/workflow.jsonl"),
  },
  async execute(args, context) {
    const cwd = process.cwd();
    const meta = { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID };
    let patchHash = args.patchHash ?? null;
    let patch: string | null = null;
    let patchPath: string | null = patchHash ? resolve(cwd, `.opencode/generated/${patchHash}.diff`) : null;

    if (patchHash) {
      try {
        patch = readGeneratedPatch(cwd, patchHash);
      } catch (e: any) {
        const reason: DiagnosisReason = "missing_patch_file";
        const detail = {
          reason,
          note: e?.message,
        };
        const rec = { kind: "diagnosis" as const, ts: isoNow(), meta, patchHash, ok: false, detail };
        appendReceipt(args.receiptPath, rec);
        return JSON.stringify({ ...rec, nextTool: NEXT_TOOL_MAP[reason], explanation: e?.message }, null, 2);
      }
    }

    if (!patch && args.patch) {
      patch = normalizeUnifiedDiff(args.patch);
      patchHash = sha256(patch);
      patchPath = null;
    }

    if (!patch || !patchHash) {
      throw new Error("diagnose_patch_failure requires either patchHash or patch text.");
    }

    if (!patchPath) {
      patchPath = resolve(cwd, `.opencode/.tmp/diagnose-${patchHash}.diff`);
      mkdirSync(dirname(patchPath), { recursive: true });
      writeFileSync(patchPath, patch, "utf8");
    }

    const receipts = readReceipts(args.receiptPath);
    const scoped = receipts.filter((r) => r.patchHash === patchHash);

    let reason: DiagnosisReason = null;
    let explanation = "";

    if (!scoped.length) {
      reason = "missing_receipts";
      explanation = "No receipts found for this patch hash. Start over with inspect_repo → generate_patch.";
    }

    const validation = scoped.filter((r) => r.kind === "validation").slice(-1)[0];
    if (!reason && !validation) {
      reason = "missing_validation";
      explanation = "Validation never ran (or the receipt is missing).";
    }
    if (!reason && validation && !validation.ok) {
      reason = "validation_failed";
      explanation = "Validation receipt exists but reported failure; inspect the validation output/gates.";
    }

    const actualHash = sha256(patch);
    if (!reason && patchHash && actualHash !== patchHash) {
      reason = "patch_hash_mismatch";
      explanation = "The normalized patch hash no longer matches the stored hash; regenerate the patch.";
    }

    if (!reason) {
      try {
        ensureUnifiedDiffLooksReal(patch);
      } catch (err: any) {
        reason = "malformed_diff";
        explanation = err?.message ?? "Diff headers look malformed.";
      }
    }

    if (!reason) {
      try {
        const touched = extractTouched(patch);
        if (!touched.length) throw new Error("Patch touches zero files.");
        validateTouchedPaths(touched, { allowPrefixes: ALLOW_PATH_PREFIXES, denyPrefixes: DENY_PATH_PREFIXES });
      } catch (err: any) {
        reason = "forbidden_path";
        explanation = err?.message ?? "Touched path is not allowed.";
      }
    }

    if (!reason) {
      const basePaths = gatherBasePaths(patch);
      if (validation?.detail?.baseHashes) {
        const compute = computeBaseHashes(basePaths, cwd);
        for (const [path, expected] of Object.entries(validation.detail.baseHashes ?? {})) {
          if (!compute[path] || compute[path] !== expected) {
            reason = "stale_base";
            explanation = `Base file ${path} changed since validation.`;
            break;
          }
        }
      }
    }

    if (!reason) {
      const check = await run("git", ["apply", "--check", "--whitespace=nowarn", patchPath!], cwd);
      if (!check.ok) {
        reason = "git_apply_check_failed";
        explanation = check.stderr || check.stdout || "git apply --check failed.";
      }
    }

    const detail = {
      reason,
      explanation,
      receipts: scoped.map((r) => r.kind),
      normalizedPreview: patch.slice(0, 1200),
      nextSteps: reason === "stale_base" || reason === "git_apply_check_failed"
        ? ["inspect_repo", "generate_patch"]
        : reason === "missing_receipts"
          ? ["inspect_repo"]
          : [],
    };

    const rec = {
      kind: "diagnosis" as const,
      ts: isoNow(),
      meta,
      patchHash,
      ok: reason === null,
      detail,
    };
    appendReceipt(args.receiptPath, rec);

    const response: any = { ...rec };
    if (reason) {
      response.ok = false;
      response.nextTool = NEXT_TOOL_MAP[reason];
      response.hints = NORMALIZATION_HINTS;
    }

    return JSON.stringify(response, null, 2);
  },
});
```

## `inspect_repo.ts`
**Summary:** Records file hashes for the files you will patch and emits the inspection receipt that starts the chain.
```ts
import { tool } from "@opencode-ai/plugin";
import { readFileSync, statSync } from "node:fs";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { appendReceipt, isoNow, sha256 } from "./_ledger";

const execFileAsync = promisify(execFile);

async function gitHead(cwd: string) {
  const { stdout } = await execFileAsync("git", ["rev-parse", "HEAD"], { cwd });
  return (stdout ?? "").trim();
}

function assertFile(p: string) {
  const st = statSync(p, { throwIfNoEntry: false } as any);
  if (!st) throw new Error(`Not found: ${p}`);
  if (!st.isFile()) throw new Error(`Not a file: ${p}`);
}

export default tool({
  description: "Inspect files (real read + hash) and emit an inspection receipt. This is mandatory before patch apply.",
  args: {
    files: tool.schema.array(tool.schema.string()).min(1).describe("Repo-relative file paths to inspect."),
    receiptPath: tool.schema.string().default(".opencode/ledger/workflow.jsonl"),
  },
  async execute(args, context) {
    const cwd = process.cwd();
    const headSHA = await gitHead(cwd);

    const inspected = args.files.map((f) => f.trim()).filter(Boolean);
    const fileHashes: Record<string, string> = {};

    for (const f of inspected) {
      assertFile(f);
      const content = readFileSync(f, "utf8");
      fileHashes[f] = sha256(content);
    }

    const rec = {
      kind: "inspection" as const,
      ts: isoNow(),
      meta: { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID },
      headSHA,
      ok: true,
      detail: { inspected, fileHashes },
    };

    appendReceipt(args.receiptPath, rec);
    return JSON.stringify(rec, null, 2);
  },
});
```

## `inspiration_patterns.ts`
**Summary:** Indexes Inspiration/, writes the pattern registry + backlog in docs, and emits the resulting diff as a patch.
```ts
import { tool } from "@opencode-ai/plugin";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import {
  mkdirSync,
  writeFileSync,
  readFileSync,
  existsSync,
  readdirSync,
  statSync,
} from "node:fs";
import { dirname, resolve, relative } from "node:path";
import { createHash } from "node:crypto";

const execFileAsync = promisify(execFile);

async function run(cmd: string, argv: string[], cwd: string) {
  try {
    const r = await execFileAsync(cmd, argv, { cwd, maxBuffer: 160 * 1024 * 1024 });
    return { ok: true, code: 0, stdout: r.stdout?.toString?.() ?? "", stderr: r.stderr?.toString?.() ?? "" };
  } catch (e: any) {
    return {
      ok: false,
      code: typeof e?.code === "number" ? e.code : 1,
      stdout: e?.stdout?.toString?.() ?? "",
      stderr: e?.stderr?.toString?.() ?? e?.message ?? String(e),
    };
  }
}

function sha256(text: string) {
  return createHash("sha256").update(text, "utf8").digest("hex");
}

function shortHash(text: string) {
  return sha256(text).slice(0, 12);
}

function listFiles(rootAbs: string, exts: Set<string>, maxFiles: number) {
  const out: string[] = [];
  const stack = [rootAbs];

  while (stack.length) {
    const dir = stack.pop()!;
    const entries = readdirSync(dir, { withFileTypes: true });
    for (const e of entries) {
      const p = resolve(dir, e.name);
      if (e.isDirectory()) {
        if (e.name === ".git" || e.name === "node_modules" || e.name === ".build") continue;
        stack.push(p);
        continue;
      }
      if (!e.isFile()) continue;
      const dot = e.name.lastIndexOf(".");
      const ext = dot >= 0 ? e.name.slice(dot).toLowerCase() : "";
      if (!exts.has(ext)) continue;
      out.push(p);
      if (out.length >= maxFiles) return out;
    }
  }
  return out;
}

function extractCandidates(text: string) {
  const lines = text.split(/\r?\n/);
  const candidates: { title: string; body: string }[] = [];

  let currentTitle: string | null = null;
  let buf: string[] = [];

  const flush = () => {
    const body = buf.join("\n").trim();
    if (currentTitle && body) candidates.push({ title: currentTitle.trim(), body });
    currentTitle = null;
    buf = [];
  };

  for (const line of lines) {
    const h = line.match(/^\s{0,3}(#{1,3})\s+(.+?)\s*$/);
    if (h) {
      flush();
      currentTitle = h[2];
      continue;
    }

    const labeled = line.match(/^\s*(Pattern|Principle|Idea|Rule|Invariant)\s*:\s*(.+)\s*$/i);
    if (labeled) {
      flush();
      currentTitle = `${labeled[1]}: ${labeled[2]}`;
      continue;
    }

    buf.push(line);
  }
  flush();

  return candidates
    .map((c) => ({
      title: c.title.replace(/\s+/g, " ").slice(0, 120),
      body: c.body.slice(0, 5000),
    }))
    .filter((c) => c.body.length >= 80);
}

function classifyPattern(title: string, body: string) {
  const t = (title + " " + body).toLowerCase();
  const tags: string[] = [];

  if (t.includes("swift 6") || t.includes("sendable") || t.includes("actor") || t.includes("concurrency"))
    tags.push("concurrency");
  if (t.includes("receipt") || t.includes("ledger") || t.includes("audit") || t.includes("provenance"))
    tags.push("governance");
  if (t.includes("vitepress") || t.includes(".vitepress") || t.includes("docs")) tags.push("docs");
  if (t.includes("dependency") || t.includes("package.swift") || t.includes("swiftpm")) tags.push("deps");
  if (t.includes("tool") || t.includes("opencode") || t.includes("agent")) tags.push("agent-tools");

  let suggestedPhase = "Backlog";
  if (tags.includes("governance")) suggestedPhase = "Governance Spine";
  if (tags.includes("concurrency")) suggestedPhase = "Swift 6 Migration";
  if (tags.includes("agent-tools")) suggestedPhase = "Tooling and Orchestration";
  if (tags.includes("docs")) suggestedPhase = "Documentation Platform";

  return { tags, suggestedPhase };
}

function appendFile(pathAbs: string, content: string) {
  mkdirSync(dirname(pathAbs), { recursive: true });
  writeFileSync(pathAbs, content, "utf8");
}

export default tool({
  description:
    "Extract reusable patterns from Inspiration/, generate a Pattern Registry + Roadmap Backlog, and emit a patch into .opencode/generated (no direct mutation).",
  args: {
    inspirationDir: tool.schema.string().default("Inspiration"),
    registryOut: tool.schema.string().default("Docs/patterns/pattern-registry.json"),
    roadmapOut: tool.schema.string().default("Docs/roadmap/pattern-backlog.md"),
    allowedExts: tool.schema.array(tool.schema.string()).default([".md", ".txt"]),
    maxFiles: tool.schema.number().int().positive().default(500),
    maxPatterns: tool.schema.number().int().positive().default(400),
    ledgerPath: tool.schema.string().default(".opencode/ledger/workflow.jsonl"),
  },
  async execute(args, context) {
    const repo = process.cwd();

    const head = await run("git", ["rev-parse", "HEAD"], repo);
    if (!head.ok) throw new Error(`git rev-parse failed:\n${head.stderr || head.stdout}`);
    const headSHA = head.stdout.trim();

    const wtName = `insp-${shortHash(headSHA + context.sessionID)}`;
    const wtPath = resolve(repo, ".opencode", ".tmp", wtName);
    mkdirSync(dirname(wtPath), { recursive: true });

    const addWT = await run("git", ["worktree", "add", "--detach", wtPath, headSHA], repo);
    if (!addWT.ok) throw new Error(`git worktree add failed:\n${addWT.stderr || addWT.stdout}`);

    try {
      const inspAbs = resolve(wtPath, args.inspirationDir);
      if (!existsSync(inspAbs) || !statSync(inspAbs).isDirectory()) {
        throw new Error(`Inspiration folder not found: ${args.inspirationDir}`);
      }

      const exts = new Set(args.allowedExts.map((s) => s.toLowerCase()));
      const files = listFiles(inspAbs, exts, args.maxFiles);

      const patterns: any[] = [];
      for (const f of files) {
        const raw = readFileSync(f, "utf8");
        const candidates = extractCandidates(raw);
        for (const c of candidates) {
          const { tags, suggestedPhase } = classifyPattern(c.title, c.body);
          const sourceRel = relative(wtPath, f).replace(/\\/g, "/");
          const id = shortHash(sourceRel + "\n" + c.title + "\n" + c.body);

          patterns.push({
            id,
            title: c.title,
            source: sourceRel,
            tags,
            suggestedPhase,
            summary: c.body.split(/\r?\n/).slice(0, 12).join(" ").replace(/\s+/g, " ").slice(0, 420),
            excerpt: c.body.slice(0, 1200),
          });

          if (patterns.length >= args.maxPatterns) break;
        }
        if (patterns.length >= args.maxPatterns) break;
      }

      patterns.sort((a, b) => (a.suggestedPhase + a.title).localeCompare(b.suggestedPhase + b.title));

      const registryAbs = resolve(wtPath, args.registryOut);
      mkdirSync(dirname(registryAbs), { recursive: true });
      writeFileSync(
        registryAbs,
        JSON.stringify(
          {
            schemaVersion: 1,
            generatedAt: new Date().toISOString(),
            inspirationDir: args.inspirationDir,
            count: patterns.length,
            patterns,
          },
          null,
          2
        ) + "\n",
        "utf8"
      );

      const roadmapAbs = resolve(wtPath, args.roadmapOut);
      let md = "";
      md += `# Pattern Backlog (Generated)\n\n`;
      md += `Generated at: ${new Date().toISOString()}\n\n`;
      md += `Source: ${args.inspirationDir}\n\n`;
      md += `This file is machine-generated. Edit the registry inputs, then regenerate.\n\n`;

      let currentPhase = "";
      for (const p of patterns) {
        if (p.suggestedPhase !== currentPhase) {
          currentPhase = p.suggestedPhase;
          md += `## ${currentPhase}\n\n`;
        }
        md += `### ${p.title}\n\n`;
        md += `Source: \`${p.source}\`\n\n`;
        md += `Tags: ${p.tags.join(", ") || "none"}\n\n`;
        md += `${p.summary}\n\n`;
      }
      appendFile(roadmapAbs, md);

      const diff = await run("git", ["diff"], wtPath);
      const patchText = diff.stdout;

      if (!patchText.trim()) {
        return JSON.stringify(
          {
            tool: "inspiration_patterns",
            ok: true,
            note: "No changes produced.",
            meta: { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID },
            ts: new Date().toISOString(),
          },
          null,
          2
        );
      }

      const patchHash = sha256(patchText);
      const outPath = resolve(repo, ".opencode", "generated", `${patchHash}.diff`);
      mkdirSync(dirname(outPath), { recursive: true });
      writeFileSync(outPath, patchText, "utf8");

      return JSON.stringify(
        {
          tool: "inspiration_patterns",
          ok: true,
          patchHash,
          storedAt: `.opencode/generated/${patchHash}.diff`,
          registryOut: args.registryOut,
          roadmapOut: args.roadmapOut,
          fileCount: files.length,
          patternCount: patterns.length,
          meta: { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID },
          ts: new Date().toISOString(),
        },
        null,
        2
      );
    } finally {
      await run("git", ["worktree", "remove", "--force", wtPath], repo);
    }
  },
});
```

## `repo_clean_check.ts`
**Summary:** Pre-flight that validates branch, workspace cleanliness, and submodules before doing patch-worthy work.
```ts
import { tool } from "@opencode-ai/plugin";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { resolve } from "node:path";

const execFileAsync = promisify(execFile);

async function runGit(args: string[], cwd: string) {
  const r = await execFileAsync("git", args, { cwd, maxBuffer: 20 * 1024 * 1024 });
  return { stdout: r.stdout?.toString?.() ?? "", stderr: r.stderr?.toString?.() ?? "" };
}

function parseStatus(lines: string[]) {
  return lines
    .map((line) => {
      const trimmed = line.trim();
      if (!trimmed) return null;
      return { code: line.slice(0, 2).trim(), path: line.slice(3).trim() };
    })
    .filter(Boolean) as Array<{ code: string; path: string }>;
}

function parseSubmodules(raw: string) {
  return raw
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => ({ code: line[0], line }));
}

export default tool({
  description: "Ensure the repo is on the expected branch with a clean working tree and submodules.",
  args: {
    branch: tool.schema.string().default("main"),
    allowUntracked: tool.schema.boolean().default(false),
    forbiddenPaths: tool.schema.array(tool.schema.string()).default([".opencode/", "Docs/governance/"]),
  },
  async execute(args, context) {
    const cwd = process.cwd();

    const branchRaw = await runGit(["rev-parse", "--abbrev-ref", "HEAD"], cwd);
    const branchName = branchRaw.stdout.trim();
    if (!branchName) throw new Error("Unable to determine current branch.");
    const branchOk = branchName === args.branch;

    const statusRaw = await runGit(["status", "--porcelain=v1"], cwd);
    const statusEntries = parseStatus(statusRaw.stdout.split("\n"));
    const forbiddenTouched = statusEntries
      .map((entry) => entry.path)
      .filter((path) => args.forbiddenPaths.some((prefix) => path === prefix || path.startsWith(prefix.endsWith("/") ? prefix : `${prefix}/`)));
    const dirtyEntries = statusEntries.filter((entry) => {
      if (entry.code === "??" && args.allowUntracked) return false;
      return !!entry.code;
    });

    const subRaw = await runGit(["submodule", "status", "--recursive"], cwd);
    const dirtySubmodules = parseSubmodules(subRaw.stdout).filter((s) => s.code && s.code !== " ");

    const ok = branchOk && dirtyEntries.length === 0 && dirtySubmodules.length === 0;

    return JSON.stringify(
      {
        tool: "repo_clean_check",
        ok,
        branch: branchName,
        expectedBranch: args.branch,
        branchMatch: branchOk,
        dirtyEntries: dirtyEntries.map((e) => ({ code: e.code, path: e.path })),
        forbiddenTouched,
        submoduleStatus: dirtySubmodules.map((s) => s.line),
        meta: { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID },
        ts: new Date().toISOString(),
      },
      null,
      2
    );
  },
});
```

## `repo_diff.ts`
**Summary:** Reports git status/diff (staged or unstaged) and can optionally run git apply --check on a provided patch.
```ts
import { tool } from "@opencode-ai/plugin";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { createHash } from "node:crypto";

const execFileAsync = promisify(execFile);

async function run(cmd: string, args: string[], cwd: string) {
  try {
    const { stdout, stderr } = await execFileAsync(cmd, args, { cwd, maxBuffer: 20 * 1024 * 1024 });
    return { ok: true, code: 0, stdout: stdout ?? "", stderr: stderr ?? "" };
  } catch (e: any) {
    return {
      ok: false,
      code: typeof e?.code === "number" ? e.code : 1,
      stdout: e?.stdout?.toString?.() ?? "",
      stderr: e?.stderr?.toString?.() ?? e?.message ?? String(e),
    };
  }
}

function sha256(text: string) {
  return createHash("sha256").update(text, "utf8").digest("hex");
}

function truncate(s: string, max: number) {
  if (s.length <= max) return s;
  return s.slice(0, max) + `\n\n[truncated to ${max} chars]\n`;
}

export default tool({
  description: "Show git status/diff and optionally check a unified diff for apply-ability (no mutation).",
  args: {
    staged: tool.schema.boolean().default(false).describe("Show staged diff instead of working tree."),
    paths: tool.schema.array(tool.schema.string()).optional().describe("Optional path filters."),
    maxChars: tool.schema.number().int().positive().default(60_000).describe("Max characters for diff output."),
    patchToCheck: tool.schema.string().optional().describe("If provided, runs `git apply --check` on this patch text."),
  },
  async execute(args, context) {
    const cwd = process.cwd();
    const meta = { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID };

    const status = await run("git", ["status", "--porcelain=v1"], cwd);

    const diffArgs = ["diff"];
    if (args.staged) diffArgs.push("--cached");
    if (args.paths?.length) diffArgs.push("--", ...args.paths);

    const diff = await run("git", diffArgs, cwd);

    let patchCheck: any = null;
    if (args.patchToCheck) {
      const hash = sha256(args.patchToCheck);
      const tmp = resolve(cwd, `.opencode/.tmp/check-${hash}.diff`);
      mkdirSync(dirname(tmp), { recursive: true });
      writeFileSync(tmp, args.patchToCheck, "utf8");
      patchCheck = await run("git", ["apply", "--check", "--whitespace=nowarn", tmp], cwd);
    }

    return JSON.stringify(
      {
        tool: "repo_diff",
        ok: status.ok && diff.ok && (patchCheck ? patchCheck.ok : true),
        status,
        diff: { ...diff, stdout: truncate(diff.stdout, args.maxChars) },
        patchCheck,
        meta,
        ts: new Date().toISOString(),
      },
      null,
      2
    );
  },
});
```

## `rollback_last_apply.ts`
**Summary:** Reverses the most recent successful patch apply via git apply --reverse and records a rollback receipt.
```ts
import { tool } from "@opencode-ai/plugin";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { resolve } from "node:path";
import { existsSync } from "node:fs";
import { appendReceipt, isoNow, readReceipts } from "./_ledger";

const execFileAsync = promisify(execFile);

async function run(cmd: string[], cwd: string) {
  try {
    const r = await execFileAsync(cmd[0], cmd.slice(1), { cwd, maxBuffer: 20 * 1024 * 1024 });
    return { stdout: r.stdout?.toString?.() ?? "", stderr: r.stderr?.toString?.() ?? "", code: 0, ok: true };
  } catch (e: any) {
    return { stdout: e?.stdout?.toString?.() ?? "", stderr: e?.stderr?.toString?.() ?? e?.message ?? String(e), code: typeof e?.code === "number" ? e.code : 1, ok: false };
  }
}

export default tool({
  description: "Rollback the most recent successfully applied patch from the ledger.",
  args: {
    ledgerPath: tool.schema.string().default(".opencode/ledger/workflow.jsonl"),
  },
  async execute(args, context) {
    const cwd = process.cwd();
    const receipts = readReceipts(args.ledgerPath);
    const lastApply = receipts
      .filter((r) => r.kind === "apply_result" && r.ok && r.patchHash)
      .reverse()[0];
    if (!lastApply?.patchHash) throw new Error("No previously applied patch found to rollback.");

    const patchPath = resolve(cwd, `.opencode/generated/${lastApply.patchHash}.diff`);
    if (!existsSync(patchPath)) throw new Error(`Patch file missing: ${patchPath}`);

    const check = await run(["git", "apply", "--reverse", "--check", "--whitespace=nowarn", patchPath], cwd);
    if (!check.ok) {
      throw new Error(`Rollback check failed:\n${check.stderr || check.stdout}`);
    }

    const apply = await run(["git", "apply", "--reverse", "--whitespace=nowarn", patchPath], cwd);
    if (!apply.ok) throw new Error(`Rollback apply failed:\n${apply.stderr || apply.stdout}`);

    const ts = isoNow();
    appendReceipt(args.ledgerPath, {
      kind: "rollback",
      ts,
      meta: { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID },
      patchHash: lastApply.patchHash,
      ok: true,
      detail: { note: "Reverted last apply_result.", revertedPatch: lastApply.patchHash },
    });

    return JSON.stringify(
      {
        tool: "rollback_last_apply",
        ok: true,
        patchHash: lastApply.patchHash,
        detail: { revertedPatch: lastApply.patchHash },
        meta: { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID },
        ts,
      },
      null,
      2
    );
  },
});
```

## `scratch_worktree.ts`
**Summary:** Runs a command in a detached worktree, captures the resulting diff, and stores it as a generated patch.
```ts
import { tool } from "@opencode-ai/plugin";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { createHash } from "node:crypto";
import { appendReceipt, isoNow, sha256 } from "./_ledger";

const execFileAsync = promisify(execFile);

async function run(cmd: string, argv: string[], cwd: string) {
  try {
    const r = await execFileAsync(cmd, argv, { cwd, maxBuffer: 120 * 1024 * 1024 });
    return { ok: true, code: 0, stdout: r.stdout?.toString?.() ?? "", stderr: r.stderr?.toString?.() ?? "" };
  } catch (e: any) {
    return {
      ok: false,
      code: typeof e?.code === "number" ? e.code : 1,
      stdout: e?.stdout?.toString?.() ?? "",
      stderr: e?.stderr?.toString?.() ?? e?.message ?? String(e),
    };
  }
}

function shortHash(text: string) {
  return createHash("sha256").update(text, "utf8").digest("hex").slice(0, 12);
}

function ensureDiffLooksReal(patch: string) {
  return patch.includes("\n--- ") && patch.includes("\n+++ ") && patch.includes("\n@@");
}

export default tool({
  description: "Run a command in a detached scratch worktree and capture the resulting diff as a governed patch.",
  args: {
    command: tool.schema.string().min(1).describe("Shell command (executed via bash -lc) to run inside the scratch worktree.").default("true"),
    ledgerPath: tool.schema.string().default(".opencode/ledger/workflow.jsonl"),
  },
  async execute(args, context) {
    const cwd = process.cwd();
    const meta = { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID };

    const head = await run("git", ["rev-parse", "HEAD"], cwd);
    if (!head.ok) throw new Error(`git rev-parse failed: ${head.stderr || head.stdout}`);
    const headSHA = head.stdout.trim();

    const wtName = `scratch-${shortHash(headSHA + context.sessionID)}`;
    const wtPath = resolve(cwd, ".opencode", ".tmp", wtName);
    mkdirSync(dirname(wtPath), { recursive: true });

    const addWT = await run("git", ["worktree", "add", "--detach", wtPath, headSHA], cwd);
    if (!addWT.ok) throw new Error(`git worktree add failed:\n${addWT.stderr || addWT.stdout}`);

    try {
      const cmdResult = await run("bash", ["-lc", args.command], wtPath);
      if (!cmdResult.ok) throw new Error(`Scratch command failed:\n${cmdResult.stderr || cmdResult.stdout}`);

      const diff = await run("git", ["diff"], wtPath);
      const patchText = diff.stdout;

      if (!patchText.trim()) {
        const rec = {
          kind: "generation" as const,
          ts: isoNow(),
          meta,
          patchHash: null,
          ok: true,
          detail: { command: args.command, note: "Command produced no diff." },
        };
        appendReceipt(args.ledgerPath, rec);
        return JSON.stringify({ ...rec, patchPreviewBytes: 0, commandResult: cmdResult }, null, 2);
      }

      if (!ensureDiffLooksReal(patchText)) throw new Error("Scratch diff did not resemble a unified diff.");

      const patchHash = sha256(patchText);
      const outPath = resolve(cwd, ".opencode", "generated", `${patchHash}.diff`);
      mkdirSync(dirname(outPath), { recursive: true });
      writeFileSync(outPath, patchText, "utf8");

      const rec = {
        kind: "generation" as const,
        ts: isoNow(),
        meta,
        patchHash,
        ok: true,
        detail: { command: args.command, storedAt: `.opencode/generated/${patchHash}.diff` },
      };
      appendReceipt(args.ledgerPath, rec);

      return JSON.stringify(
        {
          ...rec,
          patchPreviewBytes: Buffer.byteLength(patchText, "utf8"),
          commandResult: cmdResult,
        },
        null,
        2
      );
    } finally {
      await run("git", ["worktree", "remove", "--force", wtPath], cwd);
    }
  },
});
```

## `swiftpm.ts`
**Summary:** Runs SwiftPM build/test with strict concurrency options, logs the output, and returns a trimmed tail plus log path.
```ts
import { tool } from "@opencode-ai/plugin";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { createHash } from "node:crypto";

const execFileAsync = promisify(execFile);

async function run(cmd: string, argv: string[], cwd: string) {
  try {
    const r = await execFileAsync(cmd, argv, { cwd, maxBuffer: 80 * 1024 * 1024 });
    return { ok: true, code: 0, stdout: r.stdout?.toString?.() ?? "", stderr: r.stderr?.toString?.() ?? "" };
  } catch (e: any) {
    return {
      ok: false,
      code: typeof e?.code === "number" ? e.code : 1,
      stdout: e?.stdout?.toString?.() ?? "",
      stderr: e?.stderr?.toString?.() ?? e?.message ?? String(e),
    };
  }
}

function sha(text: string) {
  return createHash("sha256").update(text, "utf8").digest("hex").slice(0, 16);
}

function tail(text: string, maxChars: number) {
  return text.length <= maxChars ? text : text.slice(text.length - maxChars);
}

export default tool({
  description: "Run SwiftPM build/test with strict concurrency options and return real compiler errors without raw shell access.",
  args: {
    action: tool.schema.enum(["build", "test"]).default("build"),
    configuration: tool.schema.enum(["debug", "release"]).default("debug"),
    target: tool.schema.string().optional().describe("Optional SwiftPM target name (passed as --target)."),
    strictConcurrency: tool.schema.boolean().default(true),
    extraSwiftcFlags: tool.schema.array(tool.schema.string()).default([]),
    maxReturnChars: tool.schema.number().int().positive().default(60000),
    logDir: tool.schema.string().default(".opencode/logs")
  },
  async execute(args, context) {
    const cwd = process.cwd();

    const argv: string[] = [args.action, "-c", args.configuration];
    if (args.target) argv.push("--target", args.target);

    if (args.strictConcurrency) argv.push("-Xswiftc", "-strict-concurrency=complete");
    for (const f of args.extraSwiftcFlags) argv.push("-Xswiftc", f);

    const r = await run("swift", argv, cwd);

    const combined = r.stdout + (r.stderr ? "\n" + r.stderr : "");
    const h = sha(combined + JSON.stringify(argv));
    const logPath = resolve(cwd, args.logDir, `swiftpm-${args.action}-${h}.log`);
    mkdirSync(dirname(logPath), { recursive: true });
    writeFileSync(logPath, combined, "utf8");

    return JSON.stringify(
      {
        tool: "swiftpm",
        ok: r.ok,
        code: r.code,
        argv: ["swift", ...argv],
        logPath: `${args.logDir}/swiftpm-${args.action}-${h}.log`,
        outputTail: tail(combined, args.maxReturnChars),
        meta: { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID },
        ts: new Date().toISOString()
      },
      null,
      2
    );
  }
});
```

## `swiftpm_log.ts`
**Summary:** Reads the newest SwiftPM log and extracts actionable compiler diagnostics with context.
```ts
import { tool } from "@opencode-ai/plugin";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { resolve } from "node:path";

function findLatestLog(cwd: string) {
  const logsDir = resolve(cwd, ".opencode", "logs");
  if (!existsSync(logsDir)) throw new Error(`Logs directory missing: ${logsDir}`);
  const entries = readdirSync(logsDir)
    .filter((name) => name.startsWith("swiftpm-") && name.endsWith(".log"))
    .map((name) => ({
      name,
      path: resolve(logsDir, name),
      mtime: statSync(resolve(logsDir, name)).mtime.getTime(),
    }))
    .sort((a, b) => b.mtime - a.mtime);
  if (!entries.length) throw new Error("No SwiftPM logs found in .opencode/logs/");
  return entries[0].path;
}

function extractDiagnostics(
  lines: string[],
  contextLines: number,
  maxDiagnostics: number
) {
  const diagnostics: Array<{
    severity: "error" | "warning";
    message: string;
    file?: string;
    line?: number;
    column?: number;
    snippet: string;
  }> = [];

  const detailRegex =
    /^(?<file>[^:\s].+?):(?<line>\d+):(?<column>\d+):\s*(?<severity>error|warning):\s*(?<message>.*)$/i;
  const basicRegex = /\b(error|warning):/i;

  for (let idx = 0; idx < lines.length && diagnostics.length < maxDiagnostics; idx += 1) {
    const line = lines[idx];
    const basicMatch = line.match(basicRegex);
    if (!basicMatch) continue;
    const severity = basicMatch[1].toLowerCase() as "error" | "warning";

    const detailMatch = line.match(detailRegex);
    let file: string | undefined;
    let lineNum: number | undefined;
    let column: number | undefined;
    let message = line.trim();
    if (detailMatch?.groups) {
      file = detailMatch.groups.file;
      lineNum = Number(detailMatch.groups.line);
      column = Number(detailMatch.groups.column);
      message = detailMatch.groups.message;
    } else {
      const parts = line.split(basicMatch[0]);
      if (parts.length > 1) message = basicMatch[0] + parts[1].trim();
    }

    const start = Math.max(0, idx - contextLines);
    const end = Math.min(lines.length, idx + contextLines + 1);
    const snippet = lines.slice(start, end).join("\n");

    diagnostics.push({
      severity,
      message,
      file,
      line: lineNum,
      column,
      snippet,
    });
  }

  return diagnostics;
}

export default tool({
  description: "Summarize SwiftPM log diagnostics so agents can see errors & warnings without dumping huge logs.",
  args: {
    logPath: tool.schema.string().optional().describe("Explicit log file path (defaults to latest swiftpm log)."),
    contextLines: tool.schema.number().int().min(0).default(3),
    maxDiagnostics: tool.schema.number().int().positive().default(20),
  },
  async execute(args, context) {
    const cwd = process.cwd();
    const resolvedLogPath = args.logPath ? resolve(cwd, args.logPath) : findLatestLog(cwd);

    if (!existsSync(resolvedLogPath)) throw new Error(`Log not found: ${resolvedLogPath}`);

    const raw = readFileSync(resolvedLogPath, "utf8");
    const lines = raw.split(/\r?\n/);
    const diagnostics = extractDiagnostics(lines, args.contextLines, args.maxDiagnostics);

    const meta = { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID };

    return JSON.stringify(
      {
        tool: "swiftpm_log",
        logPath: resolvedLogPath,
        diagnostics,
        count: diagnostics.length,
        message: diagnostics.length ? "Diagnostics extracted." : "No errors or warnings found.",
        meta,
        ts: new Date().toISOString(),
      },
      null,
      2
    );
  },
});
```

## `validate_patch.ts`
**Summary:** Runs git apply --check plus the configured gates, records base hashes, and returns the next hint for apply_patch.
```ts
import { tool } from "@opencode-ai/plugin";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { appendReceipt, isoNow, sha256 } from "./_ledger";
import { gatherBasePaths, computeBaseHashes } from "./_patch_utils";

const execFileAsync = promisify(execFile);

export default tool({
  description: "Validate a generated patch: git apply --check plus your governance gates. Emits a validation receipt.",
  args: {
    patchHash: tool.schema.string().min(16),
    requireGreenGates: tool.schema.boolean().default(true),
    gatesCommand: tool.schema.string().default("./Scripts/ci_all"),
    receiptPath: tool.schema.string().default(".opencode/ledger/workflow.jsonl"),
  },
  async execute(args, context) {
    const cwd = process.cwd();
    const patchPath = resolve(cwd, `.opencode/generated/${args.patchHash}.diff`);
    if (!existsSync(patchPath)) throw new Error(`Unknown patchHash; run generate_patch first: ${args.patchHash}`);

    const patch = readFileSync(patchPath, "utf8");
    if (sha256(patch) !== args.patchHash) throw new Error("Patch hash mismatch (generated file corrupted or tampered).");

    const applyCheck = await run("git", ["apply", "--check", "--whitespace=nowarn", patchPath], cwd);

    let gates: any = null;
    if (args.requireGreenGates) {
      gates = await run("bash", ["-lc", args.gatesCommand], cwd);
    }

    const ok = applyCheck.ok && (!args.requireGreenGates || gates?.ok);

    const basePaths = gatherBasePaths(patch);
    const baseHashes = computeBaseHashes(basePaths, cwd);

    const rec = {
      kind: "validation" as const,
      ts: isoNow(),
      meta: { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID },
      patchHash: args.patchHash,
      ok,
      detail: { applyCheck, gates, baseHashes },
    };

    appendReceipt(args.receiptPath, rec);
    return JSON.stringify(rec, null, 2);
  },
});
```

## `vitepress_build.ts`
**Summary:** Builds the VitePress site in a detached worktree, writes the log, and reports the output tail.
```ts
import { tool } from "@opencode-ai/plugin";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { createHash } from "node:crypto";

const execFileAsync = promisify(execFile);

async function run(cmd: string, argv: string[], cwd: string) {
  try {
    const r = await execFileAsync(cmd, argv, { cwd, maxBuffer: 120 * 1024 * 1024 });
    return { ok: true, code: 0, stdout: r.stdout?.toString?.() ?? "", stderr: r.stderr?.toString?.() ?? "" };
  } catch (e: any) {
    return {
      ok: false,
      code: typeof e?.code === "number" ? e.code : 1,
      stdout: e?.stdout?.toString?.() ?? "",
      stderr: e?.stderr?.toString?.() ?? e?.message ?? String(e),
    };
  }
}

function tail(text: string, maxChars: number) {
  return text.length <= maxChars ? text : text.slice(text.length - maxChars);
}

function shortHash(s: string) {
  return createHash("sha256").update(s, "utf8").digest("hex").slice(0, 12);
}

export default tool({
  description:
    "Build VitePress site in a detached git worktree, capture logs to a file, and return a short diagnostic tail.",
  args: {
    siteDir: tool.schema.string().default("docs").describe("Directory that contains the VitePress site root."),
    installCommand: tool.schema
      .string()
      .default("bun install")
      .describe("Dependency install command executed in the worktree (bun/npm/pnpm)."),
    buildCommand: tool.schema
      .string()
      .default("bunx vitepress build")
      .describe("Build command executed inside siteDir. Default output is .vitepress/dist."),
    logDir: tool.schema.string().default(".opencode/logs"),
    maxReturnChars: tool.schema.number().int().positive().default(60000)
  },
  async execute(args, context) {
    const cwd = process.cwd();

    const head = await run("git", ["rev-parse", "HEAD"], cwd);
    if (!head.ok) throw new Error(`git rev-parse failed:\n${head.stderr || head.stdout}`);
    const headSHA = head.stdout.trim();

    const wtName = `vitepress-${shortHash(headSHA + context.sessionID)}`;
    const wtPath = resolve(cwd, ".opencode", ".tmp", wtName);
    mkdirSync(dirname(wtPath), { recursive: true });

    const addWT = await run("git", ["worktree", "add", "--detach", wtPath, headSHA], cwd);
    if (!addWT.ok) throw new Error(`git worktree add failed:\n${addWT.stderr || addWT.stdout}`);

    try {
      const install = await run("bash", ["-lc", args.installCommand], wtPath);
      if (!install.ok) throw new Error(`Install failed:\n${install.stderr || install.stdout}`);

      const sitePath = resolve(wtPath, args.siteDir);
      const build = await run("bash", ["-lc", args.buildCommand], sitePath);

      const combined = (install.stdout + "\n" + install.stderr + "\n" + build.stdout + "\n" + build.stderr).trim();
      const h = shortHash(combined + args.buildCommand + args.installCommand);

      const logPath = resolve(cwd, args.logDir, `vitepress-build-${h}.log`);
      mkdirSync(dirname(logPath), { recursive: true });
      writeFileSync(logPath, combined + "\n", "utf8");

      return JSON.stringify(
        {
          tool: "vitepress_build",
          ok: build.ok,
          code: build.code,
          siteDir: args.siteDir,
          outputDir: `${args.siteDir}/.vitepress/dist`,
          logPath: `${args.logDir}/vitepress-build-${h}.log`,
          outputTail: tail(combined, args.maxReturnChars),
          meta: { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID },
          ts: new Date().toISOString()
        },
        null,
        2
      );
    } finally {
      await run("git", ["worktree", "remove", "--force", wtPath], cwd);
    }
  }
});
```

## `worktree_create.ts`
**Summary:** Creates an isolated git worktree and branch for parallel agent work, returning metadata for a new session.
```ts
import { tool } from "@opencode-ai/plugin";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { createHash } from "node:crypto";

const execFileAsync = promisify(execFile);

async function run(cmd: string, argv: string[], cwd: string) {
  try {
    const r = await execFileAsync(cmd, argv, { cwd, maxBuffer: 40 * 1024 * 1024 });
    return { ok: true, code: 0, stdout: r.stdout?.toString?.() ?? "", stderr: r.stderr?.toString?.() ?? "" };
  } catch (e: any) {
    return {
      ok: false,
      code: typeof e?.code === "number" ? e.code : 1,
      stdout: e?.stdout?.toString?.() ?? "",
      stderr: e?.stderr?.toString?.() ?? e?.message ?? String(e),
    };
  }
}

function slug(s: string) {
  return s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 60);
}

function shortHash(s: string) {
  return createHash("sha256").update(s, "utf8").digest("hex").slice(0, 8);
}

export default tool({
  description:
    "Create a git worktree + branch for an isolated task so multiple agents can work in parallel without file collisions.",
  args: {
    taskName: tool.schema.string().min(3).describe("Human readable task name."),
    baseRef: tool.schema.string().default("HEAD").describe("Base ref to branch from."),
    worktreeRoot: tool.schema.string().default(".opencode/worktrees")
  },
  async execute(args, context) {
    const cwd = process.cwd();
    const base = await run("git", ["rev-parse", args.baseRef], cwd);
    if (!base.ok) throw new Error(`git rev-parse failed:\n${base.stderr || base.stdout}`);
    const baseSHA = base.stdout.trim();

    const branch = `agent/${slug(args.taskName)}-${shortHash(baseSHA + context.sessionID + args.taskName)}`;
    const path = resolve(cwd, args.worktreeRoot, branch);
    mkdirSync(dirname(path), { recursive: true });

    const createBranch = await run("git", ["branch", branch, baseSHA], cwd);
    if (!createBranch.ok) throw new Error(`git branch failed:\n${createBranch.stderr || createBranch.stdout}`);

    const addWT = await run("git", ["worktree", "add", path, branch], cwd);
    if (!addWT.ok) throw new Error(`git worktree add failed:\n${addWT.stderr || addWT.stdout}`);

    return JSON.stringify(
      {
        tool: "worktree_create",
        ok: true,
        taskName: args.taskName,
        baseRef: args.baseRef,
        baseSHA,
        branch,
        worktreePath: `${args.worktreeRoot}/${branch}`,
        note: "Start a separate opencode process in worktreePath for true parallelism.",
        meta: { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID },
        ts: new Date().toISOString()
      },
      null,
      2
    );
  }
});
```

## `worktree_remove.ts`
**Summary:** Safely removes a worktree and optionally deletes its branch, returning the result in structured JSON.
```ts
import { tool } from "@opencode-ai/plugin";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

async function run(cmd: string, argv: string[], cwd: string) {
  try {
    const r = await execFileAsync(cmd, argv, { cwd, maxBuffer: 40 * 1024 * 1024 });
    return { ok: true, code: 0, stdout: r.stdout?.toString?.() ?? "", stderr: r.stderr?.toString?.() ?? "" };
  } catch (e: any) {
    return {
      ok: false,
      code: typeof e?.code === "number" ? e.code : 1,
      stdout: e?.stdout?.toString?.() ?? "",
      stderr: e?.stderr?.toString?.() ?? e?.message ?? String(e),
    };
  }
}

export default tool({
  description: "Remove a git worktree safely (and optionally delete its branch).",
  args: {
    worktreePath: tool.schema.string().min(3),
    deleteBranch: tool.schema.boolean().default(false),
    branchName: tool.schema.string().optional()
  },
  async execute(args, context) {
    const cwd = process.cwd();

    const rm = await run("git", ["worktree", "remove", "--force", args.worktreePath], cwd);
    if (!rm.ok) throw new Error(`git worktree remove failed:\n${rm.stderr || rm.stdout}`);

    let del: any = null;
    if (args.deleteBranch && args.branchName) {
      del = await run("git", ["branch", "-D", args.branchName], cwd);
      if (!del.ok) throw new Error(`git branch -D failed:\n${del.stderr || del.stdout}`);
    }

    return JSON.stringify(
      {
        tool: "worktree_remove",
        ok: true,
        worktreePath: args.worktreePath,
        deleteBranch: args.deleteBranch,
        branchName: args.branchName ?? null,
        deleteResult: del,
        meta: { agent: context.agent, sessionID: context.sessionID, messageID: context.messageID },
        ts: new Date().toISOString()
      },
      null,
      2
    );
  }
});
```

## `task.ts`
**Summary:** Enforces the wrapper path for launching subagents. Every invocation expands to `node Scripts/subagent_wrapper.js --session <session> --subagent <role> --ledger <ledger> --statusFile <status> --timeout <ms> -- <command>`, so the Conductor observes `subagent.started` before waiting and always receives exactly one terminal receipt.
```ts
import { tool } from "@opencode-ai/plugin";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { randomUUID } from "node:crypto";

const execFileAsync = promisify(execFile);

const DEFAULT_TIMEOUT_MS = 600000;

function ensureDir(path: string) {
  mkdirSync(path, { recursive: true });
}

export default tool({
  description:
    "Canonical wrapper for launching subagents through Scripts/subagent_wrapper.js, ensuring the ledger/status files stay in sync and timeouts are enforced.",
  args: {
    subagent: tool.schema.string().describe("Subagent name such as scout, judge, migrator, or integrator."),
    command: tool.schema
      .string()
      .describe("Shell command that the subagent should execute, e.g. `opencode agent run scout --session \"$SESSION\"`."),
    ledger: tool.schema
      .string()
      .default(".opencode/ledger/workflow.jsonl")
      .describe("Ledger path shared between the Conductor and subagents."),
    statusRoot: tool.schema
      .string()
      .default(".opencode/runtime/status")
      .describe("Directory where per-session heartbeat files are written."),
    timeout: tool.schema
      .number()
      .default(DEFAULT_TIMEOUT_MS)
      .describe("Maximum runtime in milliseconds before the wrapper kills the child and emits a timeout failure.")
  },
  async execute(args, context) {
    const cwd = context.directory ?? process.cwd();
    const sessionID = context.sessionID ?? randomUUID();
    const messageID = context.messageID ?? randomUUID();
    const statusRootPath = resolve(cwd, args.statusRoot);
    ensureDir(statusRootPath);
    const statusFile = resolve(statusRootPath, `${sessionID}-${args.subagent}.json`);
    const scriptPath = resolve(cwd, "Scripts/subagent_wrapper.js");

    const wrapperArgs = [
      scriptPath,
      "--session",
      sessionID,
      "--subagent",
      args.subagent,
      "--ledger",
      args.ledger,
      "--statusFile",
      statusFile,
      "--timeout",
      String(Math.max(1, args.timeout)),
      "--agent",
      context.agent,
      "--message",
      messageID,
      "--",
      args.command
    ];

    const result = await execFileAsync("node", wrapperArgs, {
      cwd,
      env: { ...process.env, OPENCODE_LEDGER_PATH: args.ledger, OPENCODE_STATUS_FILE: statusFile }
    });

    return {
      tool: "task",
      meta: {
        agent: context.agent,
        sessionID,
        messageID
      },
      ...result,
      ledgerPath: args.ledger,
      statusFile,
      subagent: args.subagent,
      timeout: args.timeout
    };
  }
});
```

## `.opencode/plugin.ts`
**Summary:** Enforcement plugin that blocks `apply_patch` and `commit_changes` unless the receipt chain, phase contract acceptance refs, gates, and latest base hashes are satisfied, and writes quarantine records when tools fail.
```ts
import type { Plugin } from "@opencode-ai/plugin";
import { appendReceipt, isoNow, readReceipts, requireInOrder } from "./tool/_ledger";
import { verifyBaseHashes } from "./tool/_patch_utils";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { existsSync, appendFileSync, readFileSync, readdirSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";

const execFileAsync = promisify(execFile);

const LEDGER_PATH = ".opencode/ledger/workflow.jsonl";
const QUARANTINE_PATH = ".opencode/ledger/quarantine.jsonl";
const PHASE_DIR = "Docs/governance/phases";

async function runGit(args: string[], cwd: string) {
  try {
    const r = await execFileAsync("git", args, { cwd, maxBuffer: 20 * 1024 * 1024 });
    return { ok: true, stdout: r.stdout?.toString?.() ?? "", stderr: r.stderr?.toString?.() ?? "" };
  } catch (error: any) {
    return {
      ok: false,
      stdout: error?.stdout?.toString?.() ?? "",
      stderr: error?.stderr?.toString?.() ?? error?.message ?? String(error),
    };
  }
}

function parsePorcelain(raw: string) {
  return raw
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => ({ path: line.slice(3).trim(), code: line.slice(0, 2).trim() }));
}

function quarantineSet(quarantinePath: string) {
  if (!existsSync(quarantinePath)) return new Set<string>();
  return new Set(
    readFileSync(quarantinePath, "utf8")
      .split("\n")
      .map((line) => line.trim())
      .filter(Boolean)
      .map((line) => {
        try {
          return JSON.parse(line).patchHash;
        } catch {
          return null;
        }
      })
      .filter(Boolean) as string[]
  );
}

function appendQuarantineRecord(
  quarantinePath: string,
  ledgerPath: string,
  patchHash: string,
  reason: string,
  tool: string,
  meta: { agent: string; sessionID: string; messageID: string }
) {
  mkdirSync(dirname(quarantinePath), { recursive: true });
  const row = { patchHash, reason, tool, ts: isoNow() };
  appendFileSync(quarantinePath, JSON.stringify(row) + "\n", "utf8");
  appendReceipt(ledgerPath, {
    kind: "quarantine",
    ts: row.ts,
    meta,
    patchHash,
    ok: false,
    detail: { reason, tool },
  });
}

function ensureReceiptChain(patchHash: string, ledger: ReturnType<typeof readReceipts>) {
  const scoped = ledger.filter((r) => r.patchHash === patchHash);
  requireInOrder(scoped, ["inspection", "generation", "proposal", "validation"]);
  const latestValidation = scoped.filter((r) => r.kind === "validation").slice(-1)[0];
  if (!latestValidation?.ok) throw new Error("Latest validation receipt is not ok.");
}

async function runCommand(command: string, cwd: string) {
  try {
    const r = await execFileAsync("bash", ["-lc", command], { cwd, maxBuffer: 60 * 1024 * 1024 });
    return { ok: true, stdout: r.stdout?.toString?.() ?? "", stderr: r.stderr?.toString?.() ?? "" };
  } catch (e: any) {
    return {
      ok: false,
      stdout: e?.stdout?.toString?.() ?? "",
      stderr: e?.stderr?.toString?.() ?? e?.message ?? String(e),
    };
  }
}

function findPhaseContractPath(directory: string, phaseId: string) {
  const phaseDir = resolve(directory, PHASE_DIR);
  if (!existsSync(phaseDir)) throw new Error(`Phase directory missing: ${PHASE_DIR}`);
  const matches = readdirSync(phaseDir, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.startsWith(`${phaseId}-`) && entry.name.endsWith(".md"))
    .map((entry) => resolve(phaseDir, entry.name));
  if (!matches.length) throw new Error(`Phase contract not found for ${phaseId} in ${PHASE_DIR}`);
  return matches[0];
}

function parsePhaseContract(contractPath: string) {
  const lines = readFileSync(contractPath, "utf8").split(/\r?\n/);
  const acceptanceSet = new Set<string>();
  const acceptanceNormalized = new Set<string>();
  const gates: string[] = [];
  let inAcceptance = false;

  const addAcceptance = (text: string) => {
    const trimmed = text.trim();
    if (!trimmed) return;
    acceptanceSet.add(trimmed);
    acceptanceNormalized.add(trimmed.toLowerCase());
  };

  for (const rawLine of lines) {
    const line = rawLine.trim();
    const lower = line.toLowerCase();
    if (lower.startsWith("primary gates:")) {
      const cmdText = line.slice(line.indexOf(":") + 1);
      gates.push(
        ...cmdText
          .split(",")
          .map((cmd) => cmd.trim())
          .filter(Boolean)
      );
    }
    if (lower === "## acceptance criteria") {
      inAcceptance = true;
      continue;
    }
    if (inAcceptance && line.startsWith("## ") && lower !== "## acceptance criteria") {
      inAcceptance = false;
    }
    if (inAcceptance) {
      const match = line.match(/^[-*]\s+(.*)$/);
      if (match) {
        addAcceptance(match[1]);
      } else if (line && !line.startsWith("##")) {
        addAcceptance(line);
      }
    }
  }
  return { acceptanceSet, acceptanceNormalized, gates };
}

function getLatestProposalForPatch(receipts: ReturnType<typeof readReceipts>, patchHash: string) {
  return receipts
    .filter((r) => r.kind === "proposal" && r.patchHash === patchHash)
    .reverse()[0];
}

async function enforcePhaseContract(directory: string, patchHash: string, detail: any) {
  const phaseId = detail?.phaseId;
  const acceptanceRefs = Array.isArray(detail?.acceptanceRefs) ? detail.acceptanceRefs : [];
  if (!phaseId) throw new Error("Proposal missing phaseId.");
  if (!acceptanceRefs.length) throw new Error("Proposal must cite at least one acceptance criterion.");

  const contractPath = findPhaseContractPath(directory, phaseId);
  const { acceptanceSet, acceptanceNormalized, gates } = parsePhaseContract(contractPath);
  if (!acceptanceSet.size) throw new Error(`Phase ${phaseId} has no listed acceptance criteria.`);

  for (const ref of acceptanceRefs) {
    const trimmed = ref.trim();
    if (!trimmed) continue;
    if (!acceptanceNormalized.has(trimmed.toLowerCase())) {
      throw new Error(`Acceptance criterion "${trimmed}" not found in ${phaseId} contract (${contractPath}).`);
    }
  }

  for (const gate of gates) {
    if (!gate) continue;
    const runResult = await runCommand(gate, directory);
    if (!runResult.ok) {
      throw new Error(
        `Phase ${phaseId} gate "${gate}" failed:\n${runResult.stderr || runResult.stdout}`
      );
    }
  }
}

const plugin: Plugin = async ({ directory }) => {
  const ledgerPath = resolve(directory, LEDGER_PATH);
  const quarantinePath = resolve(directory, QUARANTINE_PATH);

  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool === "apply_patch") {
        const patchHash: string | undefined = output.args?.patchHash;
        if (!patchHash) throw new Error("Missing patchHash argument for apply_patch.");
        const quarantined = quarantineSet(quarantinePath);
        if (quarantined.has(patchHash)) {
          throw new Error(`Patch ${patchHash} is quarantined (use quarantine_patch to update).`);
        }
        const ledger = readReceipts(ledgerPath);
        ensureReceiptChain(patchHash, ledger);
        const validation = ledger.filter((r) => r.kind === "validation" && r.patchHash === patchHash).reverse()[0];
        if (!validation) throw new Error("No validation receipt found for this patch.");
        verifyBaseHashes(directory, validation.detail?.baseHashes ?? {});
        const proposal = getLatestProposalForPatch(ledger, patchHash);
        if (!proposal) throw new Error("No proposal receipt for this patch.");
        await enforcePhaseContract(directory, patchHash, proposal.detail ?? {});
      }

      if (input.tool === "commit_changes") {
        const status = await runGit(["status", "--porcelain=v1"], directory);
        if (!status.ok) throw new Error(`Failed to read git status: ${status.stderr}`);
        const dirty = parsePorcelain(status.stdout);
        const forbidden = dirty.filter((entry) => entry.path.startsWith(".opencode/") || entry.path.startsWith("Docs/governance/"));
        if (forbidden.length) {
          throw new Error(`Forbidden paths modified: ${forbidden.map((f) => f.path).join(", ")}`);
        }
        const head = await runGit(["rev-parse", "--abbrev-ref", "HEAD"], directory);
        if (head.stdout.trim() !== "main") throw new Error("Commits are only allowed on 'main'.");
        const sub = await runGit(["submodule", "status", "--recursive"], directory);
        const dirtySubmodule = sub.stdout.split("\n").some((line) => line.startsWith("+") || line.startsWith("-") || line.startsWith("U"));
        if (dirtySubmodule) throw new Error("Submodule(s) are out of sync; please sync before committing.");
        const receipts = readReceipts(ledgerPath);
        const lastApply = receipts.filter((r) => r.kind === "apply_result" && r.ok).slice(-1)[0];
        if (!lastApply) throw new Error("No successful apply_result found; commit not allowed.");
      }
    },
    "tool.execute.after": async (input, output) => {
      try {
        const payload = JSON.parse(output.output);
        if (payload && payload.patchHash && payload.ok === false) {
          appendQuarantineRecord(
            quarantinePath,
            ledgerPath,
            payload.patchHash,
            payload.detail?.note ?? "Tool reported failure",
            input.tool,
            { agent: "plugin", sessionID: input.sessionID, messageID: input.callID }
          );
        }
      } catch {
        // best-effort only
      }
    },
  };
};

export default plugin;
```
