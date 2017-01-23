const KEY_PREFIX = "hoverpad";
var credentials;
var app = Elm.Main.embed(document.getElementById("root"));

app.ports.getData.subscribe(function(token) {
  // Update global credentials state;
  credentials = token.split(',', 2);
  console.log(token, credentials);

  const email = credentials[0];
  const passphrase = credentials[1];
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
    app.ports.newData.send("New pad");
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

var setDataDebounceTimeout;
app.ports.setData.subscribe(function(content) {
  if (setDataDebounceTimeout) {
    clearTimeout(setDataDebounceTimeout);
  }
  setDataDebounceTimeout = setTimeout(function() {
    const email = credentials[0];
    const passphrase = credentials[1];
    const key = KEY_PREFIX + '-' + email;

    console.log(credentials);

    encrypt(passphrase, content)
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
  }, 500);
});
