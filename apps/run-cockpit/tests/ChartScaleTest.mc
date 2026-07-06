import Toybox.Lang;
import Toybox.Test;

(:test)
function chartScale_maxFillsBand(logger as Logger) as Boolean {
    return ChartScale.barPx(600, 600, 70) == 70;
}

(:test)
function chartScale_zeroCount(logger as Logger) as Boolean {
    return ChartScale.barPx(0, 600, 70) == 0;
}

(:test)
function chartScale_zeroMax(logger as Logger) as Boolean {
    return ChartScale.barPx(5, 0, 70) == 0;
}

(:test)
function chartScale_half(logger as Logger) as Boolean {
    return ChartScale.barPx(50, 100, 70) == 35;
}
