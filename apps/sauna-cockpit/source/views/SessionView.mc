import Toybox.Lang;
import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.System;

const LIVE_ROWS = 4;

// The in-session screen. Page 0 is the cockpit: a bezel ring filling toward the phase target,
// the phase countdown (or elapsed time without a target), HR in zone colour, the watch
// temperature, and the phase's HR min/avg/max. Pages 1 and 2 are the heat and rest tables.
class SessionView extends WatchUi.View {
    var page as Number = 0;
    private var _c as SessionController;

    function initialize(c as SessionController) {
        View.initialize();
        _c = c;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.FG, Theme.BG);
        dc.clear();
        var m = _c.model;
        if (m == null) { return; }
        if (page == 0) {
            drawCockpit(dc, m);
        } else {
            drawRounds(dc, m, page == 1 ? TABLE_HEAT : TABLE_REST);
        }
        drawBanner(dc);
    }

    private function drawCockpit(dc as Graphics.Dc, m as SessionModel) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var paused = _c.state == STATE_PAUSED;
        var target = m.targetSec();
        var el = m.current.seconds;
        var over = target > 0 && el >= target;
        var color = Theme.phaseColor(m.phase);

        Theme.ring(dc, target > 0 ? el.toFloat() / target : 0.0, over ? Theme.WARN : color);

        var label = paused ? "PAUSED" : (m.phase == PHASE_HEAT ? "HEAT  R" + m.round : "COOL  R" + m.round);
        Theme.text(dc, cx, h * 17 / 100, Graphics.FONT_SMALL, label, paused ? Theme.CAUTION : color, Graphics.TEXT_JUSTIFY_CENTER);

        // Main number: time left toward the target, then overtime with a "+"; plain elapsed time
        // when the phase has no target.
        var main = target == 0 ? Fmt.clock(el) : (over ? "+" + Fmt.clock(el - target) : Fmt.clock(target - el));
        Theme.text(dc, cx, h * 36 / 100, Graphics.FONT_NUMBER_HOT, main, over ? Theme.WARN : Theme.FG, Graphics.TEXT_JUSTIFY_CENTER);
        var sub = target == 0 ? "elapsed" : Fmt.clock(el) + " of " + Fmt.clock(target);
        Theme.text(dc, cx, h * 50 / 100, Graphics.FONT_XTINY, sub, Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);

        var hr = m.lastHr;
        Theme.text(dc, cx - w * 3 / 100, h * 63 / 100, Graphics.FONT_NUMBER_MILD, hr != null ? hr.format("%d") : "--",
            m.hrHigh() ? Theme.WARN : Theme.zoneColor(hr), Graphics.TEXT_JUSTIFY_RIGHT);
        var t = m.lastTemp;
        var tc = m.tempHigh() ? Theme.WARN : (m.tempWarm() ? Theme.CAUTION : Theme.FG);
        Theme.text(dc, cx + w * 3 / 100, h * 63 / 100, Graphics.FONT_MEDIUM, t != null ? t.format("%.0f") + "°" : "--°",
            tc, Graphics.TEXT_JUSTIFY_LEFT);

        var s = m.current;
        var stats = Fmt.num(History.n(s.minHr)) + " / " + Fmt.num(History.n(s.avgHr())) + " / " + Fmt.num(History.n(s.maxHr));
        Theme.text(dc, cx, h * 74 / 100, Graphics.FONT_XTINY, "lo/avg/hi " + stats, Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);
        Theme.text(dc, cx, h * 83 / 100, Graphics.FONT_XTINY, "Total " + Fmt.clock(m.total.seconds), Theme.FG, Graphics.TEXT_JUSTIFY_CENTER);
        var now = System.getClockTime();
        Theme.text(dc, cx, h * 91 / 100, Graphics.FONT_XTINY, now.hour.format("%d") + ":" + now.min.format("%02d"), Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Live round table (heat or rest), showing the newest LIVE_ROWS rounds.
    private function drawRounds(dc as Graphics.Dc, m as SessionModel, kind as Number) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var f = Graphics.FONT_XTINY;
        var center = Graphics.TEXT_JUSTIFY_CENTER;
        var t = m.total;
        if (kind == TABLE_HEAT) {
            Theme.text(dc, w / 2, h * 16 / 100, Graphics.FONT_SMALL, "HEAT", Theme.HEAT, center);
            Theme.text(dc, w / 2, h * 26 / 100, f, "heat " + Fmt.clock(m.heatSeconds()) + "  total " + Fmt.clock(t.seconds), Theme.FG, center);
            Theme.text(dc, w / 2, h * 33 / 100, f,
                "HR " + Fmt.num(History.n(t.minHr)) + " / " + Fmt.num(History.n(t.avgHr())) + " / " + Fmt.num(History.n(t.maxHr)),
                Theme.DIM, center);
        } else {
            Theme.text(dc, w / 2, h * 16 / 100, Graphics.FONT_SMALL, "REST", Theme.COOL, center);
            Theme.text(dc, w / 2, h * 26 / 100, f, "rest " + Fmt.clock(t.seconds - m.heatSeconds()), Theme.FG, center);
            Theme.text(dc, w / 2, h * 33 / 100, f, "HRV now " + Fmt.num(History.n(m.current.rmssd())) + " ms", Theme.DIM, center);
        }
        var rows = m.roundRows();
        var first = rows.size() > LIVE_ROWS ? rows.size() - LIVE_ROWS : 0;
        RoundsTable.draw(dc, kind, rows, first, h * 42 / 100, LIVE_ROWS);
    }

    private function drawBanner(dc as Graphics.Dc) as Void {
        var b = _c.banner;
        if (b == null || System.getTimer() > _c.bannerUntil) { return; }
        var w = dc.getWidth();
        var h = dc.getHeight();
        var bh = dc.getFontHeight(Graphics.FONT_SMALL) + 8;
        dc.setColor(Theme.FG, Theme.FG);
        dc.fillRectangle(0, h / 2 - bh / 2, w, bh);
        Theme.text(dc, w / 2, h / 2, Graphics.FONT_SMALL, b, Theme.BG, Graphics.TEXT_JUSTIFY_CENTER);
    }
}

// START pauses (opening Resume / Save / Discard), BACK switches phase, UP/DOWN cycle the pages.
// Touch is ignored: wet fingers and towels in the sauna would otherwise switch phases.
class SessionDelegate extends WatchUi.BehaviorDelegate {
    private var _c as SessionController;
    private var _v as SessionView;

    function initialize(c as SessionController, v as SessionView) {
        BehaviorDelegate.initialize();
        _c = c;
        _v = v;
    }

    function onSelect() as Boolean {
        _c.pause();
        PauseMenu.push(_c);
        return true;
    }

    function onBack() as Boolean {
        if (_c.state == STATE_RUNNING) {
            _c.lap();
        } else {
            PauseMenu.push(_c);
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() as Boolean { return flip(1); }
    function onPreviousPage() as Boolean { return flip(-1); }

    private function flip(d as Number) as Boolean {
        _v.page = (_v.page + d + 3) % 3;
        WatchUi.requestUpdate();
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean { return true; }
    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean { return true; }
}
