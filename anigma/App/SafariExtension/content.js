// content.js

function capturePage() {
    const payload = {
        type: "capture",
        title: document.title,
        url: window.location.href,
        html: document.documentElement.outerHTML
    };
    
    browser.runtime.sendMessage({
        type: "sendToNative",
        payload: payload
    });
}

// Listen for messages from popup or background
browser.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === "capture") {
        capturePage();
        sendResponse({ status: "capturing" });
    }
});
