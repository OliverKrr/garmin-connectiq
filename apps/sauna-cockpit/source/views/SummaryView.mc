import Toybox.Lang;
import Toybox.Graphics;
import Toybox.WatchUi;

// One session's summary, paged with UP/DOWN: the heat table (with session HR, peak temperature,
// total time and calories above it), the rest table, then recovery (Body Battery before and
// after, stress before, time above the effect HR, HRV per round). Tables longer than
// SUMMARY_ROWS rounds take several pages. Shown right after Save (index -1) and from the history
// (index >= 0, where MENU offers to delete it).
const SUMMARY_ROWS = 4;

class SummaryView extends WatchUi.View {
    var page as Number = 0;
    // Pages as [table kind, first row].
    var pages as Array<Array<Number>> = [] as Array<Array<Number>>;
    private var _e as Array;

    function initialize(e as Array) {
        View.initialize();
        _e = e;
        var n = (e[History.S_ROUNDS] as Array).size();
        var kinds = [TABLE_HEAT, TABLE_REST, TABLE_HRV];
        for (var k = 0; k < kinds.size(); k++) {
            for (var first = 0; first == 0 || first < n; first += SUMMARY_ROWS) {
                pages.add([kinds[k], first]);
            }
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var f = Graphics.FONT_XTINY;
        var center = Graphics.TEXT_JUSTIFY_CENTER;
        dc.setColor(Theme.FG, Theme.BG);
        dc.clear();
        var rows = _e[History.S_ROUNDS] as Array<Array<Number>>;
        var heat = 0;
        var rest = 0;
        var above = 0;
        for (var i = 0; i < rows.size(); i++) {
            heat += rows[i][History.R_HEAT];
            rest += History.at(rows[i], History.R_COOL);
            var a = History.at(rows[i], History.R_EFF);
            if (a > 0) { above += a; }
        }
        var kind = pages[page][0];

        Theme.text(dc, cx, h * 13 / 100, f, Theme.date(_e[History.S_START] as Number), Theme.DIM, center);
        Theme.text(dc, cx, h * 22 / 100, Graphics.FONT_SMALL,
            rows.size() + (rows.size() == 1 ? " round" : " rounds") + ", " + Fmt.minutes(heat) + " heat", Theme.HEAT, center);
        if (kind == TABLE_HEAT) {
            Theme.text(dc, cx, h * 30 / 100, f,
                "HR " + Fmt.num(History.at(_e, History.S_MIN)) + " / " + Fmt.num(History.at(_e, History.S_AVG)) + " / " +
                Fmt.num(History.at(_e, History.S_MAX)) + "   max " + Fmt.temp10(History.at(_e, History.S_TEMP)), Theme.FG, center);
            Theme.text(dc, cx, h * 37 / 100, f,
                "total " + Fmt.clock(_e[History.S_TOTAL] as Number) + "   " + Fmt.num(History.at(_e, History.S_KCAL)) + " kcal", Theme.DIM, center);
        } else if (kind == TABLE_REST) {
            Theme.text(dc, cx, h * 30 / 100, f, "REST  " + Fmt.clock(rest), Theme.COOL, center);
            Theme.text(dc, cx, h * 37 / 100, f, "HRR: HR drop in the first minute", Theme.DIM, center);
        } else {
            var bb0 = History.at(_e, History.S_BB0);
            var bb1 = History.at(_e, History.S_BB1);
            Theme.text(dc, cx, h * 30 / 100, f, "Body Battery " + Fmt.num(bb0) + " > " + Fmt.num(bb1), Theme.FG, center);
            var eff = Config.effectHr();
            var s1 = History.at(_e, History.S_STRESS1);
            Theme.text(dc, cx, h * 37 / 100, f,
                "stress " + Fmt.num(History.at(_e, History.S_STRESS)) + (s1 == History.NONE ? "" : " > " + Fmt.num(s1)) + "   " +
                (eff > 0 ? eff + "+ bpm " + Fmt.clock(above) : ""), Theme.DIM, center);
        }
        RoundsTable.draw(dc, kind, rows, pages[page][1], h * 44 / 100, SUMMARY_ROWS);
        Theme.text(dc, cx, h * 90 / 100, f, (page + 1) + "/" + pages.size(), Theme.DIM, center);
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

    function onNextPage() as Boolean { return flip(1); }
    function onPreviousPage() as Boolean { return flip(-1); }

    private function flip(d as Number) as Boolean {
        var n = _v.pages.size();
        _v.page = (_v.page + d + n) % n;
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
