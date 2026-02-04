/**
 * SKU-A: Electronic Capture Tool (ect.js)
 * VERSION: 3.6.0-LOCKED
 * PATCH: HU-2.1 (Hardened)
 */

const { chromium } = require('playwright');
const fs = require('fs-extra');
const crypto = require('crypto');
const path = require('path');

class SKUAEngine {
    constructor(manifest) {
        this.manifest = manifest; 
        this.prevHash = manifest.hash;
        this.allowedSelectors = new Set(manifest.allowed_selectors);
        this.denylist = new Set(['name', 'value', 'description', 'help', 'url', 'text', 'title', 'placeholder', 'ariaLabel']);
    }

    async initialize() {
        this.browser = await chromium.launch({ headless: true });
        const actualVersion = this.browser.version();
        
        // Toolchain Gate (TM-03)
        if (actualVersion !== this.manifest.toolchain_id) {
            console.error(`FATAL: TOOLCHAIN_MISMATCH | EXPECTED: ${this.manifest.toolchain_id} | ACTUAL: ${actualVersion}`);
            process.exit(10);
        }

        this.context = await this.browser.new_context({
            userAgent: "AccessForensics/SKU-A-Forensic-Observer/3.6",
            viewport: this.manifest.viewport
        });
        
        this.page = await this.context.new_page();

        // Mutation Probe for "DOM Settled" Detection
        await this.page.addInitScript(() => {
            window.__af_mutations = 0;
            const observer = new MutationObserver(() => window.__af_mutations++);
            observer.observe(document, { attributes: true, childList: true, subtree: true });
        });
    }

    async waitForSettled(timeout = 5000) {
        const start = Date.now();
        while (Date.now() - start < timeout) {
            const mutations = await this.page.evaluate(() => window.__af_mutations);
            const animations = await this.page.evaluate(() => 
                document.getAnimations().filter(a => a.playState === 'running').length
            );
            if (mutations === 0 && animations === 0) return true;
            await new Promise(r => setTimeout(r, 500));
        }
        throw new Error("SETTLE_TIMEOUT");
    }

    _redactRecursive(node) {
        if (!node || typeof node !== 'object') return;
        if (Array.isArray(node)) {
            node.forEach(item => this._redactRecursive(item));
        } else {
            for (const key of Object.keys(node)) {
                if (this.denylist.has(key)) {
                    node[key] = "[REDACTED_BY_MINIMIZATION_POLICY]";
                } else {
                    this._redactRecursive(node[key]);
                }
            }
        }
    }

    async captureStep(selector) {
        // Selector Authority Enforcement (SA-06)
        if (!this.allowedSelectors.has(selector)) {
            console.error(`SECURITY_ERROR: OUT_OF_SCOPE_SELECTOR | ${selector}`);
            process.exit(15);
        }

        await this.waitForSettled();

        const node = await this.page.$(selector);
        const axSnapshot = await this.page.accessibility.snapshot({ root: node });
        this._redactRecursive(axSnapshot);

        const telemetry = {
            timestamp: new Date().toISOString(),
            selector,
            ax_tree: axSnapshot,
            styles: await node.evaluate((el, props) => 
                props.reduce((a, p) => ({ ...a, [p]: getComputedStyle(el).getPropertyValue(p) }), {}), 
                this.manifest.css_allowlist
            )
        };

        this._logChained(telemetry);
    }

    _logChained(data) {
        const canonical = JSON.stringify(data, Object.keys(data).sort());
        const hash = crypto.createHash('sha256').update(this.prevHash + canonical).digest('hex');
        const entry = { prev_hash: this.prevHash, data, hash };
        this.prevHash = hash;
        fs.appendFileSync('journal.ndjson', JSON.stringify(entry) + '\n');
    }
}
