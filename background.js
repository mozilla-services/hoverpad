const authenticateURL = "https://kinto.dev.mozaws.net/v1/fxa-oauth/login?redirect=https://natim.github.io/get_fxa_token/%23";
const redirectIntermediate = "https://natim.github.io/get_fxa_token/#";

function tabCallback(tabId, changeInfo, updatedTab) {
  if (changeInfo.status === 'complete' && updatedTab.url.indexOf(redirectIntermediate) === 0) {
    chrome.tabs.remove(tabId);
    const bearer = updatedTab.url.split(redirectIntermediate)[1];
    chrome.storage.local.set({bearer: bearer}, function() {
      if (chrome.runtime.lastError) {
        console.error(chrome.runtime.lastError);
        chrome.runtime.sendMessage({ action: 'error', error: chrome.runtime.lastError });
      } else {
        chrome.runtime.sendMessage({ action: 'authenticated', bearer: bearer });
      }
    });
  }
}

function handleAuthentication() {
  chrome.tabs.create({ 'url': authenticateURL }, function () {
    chrome.tabs.onUpdated.addListener(tabCallback);
  });
}

chrome.runtime.onMessage.addListener(function (eventData) {
  switch (eventData.action) {
    case 'authenticate':
      handleAuthentication();
      break;
  }
});
