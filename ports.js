/* eslint-disable no-console */
/* globals encrypt:false, decrypt:false */
const CONTENT_KEY = "pad";

const IS_WEB_EXTENSION = (typeof chrome === "object" && typeof chrome.storage === "object");

function storePassphrase(passphrase) {
  if (!IS_WEB_EXTENSION) {
    // Insecurely storing the passphrase.
    sessionStorage.setItem("temporaryPassphrase", btoa(passphrase));
    return Promise.resolve(null);
  } else {
    return setItem("temporaryPassphrase", passphrase);
  }
}

function dropPassphrase() {
  if (!IS_WEB_EXTENSION) {
    sessionStorage.removeItem("temporaryPassphrase");
    return Promise.resolve(null);
  } else {
    return setItem("temporaryPassphrase", null);
  }
}

function getPassphrase() {
  // Insecurely retrieving the passphrase.
  if (!IS_WEB_EXTENSION) {
    const passphrase = sessionStorage.getItem("temporaryPassphrase");
    if (passphrase === null) {
      return null;
    }
    return Promise.resolve(atob(passphrase));
  } else {
    return getItem("temporaryPassphrase");
  }
}

function getItem(key) {
  if (!IS_WEB_EXTENSION) {
    return Promise.resolve(localStorage.getItem(key));
  } else {
    return new Promise(function(resolve, reject) {
      chrome.storage.local.get(key, function(data) {
        resolve(data[key] || null);
      });
    });
  }
}

function setItem(key, value) {
  if (!IS_WEB_EXTENSION) {
    if (value === null) {
      localStorage.removeItem(key);
    } else {
      localStorage.setItem(key, value);
    }
    return Promise.resolve(null);
  } else {
    return new Promise(function(resolve, reject) {
      let payload = {};
      payload[key] = value;
      chrome.storage.local.set(payload, () => {
        resolve(null);
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
        app.ports.dataSaved.send(data.key);
      })
      .catch(function(err) {
        console.error(err);
        app.ports.newError.send('Nothing retrieved: ' + err.message);
      });
  });

  app.ports.savePassphrase.subscribe(function(passphrase) {
    storePassphrase(passphrase)
      .then(function() {
        console.log("Passphrase saved");
      })
      .catch(function(err) {
        console.error(err);
        app.ports.newError.send('Could not save passphrase: ' + err.message);
      });
  });

  app.ports.dropPassphrase.subscribe(function() {
    dropPassphrase()
      .then(function() {
        console.log("Passphrase dropped");
      })
      .catch(function(err) {
        console.error(err);
        app.ports.newError.send('Could not drop passphrase: ' + err.message);
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
      const {origin, pathname} = document.location;
      const redirect = encodeURIComponent(`${origin}${pathname}#auth=`);
      document.location.href = "https://kinto.dev.mozaws.net/v1/fxa-oauth/login?redirect=" + redirect;
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

Promise.all([
  getItem('lockAfterSeconds'),
  getItem('bearer'),
  getItem('contentWasSynced'),
  getPassphrase()
]).then(function(results) {
  const flags = {
    lockAfterSeconds: handleMaybeInt(results[0]),
    fxaToken: results[1],
    contentWasSyncedRemotely: results[2],
    passphrase: results[3]
  };
  createElmApp(flags);
}).catch(function(err) {
  console.error(err);
});
