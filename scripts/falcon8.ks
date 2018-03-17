PRINT "Preflight.".
LOCAL _steering IS HEADING(0, 90).
LOCK STEERING TO _steering.
LOCK THROTTLE TO 1.
WAIT .5.

PRINT "Launch.".
STAGE.
WAIT UNTIL SHIP:ALTITUDE > 300.

PRINT "Roll program.".
SET _steering TO HEADING(90, 90).
WAIT UNTIL SHIP:VERTICALSPEED >= 100.

PRINT "Begining gravity turn.".
SET _steering TO HEADING(90, 90 - 10).
WAIT 3.
LOCK _error TO VANG(SHIP:FACING:FOREVECTOR, SHIP:SRFPROGRADE:FOREVECTOR).
UNTIL (_error < .5) {
	//PRINT "Error: " + _error.
	WAIT .01.
}
UNLOCK _error.

PRINT "Locking to prograde.".
LOCK STEERING TO SHIP:SRFPROGRADE.

LOCK _firstStageDvDetached TO fn_calculateDv(4, true).
LOCK _dvUntilMeco TO _firstStageDvDetached - SHIP:VELOCITY:SURFACE:MAG*2 - 500.
WAIT UNTIL (_dvUntilMeco <= 0).

PRINT "MECO.".
LOCK THROTTLE TO 0.
WAIT .001.
STAGE.
WAIT 3.

WAIT UNTIL ETA:APOAPSIS < 15.

PRINT "Reorienting for return burn.".
RCS ON.
SET _steering TO HEADING(-90, 0).
LOCK STEERING TO _steering.

LOCK _error TO VANG(SHIP:FACING:FOREVECTOR, SHIP:SRFPROGRADE:FOREVECTOR).
UNTIL (_error < .5) {
	//PRINT "Error: " + _error.
	WAIT .01.
}
UNLOCK _error.



PRINT "Return burn.".
LOCK THROTTLE TO 1.

WAIT 10.


















// Calculates the dV of the given stage.
// If _detached is true, the dV will be calculated as if the stage were isolated.
// If _detached is false, the dV will be calculated in relation to the whole vessel.
LOCAL FUNCTION fn_calculateDv {
	PARAMETER _stage.
	PARAMETER _detached.

	LOCAL _parts IS fn_filter(
		SHIP:PARTS, 
		{ PARAMETER _part. RETURN _part:STAGE >= _stage. }
	).

	LOCAL _stageDryMass IS 0.
	LOCAL _stageIsp IS 0.
	LOCAL _stageMass IS 0.
	FOR _part IN _parts {
		SET _stageDryMass TO _stageDryMass + _part:DRYMASS.
		IF _part:HASSUFFIX("ISP") {
			SET _stageIsp TO MAX(_stageIsp, _part:ISP).
		}
		SET _stageMass TO _stageMass + _part:MASS.
	}

	// prevent NaN errors
	IF (_stageDryMass * _stageIsp * _stageMass = 0) {
		RETURN 0.
	}

	IF _detached {
		RETURN _stageIsp * 9.8 * LN(_stageMass / _stageDryMass).
	}
	ELSE {
		RETURN _stageIsp * 9.8 * LN(_shipMass / (SHIP:MASS - _stageMass + _stageDryMass)).
	}
}

LOCAL FUNCTION fn_filter {
	PARAMETER _list.
	PARAMETER _lambda.

	LOCAL _filtered IS LIST().
	FOR _item IN _list {
		IF _lambda(_item) {
			_filtered:ADD(_item).
		}
	}
	RETURN _filtered.
}

LOCAL FUNCTION fn_map {
	PARAMETER _list.
	PARAMETER _lambda.

	LOCAL _mapped IS LIST().
	FOR _item IN _list {
		_mapped:ADD(_labmda(_item)).
	}
	RETURN _mapped.
}