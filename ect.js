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
        this.outputDir = path.join('artifacts', `${manifest.matter_id}_${Date.now()}`);
        fs.ensureDirSync(this.outputDir);
    }
    async initialize() {
        this.browser = await chromium.launch({ headless: true });
        this.context = await this.browser.newContext({ 
            userAgent: "AccessForensics/SKU-A-Forensic-Observer/4.3.1", 
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
    async captureMirror() {
        const content = await this.page.content();
        fs.writeFileSync(path.join(this.outputDir, 'verification_mirror.html'), content);
        return content;
    }
    async captureStep(selector) {
        const node = await this.page.$(selector);
        if (!node) return null;
        const axSnapshot = await this.page.accessibility.snapshot({ root: node });
        this._redactRecursive(axSnapshot);
        const telemetry = { timestamp: new Date().toISOString(), selector, ax_tree: axSnapshot };
        const canonical = JSON.stringify(telemetry, Object.keys(telemetry).sort());
        const hash = crypto.createHash('sha256').update(this.prevHash + canonical).digest('hex');
        const entry = { prev_hash: this.prevHash, data: telemetry, hash };
        this.prevHash = hash;
        fs.appendFileSync(path.join(this.outputDir, 'journal.ndjson'), JSON.stringify(entry) + '\n');
        return entry;
    }
    _redactRecursive(node) {
        if (!node || typeof node !== 'object') return;
        if (Array.isArray(node)) { node.forEach(i => this._redactRecursive(i)); }
        else {
            for (const k of Object.keys(node)) {
                if (this.denylist.has(k)) node[k] = "[MINIMIZED]";
                else this._redactRecursive(node[k]);
            }
        }
    }
}
module.exports = SKUAEngine;