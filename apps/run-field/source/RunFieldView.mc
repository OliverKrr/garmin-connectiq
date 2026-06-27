import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Activity;
import Toybox.UserProfile;
import Toybox.Lang;

// Full-screen running data field: grid of pace/HR/distance/duration + clock, with
// HR coloured by zone and a time-in-zone bar sidebar. Geometry is cached in
// onLayout; onUpdate reads cached model values and allocates nothing.
class RunFieldView extends WatchUi.DataField {
    private const ROLLING_WINDOW_SEC = 25;
    private var _model as RunModel;
    private var _layout as GridLayout or Null = null;

    function initialize() {
        DataField.initialize();
        var z = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_RUNNING);
        if (z == null || z.size() < 6) {
            z = [93, 111, 130, 148, 167, 185]; // sane default if unconfigured
        }
        _model = new RunModel(ROLLING_WINDOW_SEC, new HrZoneModel(z));
    }

    function onLayout(dc as Graphics.Dc) as Void {
        _layout = new GridLayout(dc.getWidth(), dc.getHeight());
    }

    function compute(info as Activity.Info) as Void {
        _model.update(info);
    }

    function onTimerLap() as Void {
        _model.onLap();
    }

    function onTimerReset() as Void {
        _model.onReset();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var bg = getBackgroundColor();
        var fg = (bg == Graphics.COLOR_WHITE) ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
        dc.setColor(Graphics.COLOR_TRANSPARENT, bg);
        dc.clear();

        if (_layout == null) {
            return;
        }

        _cell(dc, _layout.clock(), fg, "", _model.clockStr(), Graphics.FONT_SMALL);

        var pc = _layout.paceCells();
        _cell(dc, pc[0], fg, "PACE", _model.paceCurStr(), Graphics.FONT_NUMBER_MILD);
        _cell(dc, pc[1], fg, "LAP", _model.paceLapStr(), Graphics.FONT_NUMBER_MILD);
        _cell(dc, pc[2], fg, "AVG", _model.paceAvgStr(), Graphics.FONT_NUMBER_MILD);

        var hc = _layout.hrCells();
        _cell(dc, hc[0], _model.hrColor(_model.hrCur(), fg), "HR " + _model.fractionalZoneStr(), _hrStr(_model.hrCur()), Graphics.FONT_NUMBER_MILD);
        _cell(dc, hc[1], _model.hrColor(_model.hrLap(), fg), "LAP", _hrStr(_model.hrLap()), Graphics.FONT_NUMBER_MILD);
        _cell(dc, hc[2], _model.hrColor(_model.hrAvg(), fg), "AVG", _hrStr(_model.hrAvg()), Graphics.FONT_NUMBER_MILD);

        var bc = _layout.bottomCells();
        _cell(dc, bc[0], fg, "DIST", _model.distanceStr() + " km", Graphics.FONT_NUMBER_MILD);
        _cell(dc, bc[1], fg, "TIME", _model.durationStr(), Graphics.FONT_NUMBER_MILD);

        _drawSidebar(dc, _layout.sidebar(), fg);
    }

    private function _cell(dc as Graphics.Dc, r as Array, color as Graphics.ColorType, label as String, value as String, valueFont as Graphics.FontType) as Void {
        var cx = r[0] + r[2] / 2;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (!label.equals("")) {
            dc.drawText(cx, r[1] + 1, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.drawText(cx, r[1] + r[3] / 2, valueFont, value, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function _hrStr(hr as Number or Null) as String {
        return (hr == null) ? "--" : hr.format("%d");
    }

    private function _drawSidebar(dc as Graphics.Dc, r as Array, fg as Graphics.ColorType) as Void {
        var counts = _model.zoneCounts();
        var max = _model.zoneMax();
        var n = 5;
        var gap = 2;
        var barW = (r[2] - (n - 1) * gap) / n;
        var baseY = r[1] + r[3];
        for (var i = 0; i < n; i++) {
            var x = r[0] + i * (barW + gap);
            var frac = (max > 0) ? counts[i].toFloat() / max : 0.0;
            var bh = (r[3] * frac).toNumber();
            if (bh < 1 && counts[i] > 0) { bh = 1; }
            dc.setColor(_model.zoneColor(i + 1), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, baseY - bh, barW, bh);
        }
    }
}
