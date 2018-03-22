@LAZYGLOBAL OFF.

LOCAL _padPosition IS SHIP:POSITION - SHIP:BODY:POSITION.
LOCAL _returnPosition IS _padPosition.

IF (TRUE) {

	PRINT "Preflight.".
	LOCK STEERING TO HEADING(0, 90).
	LOCK THROTTLE TO 1.
	WAIT .5.

	PRINT "Launch.".
	STAGE.
	WAIT UNTIL SHIP:ALTITUDE > 300.

	PRINT "Roll program.".
	LOCK STEERING TO HEADING(90, 90).
	WAIT UNTIL SHIP:VERTICALSPEED >= 100.

	PRINT "Begining gravity turn.".
	LOCK STEERING TO HEADING(90, 90 - 10).
	WAIT 3.
	LOCK _error TO VANG(SHIP:FACING:FOREVECTOR, SHIP:SRFPROGRADE:FOREVECTOR).
	UNTIL (_error < .5) {
		WAIT .01.
	}
	UNLOCK _error.

	PRINT "Locking to prograde.".
	LOCK STEERING TO SHIP:SRFPROGRADE.

	LOCK _firstStageDvDetached TO fn_calculateDv(4, true).
	LOCK _dvUntilMeco TO _firstStageDvDetached - SHIP:VELOCITY:SURFACE:MAG*2 - 500.
	UNTIL (_dvUntilMeco <= 0) {
		PRINT "First stage dV: " + _firstStageDvDetached.
		WAIT .1.
	}

	PRINT "MECO.".
	LOCK THROTTLE TO 0.
	WAIT 1.

	PRINT "Booster separation".
	STAGE.
	WAIT 2.

}

UNTIL (FALSE) {
	WAIT .1.
}

// TODO: tell the upper stage to go

PRINT "Reorienting for return burn.".
RCS ON.
LOCK _steering TO 1.


LOCAL _oldMaxStoppingTime IS STEERINGMANAGER:MAXSTOPPINGTIME.
SET STEERINGMANAGER:MAXSTOPPINGTIME TO 4.
SET _steering TO HEADING(-90, 0).
LOCK STEERING TO _steering.

LOCK _error TO VANG(SHIP:FACING:FOREVECTOR, _steering:FOREVECTOR).
UNTIL (_error < 5) {
	PRINT "Error: " + _error.
	WAIT .01.
}
UNLOCK _error.
SET STEERINGMANAGER:MAXSTOPPINGTIME TO _oldMaxStoppingTime.



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
