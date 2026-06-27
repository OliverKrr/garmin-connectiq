import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Activity;
import Toybox.Lang;

// Minimal full-screen data field used to prove the build -> sim -> sideload
// pipeline. Real metrics and the grid + chart-sidebar layout come later.
class RunFieldView extends WatchUi.DataField {
    private var _elapsedSec as Number = 0;
    // Pre-formatted display string, rebuilt only when the value changes so the
    // draw loop (onUpdate) never allocates (see the convention in CLAUDE.md).
    private var _label as String = "run-field 0s";

    function initialize() {
        DataField.initialize();
    }

    // Cache layout geometry here once metrics/layout are added.
    function onLayout(dc as Graphics.Dc) as Void {
    }

    // Called ~once per second while the activity records.
    function compute(info as Activity.Info) as Void {
        var t = info.timerTime;
        if (t != null) {
            var secs = (t as Number) / 1000;
            if (secs != _elapsedSec) {
                _elapsedSec = secs;
                _label = "run-field " + secs + "s";
            }
        }
    }

    // Render the field. getBackgroundColor() respects the user's theme.
    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, getBackgroundColor());
        dc.clear();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2,
            Graphics.FONT_MEDIUM,
            _label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}
