document.addEventListener('DOMContentLoaded', function () {
  browser.storage.local.get('bearer').then((data) => {
    if ('bearer' in data) {
      document.querySelector('a#login').style.display = "none";
      console.log("Bearer ", data.bearer);
    }
  });
  document.querySelector('a#login').addEventListener("click", (event) => {
    event.preventDefault();
    chrome.runtime.sendMessage({ action: 'authenticate' });
  });
  chrome.runtime.onMessage.addListener(function (eventData) {
    console.log(eventData);
    switch (eventData.action) {
      case 'authenticated':
        console.log("Bearer ", eventData.bearer);
        break;
    }
  });
});
