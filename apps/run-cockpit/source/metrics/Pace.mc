import Toybox.Lang;

// Pace computation helpers (seconds per kilometre). Pure; unit-tested.
module Pace {

    // Seconds-per-km from an instantaneous/average speed in m/s. null/<=0 -> null.
    function secPerKmFromSpeed(speedMps as Float or Null) as Float or Null {
        if (speedMps == null || speedMps <= 0.0) {
            return null;
        }
        return 1000.0 / speedMps;
    }

    // Seconds-per-km from a distance delta (m) over a time delta (ms). Invalid -> null.
    function secPerKmFromDelta(distM as Float, timeMs as Number) as Float or Null {
        if (distM <= 0.0 || timeMs <= 0) {
            return null;
        }
        var speedMps = distM / (timeMs / 1000.0);
        return 1000.0 / speedMps;
    }

    // Speed in m/s from seconds-per-km, for the FIT fields. null/<=0 (no pace yet, standing) -> 0.
    function speedFromSecPerKm(secPerKm as Float or Null) as Float {
        if (secPerKm == null || secPerKm <= 0.0) {
            return 0.0;
        }
        return 1000.0 / secPerKm;
    }
}
