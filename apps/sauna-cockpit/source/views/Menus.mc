import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Time;

// Navigation rule for every screen here: a Confirmation pops itself after onResponse, so no
// delegate pushes, pops or switches views around one. Each screen instead checks the state
// in onShow when it comes back to the top (a session that ended, a history that changed)
// and moves on from there.

// Pause menu: Resume / Settings / Save / Discard. Back resumes. Once the session has ended (Save, or
// Discard confirmed) it closes itself, and SessionView.onShow moves on.
class PauseMenu extends WatchUi.Menu2 {
    private var _c as SessionController;

    function initialize(c as SessionController) {
        Menu2.initialize({:title => "Paused"});
        _c = c;
        addItem(new WatchUi.MenuItem("Resume", null, :resume, null));
        addItem(new WatchUi.MenuItem("Settings", null, :settings, null));
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
        } else if (id == :settings) {
            SettingsMenu.push(_c);
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

// Settings on the watch, before or during a session (MENU, or Settings in the pause menu). They
// write the same properties as the Garmin Connect settings, and a running session takes new
// targets and limits at once. Recording options only show while no session runs, since they
// apply when one starts. Number settings open a ChoiceMenu of values.
class SettingsMenu extends WatchUi.Menu2 {
    // [id, title] of the value settings; ids are property keys, except "heat"/"cool" (target
    // minutes, 0 = off, stored as two properties).
    static const CHOICES = [
        ["heat", "Heat target"], ["cool", "Rest target"],
        ["heatScreen", "Heat screen"], ["restScreen", "Rest screen"],
        ["tempWarn", "Temp pre-warning"], ["tempLimit", "Temp alert"], ["hrLimit", "HR alert"],
    ];
    static const TOGGLES = [["alertVibrate", "Vibrate"], ["alertTone", "Beep"], ["alertLight", "Light up"]];

    function initialize(c as SessionController) {
        Menu2.initialize({:title => "Settings"});
        for (var i = 0; i < CHOICES.size(); i++) {
            addItem(new WatchUi.MenuItem(CHOICES[i][1], label(CHOICES[i][0]), CHOICES[i][0], null));
        }
        for (var i = 0; i < TOGGLES.size(); i++) {
            addItem(new WatchUi.ToggleMenuItem(TOGGLES[i][1], null, TOGGLES[i][0], Config._bool(TOGGLES[i][0], i != 1), null));
        }
        if (c.state == STATE_IDLE) {
            addItem(new WatchUi.MenuItem("Record as", label("recordAs"), "recordAs", null));
            addItem(new WatchUi.ToggleMenuItem("Save activity", null, "recordActivity", Config.recordActivity(), null));
        }
    }

    // Back from a ChoiceMenu: show the value just chosen.
    function onShow() as Void {
        for (var i = 0; i < CHOICES.size(); i++) {
            var item = getItem(i);
            if (item != null) { item.setSubLabel(label(CHOICES[i][0])); }
        }
        var idx = findItemById("recordAs");
        if (idx >= 0) { (getItem(idx) as WatchUi.MenuItem).setSubLabel(label("recordAs")); }
    }

    static function push(c as SessionController) as Void {
        WatchUi.pushView(new SettingsMenu(c), new SettingsMenuDelegate(c), WatchUi.SLIDE_UP);
    }

    // [label, value] choices of a value setting.
    static function options(id as String) as Array<Array> {
        var o = [] as Array<Array>;
        if (id.equals("heatScreen") || id.equals("restScreen")) {
            return [["Normal", SCREEN_NORMAL], ["Dim", SCREEN_DIM], ["Dark", SCREEN_DARK]];
        }
        if (id.equals("recordAs")) { return [["Other", 0], ["Meditation", 1]]; }
        o.add(["Off", 0]);
        if (id.equals("heat") || id.equals("cool")) {
            for (var v = 1; v <= 30; v++) { o.add([v + " min", v]); }
        } else if (id.equals("hrLimit")) {
            for (var v = 120; v <= 200; v += 5) { o.add([v + " bpm", v]); }
        } else {
            for (var v = id.equals("tempWarn") ? 36 : 38; v <= 55; v++) { o.add([v + "°C", v]); }
        }
        return o;
    }

    static function current(id as String) as Number {
        if (id.equals("heat")) { return Config.heatTargetMin(); }
        if (id.equals("cool")) { return Config.coolTargetMin(); }
        if (id.equals("heatScreen")) { return Config.heatScreen(); }
        if (id.equals("restScreen")) { return Config.restScreen(); }
        if (id.equals("tempWarn")) { return Config.tempWarn(); }
        if (id.equals("tempLimit")) { return Config.tempLimit(); }
        if (id.equals("hrLimit")) { return Config.hrLimit(); }
        return Config.recordAsMeditation() ? 1 : 0;
    }

    static function label(id as String) as String {
        var o = options(id);
        var v = current(id);
        for (var i = 0; i < o.size(); i++) {
            if (o[i][1] == v) { return o[i][0] as String; }
        }
        return v.toString();
    }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _c as SessionController;

    function initialize(c as SessionController) {
        Menu2InputDelegate.initialize();
        _c = c;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        if (item instanceof WatchUi.ToggleMenuItem) {
            Config.set(id, (item as WatchUi.ToggleMenuItem).isEnabled());
            return;
        }
        var o = SettingsMenu.options(id);
        var v = SettingsMenu.current(id);
        var focus = 0;
        for (var i = 0; i < o.size(); i++) {
            if (o[i][1] == v) { focus = i; }
        }
        var m = new WatchUi.Menu2({:title => item.getLabel(), :focus => focus});
        for (var i = 0; i < o.size(); i++) {
            m.addItem(new WatchUi.MenuItem(o[i][0] as String, null, o[i][1], null));
        }
        WatchUi.pushView(m, new ChoiceDelegate(_c, id), WatchUi.SLIDE_LEFT);
    }
}

// One value setting's choices; selecting one stores it and goes back.
class ChoiceDelegate extends WatchUi.Menu2InputDelegate {
    private var _c as SessionController;
    private var _id as String;

    function initialize(c as SessionController, id as String) {
        Menu2InputDelegate.initialize();
        _c = c;
        _id = id;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var v = item.getId() as Number;
        if (_id.equals("heat")) {
            Config.setHeatTargetMin(v);
        } else if (_id.equals("cool")) {
            Config.setCoolTargetMin(v);
        } else {
            Config.set(_id, v);
        }
        _c.applySettings();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
