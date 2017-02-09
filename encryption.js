const ivLen = 16;
const salt = '9i0+apMFBsbXMU9Kfai2Cw==';
const encoder = new TextEncoder();
const decoder = new TextDecoder();
var subtle;
if (typeof(crypto.subtle) === "undefined") {
  subtle = crypto.webkitSubtle;
} else {
  subtle = crypto.subtle;
}

/* Generate a key from a passphrase */
function generateKey(passphrase, appWiseSalt) {
  const passphraseKey = encoder.encode(md5(passphrase));
  const salt = encoder.encode(atob(appWiseSalt));

  return subtle.importKey(
    'raw',
    passphraseKey,
    'AES-CBC',
    false,
    ['encrypt', 'decrypt']
  );
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

  console.debug('encrypt', passphrase, content);

  return generateKey(passphrase, salt)
    .then(encryptionKey => {
      return subtle.encrypt(
        {name: 'AES-CBC',
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
  console.log(buf, buf.length, ivLen);
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
  try {
    var parts = separateIvFromData(encryptedData);
  } catch (err) {
    return Promise.resolve('Reset previously malformed saved pad');
  }

  console.debug('decrypt', passphrase, encryptedContent);

  return generateKey(passphrase, salt)
    .then(decryptionKey => {
      return subtle.decrypt(
        {name: 'AES-CBC',
         iv: parts.iv},
        decryptionKey,
        parts.data)
    })
    .then(decryptedArrayBuffer => {
      const decrypted = decoder.decode(decryptedArrayBuffer);
      console.debug("decrypted", decrypted);
      return decrypted
    });
}
