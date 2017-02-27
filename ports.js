const KEY_PREFIX = "hoverpad";
var app;
if (typeof(Elm) === "undefined") {
  // This happens if we're in the context of Electron.
  const Elm = require('./hoverpad.js');
  app = Elm.Main.fullscreen();
} else {
  app = Elm.Main.fullscreen();
}

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
      console.error("Error decrypting", err);
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
  document.execCommand("bold", false, null);
});

app.ports.copySelection.subscribe(function(content) {
  console.log('Copy');
  document.execCommand("copy", false, null);
});
