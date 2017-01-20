const KEY_PREFIX = "hoverpad";
var credentials;

app.ports.getData.subscribe(function(token) {
  // Update global credentials state;
  credentials = token.split(',', 2);
  console.log(token, credentials);
  
  const email = credentials[0];
  const passphrase = credentials[1];
  const key = KEY_PREFIX + '-' + email;
  
  if (typeof chrome == "undefined") {
    decryptAndNotify(email, passphrase, localStorage.getItem(key));
  } else {
    chrome.storage.local.get(
      key,
      data => {
        if (chrome.runtime.lastError) {
          console.error('Nothing retrieved', chrome.runtime.lastError);
        }
        decryptAndNotify(email, passphrase, data[key]);
    });
  }
});

function decryptAndNotify(email, passphrase, encryptedContent) {
  console.log(email, passphrase, encryptedContent);
  if (!encryptedContent) {
    app.ports.newData.send(["ok", "New pad"]);
    return;
  }
  decrypt(email, passphrase, encryptedContent)
    .then(content => {
      app.ports.newData.send(["ok", content]);
    })
    .catch(err => {
      console.error("Error decrypting", err);
      app.ports.newData.send(["nok", "" + err]);
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

    encrypt(email, passphrase, content)
      .then(encryptedContent => {
        if (typeof chrome == "undefined") {
          localStorage.setItem(key, encryptedContent)
          app.ports.dataSaved.send("ok");
        } else {
          var data = {};
          data[key] = content;
          chrome.storage.local.set(
            data,
            () => {
              if (chrome.runtime.lastError) {
                console.error('Error saving to chrome.storage', chrome.runtime.lastError);
                app.ports.dataSaved.send("nok");
                return;
              }
              app.ports.dataSaved.send("ok");
            });
        }
      })
      .catch(err => {
        console.error('Error encrypting', err);
        app.ports.dataSaved.send("nok");
      });
  }, 500);
});
