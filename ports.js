/* eslint-disable no-console */
/* globals encrypt:false, decrypt:false */

function createElmApp(flags) {
  let app;
  if (typeof Elm === 'undefined') {
    const Elm = require('./hoverpad.js');
    app = Elm.Main.fullscreen(flags);
  } else {
    app = Elm.Main.fullscreen(flags);
  }

  app.ports.getData.subscribe(function() {
    if (typeof chrome == "undefined" || typeof chrome.storage == "undefined") {
      let data = localStorage.getItem('hoverpad');
      app.ports.newData.send(["hoverpad", data || ""]);
    } else {
      chrome.storage.local.get(
        'hoverpad',
        data => {
          if (chrome.runtime.lastError) {
            console.error('Nothing retrieved', chrome.runtime.lastError);
            app.ports.newError.send('Nothing retrieved');
          } else {
            console.log(data);
            app.ports.newData.send(['hoverpad', data['hoverpad'] || ""]);
          }
      });
    }
  });

  app.ports.saveData.subscribe(function(data) {
    if (typeof chrome == "undefined" || typeof chrome.storage == "undefined") {
      localStorage.setItem(data.key, data.content);
      app.ports.dataSaved.send("");
    } else {
      let payload = {};
      payload[data.key] = data.content;
      chrome.storage.local.set(payload, () => {
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
    document.execCommand('bold', false, null);
  });

  app.ports.copySelection.subscribe(function(content) {
    document.execCommand('copy', false, null);
  });

  window.addEventListener('click', function () {
    app.ports.bodyClicked.send("");
  });

  return app;
}

if (typeof chrome == "undefined" || typeof chrome.storage == "undefined") {
  createElmApp({lockAfterSeconds: localStorage.getItem('lockAfterSeconds'),
                lastModified: localStorage.getItem('lastModified')});
} else {
  chrome.storage.local.get(
    ['lockAfterSeconds', 'lastModified'],
    data => {
      createElmApp({lockAfterSeconds: data['lockAfterSeconds'],
                    lastModified: data['lastModified']});
    });
}
