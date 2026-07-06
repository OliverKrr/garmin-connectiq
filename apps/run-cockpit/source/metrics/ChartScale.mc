import Toybox.Lang;

// Pure bar-chart scaling. Height of a zone's bar so the busiest zone fills bandH
// (share-of-max). 0 when the zone is empty or nothing has been recorded yet.
module ChartScale {
    function barPx(count as Number, max as Number, bandH as Number) as Number {
        if (max <= 0 || count <= 0) {
            return 0;
        }
        return (bandH * count) / max;
    }
}
