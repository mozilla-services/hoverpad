/* eslint-disable no-console */
/* globals encrypt:false, decrypt:false */

let app;
if (typeof Elm === 'undefined') {
  // This happens if we're in the context of Electron.
  const Elm = require('./hoverpad.js');
  app = Elm.Main.fullscreen();
} else {
  app = Elm.Main.fullscreen();
}

app.ports.getData.subscribe(function() {
  if (typeof chrome == "undefined" || typeof chrome.storage == "undefined") {
    app.ports.newData.send(localStorage.getItem('hoverpad'));
  } else {
    chrome.storage.local.get(
      'hoverpad',
      data => {
        if (chrome.runtime.lastError) {
          console.error('Nothing retrieved', chrome.runtime.lastError);
          app.ports.newError.send('Nothing retrieved');
        } else {
          app.ports.newData.send(data['hoverpad']);
        }
    });
  }
});

app.ports.saveData.subscribe(function(encrypted) {
  if (typeof chrome == "undefined" || typeof chrome.storage == "undefined") {
    localStorage.setItem('hoverpad', encrypted);
    app.ports.dataSaved.send("");
  } else {
    chrome.storage.local.set({"hoverpad": encrypted}, () => {
        if (chrome.runtime.lastError) {
          console.error('Nothing saved', chrome.runtime.lastError);
          app.ports.newError.send('Nothing saved');
        } else {
          app.ports.dataSaved.send("");
        }
    });
  }
});

app.ports.decryptData.subscribe(function(data) {
  console.log(data);
  if (!data.content) {
    app.ports.dataDecrypted.send(null);
    return;
  }
  decrypt(data.passphrase, data.content)
    .then(content => {
      app.ports.dataDecrypted.send(content);
    })
    .catch(err => {
      console.error('Error decrypting', err);
      app.ports.dataNotDecrypted.send(err.message);
    });
});

app.ports.encryptData.subscribe(function(data) {
  if (!data.content) {
    return;
  }
  encrypt(data.passphrase, data.content.replace(/<br>$/g, ''))
    .then(encryptedContent => {
      app.ports.dataEncrypted.send(encryptedContent);
    })
    .catch(err => {
      console.error('Error encrypting', err);
      app.ports.dataNotEncrypted.send(err.message);
    });
});

app.ports.blurSelection.subscribe(function(content) {
  console.log('Blur');
  document.execCommand('bold', false, null);
});

app.ports.copySelection.subscribe(function(content) {
  console.log('Copy');
  document.execCommand('copy', false, null);
});
