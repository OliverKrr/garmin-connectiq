import Toybox.Lang;

// Pure formatting helpers. No Graphics/UI dependencies so they are unit-testable.
module PaceFormat {

    // Pace in seconds-per-km -> "m:ss". null / non-positive / absurd -> "--:--".
    function paceSecPerKm(secPerKm as Float or Null) as String {
        if (secPerKm == null || secPerKm <= 0.0 || secPerKm > 5999.0) {
            return "--:--";
        }
        var total = (secPerKm + 0.5).toNumber();
        var minutes = total / 60;
        var seconds = total % 60;
        return minutes.format("%d") + ":" + seconds.format("%02d");
    }

    // Duration in milliseconds -> "mm:ss" (<1h) or "h:mm:ss". null/negative -> "--:--".
    function durationMs(ms as Number or Null) as String {
        if (ms == null || ms < 0) {
            return "--:--";
        }
        var total = ms / 1000;
        var hours = total / 3600;
        var minutes = (total % 3600) / 60;
        var seconds = total % 60;
        if (hours > 0) {
            return hours.format("%d") + ":" + minutes.format("%02d") + ":" + seconds.format("%02d");
        }
        return minutes.format("%d") + ":" + seconds.format("%02d");
    }
}
