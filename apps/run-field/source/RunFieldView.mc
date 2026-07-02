import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Activity;
import Toybox.UserProfile;
import Toybox.Lang;

// Full-screen running data field: grid of pace/HR/distance/duration + clock, with
// HR coloured by zone and a time-in-zone bar strip along the bottom. Geometry is
// cached in onLayout; onUpdate reads cached model values and allocates nothing.
class RunFieldView extends WatchUi.DataField {
    // Largest-first bold numeric candidates; the fit-to-cell picker in onLayout chooses per row.
    private const VALUE_FONTS = [
        Graphics.FONT_NUMBER_MEDIUM,
        Graphics.FONT_NUMBER_MILD,
        Graphics.FONT_LARGE,
        Graphics.FONT_MEDIUM,
    ];
    private var _fPace as Graphics.FontType = Graphics.FONT_TINY;
    private var _fHr as Graphics.FontType = Graphics.FONT_TINY;
    private var _fBottom as Graphics.FontType = Graphics.FONT_TINY;
    private var _fClock as Graphics.FontType = Graphics.FONT_MEDIUM;
    // Initialised with a throwaway default so the type checker sees it non-null;
    // reloadSettings() (called from initialize) immediately replaces it.
    private var _model as RunModel = new RunModel(25, new HrZoneModel([93, 111, 130, 148, 167, 185]));
    private var _layout as GridLayout or Null = null;

    function initialize() {
        DataField.initialize();
        reloadSettings();
    }

    // (Re)read app settings and rebuild the model. Called at init and from the
    // app's onSettingsChanged() so edits apply live. Rebuilding resets in-activity
    // accumulators (lap/avg/time-in-zone) — acceptable for an occasional change.
    function reloadSettings() as Void {
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
        _model.setAutoToggleSec(AppConfig.autoToggleSec());
        var model = AppConfig.paceZoneModel(); // 0=Off,1=80/20,2=Friel,3=CTS,4=MyProCoach,5=Custom
        var pz = null as PaceZoneModel or Null;
        if (model == 5) { // Custom
            var custom = AppConfig.paceZones(); // 4 or 6 boundaries, or null
            if (custom != null) {
                pz = new PaceZoneModel(custom);
            }
        } else if (model != 0) { // a preset (1-4)
            var thr = AppConfig.thresholdPaceSec();
            if (thr != null) {
                pz = new PaceZoneModel(AppConfig.derivePaceBoundaries(thr, model));
            }
        }
        _model.setPaceZones(pz);
    }

    function onLayout(dc as Graphics.Dc) as Void {
        _layout = new GridLayout(dc.getWidth(), dc.getHeight());
        var pc = _layout.paceCells();
        var hc = _layout.hrCells();
        var bc = _layout.bottomCells();
        // Value sits in the lower ~58% of the cell (label is above), so budget that height.
        _fPace = _pickFont(dc, "88:88", pc[0][2], (pc[0][3] * 58) / 100, VALUE_FONTS);
        _fHr = _pickFont(dc, "888", hc[0][2], (hc[0][3] * 58) / 100, VALUE_FONTS);
        // Bottom row: DIST value "88.88" and TIME up to "8:88:88" — size for the wider one.
        _fBottom = _pickFont(dc, "8:88:88", bc[0][2], (bc[0][3] * 58) / 100, VALUE_FONTS);
    }

    // Largest candidate whose text fits (width, and height*0.55 to counter NUMBER-font over-report).
    private function _pickFont(dc as Graphics.Dc, text as String, cellW as Number, availH as Number, candidates as Array) as Graphics.FontType {
        for (var i = 0; i < candidates.size(); i++) {
            var f = candidates[i];
            var dims = dc.getTextDimensions(text, f);
            if (dims[0] <= cellW - 4 && dims[1] * 0.55 <= availH) {
                return f;
            }
        }
        return candidates[candidates.size() - 1];
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
        var onWhite = (bg == Graphics.COLOR_WHITE);
        dc.setColor(Graphics.COLOR_TRANSPARENT, bg);
        dc.clear();

        if (_layout == null) {
            return;
        }

        _cell(dc, _layout.clock(), fg, "", _model.clockStr(), _fClock);

        var pc = _layout.paceCells();
        if (_model.showPower()) {
            _cell(dc, pc[0], _model.powerColor(_model.powerCur(), fg, onWhite), "PWR" + _model.powerZoneStrFor(_model.powerCur()), _model.powerStr(_model.powerCur()), _fPace);
            _cell(dc, pc[1], _model.powerColor(_model.powerLap(), fg, onWhite), "LAP" + _model.powerZoneStrFor(_model.powerLap()), _model.powerStr(_model.powerLap()), _fPace);
            _cell(dc, pc[2], _model.powerColor(_model.powerAvg(), fg, onWhite), "AVG" + _model.powerZoneStrFor(_model.powerAvg()), _model.powerStr(_model.powerAvg()), _fPace);
        } else {
            _cell(dc, pc[0], _model.paceCurColor(fg, onWhite), "PACE" + _model.paceCurZone(), _model.paceCurStr(), _fPace);
            _cell(dc, pc[1], _model.paceLapColor(fg, onWhite), "LAP" + _model.paceLapZone(), _model.paceLapStr(), _fPace);
            _cell(dc, pc[2], _model.paceAvgColor(fg, onWhite), "AVG" + _model.paceAvgZone(), _model.paceAvgStr(), _fPace);
        }

        var hc = _layout.hrCells();
        _cell(dc, hc[0], _model.hrColor(_model.hrCur(), fg, onWhite), "HR " + _model.fractionalZoneStrFor(_model.hrCur()), _hrStr(_model.hrCur()), _fHr);
        _cell(dc, hc[1], _model.hrColor(_model.hrLap(), fg, onWhite), "LAP " + _model.fractionalZoneStrFor(_model.hrLap()), _hrStr(_model.hrLap()), _fHr);
        _cell(dc, hc[2], _model.hrColor(_model.hrAvg(), fg, onWhite), "AVG " + _model.fractionalZoneStrFor(_model.hrAvg()), _hrStr(_model.hrAvg()), _fHr);

        var bc = _layout.bottomCells();
        _cell(dc, bc[0], fg, "DIST KM", _model.distanceStr(), _fBottom);
        _cell(dc, bc[1], fg, "TIME", _model.durationStr(), _fBottom);

        _drawZoneBars(dc, _layout.zoneBar(), fg, onWhite);
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
    private function _drawZoneBars(dc as Graphics.Dc, r as Array, fg as Graphics.ColorType, onWhite as Boolean) as Void {
        var counts = _model.zoneCounts();
        var max = _model.zoneMax();
        var n = 5;
        var gap = 3;
        var barW = (r[2] - (n - 1) * gap) / n;
        var baseY = r[1] + r[3];
        var trackH = (r[3] / 6 > 2) ? r[3] / 6 : 2;
        for (var i = 0; i < n; i++) {
            var x = r[0] + i * (barW + gap);
            dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, baseY - trackH, barW, trackH);
            // Height = this zone's share of the busiest zone, so the tallest bar fills the band.
            var bh = ChartScale.barPx(counts[i], max, r[3]);
            if (bh < 1 && counts[i] > 0) {
                bh = 1;
            }
            if (bh > 0) {
                dc.setColor(_model.zoneColor(i + 1, onWhite), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, baseY - bh, barW, bh);
            }
        }
    }
}
