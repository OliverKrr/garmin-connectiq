import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Activity;
import Toybox.UserProfile;
import Toybox.Lang;

// Full-screen running data field: grid of pace/HR/distance/duration + clock, with
// HR coloured by zone and a time-in-zone bar strip along the bottom. Geometry is
// cached in onLayout; onUpdate reads cached model values and allocates nothing.
class RunFieldView extends WatchUi.DataField {
    private const VALUE_FONT = Graphics.FONT_TINY;
    private var _model as RunModel;
    private var _layout as GridLayout or Null = null;

    function initialize() {
        DataField.initialize();
        var z = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_RUNNING);
        if (z == null || z.size() < 6) {
            z = [93, 111, 130, 148, 167, 185]; // sane default if unconfigured
        }
        _model = new RunModel(AppConfig.rollingWindowSec(), new HrZoneModel(z));
        _model.setUsePower(AppConfig.usePower());
        if (UserProfile has :getPowerZones) {
            var pz = UserProfile.getPowerZones(Activity.SPORT_RUNNING);
            if (pz != null && pz.size() >= 6) {
                _model.setPowerZones(new HrZoneModel(pz));
            }
        }
        if (AppConfig.paceZonesEnabled()) {
            var pzb = AppConfig.paceZones();
            if (pzb != null) {
                _model.setPaceZones(new PaceZoneModel(pzb));
            }
        }
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
        if (_model.usePower()) {
            _cell(dc, pc[0], _model.powerColor(_model.powerCur(), fg), "PWR", _model.powerStr(_model.powerCur()), VALUE_FONT);
            _cell(dc, pc[1], _model.powerColor(_model.powerLap(), fg), "LAP", _model.powerStr(_model.powerLap()), VALUE_FONT);
            _cell(dc, pc[2], _model.powerColor(_model.powerAvg(), fg), "AVG", _model.powerStr(_model.powerAvg()), VALUE_FONT);
        } else {
            _cell(dc, pc[0], _model.paceCurColor(fg), "PACE", _model.paceCurStr(), VALUE_FONT);
            _cell(dc, pc[1], _model.paceLapColor(fg), "LAP", _model.paceLapStr(), VALUE_FONT);
            _cell(dc, pc[2], _model.paceAvgColor(fg), "AVG", _model.paceAvgStr(), VALUE_FONT);
        }

        var hc = _layout.hrCells();
        _cell(dc, hc[0], _model.hrColor(_model.hrCur(), fg), "HR " + _model.fractionalZoneStrFor(_model.hrCur()), _hrStr(_model.hrCur()), VALUE_FONT);
        _cell(dc, hc[1], _model.hrColor(_model.hrLap(), fg), "LAP " + _model.fractionalZoneStrFor(_model.hrLap()), _hrStr(_model.hrLap()), VALUE_FONT);
        _cell(dc, hc[2], _model.hrColor(_model.hrAvg(), fg), "AVG " + _model.fractionalZoneStrFor(_model.hrAvg()), _hrStr(_model.hrAvg()), VALUE_FONT);

        var bc = _layout.bottomCells();
        _cell(dc, bc[0], fg, "DIST", _model.distanceStr() + " km", VALUE_FONT);
        _cell(dc, bc[1], fg, "TIME", _model.durationStr(), VALUE_FONT);

        _drawZoneBars(dc, _layout.zoneBar(), fg);
    }

    // Draw a small label (top) + value (centre) inside rect [x,y,w,h].
    private function _cell(dc as Graphics.Dc, r as Array, color as Graphics.ColorType, label as String, value as String, valueFont as Graphics.FontType) as Void {
        var cx = r[0] + r[2] / 2;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (label.equals("")) {
            // No label (clock): vertically centre the value.
            dc.drawText(cx, r[1] + r[3] / 2, valueFont, value, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.drawText(cx, r[1], Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER);
            // Value sits below the label (top-justified) so full-height digits never overlap it.
            dc.drawText(cx, r[1] + (r[3] * 42) / 100, valueFont, value, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function _hrStr(hr as Number or Null) as String {
        return (hr == null) ? "--" : hr.format("%d");
    }

    // 5 vertical bars across a horizontal strip, heights proportional to time in
    // each zone and coloured per zone (a faint baseline track shows empty bars).
    private function _drawZoneBars(dc as Graphics.Dc, r as Array, fg as Graphics.ColorType) as Void {
        var counts = _model.zoneCounts();
        var total = _model.zoneTotal();
        var n = 5;
        var gap = 3;
        var barW = (r[2] - (n - 1) * gap) / n;
        var baseY = r[1] + r[3];
        var trackH = (r[3] / 6 > 2) ? r[3] / 6 : 2;
        for (var i = 0; i < n; i++) {
            var x = r[0] + i * (barW + gap);
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, baseY - trackH, barW, trackH);
            // Height = this zone's share of total time, so all bars sum to full height.
            var frac = (total > 0) ? counts[i].toFloat() / total : 0.0;
            var bh = (r[3] * frac).toNumber();
            if (bh < 1 && counts[i] > 0) {
                bh = 1;
            }
            if (bh > 0) {
                dc.setColor(_model.zoneColor(i + 1), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, baseY - bh, barW, bh);
            }
        }
    }
}
