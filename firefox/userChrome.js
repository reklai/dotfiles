// Ghostty Super shortcuts, added beside Firefox's Ctrl shortcuts.
// Numbered tabs (Super+1-4) and Super+E are intentionally absent.
// Brackets follow macOS: Super+[ ] is back and forward, Super+Shift+[ ] is tabs.
(function () {
	if (window.__ghosttyKeys) {
		return;
	}
	window.__ghosttyKeys = true;

	const binds = [
		{ key: "x", shift: false, command: "cmd_cut" },
		{ key: "c", shift: false, command: "cmd_copy" },
		{ key: "v", shift: false, command: "cmd_paste" },
		{ key: "t", shift: false, command: "cmd_newNavigatorTabNoEvent" },
		{ key: "w", shift: false, command: "cmd_close" },
		{ key: "w", shift: true, command: "cmd_closeWindow" },
		{ key: "e", shift: true, command: "cmd_newNavigator" },
		{ key: "q", shift: false, command: "cmd_quitApplication" },
		{ key: "r", shift: false, command: "Browser:Reload" },
		{ key: "r", shift: true, command: "Browser:ReloadSkipCache" },
		{ code: "BracketLeft", shift: false, command: "Browser:Back" },
		{ code: "BracketRight", shift: false, command: "Browser:Forward" },
		{ code: "BracketLeft", shift: true, command: "Browser:PrevTab" },
		{ code: "BracketRight", shift: true, command: "Browser:NextTab" },
	];

	function run(command) {
		const el = document.getElementById(command);
		if (el && typeof el.doCommand === "function") {
			el.doCommand();
			return;
		}
		if (typeof goDoCommand === "function") {
			goDoCommand(command);
		}
	}

	// Ctrl+N and Ctrl+P as Down and Up, like macOS. Replaces New Window and Print.
	const arrows = { n: "ArrowDown", p: "ArrowUp" };

	function pressArrow(name) {
		// The address bar list is moved directly; it needs no key event.
		try {
			if (gURLBar.view.isOpen) {
				gURLBar.view.selectBy(1, { reverse: name === "ArrowUp" });
				return;
			}
		} catch (error) {
			console.error(error);
		}
		// A key cannot be sent while the real one is still being dispatched.
		setTimeout(() => sendArrow(name), 0);
	}

	function sendArrow(name) {
		const tip = Cc["@mozilla.org/text-input-processor;1"].createInstance(Ci.nsITextInputProcessor);
		if (!tip.beginInputTransactionForTests(window)) {
			return;
		}
		const press = new KeyboardEvent("", {
			key: name,
			code: name,
			keyCode: name === "ArrowDown" ? KeyboardEvent.DOM_VK_DOWN : KeyboardEvent.DOM_VK_UP,
		});
		tip.keydown(press);
		tip.keyup(press);
	}

	window.addEventListener(
		"keydown",
		(event) => {
			if (event.ctrlKey && !event.metaKey && !event.altKey && !event.shiftKey) {
				const arrow = arrows[event.key.toLowerCase()];
				if (arrow) {
					event.preventDefault();
					event.stopPropagation();
					pressArrow(arrow);
				}
				return;
			}
			if (!event.metaKey || event.ctrlKey || event.altKey || event.repeat) {
				return;
			}
			const key = event.key.toLowerCase();
			const bind = binds.find((item) => {
				if (item.shift !== event.shiftKey) {
					return false;
				}
				// Shift+[ is "{", so brackets match the physical key.
				if (item.code) {
					return item.code === event.code;
				}
				return item.key === key;
			});
			if (!bind) {
				return;
			}
			event.preventDefault();
			event.stopPropagation();
			run(bind.command);
		},
		true,
	);
})();
