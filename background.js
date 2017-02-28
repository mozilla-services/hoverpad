const authenticateURL = "http://localhost:8888/v1/fxa-oauth/login?redirect=https://natim.github.io/get_fxa_token/%23";
const redirectIntermediate = "https://natim.github.io/get_fxa_token/#";

function tabCallback(tabId, changeInfo, updatedTab) {
  if (changeInfo.status == 'complete' && updatedTab.url.indexOf(redirectIntermediate) === 0) {
    browser.tabs.remove(tabId);
    const bearer = updatedTab.url.split(redirectIntermediate)[1];
    browser.storage.local.set({bearer: bearer});
    chrome.runtime.sendMessage({ action: 'authenticated' });
  }
}

function handleAuthentication() {
  browser.tabs.create({ 'url': authenticateURL }, function (tab) {
	browser.tabs.onUpdated.addListener(tabCallback);
  });
}

chrome.runtime.onMessage.addListener(function (eventData) {
  switch (eventData.action) {
    case 'authenticate':
      handleAuthentication();
      break;
  }
});
