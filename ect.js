const { chromium } = require('playwright');
const fs = require('fs-extra');
const crypto = require('crypto');
const path = require('path');

class SKUAEngine {
    constructor(manifest) {
        this.manifest = manifest; 
        this.prevHash = manifest.hash || '00000000000000000000000000000000';
        this.allowedSelectors = new Set(manifest.allowed_selectors);
        this.denylist = new Set(['name', 'value', 'description', 'help', 'url', 'text', 'title', 'placeholder', 'ariaLabel']);
        this.outputDir = manifest.mode === 'FULL_CAPTURE' ? 
            path.join('artifacts', `${manifest.matter_id}_${Date.now()}`) : null;
        if (this.outputDir) fs.ensureDirSync(this.outputDir);
    }

    async initialize() {
        this.browser = await chromium.launch({ headless: true });
        this.context = await this.browser.newContext({
            userAgent: "AccessForensics/SKU-A-Forensic-Observer/3.6.7",
            viewport: this.manifest.viewport,
            ignoreHTTPSErrors: true
        });
        this.page = await this.context.newPage();
        await this.page.addInitScript(() => {
            window.__af_mutations = 0;
            const observer = new MutationObserver(() => window.__af_mutations++);
            observer.observe(document, { attributes: true, childList: true, subtree: true });
        });
    }

    async waitForSettled(timeout = 10000) {
        const start = Date.now();
        let lastCount = await this.page.evaluate(() => window.__af_mutations);
        while (Date.now() - start < timeout) {
            await new Promise(r => setTimeout(r, 750));
            const currentCount = await this.page.evaluate(() => window.__af_mutations);
            const finiteAnimations = await this.page.evaluate(() => 
                document.getAnimations().filter(a => a.playState === 'running' && a.effect && a.effect.getTiming().iterations !== Infinity).length
            );
            if (currentCount === lastCount && finiteAnimations === 0) return true;
            lastCount = currentCount;
        }
    }

    _redactRecursive(node) {
        if (!node || typeof node !== 'object') return;
        if (Array.isArray(node)) { node.forEach(item => this._redactRecursive(item)); }
        else {
            for (const key of Object.keys(node)) {
                if (this.denylist.has(key)) node[key] = "[REDACTED_FOR_MINIMIZATION]";
                else this._redactRecursive(node[key]);
            }
        }
    }

    async captureStep(selector, interaction = "PASSIVE") {
        if (!this.allowedSelectors.has(selector)) { process.exit(15); }
        await this.waitForSettled();
        const node = await this.page.$(selector);
        if (!node) return null;
        
        const axSnapshot = await this.page.accessibility.snapshot({ root: node });
        this._redactRecursive(axSnapshot);
        const telemetry = {
            timestamp: new Date().toISOString(),
            selector, interaction, ax_tree: axSnapshot,
            styles: await node.evaluate((el, props) => props.reduce((a, p) => ({ ...a, [p]: getComputedStyle(el).getPropertyValue(p) }), {}), this.manifest.css_allowlist || [])
        };

        const canonical = JSON.stringify(telemetry, Object.keys(telemetry).sort());
        const hash = crypto.createHash('sha256').update(this.prevHash + canonical).digest('hex');
        const entry = { prev_hash: this.prevHash, data: telemetry, hash };
        this.prevHash = hash;
        
        if (this.outputDir) {
            const jp = path.join(this.outputDir, 'journal.ndjson');
            fs.appendFileSync(jp, JSON.stringify(entry) + '\n');
        }
        return entry;
    }
}
module.exports = SKUAEngine;