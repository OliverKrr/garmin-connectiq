import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Time;

// Navigation rule for every screen here: a Confirmation pops itself after onResponse, so no
// delegate pushes, pops or switches views around one. Each screen instead checks the state
// in onShow when it comes back to the top (a session that ended, a history that changed)
// and moves on from there.

// Pause menu: Resume / Save / Discard. Back resumes. Once the session has ended (Save, or
// Discard confirmed) it closes itself, and SessionView.onShow moves on.
class PauseMenu extends WatchUi.Menu2 {
    private var _c as SessionController;

    function initialize(c as SessionController) {
        Menu2.initialize({:title => "Paused"});
        _c = c;
        addItem(new WatchUi.MenuItem("Resume", null, :resume, null));
        addItem(new WatchUi.MenuItem("Save", null, :save, null));
        addItem(new WatchUi.MenuItem("Discard", null, :discard, null));
    }

    function onShow() as Void {
        if (_c.state == STATE_IDLE) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
    }

    static function push(c as SessionController) as Void {
        WatchUi.pushView(new PauseMenu(c), new PauseMenuDelegate(c), WatchUi.SLIDE_UP);
    }
}

class PauseMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _c as SessionController;

    function initialize(c as SessionController) {
        Menu2InputDelegate.initialize();
        _c = c;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :resume) {
            _c.resume();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id == :save) {
            _c.save();
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        } else if (id == :discard) {
            WatchUi.pushView(new WatchUi.Confirmation("Discard session?"), new DiscardDelegate(_c), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    function onBack() as Void {
        _c.resume();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

class DiscardDelegate extends WatchUi.ConfirmationDelegate {
    private var _c as SessionController;

    function initialize(c as SessionController) {
        ConfirmationDelegate.initialize();
        _c = c;
    }

    function onResponse(r as WatchUi.Confirm) as Boolean {
        if (r == WatchUi.CONFIRM_YES) {
            _c.discard();
        }
        return true;
    }
}

// Saved sessions, newest first, under 7- and 30-day totals. Rebuilds its items whenever it
// comes back to the top after the history changed (a deleted session, Clear history).
class HistoryMenu extends WatchUi.Menu2 {
    private var _built as Number = -1;

    function initialize() {
        Menu2.initialize({:title => "History"});
        build();
    }

    function onShow() as Void {
        if (_built != History.version) { build(); }
    }

    private function build() as Void {
        while (deleteItem(0) == true) { }
        var list = History.load();
        var now = Time.now().value();
        addItem(new WatchUi.MenuItem("7 days", totalsLine(History.totalsSince(list, now - 7 * 86400)), :week, null));
        addItem(new WatchUi.MenuItem("30 days", totalsLine(History.totalsSince(list, now - 30 * 86400)), :month, null));
        for (var i = 0; i < list.size(); i++) {
            var e = list[i];
            var rounds = (e[History.S_ROUNDS] as Array).size();
            var sub = rounds + "R, " + Fmt.minutes(e[History.S_TOTAL] as Number) + ", HR " +
                Fmt.num(History.at(e, History.S_AVG)) + "/" + Fmt.num(History.at(e, History.S_MAX));
            addItem(new WatchUi.MenuItem(Theme.date(e[History.S_START] as Number), sub, i, null));
        }
        if (list.size() > 0) {
            addItem(new WatchUi.MenuItem("Clear history", null, :clear, null));
        }
        _built = History.version;
    }

    static function totalsLine(t as Array<Number>) as String {
        return t[0] + "x, " + t[1] + (t[1] == 1 ? " round, " : " rounds, ") + Fmt.minutes(t[2]) + " heat";
    }

    static function push() as Void {
        WatchUi.pushView(new HistoryMenu(), new HistoryMenuDelegate(), WatchUi.SLIDE_UP);
    }
}

class HistoryMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id instanceof Number) {
            var list = History.load();
            if (id < list.size()) {
                var v = new SummaryView(list[id]);
                WatchUi.pushView(v, new SummaryDelegate(v, id), WatchUi.SLIDE_LEFT);
            }
        } else if (id == :clear) {
            WatchUi.pushView(new WatchUi.Confirmation("Clear all history?"), new ClearDelegate(), WatchUi.SLIDE_IMMEDIATE);
        }
    }
}

class ClearDelegate extends WatchUi.ConfirmationDelegate {
    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(r as WatchUi.Confirm) as Boolean {
        if (r == WatchUi.CONFIRM_YES) {
            History.save([] as Array<Array>);
        }
        return true;
    }
}
