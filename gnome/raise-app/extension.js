import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

// Same action as GNOME's switch-to-application, chosen by app id rather than dock slot.
const APPS = [
    ['firefox', 'org.mozilla.firefox.desktop'],
    ['ghostty', 'com.mitchellh.ghostty.desktop'],
    ['nautilus', 'org.gnome.Nautilus.desktop'],
];

function warpToWindow(metaWindow) {
    if (!metaWindow)
        return;
    const rect = metaWindow.get_frame_rect();
    const seat = Clutter.get_default_backend().get_default_seat();
    seat.warp_pointer(rect.x + (rect.width / 2), rect.y + (rect.height / 2));
}

function raise(appId) {
    const app = Shell.AppSystem.get_default().lookup_app(appId);
    if (!app)
        return;
    Main.overview.hide();
    app.activate();
    GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
        warpToWindow(global.display.focus_window);
        return GLib.SOURCE_REMOVE;
    });
}

export default class RaiseAppExtension extends Extension {
    enable() {
        this._settings = this.getSettings();
        const mode = Shell.ActionMode.NORMAL | Shell.ActionMode.OVERVIEW;
        const flags = Meta.KeyBindingFlags.IGNORE_AUTOREPEAT;
        for (const [key, appId] of APPS) {
            Main.wm.addKeybinding(key, this._settings, flags, mode, () => {
                raise(appId);
            });
        }
    }

    disable() {
        for (const [key] of APPS)
            Main.wm.removeKeybinding(key);
        this._settings = null;
    }
}
