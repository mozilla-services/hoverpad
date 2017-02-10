const KEY_PREFIX = "hoverpad";
var email;
var passphrase;
var app;
if (typeof(Elm) === "undefined") {
  // This happens if we're in the context of Electron.
  const Elm = require('./hoverpad.js');
  app = Elm.Main.fullscreen();
} else {
  app = Elm.Main.fullscreen();
}

app.ports.getData.subscribe(function(credentials) {
  console.log(credentials);

  email = credentials.email;
  passphrase = credentials.passphrase;
  const key = KEY_PREFIX + '-' + email;

  if (typeof chrome == "undefined" || typeof chrome.storage == "undefined") {
    decryptAndNotify(passphrase, localStorage.getItem(key));
  } else {
    chrome.storage.local.get(
      key,
      data => {
        if (chrome.runtime.lastError) {
          console.error('Nothing retrieved', chrome.runtime.lastError);
        }
        console.log('get', data);
        decryptAndNotify(passphrase, data[key]);
    });
  }
});

function decryptAndNotify(passphrase, encryptedContent) {
  console.log(email, passphrase, encryptedContent);
  if (!encryptedContent) {
    app.ports.newData.send(null);
    return;
  }
  decrypt(passphrase, encryptedContent)
    .then(content => {
      app.ports.newData.send(content);
    })
    .catch(err => {
      console.error("Error decrypting", err);
      app.ports.newError.send(err.message);
    });
}

app.ports.setData.subscribe(function(content) {
  const key = KEY_PREFIX + '-' + email;

  encrypt(passphrase, content.replace(/<br>$/g, ''))
    .then(encryptedContent => {
      if (typeof chrome == "undefined" || typeof chrome.storage == "undefined") {
        localStorage.setItem(key, encryptedContent)
        app.ports.dataSaved.send("");
      } else {
        var data = {};
        data[key] = encryptedContent;
        console.log('set', data)
        chrome.storage.local.set(
          data,
          () => {
            if (chrome.runtime.lastError) {
              console.error('Error saving to chrome.storage', chrome.runtime.lastError);
              app.ports.dataNotSaved.send(chrome.runtime.lastError);
              return;
            }
            app.ports.dataSaved.send("");
          });
      }
    })
    .catch(err => {
      console.error('Error encrypting', err);
      app.ports.dataNotSaved.send(err.message);
    });
});

app.ports.blurSelection.subscribe(function(content) {
  console.log('Blur');
  document.execCommand("bold", false, null);
});

app.ports.copySelection.subscribe(function(content) {
  console.log('Copy');
  document.execCommand("copy", false, null);
});
