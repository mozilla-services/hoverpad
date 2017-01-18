/* initialise variables */

var inputBody = document.querySelector('.pad textarea');
inputBody.addEventListener('input', onInput);

var lock = document.querySelector('#lock');
lock.addEventListener('click', toggleLock);

var connect = document.querySelector('#connect');
connect.addEventListener('click', openSyncPanel);

/* generic error handler */
function onError(error) {
  console.log(error);
}

/* display previously-saved stored notes on startup */

initialize();

function initialize() {
  if (typeof browser == "undefined") {
    return;
  }
  toggleLock();
  var gettingContent = browser.storage.sync.get('hoverpad');
  gettingContent.then((result) => {
    inputBody.value = result.hoverpad || '';
  }, onError);
}


function toggleLock() {
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

function openSyncPanel() {
  browser.runtime.openOptionsPage();
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
  var storingNote = browser.storage.sync.set({hoverpad: body});
  storingNote.then(blinkGreen, onError);
}

function blinkGreen() {
  inputBody.style.backgroundColor='lightgreen';
  setTimeout(backToWhite, 200);
}


function backToWhite() {
  inputBody.style.backgroundColor='white';
}
