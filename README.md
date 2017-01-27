# Hoverpad

![Hoverpad](https://cloud.githubusercontent.com/assets/229453/22067769/f0b61f04-dd92-11e6-8c3b-3360963144a8.png)

A persistent pad — click a button in your browser and add some notes,
which will persist even after browser restarts and be synced between
your browsers.

Works in Firefox 53+, and will also work as a Chrome extension, out of
the box.

Try out [the demo](https://mozilla-services.github.io/hoverpad/)

## What it does

This extension includes:

* A browser action that creates a popup — within the popup is:
	* A form elements for entering the body text.
		
Hoverpad uses the WebExtensions
[Storage API](https://developer.mozilla.org/en-US/Add-ons/WebExtensions/API/storage)
to persist the notes.

## What it shows

* How to persist data in a WebExtension using the Storage Sync API.

## How to try the addon in Firefox?

**You will need Firefox Beta or Firefox Nightly to use this addons.**

### From addons.mozilla.org

Grab it from AMO: https://addons.mozilla.org/fr/firefox/addon/hoverpad/

If you want to install while it is not verified yet, you can:

1. Go to `about:config`
2. Toggle `xpinstall.signatures.required` to true
3. You will get automatic updates

If you don't care about automatic updates, you can also install the latest XPI from there: https://github.com/Natim/hoverpad/releases

### From the source code

1. Go to `about:debugging`
2. Click the Load a temporary module
3. Select the manifest.json
4. You would need to do that each time you restart Firefox.
5. You can click on the `Refresh` button to change the files and reload the add-on.

## How to try the addon in Chrome?


### From the Chrome Store

Grab it from the Chrome Store: https://chrome.google.com/webstore/detail/hoverpad/kedanmokpljgpkgfojeoigehigpoljie

### From the source code

1. Go to ``chrome://extensions``
2. Tick the Developer Mode
3. Load the hoverpad repository folder.
