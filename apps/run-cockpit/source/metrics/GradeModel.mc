import Toybox.Lang;

// Grade (%) from barometric altitude over a distance window. Altitude is EMA-smoothed; grade updates
// only once the window spans >= MIN_M (guards altimeter noise + near-zero distance when slow/stopped);
// output clamped to +/-40 and EMA-smoothed. Feed metres each active second.
class GradeModel {
    private const WIN_M = 30.0;
    private const MIN_M = 10.0;
    private const ALT_A = 0.3;
    private const GRADE_A = 0.4;
    private const CLAMP = 40.0;

    private var _dist as Array<Float> = [];
    private var _alt as Array<Float> = [];
    private var _altEma as Float or Null = null;
    private var _grade as Float = 0.0;

    function update(distM as Float or Null, altM as Float or Null) as Void {
        if (distM == null || altM == null) { return; }
        _altEma = (_altEma == null) ? altM : (_altEma + ALT_A * (altM - _altEma));
        _dist.add(distM);
        _alt.add(_altEma);
        while (_dist.size() > 2 && (distM - _dist[1]) >= WIN_M) {
            _dist = _dist.slice(1, null);
            _alt = _alt.slice(1, null);
        }
        var span = distM - _dist[0];
        if (span >= MIN_M) {
            var g = (_alt[_alt.size() - 1] - _alt[0]) / span * 100.0;
            if (g > CLAMP) { g = CLAMP; }
            if (g < -CLAMP) { g = -CLAMP; }
            _grade = _grade + GRADE_A * (g - _grade);
        }
    }

    function grade() as Float { return _grade; }

    function reset() as Void {
        _dist = [];
        _alt = [];
        _altEma = null;
        _grade = 0.0;
    }
}
