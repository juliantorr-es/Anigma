// background.js

browser.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.type === "sendToNative") {
        browser.runtime.sendNativeMessage("application.id", request.payload)
        .then((response) => {
            sendResponse(response);
        })
        .catch((error) => {
            sendResponse({ error: error.message });
        });
        return true; // Keep channel open
    }
});
