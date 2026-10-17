import Toybox.Lang;
import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Time;

// Idle screen: live HR and watch temperature, the last session and the 7-day totals.
// START begins a session, DOWN/MENU opens the history, BACK exits.
class StartView extends WatchUi.View {
    private var _c as SessionController;
    private var _last as String = "";
    private var _week as String = "";

    function initialize(c as SessionController) {
        View.initialize();
        _c = c;
    }

    function onShow() as Void {
        var list = History.load();
        _last = list.size() > 0 ? lastLine(list[0]) : "No sessions yet";
        var t = History.totalsSince(list, Time.now().value() - 7 * 86400);
        _week = "7 days: " + t[0] + "x, " + t[1] + " rounds, " + Fmt.minutes(t[2]);
    }

    private function lastLine(e as Array) as String {
        var rounds = (e[History.S_ROUNDS] as Array).size();
        return "Last: " + Theme.date(e[History.S_START] as Number) + ", " + rounds + (rounds == 1 ? " round" : " rounds");
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        dc.setColor(Theme.FG, Theme.BG);
        dc.clear();
        // START button hint at about 2 o'clock, where the fēnix/Enduro START key sits.
        dc.setPenWidth(w * 4 / 100);
        dc.setColor(Theme.GO, Theme.BG);
        dc.drawArc(cx, h / 2, w / 2 - w * 2 / 100 - 1, Graphics.ARC_CLOCKWISE, 40, 20);
        dc.setPenWidth(1);

        Theme.text(dc, cx, h * 20 / 100, Graphics.FONT_MEDIUM, "SAUNA", Theme.HEAT, Graphics.TEXT_JUSTIFY_CENTER);
        var hr = _c.hr();
        Theme.text(dc, cx - w * 4 / 100, h * 40 / 100, Graphics.FONT_NUMBER_MEDIUM, hr != null ? hr.format("%d") : "--",
            Theme.zoneColor(hr), Graphics.TEXT_JUSTIFY_RIGHT);
        var temp = _c.temp();
        var limit = Config.tempLimit();
        var tc = (temp != null && limit > 0 && temp >= limit) ? Theme.WARN : Theme.FG;
        Theme.text(dc, cx + w * 4 / 100, h * 40 / 100, Graphics.FONT_LARGE, temp != null ? temp.format("%.0f") + "°" : "--°",
            tc, Graphics.TEXT_JUSTIFY_LEFT);
        Theme.text(dc, cx - w * 4 / 100, h * 51 / 100, Graphics.FONT_XTINY, "bpm", Theme.DIM, Graphics.TEXT_JUSTIFY_RIGHT);
        Theme.text(dc, cx + w * 4 / 100, h * 51 / 100, Graphics.FONT_XTINY, "watch", Theme.DIM, Graphics.TEXT_JUSTIFY_LEFT);

        Theme.text(dc, cx, h * 63 / 100, Graphics.FONT_XTINY, _last, Theme.FG, Graphics.TEXT_JUSTIFY_CENTER);
        Theme.text(dc, cx, h * 71 / 100, Graphics.FONT_XTINY, _week, Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);
        Theme.text(dc, cx, h * 84 / 100, Graphics.FONT_XTINY, "History  v", Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class StartDelegate extends WatchUi.BehaviorDelegate {
    private var _c as SessionController;

    function initialize(c as SessionController) {
        BehaviorDelegate.initialize();
        _c = c;
    }

    function onSelect() as Boolean {
        _c.start();
        var v = new SessionView(_c);
        WatchUi.switchToView(v, new SessionDelegate(_c, v), WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onNextPage() as Boolean {
        HistoryMenu.push();
        return true;
    }

    function onMenu() as Boolean {
        return onNextPage();
    }

    // Wet fingers in the sauna: the screen ignores touches.
    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        return true;
    }
}
