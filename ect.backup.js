/**
 * ect.js
 * Access Forensics SKU-A v3.0 Executor (Forensic-Grade)
 *
 * Generates a sealed evidence packet under:
 *   runs/<YYYYMMDDTHHMMSSZ>_<case_label>/
 *
 * Required artifacts (per SKU-A v3.0):
 *   screenshots/
 *     screenshot_<flow_id>_step_<NNN>.png
 *     html/page_<flow_id>_step_<NNN>.html
 *     ax/ax_<flow_id>_step_<NNN>.json
 *   network.har
 *   trace.zip
 *   video.webm
 *   journal.ndjson
 *   run_metadata.json
 *   interaction_log.json
 *   evidence_index.json
 *   console.json
 *   manifest.json
 *   packet_hash.txt  (sha256(manifest.json bytes))
 */

"use strict";

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const os = require("os");
const { chromium } = require("playwright");

// --- Playwright Version (package bound) ---
let playwrightVersion = "unknown";
try {
  // eslint-disable-next-line import/no-extraneous-dependencies
  playwrightVersion = require("playwright/package.json").version;
} catch (_) {}

// --- Helpers ---
function nowIso() {
  return new Date().toISOString();
}

function pad3(n) {
  return String(n).padStart(3, "0");
}

function safeToken(s) {
  return String(s || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
}

function ensureDir(p) {
  fs.mkdirSync(p, { recursive: true });
}

function writeJson(p, obj) {
  fs.writeFileSync(p, JSON.stringify(obj, null, 2) + "\n", "utf-8");
}

function readJson(p) {
  return JSON.parse(fs.readFileSync(p, "utf-8"));
}

function sha256Bytes(buf) {
  return crypto.createHash("sha256").update(buf).digest("hex");
}

// Returns null if missing, throws on read error (never silently swallows integrity failures)
function sha256File(filePath) {
  try {
    const buf = fs.readFileSync(filePath);
    return sha256Bytes(buf);
  } catch (e) {
    if (e && e.code === "ENOENT") return null;
    throw e;
  }
}

function statSize(filePath) {
  try {
    return fs.statSync(filePath).size;
  } catch (e) {
    if (e && e.code === "ENOENT") return 0;
    throw e;
  }
}

function formatRunTimestampUTC(d = new Date()) {
  // YYYYMMDDTHHMMSSZ
  const yyyy = String(d.getUTCFullYear());
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(d.getUTCDate()).padStart(2, "0");
  const HH = String(d.getUTCHours()).padStart(2, "0");
  const MM = String(d.getUTCMinutes()).padStart(2, "0");
  const SS = String(d.getUTCSeconds()).padStart(2, "0");
  return `${yyyy}${mm}${dd}T${HH}${MM}${SS}Z`;
}

/**
 * Stable JSON stringify: recursively sorts keys so manifest.json bytes are deterministic.
 * Arrays preserve order (we explicitly sort manifest.files by path before stringify).
 */
function stableStringify(value, indent = 2) {
  const seen = new WeakSet();

  function sorter(v) {
    if (v === null || typeof v !== "object") return v;

    if (seen.has(v)) {
      // Cycles should never exist in our data, but if they do, we hard fail
      throw new Error("Non-deterministic structure: cyclic reference detected");
    }
    seen.add(v);

    if (Array.isArray(v)) {
      return v.map(sorter);
    }

    const keys = Object.keys(v).sort((a, b) => a.localeCompare(b));
    const out = {};
    for (const k of keys) out[k] = sorter(v[k]);
    return out;
  }

  const sorted = sorter(value);
  return JSON.stringify(sorted, null, indent) + "\n";
}

function assertRequiredFile(absPath, label) {
  if (!fs.existsSync(absPath)) {
    throw new Error(`REQUIRED ARTIFACT MISSING: ${label} (${absPath})`);
  }
  const st = fs.statSync(absPath);
  if (!st.isFile() && !st.isDirectory()) {
    throw new Error(`REQUIRED ARTIFACT INVALID: ${label} (${absPath})`);
  }
}

// --- Main ---
async function main() {
  const flowPath = process.argv[2];
  if (!flowPath) {
    console.error("USAGE: node ect.js flows/<target_flow>.json");
    process.exitCode = 1;
    return;
  }

  // ---- Parse flow ----
  let flow;
  try {
    flow = readJson(flowPath);
  } catch (e) {
    console.error("FATAL: Could not parse flow JSON:", e && e.message ? e.message : String(e));
    process.exitCode = 1;
    return;
  }

  // ---- Validate flow schema (strict) ----
  const flowId = safeToken(flow.flow_id);
  if (!flowId) {
    console.error('FATAL: flow.flow_id missing/invalid (expected non-empty string).');
    process.exitCode = 1;
    return;
  }
  if (!flow.start_url || typeof flow.start_url !== "string") {
    console.error("FATAL: flow.start_url missing/invalid (expected string).");
    process.exitCode = 1;
    return;
  }
  if (!Array.isArray(flow.steps)) {
    console.error("FATAL: flow.steps missing/invalid (expected array).");
    process.exitCode = 1;
    return;
  }
  for (let i = 0; i < flow.steps.length; i++) {
    const s = flow.steps[i];
    if (!s || typeof s !== "object") {
      console.error(`FATAL: flow.steps[${i}] invalid (expected object).`);
      process.exitCode = 1;
      return;
    }
    if (!s.type || typeof s.type !== "string") {
      console.error(`FATAL: flow.steps[${i}].type missing/invalid (expected string).`);
      process.exitCode = 1;
      return;
    }
  }

  const caseLabel = safeToken(flow.case_label || flow.case || flow.matter || flow.flow_id);
  const runTs = formatRunTimestampUTC(new Date());
  const runId = `${runTs}_${caseLabel || flowId}`;
  const runDir = path.join("runs", runId);

  // Folder layout per spec
  const screenshotsDir = path.join(runDir, "screenshots");
  const htmlDir = path.join(screenshotsDir, "html");
  const axDir = path.join(screenshotsDir, "ax");
  const videoTempDir = path.join(runDir, "video_temp");

  ensureDir(htmlDir);
  ensureDir(axDir);

  const journalPath = path.join(runDir, "journal.ndjson");
  const journal = fs.createWriteStream(journalPath, { flags: "a" });

  const emit = (event) => {
    if (!journal || journal.destroyed || journal.writableEnded) return;
    journal.write(
      JSON.stringify({
        timestamp_utc: nowIso(),
        run_id: runId,
        ...event,
      }) + "\n"
    );
  };

  const runMetadataPath = path.join(runDir, "run_metadata.json");
  const interactionLogPath = path.join(runDir, "interaction_log.json");
  const evidenceIndexPath = path.join(runDir, "evidence_index.json");
  const consoleLogPath = path.join(runDir, "console.json");
  const harPath = path.join(runDir, "network.har");
  const tracePath = path.join(runDir, "trace.zip");
  const manifestPath = path.join(runDir, "manifest.json");
  const packetHashPath = path.join(runDir, "packet_hash.txt");

  const interactionLog = [];
  const evidenceIndex = [];
  const consoleEvents = [];

  let runStatus = "running";
  let runError = null;

  // ---- Run metadata (initial) ----
  const runMetadata = {
    run_id: runId,
    case_label: caseLabel || null,
    flow_id: flow.flow_id,
    site: flow.start_url,
    started_at_utc: nowIso(),
    finished_at_utc: null,
    status: runStatus,
    error: null,
    environment: {
      node_version: process.version,
      playwright_version: playwrightVersion,
      chromium_version: null, // populated after launch
      os_type: os.type(),
      os_release: os.release(),
      os_platform: os.platform(),
      os_arch: os.arch(),
      timezone_reported: Intl.DateTimeFormat().resolvedOptions().timeZone || "unknown",
      locale_reported: Intl.DateTimeFormat().resolvedOptions().locale || "unknown",
    },
    artifacts: {
      screenshots_dir: "screenshots/",
      network_har: "network.har",
      trace_zip: "trace.zip",
      video_webm: null,
      journal_ndjson: "journal.ndjson",
      run_metadata: "run_metadata.json",
      interaction_log: "interaction_log.json",
      evidence_index: "evidence_index.json",
      console_json: "console.json",
      manifest: "manifest.json",
      packet_hash: "packet_hash.txt",
    },
    packet_hash: null,
  };

  writeJson(runMetadataPath, runMetadata);

  // ---- Playwright runtime handles ----
  let browser = null;
  let context = null;
  let page = null;

  // ---- Evidence capture ----
  let stepIndex = 0;

  async function captureEvidence(label) {
    const stepStr = pad3(stepIndex);
    const base = `${flowId}_step_${stepStr}`;

    const relScreenshot = `screenshots/screenshot_${base}.png`;
    const relHtml = `screenshots/html/page_${base}.html`;
    const relAx = `screenshots/ax/ax_${base}.json`;

    const absScreenshot = path.join(runDir, relScreenshot);
    const absHtml = path.join(runDir, relHtml);
    const absAx = path.join(runDir, relAx);

    // Screenshot
    try {
      await page.screenshot({ path: absScreenshot, fullPage: false });
    } catch (e) {
      const msg = `Screenshot failed: ${e && e.message ? e.message : String(e)}`;
      consoleEvents.push({ timestamp_utc: nowIso(), type: "evidence_error", text: msg });
      emit({ event: "capture.error", type: "screenshot", error: msg });
    }

    // HTML
    try {
      const html = await page.content().catch(() => "");
      fs.writeFileSync(absHtml, html, "utf-8");
    } catch (e) {
      const msg = `HTML save failed: ${e && e.message ? e.message : String(e)}`;
      consoleEvents.push({ timestamp_utc: nowIso(), type: "evidence_error", text: msg });
      emit({ event: "capture.error", type: "html", error: msg });
    }

    // AX snapshot
    try {
      const ax = await page.accessibility.snapshot({ interestingOnly: false });
      writeJson(absAx, ax || { note: "AX snapshot returned null" });
    } catch (e) {
      const msg = `AX snapshot failed: ${e && e.message ? e.message : String(e)}`;
      emit({ event: "capture.error", type: "ax", error: msg });
      writeJson(absAx, { error: "AX snapshot failed", message: msg });
    }

    const ev = {
      step_index: stepIndex,
      label: label || null,
      screenshot: relScreenshot,
      html: relHtml,
      ax: relAx,
    };

    evidenceIndex.push(ev);
    emit({ event: "evidence.captured", ...ev });
    return ev;
  }

  // ---- Step handlers (strict) ----
  async function handleStep(s) {
    if (s.type === "wait_selector") {
      const sel = String(s.selector || "");
      const timeout = Number(s.timeout_ms || 8000);
      const delay = Number(s.delay_ms || 0);

      if (!sel) throw new Error("wait_selector requires selector");

      await page.waitForSelector(sel, { state: "visible", timeout });

      const count = await page.locator(sel).count();
      if (count === 0) throw new Error(`Selector "${sel}" not found (0 matches).`);
      if (count > 1) throw new Error(`Ambiguity Error: "${sel}" matched ${count} elements (expected 1).`);

      if (delay > 0) await page.waitForTimeout(delay);
      return;
    }

    if (s.type === "assert_url_contains") {
      const expected = String(s.text || "");
      if (!expected) throw new Error("assert_url_contains requires text");
      const current = page.url();
      if (!current.includes(expected)) {
        throw new Error(`Assertion Failed: URL "${current}" does not contain "${expected}"`);
      }
      return;
    }

    if (s.type === "assert_text_present") {
      const expected = String(s.text || "");
      const timeout = Number(s.timeout_ms || 5000);
      if (!expected) throw new Error("assert_text_present requires text");

      await page.waitForFunction(
        (txt) => document.body && document.body.innerText && document.body.innerText.includes(txt),
        expected,
        { timeout }
      );

      return;
    }

    if (s.type === "scroll") {
      const dy = Number(s.deltaY || 1200);
      const delay = Number(s.delay_ms || 250);
      await page.mouse.wheel(0, dy);
      if (delay > 0) await page.waitForTimeout(delay);
      return;
    }

    if (s.type === "tab") {
      const count = Number(s.count || 10);
      const delay = Number(s.delay_ms || 80);
      for (let i = 0; i < count; i++) {
        await page.keyboard.press("Tab");
        if (delay > 0) await page.waitForTimeout(delay);
      }
      return;
    }

    if (s.type === "click_selector" || s.type === "type_selector") {
      const sel = String(s.selector || "");
      const timeout = Number(s.timeout_ms || 5000);
      const delay = Number(s.delay_ms || (s.type === "click_selector" ? 500 : 250));

      if (!sel) throw new Error(`${s.type} requires selector`);

      await page.waitForSelector(sel, { state: "visible", timeout });

      const loc = page.locator(sel);
      const count = await loc.count();
      if (count === 0) throw new Error(`Selector "${sel}" disappeared (0 matches).`);
      if (count > 1) throw new Error(`Ambiguity Error: Selector "${sel}" matched ${count} elements (expected 1).`);

      if (s.type === "click_selector") {
        await loc.click({ timeout });
      } else {
        await loc.fill(String(s.text || ""), { timeout });
      }

      if (delay > 0) await page.waitForTimeout(delay);
      return;
    }

    if (s.type === "press") {
      const key = String(s.key || "Enter");
      const delay = Number(s.delay_ms || 300);
      await page.keyboard.press(key);
      if (delay > 0) await page.waitForTimeout(delay);
      return;
    }

    throw new Error(`Unknown step type: "${s.type}"`);
  }

  try {
    emit({ event: "run.start", flow_id: flow.flow_id, start_url: flow.start_url });

    browser = await chromium.launch({ headless: true });
    runMetadata.environment.chromium_version = await browser.version();
    writeJson(runMetadataPath, runMetadata);

    context = await browser.newContext({
      viewport: { width: 1366, height: 768 },
      locale: "en-US",
      timezoneId: "UTC",
      recordHar: { path: harPath },
      recordVideo: { dir: videoTempDir },
    });

    await context.tracing.start({ screenshots: true, snapshots: true, sources: true });

    page = await context.newPage();

    page.on("console", (msg) => {
      consoleEvents.push({
        timestamp_utc: nowIso(),
        type: msg.type(),
        text: msg.text(),
      });
    });

    page.on("pageerror", (err) => {
      consoleEvents.push({
        timestamp_utc: nowIso(),
        type: "pageerror",
        text: String(err),
      });
    });

    // ---- Initial navigation (Step 001) ----
    stepIndex++;
    emit({ event: "step.start", step_index: stepIndex, action: "navigate", url: flow.start_url });

    await page.goto(flow.start_url, { waitUntil: "domcontentloaded", timeout: 30000 });

    const ev0 = await captureEvidence("Initial page load");

    interactionLog.push({
      step_index: stepIndex,
      action: "navigate",
      result: "success",
      error_message: null,
      url: page.url(),
      note: null,
      screenshot: ev0.screenshot,
      html: ev0.html,
      ax: ev0.ax,
      timestamp_utc: nowIso(),
    });

    emit({ event: "step.end", step_index: stepIndex, status: "success" });

    // ---- Process steps (fail fast) ----
    for (const s of flow.steps) {
      stepIndex++;
      emit({ event: "step.start", step_index: stepIndex, action: s.type, detail: s });

      let stepErr = null;
      try {
        await handleStep(s);
      } catch (e) {
        stepErr = e;
      }

      const ev = await captureEvidence(s.note || s.type);

      interactionLog.push({
        step_index: stepIndex,
        action: s.type,
        result: stepErr ? "failed_action" : "success",
        error_message: stepErr ? (stepErr.message || String(stepErr)) : null,
        url: page.url(),
        note: s.note || null,
        screenshot: ev.screenshot,
        html: ev.html,
        ax: ev.ax,
        timestamp_utc: nowIso(),
      });

      emit({
        event: "step.end",
        step_index: stepIndex,
        status: stepErr ? "error" : "success",
        error: stepErr ? (stepErr.message || String(stepErr)) : null,
      });

      if (stepErr) throw stepErr;
    }

    runStatus = "success";
  } catch (err) {
    runStatus = "error";
    runError = err && err.message ? err.message : String(err);
  } finally {
    // ---- Forensic shutdown ----
    runMetadata.finished_at_utc = nowIso();
    runMetadata.status = runStatus;
    runMetadata.error = runError || null;

    // Stop tracing (creates trace.zip)
    if (context) {
      try {
        await context.tracing.stop({ path: tracePath });
      } catch (_) {}
    }

    // Closing context flushes video to disk
    if (context) {
      try {
        await context.close();
      } catch (_) {}
    }

    // Move video.webm out of temp, enforce uniqueness
    let videoRel = null;
    try {
      if (fs.existsSync(videoTempDir)) {
        const files = fs.readdirSync(videoTempDir).filter((f) => f.toLowerCase().endsWith(".webm"));
        if (files.length === 1) {
          const src = path.join(videoTempDir, files[0]);
          const dest = path.join(runDir, "video.webm");
          fs.renameSync(src, dest);
          videoRel = "video.webm";
        } else if (files.length > 1) {
          emit({ event: "video.error", error: `Multiple video files found: ${files.join(", ")}` });
          runStatus = "error";
          runError = runError || "Multiple video files found, cannot uniquely identify video artifact.";
        } else {
          emit({ event: "video.missing", error: "No video file generated." });
          runStatus = "error";
          runError = runError || "No video file generated.";
        }

        try {
          fs.rmSync(videoTempDir, { recursive: true, force: true });
        } catch (_) {}
      } else {
        emit({ event: "video.missing", error: "video_temp directory missing." });
        runStatus = "error";
        runError = runError || "video_temp directory missing.";
      }
    } catch (e) {
      emit({ event: "video.error", error: e && e.message ? e.message : String(e) });
      runStatus = "error";
      runError = runError || (e && e.message ? e.message : String(e));
    }

    // Close browser
    if (browser) {
      try {
        await browser.close();
      } catch (_) {}
    }

    // Write console log now (always)
    writeJson(consoleLogPath, consoleEvents);

    // Evidence index hashing (post-run sealing)
    const evidenceIndexWithHashes = evidenceIndex.map((ev) => {
      const ssAbs = path.join(runDir, ev.screenshot);
      const htmlAbs = path.join(runDir, ev.html);
      const axAbs = path.join(runDir, ev.ax);

      let ssHash = null;
      let htmlHash = null;
      let axHash = null;

      try {
        ssHash = fs.existsSync(ssAbs) ? sha256File(ssAbs) : null;
      } catch (e) {
        emit({ event: "hash.error", file: ev.screenshot, error: e.message || String(e) });
        runStatus = "error";
        runError = runError || `Hashing failed for ${ev.screenshot}`;
      }

      try {
        htmlHash = fs.existsSync(htmlAbs) ? sha256File(htmlAbs) : null;
      } catch (e) {
        emit({ event: "hash.error", file: ev.html, error: e.message || String(e) });
        runStatus = "error";
        runError = runError || `Hashing failed for ${ev.html}`;
      }

      try {
        axHash = fs.existsSync(axAbs) ? sha256File(axAbs) : null;
      } catch (e) {
        emit({ event: "hash.error", file: ev.ax, error: e.message || String(e) });
        runStatus = "error";
        runError = runError || `Hashing failed for ${ev.ax}`;
      }

      return {
        ...ev,
        screenshot_sha256: ssHash,
        screenshot_size: fs.existsSync(ssAbs) ? statSize(ssAbs) : 0,
        html_sha256: htmlHash,
        html_size: fs.existsSync(htmlAbs) ? statSize(htmlAbs) : 0,
        ax_sha256: axHash,
        ax_size: fs.existsSync(axAbs) ? statSize(axAbs) : 0,
      };
    });

    // Write interaction/evidence logs
    writeJson(interactionLogPath, interactionLog);
    writeJson(evidenceIndexPath, evidenceIndexWithHashes);

    // Update metadata with video
    runMetadata.artifacts.video_webm = videoRel;
    runMetadata.status = runStatus;
    runMetadata.error = runError || null;
    writeJson(runMetadataPath, runMetadata);

    // ---- Manifest build (deterministic) ----
    const manifest = {
      run_id: runId,
      created_at_utc: nowIso(),
      files: [],
    };

    function walk(dirAbs) {
      const entries = fs.readdirSync(dirAbs, { withFileTypes: true });
      for (const ent of entries) {
        const abs = path.join(dirAbs, ent.name);
        const rel = path.relative(runDir, abs).replace(/\\/g, "/");

        // Skip temp and seal outputs while building
        if (rel.startsWith("video_temp/")) continue;
        if (rel === "manifest.json") continue;
        if (rel === "packet_hash.txt") continue;

        if (ent.isDirectory()) {
          walk(abs);
        } else if (ent.isFile()) {
          manifest.files.push({
            path: rel,
            sha256: sha256File(abs),
            size_bytes: statSize(abs),
          });
        }
      }
    }

    try {
      walk(runDir);
    } catch (e) {
      runStatus = "error";
      runError = runError || (e && e.message ? e.message : String(e));
      runMetadata.status = runStatus;
      runMetadata.error = runError;
      writeJson(runMetadataPath, runMetadata);
    }

    // Sort files deterministically
    manifest.files.sort((a, b) => a.path.localeCompare(b.path));

    // Write manifest deterministically and hash its exact bytes
    const manifestBytes = Buffer.from(stableStringify(manifest, 2), "utf-8");
    fs.writeFileSync(manifestPath, manifestBytes);

    const packetHash = sha256Bytes(manifestBytes);
    fs.writeFileSync(packetHashPath, packetHash + "\n", "utf-8");

    // Final metadata write links packet hash
    runMetadata.packet_hash = packetHash;
    runMetadata.status = runStatus;
    runMetadata.error = runError || null;
    writeJson(runMetadataPath, runMetadata);

    // ---- Required artifact assertions (hard compliance gate) ----
    try {
      // Required directories
      assertRequiredFile(runDir, "run_dir");
      assertRequiredFile(screenshotsDir, "screenshots_dir");
      assertRequiredFile(htmlDir, "screenshots/html_dir");
      assertRequiredFile(axDir, "screenshots/ax_dir");

      // Required files
      assertRequiredFile(journalPath, "journal.ndjson");
      assertRequiredFile(runMetadataPath, "run_metadata.json");
      assertRequiredFile(interactionLogPath, "interaction_log.json");
      assertRequiredFile(evidenceIndexPath, "evidence_index.json");
      assertRequiredFile(consoleLogPath, "console.json");
      assertRequiredFile(harPath, "network.har");
      assertRequiredFile(tracePath, "trace.zip");
      assertRequiredFile(manifestPath, "manifest.json");
      assertRequiredFile(packetHashPath, "packet_hash.txt");

      // Video is required per spec, enforce
      if (!videoRel) {
        throw new Error("REQUIRED ARTIFACT MISSING: video.webm (no unique video saved)");
      }
      assertRequiredFile(path.join(runDir, "video.webm"), "video.webm");
    } catch (e) {
      runStatus = "error";
      runError = runError || (e && e.message ? e.message : String(e));
      runMetadata.status = runStatus;
      runMetadata.error = runError;
      writeJson(runMetadataPath, runMetadata);
      emit({ event: "artifact.assertion_failed", error: runError });
    }

    // Emit end events
    emit({ event: "packet.sealed", manifest: "manifest.json", packet_hash: packetHash });
    emit({ event: "run.end", status: runStatus, error: runError });

    // Flush journal
    await new Promise((resolve) => journal.end(resolve));

    console.log(`RUN COMPLETE. Status: ${String(runStatus).toUpperCase()} | Dir: ${runDir}`);

    if (runStatus === "error") process.exitCode = 1;
  }
}

main().catch((e) => {
  console.error("UNEXPECTED FATAL:", e && e.message ? e.message : String(e));
  process.exitCode = 1;
});
