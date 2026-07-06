import Toybox.Lang;
import Toybox.Test;

(:test) function powerSwitch_onAboveThreshold(l as Logger) as Boolean { return PowerSwitch.active(3.5, 3.0, false) == true; }
(:test) function powerSwitch_offWellBelow(l as Logger) as Boolean { return PowerSwitch.active(0.5, 3.0, true) == false; }
(:test) function powerSwitch_holdsInBand(l as Logger) as Boolean {
    return PowerSwitch.active(2.0, 3.0, true) == true && PowerSwitch.active(2.0, 3.0, false) == false;
}
