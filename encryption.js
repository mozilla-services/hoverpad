/* eslint-disable no-console */

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
        hash: 'sha-256'
      },
      key,
      {name: 'AES-GCM', length: 256},
      true,
      ['encrypt', 'decrypt']);
  });
}

function base64ToArrayBuffer(base64) {
  const binary_string =  window.atob(base64);
  const len = binary_string.length;
  const bytes = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    bytes[i] = binary_string.charCodeAt(i);
  }
  return bytes;
}

function arrayBufferToBase64(bytes) {
  let binary = '';
  const len = bytes.byteLength;
  for (let i = 0; i < len; i++) {
    binary += String.fromCharCode(bytes[ i ]);
  }
  return window.btoa(binary);
}

function joinIvAndData(iv, data) {
  const buf = new Uint8Array(iv.length + data.length);
  iv.forEach((byte, i) => {
    buf[i] = byte;
  });
  data.forEach((byte, i) => {
    buf[ivLen + i] = byte;
  });
  return buf;
}

/* Encryption using email, passphrase and content */
// eslint-disable-next-line no-unused-vars
function encrypt(passphrase, content) {
  const initVector = new Uint8Array(ivLen);
  crypto.getRandomValues(initVector);

  const data = encoder.encode(content);

  console.debug('encrypt', passphrase, content);

  return generateKey(passphrase, salt)
    .then(encryptionKey => {
      return crypto.subtle.encrypt(
        {
          name: 'AES-GCM',
          iv: initVector
        },
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
  console.log(buf, buf.length, ivLen);
  const iv = new Uint8Array(ivLen);
  const data = new Uint8Array(buf.length - ivLen);

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
// eslint-disable-next-line no-unused-vars
function decrypt(passphrase, encryptedContent) {
  const encryptedData = base64ToArrayBuffer(encryptedContent);
  let parts;
  try {
    parts = separateIvFromData(encryptedData);
  } catch (err) {
    return Promise.resolve('Reset previously malformed saved pad');
  }

  console.debug('decrypt', passphrase, encryptedContent);

  return generateKey(passphrase, salt)
    .then(decryptionKey => {
      return crypto.subtle.decrypt(
        {
          name: 'AES-GCM',
          iv: parts.iv
        },
        decryptionKey,
        parts.data);
    })
    .then(decryptedArrayBuffer => {
      const decrypted = decoder.decode(decryptedArrayBuffer);
      console.debug('decrypted', decrypted);
      return decrypted;
    });
}
