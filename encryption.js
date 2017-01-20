const encoder = new TextEncoder();
const decoder = new TextDecoder();

/* Encryption using email, passphrase and content */
function encrypt(email, passphrase, content) {
  const initVector = encoder.encode(email);
  const passphraseKey = encoder.encode(passphrase);
  const data = encoder.encode(content);

  return crypto.subtle.importKey(
      'raw',
      passphraseKey,
      'PBKDF2',
      false,
      ['deriveBits', 'deriveKey']
    )
    .then(key => {
      return crypto.subtle.deriveKey(
        {
          name: 'PBKDF2',
          salt: initVector,
          iterations: 100,
          'hash': 'sha-256'},
        key,
        {name: 'AES-GCM', 'length': 256},
        false,
        ['encrypt', 'decrypt']);
    })
    .then(encryptionKey => {
      return crypto.subtle.encrypt(
        {name: 'AES-GCM',
         iv: initVector},
        encryptionKey,
        data);
    });
}


/* Decryption using email, passphrase and content */
function decrypt(email, passphrase, encryptedContent) {
  const initVector = encoder.encode(email);
  const passphraseKey = encoder.encode(passphrase);
  const encryptedData = encoder.encode(content);
  return crypto.subtle.importKey(
    'raw',
    passphraseKey,
    'PBKDF2',
    false,
    ['deriveBits', 'deriveKey']
  ).then(key => {
    return crypto.subtle.deriveKey(
      {name: 'PBKDF2',
       salt: initVector,
       iterations: 100,
       'hash': 'sha-256'},
      key,
      {name: 'AES-GCM', 'length': 256},
      false,
      ['encrypt', 'decrypt']);
  }).then(encryptionKey => {
    return crypto.subtle.decrypt(
      {name: 'AES-GCM',
       iv: initVector},
      encryptionKey,
      encryptedData)
  });
}
