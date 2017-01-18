/* initialise variables */

var inputBody = document.querySelector('.pad textarea');
inputBody.addEventListener('input', onInput);

var lock = document.querySelector('#lock');
lock.addEventListener('click', toggleReadonly);

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
  var gettingContent = browser.storage.sync.get('hoverpad');
  gettingContent.then((result) => {
    inputBody.value = result.hoverpad || '';
  }, onError);
}


function toggleReadonly() {
  inputBody.readOnly = !inputBody.readOnly;
  if (inputBody.readOnly) {
    lock.textContent = 'Unlock';
  } else {
    lock.textContent = 'Lock';
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
