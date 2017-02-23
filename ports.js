/* globals encrypt:false, decrypt:false */

const KEY_PREFIX = 'hoverpad';
let app;
if (typeof(Elm) === 'undefined') {
  // This happens if we're in the context of Electron.
  const Elm = require('./hoverpad.js');
  app = Elm.Main.fullscreen();
} else {
  app = Elm.Main.fullscreen();
}

app.ports.decryptData.subscribe(function(data) {
  // eslint-disable-next-line no-console
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
      // eslint-disable-next-line no-console
      console.error('Error decrypting', err);
      app.ports.dataNotDecrypted.send(err.message);
    });
});

app.ports.encryptData.subscribe(function(data) {
  encrypt(data.passphrase, data.content.replace(/<br>$/g, ''))
    .then(encryptedContent => {
      app.ports.dataEncrypted.send(encryptedContent);
    })
    .catch(err => {
      // eslint-disable-next-line no-console
      console.error('Error encrypting', err);
      app.ports.dataNotEncrypted.send(err.message);
    });
});

app.ports.blurSelection.subscribe(function(content) {
  // eslint-disable-next-line no-console
  console.log('Blur');
  document.execCommand('bold', false, null);
});

app.ports.copySelection.subscribe(function(content) {
  // eslint-disable-next-line no-console
  console.log('Copy');
  document.execCommand('copy', false, null);
});
