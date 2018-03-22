@LAZYGLOBAL OFF.

LOCAL _padGeoCoords IS LATLNG(-.0972561023715436, -74.5576754947717).
LOCAL _returnGeoCoords IS _padGeoCoords.

LOCAL _oldMaxStoppingTime IS 0.
LOCK _steering TO HEADING(0, 90).

LOCAL _firstStageRGU IS SHIP:PARTSTAGGED("firstStage")[0].

IF (TRUE) {

	PRINT "Preflight.".
	LOCK STEERING TO _steering.
	LOCK THROTTLE TO 1.
	WAIT .5.

	PRINT "Launch.".
	STAGE.
	WAIT UNTIL SHIP:ALTITUDE > 300.

	PRINT "Roll program.".
	LOCK _steering TO HEADING(90, 90).
	WAIT UNTIL SHIP:VERTICALSPEED >= 100.

	PRINT "Begining gravity turn.".
	LOCK _steering TO HEADING(90, 90 - 10).
	WAIT 3.
	fn_waitForShipToFace({ RETURN SHIP:SRFPROGRADE:FOREVECTOR. }, .5).

	PRINT "Locking to prograde.".
	LOCK _steering TO SHIP:SRFPROGRADE.

	LOCK _firstStageDvDetached TO fn_calculateDv(4, true).
	LOCK _dvUntilMeco TO _firstStageDvDetached - SHIP:VELOCITY:SURFACE:MAG*2 - 500.
	UNTIL (_dvUntilMeco <= 0) {
		PRINT "First stage dV: " + _firstStageDvDetached.
		WAIT .1.
	}

	PRINT "MECO.".
	LOCK THROTTLE TO 0.
	WAIT 1.

	PRINT "Stage separation".
	STAGE.
	WAIT 1.
	KUNIVERSE:FORCEACTIVE(_firstStageRGU:SHIP).
	WAIT 1.

}

IF (TRUE) {

	// TODO: tell the upper stage to go

	PRINT "Re-orienting to engines first.".

	ADDONS:TR:SETTARGET(_returnGeoCoords).
	LOCK _steering TO HEADING(_returnGeoCoords:HEADING, 0).
	RCS ON.
	fn_setStoppingTime(6).
	fn_waitForShipToFace({ RETURN _steering:VECTOR. }, 5).
	fn_resetStoppingTime().

	PRINT "Ignition.".
	LOCK THROTTLE TO 1.
	RCS OFF.

	LOCK _distance TO (ADDONS:TR:IMPACTPOS:POSITION - _returnGeoCoords:POSITION):MAG.
	LOCAL _prevDistance IS _distance.
	LOCK _distanceDelta TO _distance - _prevDistance.
	UNTIL (_distanceDelta > 0 AND _distance > 1000) {
		PRINT _distanceDelta.
		SET _prevDistance TO _distance.
		// using .1 so that we don't have noise ruin our stopping condition
		WAIT .1.
	}

	PRINT "Burn complete.".
	LOCK THROTTLE TO 0.

}


PRINT "Re-orient for re-entry.".
LOCK _steering TO ADDONS:TR:PLANNEDVECTOR + ADDONS:TR:CORRECTEDVEC.
RCS ON.
BRAKES ON.
fn_setStoppingTime(6).
fn_waitForShipToFace({ RETURN _steering. }, 5).
fn_resetStoppingTime().

UNTIL (SHIP:ALTITUDE < 30000) {
	WAIT .1.
}
RCS OFF.


LOCAL FUNCTION fn_vectorDistance {
	PARAMETER _v1.
	PARAMETER _v2.

	LOCAL _d IS SQRT((_v2:X - _v1:X)^2 + (_v2:Y - _v1:Y)^2 + (_v2:Z - _v1:Z)^2).
	RETURN _d.
}



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

LOCAL FUNCTION fn_waitForShipToFace {
	PARAMETER _toVectorFunc.
	PARAMETER _threshold.

	LOCK _a TO _toVectorFunc().
	LOCK _error TO VANG(SHIP:FACING:FOREVECTOR, _a).
	UNTIL (_error < _threshold) {
		PRINT "Error: " + _error.
		WAIT .05.
	}
	UNLOCK _error.
}


LOCAL FUNCTION fn_setStoppingTime {
	PARAMETER _value.

	SET _oldMaxStoppingTime TO STEERINGMANAGER:MAXSTOPPINGTIME.
	SET STEERINGMANAGER:MAXSTOPPINGTIME TO _value.
}
LOCAL FUNCTION fn_resetStoppingTime {
	SET STEERINGMANAGER:MAXSTOPPINGTIME TO _oldMaxStoppingTime.
}