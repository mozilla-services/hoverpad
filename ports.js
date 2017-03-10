/* eslint-disable no-console */
/* globals encrypt:false, decrypt:false */
const CONTENT_KEY = "pad";

const IS_LOCAL_STORAGE = (typeof chrome == "undefined" || typeof chrome.storage == "undefined");


function getItem(key) {
  if (IS_LOCAL_STORAGE) {
    return Promise.resolve(localStorage.getItem(key));
  } else {
    return new Promise(function(resolve, reject) {
      chrome.storage.local.get(CONTENT_KEY, function(data) {
        if (chrome.runtime.lastError) {
          reject(chrome.runtime.lastError);
        } else {
          resolve(data[key] || null);
        }
      });
    });
  }
}

function setItem(key, value) {
  if (IS_LOCAL_STORAGE) {
    localStorage.setItem(key, value);
    return Promise.resolve(null);
  } else {
    return new Promise(function(resolve, reject) {
      let payload = {};
      payload[key] = value;
      chrome.storage.local.set(payload, () => {
        if (chrome.runtime.lastError) {
          reject(chrome.runtime.lastError);
        } else {
          resolve(null);
        }
      });
    });
  }
}


function createElmApp(flags) {
  let app;
  if (typeof Elm === 'undefined') {
    const Elm = require('./hoverpad.js');
    app = Elm.Main.fullscreen(flags);
  } else {
    app = Elm.Main.fullscreen(flags);
  }

  app.ports.getData.subscribe(function() {
    getItem(CONTENT_KEY)
      .then(function(data) {
        app.ports.newData.send([CONTENT_KEY, data || ""]);
      })
      .catch(function(err) {
        console.error(err);
        app.ports.newError.send('Nothing retrieved: ' + err.message);
      });
  });

  app.ports.saveData.subscribe(function(data) {
    setItem(data.key, data.content)
      .then(function() {
        app.ports.dataSaved.send("");
      })
      .catch(function(err) {
        console.error(err);
        app.ports.newError.send('Nothing retrieved: ' + err.message);
      });
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

function handleMaybeInt(maybeString) {
  const maybeInt = parseInt(maybeString, 10);
  if (Number.isNaN(maybeInt)) {
    return null;
  }
  return maybeInt;
}

getItem('lockAfterSeconds')
  .then(function(lockAfterSeconds) {
    const flags = {lockAfterSeconds: handleMaybeInt(lockAfterSeconds)};
    createElmApp(flags);
  })
  .catch(function(err) {
    console.error(err);
  });
