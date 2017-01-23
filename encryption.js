const ivLen = 16;
const salt = '9i0+apMFBsbXMU9Kfai2Cw==';
const encoder = new TextEncoder();
const decoder = new TextDecoder();

/* Generate a key from a passphrase */
function generateKey(passphrase, appWiseSalt) {
  const passphraseKey = encoder.encode(passphrase);
  const salt = encoder.encode(atob(appWiseSalt));

  return crypto.subtle.importKey(
    'raw',
    passphraseKey,
    'PBKDF2',
    false,
    ['deriveKey']
  ).then(key => {
    return crypto.subtle.deriveKey(
      {
        name: 'PBKDF2',
        salt: salt,
        iterations: 1000,
        'hash': 'sha-256'},
      key,
      {name: 'AES-GCM', 'length': 256},
      true,
      ['encrypt', 'decrypt']);
  });
}

function base64ToArrayBuffer(base64) {
    var binary_string =  window.atob(base64);
    var len = binary_string.length;
    var bytes = new Uint8Array( len );
    for (var i = 0; i < len; i++)        {
        bytes[i] = binary_string.charCodeAt(i);
    }
    return bytes;
}

function arrayBufferToBase64( bytes ) {
    var binary = '';
    var len = bytes.byteLength;
    for (var i = 0; i < len; i++) {
        binary += String.fromCharCode( bytes[ i ] );
    }
    return window.btoa( binary );
}

function joinIvAndData(iv, data) {
  console.log(iv, data);
  let buf = new Uint8Array(iv.length + data.length);
  iv.forEach((byte, i) => {
    buf[i] = byte;
  });
  data.forEach((byte, i) => {
    buf[ivLen + i] = byte;
  });
  return buf;
}

/* Encryption using email, passphrase and content */
function encrypt(passphrase, content) {
  let initVector = new Uint8Array(ivLen);
  crypto.getRandomValues(initVector);

  const passphraseKey = encoder.encode(passphrase);
  const data = encoder.encode(content);

  console.log('encrypt', passphrase, content);

  return generateKey(passphrase, salt)
    .then(encryptionKey => {
      return crypto.subtle.encrypt(
        {name: 'AES-GCM',
         iv: initVector},
        encryptionKey,
        data);
    })
    .then(encryptedData => {
      const encryptedContent = joinIvAndData(initVector, new Uint8Array(encryptedData));
      const encrypted = arrayBufferToBase64(encryptedContent);
      console.log(encrypted);
      return encrypted;
    });
}

function separateIvFromData(buf) {
  console.log(buf, buf.length);
  var iv = new Uint8Array(ivLen);
  var data = new Uint8Array(buf.length - ivLen);

  buf.forEach((byte, i) => {
    if (i < ivLen) {
      iv[i] = byte;
    } else {
      data[i - ivLen] = byte;
    }
  });
  console.log(iv, data);
  return { iv, data };
}

/* Decryption using email, passphrase and content */
function decrypt(passphrase, encryptedContent) {
  const passphraseKey = encoder.encode(passphrase);
  const encryptedData = base64ToArrayBuffer(encryptedContent);
  var parts = separateIvFromData(encryptedData);

  console.log('decrypt', passphrase, encryptedContent);

  return generateKey(passphrase, salt)
    .then(decryptionKey => {
      return crypto.subtle.decrypt(
        {name: 'AES-GCM',
         iv: parts.iv},
        decryptionKey,
        parts.data)
    })
    .then(decryptedArrayBuffer => {
      return decoder.decode(decryptedArrayBuffer);
    });
}
