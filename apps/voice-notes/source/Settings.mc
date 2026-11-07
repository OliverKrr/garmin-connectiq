import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// MENU, Settings: the settings that make sense to change on the watch, written to the same
// Application.Properties the phone's Connect IQ app edits, so both stay one source of truth.
// Upload URL, token and piece size stay phone-only.
module Settings {
    // Property, menu title, unit, choices.
    const PICKERS = {
        "keepDays" => ["Keep uploaded", "days", [0, 1, 3, 7, 14, 30]],
        "keepKb" => ["Watch space", "KB", [256, 512, 1024, 2048]],
        "retryMin" => ["Retry every", "min", [5, 15, 30, 60]],
        "maxMin" => ["Longest note", "min", [5, 10, 20, 30]]
    };
    const ORDER = ["keepDays", "keepKb", "retryMin", "maxMin"];

    function number(key as String, fallback as Number) as Number {
        var v = Application.Properties.getValue(key);
        return v instanceof Number ? v : fallback;
    }

    function label(key as String) as String {
        var p = PICKERS[key] as Array;
        var v = number(key, -1);
        if (key.equals("keepDays") && v == 0) { return "delete after upload"; }
        return v + " " + (p[1] as String);
    }

    function show(n as Notes) as Void {
        var m = new WatchUi.Menu2({:title => "Settings"});
        for (var i = 0; i < ORDER.size(); i++) {
            var key = ORDER[i] as String;
            m.addItem(new WatchUi.MenuItem((PICKERS[key] as Array)[0] as String, label(key), key, null));
        }
        var lte = Application.Properties.getValue("useLte");
        m.addItem(new WatchUi.ToggleMenuItem("Upload over LTE", {:enabled => "on", :disabled => "off"},
            "useLte", lte instanceof Boolean ? lte : true, null));
        WatchUi.pushView(m, new SettingsDelegate(n), WatchUi.SLIDE_LEFT);
    }

    // After a change made on the watch (onSettingsChanged fires only for the phone's edits).
    function applied(key as String, n as Notes) as Void {
        if (key.equals("retryMin")) {
            NotesApp.scheduleRetry();
        } else if (key.equals("keepDays") || key.equals("keepKb")) {
            Queue.prune();
            n.home();
        }
    }
}

class SettingsDelegate extends WatchUi.Menu2InputDelegate {
    private var _n as Notes;

    function initialize(n as Notes) {
        Menu2InputDelegate.initialize();
        _n = n;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var key = item.getId() as String;
        if (item instanceof WatchUi.ToggleMenuItem) {
            Application.Properties.setValue(key, item.isEnabled());
            return;
        }
        var p = Settings.PICKERS[key] as Array;
        var choices = p[2] as Array<Number>;
        var current = Settings.number(key, -1);
        var m = new WatchUi.Menu2({:title => p[0] as String});
        var focus = 0;
        for (var i = 0; i < choices.size(); i++) {
            var v = choices[i];
            var text = (key.equals("keepDays") && v == 0) ? "0 (delete after upload)" : v + " " + (p[1] as String);
            m.addItem(new WatchUi.MenuItem(text, null, v, null));
            if (v == current) { focus = i; }
        }
        m.setFocus(focus);
        WatchUi.pushView(m, new ChoiceDelegate(_n, key, item), WatchUi.SLIDE_LEFT);
    }
}

class ChoiceDelegate extends WatchUi.Menu2InputDelegate {
    private var _n as Notes;
    private var _key as String;
    private var _parent as WatchUi.MenuItem;

    function initialize(n as Notes, key as String, parent as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _n = n;
        _key = key;
        _parent = parent;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        Application.Properties.setValue(_key, item.getId() as Number);
        _parent.setSubLabel(Settings.label(_key));
        Settings.applied(_key, _n);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
