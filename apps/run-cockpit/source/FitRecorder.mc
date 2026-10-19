import Toybox.Lang;
import Toybox.FitContributor;
import Toybox.WatchUi;

// Writes the field's own GAP into the activity's FIT file as Connect IQ developer fields, so an
// analysis can compare it with Garmin's lap GAP (avg_grade_adjusted_speed) and re-check GapModel.
// Ids match resources/fitcontributions.xml; a retired id is never reused. Speeds are m/s
// (pace = 1000 / speed) and 0 while there is none. Written on every run, whatever the climb metric:
// the fields exist from initialize() on, before a settings change could switch it. The only code
// touching FIT recording; write() runs from compute(), once per second.
class FitRecorder {
    private var _gap as FitContributor.Field;
    private var _grade as FitContributor.Field;
    private var _climb as FitContributor.Field;
    private var _lapGap as FitContributor.Field;
    private var _avgGap as FitContributor.Field;

    function initialize(df as WatchUi.DataField) {
        _gap = df.createField("gap_speed", 0, FitContributor.DATA_TYPE_FLOAT, {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "m/s"});
        _grade = df.createField("gap_grade", 1, FitContributor.DATA_TYPE_FLOAT, {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "%"});
        _climb = df.createField("climb_metric", 2, FitContributor.DATA_TYPE_UINT8, {:mesgType => FitContributor.MESG_TYPE_RECORD});
        _lapGap = df.createField("lap_gap_speed", 3, FitContributor.DATA_TYPE_FLOAT, {:mesgType => FitContributor.MESG_TYPE_LAP, :units => "m/s"});
        _avgGap = df.createField("avg_gap_speed", 4, FitContributor.DATA_TYPE_FLOAT, {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "m/s"});
    }

    // The lap and session messages take the values last set here when the watch writes them.
    function write(m as RunModel) as Void {
        _gap.setData(Pace.speedFromSecPerKm(m.gapCurSec()));
        _grade.setData(m.grade());
        _climb.setData(m.climbMetricShown());
        _lapGap.setData(Pace.speedFromSecPerKm(m.gapLapSec()));
        _avgGap.setData(Pace.speedFromSecPerKm(m.gapAvgSec()));
    }
}
