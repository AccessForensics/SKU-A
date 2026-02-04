const SKUAEngine = require('./ect.js');
const fs = require('fs');

async function runTriage() {
    try {
        const manifest = JSON.parse(fs.readFileSync('triage_manifest.json', 'utf8').trim());
        const engine = new SKUAEngine(manifest);
        await engine.initialize();
        
        console.log(`NAVIGATING: ${manifest.url}`);
        await engine.page.goto(manifest.url, { waitUntil: 'networkidle', timeout: 30000 });

        let confirmationFound = false;
        let mechanicalVerb = "NONE";

        for (const selector of manifest.allowed_selectors) {
            try {
                await engine.waitForSettled();
                const node = await engine.page.$(selector);
                
                // PANEL FIX: If selector is missing, that is a reproduction of a broken path/site state.
                if (!node) {
                    confirmationFound = true;
                    mechanicalVerb = `SELECTOR_ABSENT: ${selector}`;
                    break;
                }

                // PANEL FIX: Real keyboard simulation to detect focusability
                await engine.page.keyboard.press('Tab');
                const isFocused = await engine.page.evaluate((s) => {
                    const el = document.querySelector(s);
                    return document.activeElement === el;
                }, selector);

                // If element exists but refuses focus, reproduction confirmed.
                if (!isFocused) {
                    confirmationFound = true;
                    mechanicalVerb = `FOCUS_DENIED: ${selector}`;
                    break; 
                }
            } catch (e) { continue; }
        }
        await engine.browser.close();
        
        console.log("\n------------------------------------------------------------");
        if (confirmationFound) {
            console.log(`RESULT: [ YES ] - REPRODUCIBILITY CONFIRMED`);
            console.log(`SIGNAL: ${mechanicalVerb}`);
        } else {
            console.log("RESULT: [ NO ] - NOT REPRODUCED");
        }
        console.log("------------------------------------------------------------\n");
    } catch (err) { console.error("CRITICAL_FAIL: " + err.message); }
}
runTriage();