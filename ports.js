/* eslint-disable no-console */
/* globals encrypt:false, decrypt:false */
const CONTENT_KEY = "pad";

const IS_WEB_EXTENSION = (typeof chrome === "object" && typeof chrome.storage === "object");


function getItem(key) {
  if (!IS_WEB_EXTENSION) {
    return Promise.resolve(localStorage.getItem(key));
  } else {
    return new Promise(function(resolve, reject) {
      chrome.storage.local.get(key, function(data) {
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
  if (!IS_WEB_EXTENSION) {
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
    let promise;
    if (data.content === null) {
      promise = removeItem(data.key);
    } else {
      promise = setItem(data.key, data.content);
    }
    promise.then(function() {
      app.ports.dataSaved.send(data.key);
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

  app.ports.enableSync.subscribe(function(content) {
    if (!IS_WEB_EXTENSION) {
      document.location.href = "https://kinto.dev.mozaws.net/v1/fxa-oauth/login?redirect=http://localhost:8000/%23auth=";
    } else {
      getItem('fxaToken')
        .then(function(fxaToken) {
          if (fxaToken !== null) {
            console.log("Bearer ", fxaToken);
            app.ports.syncEnabled.send(fxaToken);
          } else {
            chrome.runtime.sendMessage({ action: 'authenticate' });
          }
        });
    }
  });

  window.addEventListener('click', function () {
    app.ports.bodyClicked.send("");
  });


  if (!IS_WEB_EXTENSION) {
    // Lecture du hash si dispo
    if (window.location.hash.indexOf("#auth=") === 0) {
      const token = window.location.hash.split('#auth=')[1];
      setItem("bearer", token)
        .then(function() {
          window.location.hash = "";
          console.log("Bearer ", token);
          app.ports.syncEnabled.send(token);
        })
        .catch(function(err) {
          app.ports.newError.send(err.message);
          console.error(err);
        });
    }
  } else {
    chrome.runtime.onMessage.addListener(function (eventData) {
      switch (eventData.action) {
      case 'authenticated':
        console.log("Bearer ", eventData.bearer);
        app.ports.syncEnabled.send(eventData.bearer);
        break;
      case 'error':
        console.error(eventData.error);
        app.ports.newError.send(eventData.error);
        break;
      }
    });
  }

  return app;
}

function handleMaybeInt(maybeString) {
  const maybeInt = parseInt(maybeString, 10);
  if (Number.isNaN(maybeInt)) {
    return null;
  }
  return maybeInt;
}

Promise.all([getItem('lockAfterSeconds'), getItem('bearer'), getItem('contentWasSynced')])
  .then(function(results) {
    console.log("Flags", results);
    const flags = {lockAfterSeconds: handleMaybeInt(results[0]),
                   fxaToken: results[1],
                   contentWasSyncedRemotely: results[2]};
    createElmApp(flags);
  })
  .catch(function(err) {
    console.error(err);
  });
