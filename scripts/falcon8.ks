IF (FALSE) {

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

}






UNTIL (FALSE) {
	fn_calculateLithobrakePosition().
	WAIT 3.
}










//}

//PRINT "Waiting for apoapsis.".
//WAIT UNTIL ETA:APOAPSIS < 20.

PRINT "Booster separation".
WAIT .5.
STAGE.
WAIT 2.

// TODO: tell the upper stage to go

PRINT "Reorienting for return burn.".
RCS ON.
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



// WILL TAKE TIME
// // https://www.reddit.com/r/Kos/comments/1mmotv/how_to_determine_atmospheric_drag_on_your_craft/
LOCAL FUNCTION fn_estimateAeroArea {
	LOCAL _temporalResolution IS .05.

	LOCAL _prevVelocity IS SHIP:VELOCITY:SURFACE.
	WAIT _temporalResolution.
	LOCAL _curVelocity IS SHIP:VELOCITY:SURFACE.

	LOCAL _netAcceleration IS (_curVelocity - _prevVelocity) / _temporalResolution.
	LOCAL _dragAcceleration IS _netAcceleration - fn_getCurrentGravity().
	LOCAL _dragForce IS _dragAcceleration:MAG * SHIP:MASS.

	LOCAL _density IS 1.225 * CONSTANT:E^(SHIP:ALTITUDE/4000).
	LOCAL _dragCoefficient IS .2.
	LOCAL _area IS _dragForce / (.5 * _density * _curVelocity:MAG^2) / _dragCoefficient.
	RETURN _area.
}

LOCAL FUNCTION fn_calculateDragAt {
	PARAMETER _position.
	PARAMETER _velocity.
	PARAMETER _areoArea.

	LOCAL _altitude IS SHIP:BODY:ALTITUDEOF(_position).
	LOCAL _density IS 1.225 * CONSTANT:E^(_altitude/4000).
	LOCAL _dragCoefficient IS .2.

	LOCAL _dragForce IS (.5 * _density * _velocity:MAG^2) * (_dragCoefficient * _areoArea).
	LOCAL _dragAcceleration IS 1. //_dragForce / SHIP:MASS * -SHIP:PROGRADE:FOREVECTOR.
	RETURN _dragAcceleration.
}

// WILL TAKE TIME
// https://www.reddit.com/r/Kos/comments/1mmotv/how_to_determine_atmospheric_drag_on_your_craft/
LOCAL FUNCTION fn_calculateLithobrakePosition {
	CLEARVECDRAWS().

	Local _resolution IS 1. // per second

	LOCAL _initialPositionSoi IS SHIP:POSITION - SHIP:BODY:POSITION.
	LOCAL _positionSoi IS _initialPositionSoi.
	LOCAL _velocity IS SHIP:VELOCITY:SURFACE / _resolution.
	LOCAL _area IS fn_estimateAeroArea().

	LOCAL _i IS 0.
	LOCK _altitude TO SHIP:BODY:ALTITUDEOF(fn_getPosition(_positionSoi)).
	LOCAL _oldPositionSoi IS _positionSoi.
	LOCK _midCalculationShipMovement TO (SHIP:POSITION - SHIP:BODY:POSITION) - _initialPositionSoi.
	UNTIL (_altitude <= 0) {
		VECDRAW(
			fn_getPosition(_oldPositionSoi),
			fn_getPosition(_positionSoi),
			RGB(1,0,0),
			"",
			1,
			TRUE,
			1
		).
		SET _oldPositionSoi TO _positionSoi.

		LOCAL _drag IS V(0,0,0). //fn_calculateDragAt(fn_getPosition(_positionSoi), _velocity, _area).
		LOCAL _gravity IS fn_getGravityAt(fn_getPosition(_positionSoi)) / _resolution.

		SET _positionSoi TO _positionSoi + _velocity.
		SET _velocity TO _velocity + _drag + _gravity.
		SET _i TO _i + 1.
	}
	PRINT "X iterations " + _i.


	LOCAL FUNCTION fn_getPosition {
		PARAMETER _positionSoiParam.
		RETURN _positionSoiParam + SHIP:BODY:POSITION + _midCalculationShipMovement.
	}
}

LOCAL FUNCTION fn_getGravityAt {
	PARAMETER _position.

	// TODO: why do we need "2"?
	LOCAL _altitude2 IS SHIP:BODY:ALTITUDEOF(_position).
	LOCAL _gravityScalar IS SHIP:BODY:MU / (_altitude2 + SHIP:BODY:RADIUS)^2.
	LOCAL _gravityVector IS fn_getDownVectorAt(_position) * _gravityScalar.
	RETURN _gravityVector.
}

LOCAL FUNCTION fn_getDownVectorAt {
	PARAMETER _position.

	LOCAL _soiCoords IS SHIP:POSITION - _position - SHIP:BODY:POSITION.
	LOCAL _down IS -_soiCoords:NORMALIZED.
	RETURN _down.
}

LOCAL FUNCTION fn_getCurrentGravity {
	//PRINT SHIP:ALTITUDE + " " + SHIP:POSITION.
	RETURN fn_getGravityAt(SHIP:POSITION).
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