import Toybox.Lang;
import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.System;

const LIVE_ROWS = 4;
// A live table with more rounds than fit pages through them, this long per block.
const LIVE_PAGE_MS = 4000;
// Brightness of a dimmed screen, in percent.
const DIM_LEVEL = 40;

// The in-session screen. Page 0 is the cockpit: a bezel ring filling toward the phase target,
// the phase countdown (or elapsed time without a target), HR in zone colour, the watch
// temperature, and the phase's HR min/avg/max. Pages 1 and 2 are the heat and rest tables, page 3
// is black (the screen off on AMOLED, chosen on demand; alerts still show their banner on it).
// Between button presses the screen dims per phase (Config.heatScreen/restScreen).
const PAGES = 4;
const PAGE_BLACK = 3;
class SessionView extends WatchUi.View {
    var page as Number = 0;
    private var _c as SessionController;
    // When the current page was opened (System.getTimer ms), for paging long tables.
    private var _pageSince as Number = 0;

    function initialize(c as SessionController) {
        View.initialize();
        _c = c;
    }

    // Back on top after the pause menu closed: once the session has ended (Save or Discard),
    // move on to its summary or to the start screen.
    function onShow() as Void {
        if (_c.state != STATE_IDLE) { return; }
        var e = _c.lastEntry;
        _c.lastEntry = null;
        if (e != null) {
            var v = new SummaryView(e);
            WatchUi.switchToView(v, new SummaryDelegate(v, -1), WatchUi.SLIDE_IMMEDIATE);
        } else {
            WatchUi.switchToView(new StartView(_c), new StartDelegate(_c), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    function setPage(p as Number) as Void {
        page = p;
        _pageSince = System.getTimer();
    }

    // SCREEN_NORMAL while awake (after a button or an alert) or paused, else the phase's setting.
    function mode() as Number {
        var m = _c.model;
        if (m == null || _c.awake() || _c.state == STATE_PAUSED) { return SCREEN_NORMAL; }
        return m.phase == PHASE_HEAT ? Config.heatScreen() : Config.restScreen();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.FG, Theme.BG);
        dc.clear();
        var m = _c.model;
        if (m == null) { return; }
        var mode = mode();
        Theme.level = mode == SCREEN_NORMAL ? 100 : DIM_LEVEL;
        if (page == PAGE_BLACK) {
            // Nothing lit.
        } else if (page == 0) {
            drawCockpit(dc, m);
        } else {
            drawRounds(dc, m, page == 1 ? TABLE_HEAT : TABLE_REST);
        }
        drawBanner(dc);
        Theme.level = 100;
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

    // Live round table (heat or rest), LIVE_ROWS rounds at a time: the block with the newest round
    // first, then every LIVE_PAGE_MS the next block, round-robin.
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
        var blocks = (rows.size() + LIVE_ROWS - 1) / LIVE_ROWS;
        var first = 0;
        if (blocks > 1) {
            var step = (System.getTimer() - _pageSince) / LIVE_PAGE_MS;
            first = ((blocks - 1 + step) % blocks) * LIVE_ROWS;
        }
        RoundsTable.draw(dc, kind, rows, first, h * 42 / 100, LIVE_ROWS);
    }

    private function drawBanner(dc as Graphics.Dc) as Void {
        var b = _c.banner;
        if (b == null || System.getTimer() > _c.bannerUntil) { return; }
        var w = dc.getWidth();
        var h = dc.getHeight();
        var sub = _c.bannerSub;
        var fh = dc.getFontHeight(Graphics.FONT_SMALL);
        var sh = sub != null ? dc.getFontHeight(Graphics.FONT_XTINY) : 0;
        var bh = fh + sh + 8;
        var top = h / 2 - bh / 2;
        dc.setColor(Theme.c(Theme.FG), Theme.c(Theme.FG));
        dc.fillRectangle(0, top, w, bh);
        Theme.text(dc, w / 2, top + 4 + fh / 2, Graphics.FONT_SMALL, b, Theme.BG, Graphics.TEXT_JUSTIFY_CENTER);
        if (sub != null) {
            // The undo hint disappears with the undo window, even if the banner were longer.
            if (_c.canUndo() || !sub.equals("BACK again: undo")) {
                Theme.text(dc, w / 2, top + 4 + fh + sh / 2, Graphics.FONT_XTINY, sub, Theme.BG, Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }
}

// START pauses (opening Resume / Settings / Save / Discard), BACK switches phase (again within
// UNDO_MS undoes it), UP/DOWN cycle the pages (cockpit, heat, rest, black), MENU (hold UP) opens
// the settings without pausing. Every button wakes a dimmed screen; on a dimmed screen UP/DOWN
// only wake it.
// A tap only wakes the screen: wet fingers and towels in the sauna must not switch phases.
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

    function onMenu() as Boolean {
        _c.wake();
        SettingsMenu.push(_c);
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
        if (_v.mode() == SCREEN_NORMAL || _v.page == PAGE_BLACK) { _v.setPage((_v.page + d + PAGES) % PAGES); }
        _c.wake();
        WatchUi.requestUpdate();
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean { return wakeOnly(); }
    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean { return wakeOnly(); }

    private function wakeOnly() as Boolean {
        _c.wake();
        WatchUi.requestUpdate();
        return true;
    }
}
