import Toybox.Lang;

// Decide pace(false) vs power(true) with hysteresis: switch to power above `threshold`, back to
// pace below `threshold - hyst` (hyst = half the threshold, min 1). Holds `wasActive` in the band.
module PowerSwitch {
    function active(grade as Float, threshold as Float, wasActive as Boolean) as Boolean {
        var hyst = threshold / 2.0;
        if (hyst < 1.0) { hyst = 1.0; }
        if (grade >= threshold) { return true; }
        if (grade <= threshold - hyst) { return false; }
        return wasActive;
    }
}
