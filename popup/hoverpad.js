/* initialise variables */

/* Initialize storage */
if (typeof chrome == "undefined") {
  console.log('You are not in a webextensions');
}

if (!chrome.storage.hasOwnProperty('sync')) {
  throw new Error('Storage Sync API is not suppported in your browser.');
}

/* UX elements */
var inputBody = document.querySelector('.pad textarea');
inputBody.addEventListener('input', onInput);

var lock = document.querySelector('#lock');
lock.addEventListener('click', toggleLock);

/* display previously-saved stored notes on startup */

initialize();

/* generic error handler */
function onError(error) {
  console.log(error);
}


function initialize() {
  toggleLock();
  var gettingContent = chrome.storage.sync.get(
    'hoverpad', (result) => {
      if (chrome.runtime.lastError) return onError(chrome.runtime.lastError);
      inputBody.value = result.hoverpad || '';
    });
}


function toggleLock() {
  lock.classList.toggle('locked');
  if (inputBody.style.display === 'none') {
    inputBody.style.display = '';
    // Put focus at the end of the textarea.
    inputBody.focus();
    const val = inputBody.value;
    inputBody.value = '';
    inputBody.value = val.trim() + '\n';
    lock.textContent = 'Lock';
  } else {
    inputBody.style.display =  'none'
    lock.textContent = 'Unlock';
  }
}

/* function to store a new note in storage */
var timeout = null;

function onInput(event) {
  if (timeout) {
    clearTimeout(timeout);
  }
  timeout = setTimeout(function() {
    storeNote(event.target.value);
  }, 500);
}

function storeNote(body) {
  var storingNote = chrome.storage.sync.set({hoverpad: body}, () => {
    if (chrome.runtime.lastError) return onError(chrome.runtime.lastError);
    blinkGreen();
  });
}

function blinkGreen() {
  inputBody.style.backgroundColor='lightgreen';
  setTimeout(backToWhite, 200);
}


function backToWhite() {
  inputBody.style.backgroundColor='white';
}
