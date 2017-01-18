/* initialise variables */

var inputBody = document.querySelector('.pad textarea');
inputBody.addEventListener('input', onInput);

/* generic error handler */
function onError(error) {
  console.log(error);
}

/* display previously-saved stored notes on startup */

initialize();

function initialize() {
  var gettingContent = browser.storage.sync.get('hoverpad');
  gettingContent.then((result) => {
    inputBody.value = result.hoverpad || '';
  }, onError);
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
