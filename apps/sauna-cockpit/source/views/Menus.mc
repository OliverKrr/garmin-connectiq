import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Time;

// Pause menu: Resume / Save / Discard. Back resumes.
module PauseMenu {
    function push(c as SessionController) as Void {
        var m = new WatchUi.Menu2({:title => "Paused"});
        m.addItem(new WatchUi.MenuItem("Resume", null, :resume, null));
        m.addItem(new WatchUi.MenuItem("Save", null, :save, null));
        m.addItem(new WatchUi.MenuItem("Discard", null, :discard, null));
        WatchUi.pushView(m, new PauseMenuDelegate(c), WatchUi.SLIDE_UP);
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
            var e = _c.save();
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            var v = new SummaryView(e);
            WatchUi.switchToView(v, new SummaryDelegate(v, -1), WatchUi.SLIDE_IMMEDIATE);
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

    // The Confirmation pops itself; the pause menu and session view below it are replaced
    // by the start screen once the confirmation has closed.
    function onResponse(r as WatchUi.Confirm) as Boolean {
        if (r == WatchUi.CONFIRM_YES) {
            _c.discard();
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            WatchUi.switchToView(new StartView(_c), new StartDelegate(_c), WatchUi.SLIDE_IMMEDIATE);
        }
        return true;
    }
}

// Saved sessions, newest first, under 7- and 30-day totals.
module HistoryMenu {
    function push() as Void {
        var list = History.load();
        var m = new WatchUi.Menu2({:title => "History"});
        var now = Time.now().value();
        m.addItem(new WatchUi.MenuItem("7 days", totalsLine(History.totalsSince(list, now - 7 * 86400)), :week, null));
        m.addItem(new WatchUi.MenuItem("30 days", totalsLine(History.totalsSince(list, now - 30 * 86400)), :month, null));
        for (var i = 0; i < list.size(); i++) {
            var e = list[i];
            var rounds = (e[History.S_ROUNDS] as Array).size();
            var sub = rounds + "R, " + Fmt.minutes(e[History.S_TOTAL] as Number) + ", HR " +
                Fmt.num(e[History.S_AVG] as Number) + "/" + Fmt.num(e[History.S_MAX] as Number);
            m.addItem(new WatchUi.MenuItem(Theme.date(e[History.S_START] as Number), sub, i, null));
        }
        if (list.size() > 0) {
            m.addItem(new WatchUi.MenuItem("Clear history", null, :clear, null));
        }
        WatchUi.pushView(m, new HistoryMenuDelegate(), WatchUi.SLIDE_UP);
    }

    function totalsLine(t as Array<Number>) as String {
        return t[0] + "x, " + t[1] + " rounds, " + Fmt.minutes(t[2]) + " heat";
    }
}

class HistoryMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id instanceof Number) {
            var e = History.load()[id];
            var v = new SummaryView(e);
            WatchUi.pushView(v, new SummaryDelegate(v, id), WatchUi.SLIDE_LEFT);
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
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
        return true;
    }
}
