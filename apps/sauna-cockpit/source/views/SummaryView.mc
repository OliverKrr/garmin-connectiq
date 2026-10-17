import Toybox.Lang;
import Toybox.Graphics;
import Toybox.WatchUi;

// One session's summary: totals, session HR min/avg/max, calories, peak watch temperature and
// the round table. Shown right after Save (index -1) and from the history (index >= 0, where
// MENU offers to delete it). UP/DOWN scroll the rounds when there are more than fit.
const SUMMARY_ROWS = 4;

class SummaryView extends WatchUi.View {
    var first as Number = 0;
    private var _e as Array;

    function initialize(e as Array) {
        View.initialize();
        _e = e;
    }

    function rowCount() as Number {
        return (_e[History.S_ROUNDS] as Array).size();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        dc.setColor(Theme.FG, Theme.BG);
        dc.clear();
        var rows = _e[History.S_ROUNDS] as Array<Array<Number>>;
        var heat = 0;
        for (var i = 0; i < rows.size(); i++) { heat += rows[i][History.R_HEAT]; }

        Theme.text(dc, cx, h * 13 / 100, Graphics.FONT_XTINY, Theme.date(_e[History.S_START] as Number), Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);
        Theme.text(dc, cx, h * 22 / 100, Graphics.FONT_SMALL,
            rows.size() + (rows.size() == 1 ? " round" : " rounds") + ", " + Fmt.minutes(heat) + " heat", Theme.HEAT, Graphics.TEXT_JUSTIFY_CENTER);
        Theme.text(dc, cx, h * 30 / 100, Graphics.FONT_XTINY,
            "HR " + Fmt.num(_e[History.S_MIN] as Number) + " / " + Fmt.num(_e[History.S_AVG] as Number) + " / " + Fmt.num(_e[History.S_MAX] as Number) +
            "   max " + Fmt.temp10(_e[History.S_TEMP] as Number), Theme.FG, Graphics.TEXT_JUSTIFY_CENTER);
        var kcal = _e.size() > History.S_KCAL ? _e[History.S_KCAL] as Number : History.NONE;
        Theme.text(dc, cx, h * 37 / 100, Graphics.FONT_XTINY,
            "total " + Fmt.clock(_e[History.S_TOTAL] as Number) + "   " + Fmt.num(kcal) + " kcal", Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);
        RoundsTable.draw(dc, rows, first, h * 44 / 100, SUMMARY_ROWS);
    }
}

class SummaryDelegate extends WatchUi.BehaviorDelegate {
    private var _v as SummaryView;
    private var _index as Number;

    function initialize(v as SummaryView, index as Number) {
        BehaviorDelegate.initialize();
        _v = v;
        _index = index;
    }

    function onNextPage() as Boolean { return scroll(1); }
    function onPreviousPage() as Boolean { return scroll(-1); }

    private function scroll(d as Number) as Boolean {
        var max = _v.rowCount() - SUMMARY_ROWS;
        var f = _v.first + d;
        _v.first = f > max ? max : f;
        if (_v.first < 0) { _v.first = 0; }
        WatchUi.requestUpdate();
        return true;
    }

    // After Save the summary replaced the session view, so BACK returns to the start screen;
    // from the history it just pops.
    function onBack() as Boolean {
        if (_index < 0) {
            var c = getApp().controller;
            WatchUi.switchToView(new StartView(c), new StartDelegate(c), WatchUi.SLIDE_RIGHT);
            return true;
        }
        return false;
    }

    function onSelect() as Boolean {
        return onBack();
    }

    function onMenu() as Boolean {
        if (_index >= 0) {
            WatchUi.pushView(new WatchUi.Confirmation("Delete session?"), new DeleteDelegate(_index), WatchUi.SLIDE_IMMEDIATE);
        }
        return true;
    }
}

class DeleteDelegate extends WatchUi.ConfirmationDelegate {
    private var _index as Number;

    function initialize(index as Number) {
        ConfirmationDelegate.initialize();
        _index = index;
    }

    // Removes the session and closes its summary; the history list is rebuilt on next open.
    function onResponse(r as WatchUi.Confirm) as Boolean {
        if (r == WatchUi.CONFIRM_YES) {
            History.removeAt(_index);
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
        return true;
    }
}
