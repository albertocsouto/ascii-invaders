/*! coi-serviceworker v0.1.7 - Guido Zuidhof and contributors, licensed under MIT */
/* Enables SharedArrayBuffer on GitHub Pages by injecting COOP/COEP headers via a service worker */
let coepCredentialless = false;
if (typeof window === "undefined") {
    self.addEventListener("install", () => self.skipWaiting());
    self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()));
    self.addEventListener("fetch", function(event) {
        if (event.request.cache === "only-if-cached" && event.request.mode !== "same-origin") return;
        event.respondWith(
            fetch(event.request).then(function(response) {
                if (response.status === 0) return response;
                const newHeaders = new Headers(response.headers);
                newHeaders.set("Cross-Origin-Opener-Policy", "same-origin");
                newHeaders.set("Cross-Origin-Embedder-Policy", coepCredentialless ? "credentialless" : "require-corp");
                return new Response(response.body, {
                    status: response.status,
                    statusText: response.statusText,
                    headers: newHeaders,
                });
            }).catch(function(e) { console.error(e) })
        );
    });
} else {
    // On first load, register the service worker then reload so it takes effect
    if (!window.crossOriginIsolated) {
        navigator.serviceWorker.register(window.document.currentScript.src).then(function(reg) {
            reg.addEventListener("updatefound", function() {
                reg.installing.addEventListener("statechange", function() {
                    if (this.state === "installed") window.location.reload();
                });
            });
            if (reg.active) window.location.reload();
        });
        // Throw to prevent the rest of the page from running until we reload
        throw new Error("Registering service worker, will reload...");
    }
}
