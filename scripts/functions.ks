@LAZYGLOBAL OFF.

//**
// Executes the next node on the stack
GLOBAL FUNCTION fn_executeNextNode {
	LOCAL _node IS NEXTNODE.

	PRINT "Warping to maneuver node.".
	LOCAL LOCK _burnTime TO _node:DELTAV:MAG / (SHIP:AVAILABLETHRUST / SHIP:MASS).
	WARPTO(TIME:SECONDS + ETA:APOAPSIS - _burnTime/2 - 10).

	PRINT "Orienting for burn.".
	RCS ON.
	LOCK STEERING TO _node:BURNVECTOR.
	fn_waitForShipToFace({ RETURN _node:BURNVECTOR. }, 5).

	WAIT UNTIL ETA:APOAPSIS < _burnTime/2.

	PRINT "Throttle up.".
	LOCK THROTTLE TO 1.
	WAIT UNTIL _burnTime < 1.

	PRINT "Throttling down for fine tuning.".
	LOCK THROTTLE TO 1/5.
	
	// wait for us to bottom out the dV remaining
	LOCAL _prevDvRemaining IS _node:DELTAV:MAG.
	UNTIL (_node:DELTAV:MAG > _prevDvRemaining) {
		SET _prevDvRemaining TO _node:DELTAV:MAG.
		WAIT .001.
	}
	LOCK THROTTLE TO 0.
	RCS OFF.

	// TODO: REMOVE _node, but kOS throws an error :/
	//WAIT 1.
	//REMOVE _node.
}

//**
// Returns a new list consisting of items that match the given lambda.
//
// PARAM _list: The list to filter over
// PARAM _lambda: A function that is passed an item in _list and should return TRUE to include the item
GLOBAL FUNCTION fn_filter {
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

//**
// Performs a flip turn to the desired direction
//
// PARAM _directionFunc: A function that returns the target direction (it's a function so that it can change during execution)
// PARAM _bailOnOvershoot If true, we return as soon as overshoot occurs (presumably engines will then take over). Otherwise, we'll fine tune then return.
//
// NOTE: The ship will perform roll adjustment last, but the functino will return before it's done
GLOBAL FUNCTION fn_flipTurnTo {
	PARAMETER _directionFunc.
	PARAMETER _bailOnOvershoot.
	LOCAL LOCK _direction TO _directionFunc().

	// orient such that up is facing the target direction
	RCS ON.
	LOCAL _bar IS SHIP:FACING:VECTOR.
	LOCAL _steering IS LOOKDIRUP(_bar, _direction:VECTOR).
	LOCK STEERING TO _steering.
	WAIT .01.

	// make sure we're sufficiently stable
	LOCAL LOCK _angularVelocityDeg TO SHIP:ANGULARVEL:MAG * 180 / CONSTANT:PI.
	LOCAL LOCK _done TO STEERINGMANAGER:ROLLERROR < 1 AND _angularVelocityDeg < 2.
	WAIT UNTIL _done.
	UNLOCK _done.

	// final stability assurance
	LOCK STEERING TO "KILL".
	WAIT 1.
	UNLOCK STEERING.

	// begin flip
	LOCAL _burnTime IS 2.
	SET SHIP:CONTROL:PITCH TO 1.
	WAIT _burnTime.
	SET SHIP:CONTROL:PITCH TO 0.
	WAIT .01.

	// mmmm inertia (wait for either (1) we're at the suicide point or (2) we're no longer getting closer becasue of atmo)
	LOCAL _rcsAcceleration IS _angularVelocityDeg / _burnTime.
	LOCAL LOCK _arrestBurnDuration TO _angularVelocityDeg / _rcsAcceleration.
	LOCAL LOCK _degreesToArrest TO _angularVelocityDeg*_arrestBurnDuration - 1/2*_rcsAcceleration*(_arrestBurnDuration^2).
	LOCAL LOCK _degreesToTarget TO VANG(SHIP:FACING:VECTOR, _direction:VECTOR).
	LOCAL _prevDegreesToTarget IS _degreesToTarget.
	UNTIL (_degreesToTarget <= _degreesToArrest OR _degreesToTarget > _prevDegreesToTarget) {
		SET _prevDegreesToTarget TO _degreesToTarget.
		WAIT .01.
	}

	// end flip (by blindly burning for the calculated time)
	SET SHIP:CONTROL:PITCH TO -1.
	LOCAL _timeBurnCompleted IS TIME:SECONDS + _arrestBurnDuration.
	LOCAL _prevDegreesToTarget IS _degreesToTarget.
	UNTIL TIME:SECONDS >= _timeBurnCompleted {
		// if specified, bail out as soon as we overshoot
		// (only likely in atmo because of the extra torque)
		IF (_bailOnOvershoot AND _degreesToTarget > _prevDegreesToTarget) {
			SET SHIP:CONTROL:PITCH TO 0.
			RETURN.
		}
		SET _prevDegreesToTarget TO _degreesToTarget.
		WAIT .01.
	}.
	SET SHIP:CONTROL:PITCH TO 0.

	// fine tuning
	LOCK STEERING TO _directionFunc().
	fn_waitForShipToFace({ RETURN _direction:VECTOR. }, 10).

	RCS OFF.
	UNLOCK _direction.
}

//**
// Returns the gravity magnitude at the given altitude.
//
// PARAM _altitude: (in meters)
GLOBAL FUNCTION fn_getGravityAtAlt {
	PARAMETER _altitude.

	LOCAL _gravity IS SHIP:BODY:MU / (_altitude + SHIP:BODY:RADIUS)^2.
	RETURN _gravity.
}

//**
// Returns the orbital speed at the given altitude.
//
// PARAM _altitude: (in meters)
GLOBAL FUNCTION fn_getOrbitalSpeedAt {
	PARAMETER _altitude.

	LOCAL _r IS SHIP:BODY:RADIUS + _altitude.
	RETURN SQRT(SHIP:BODY:MU * (2/_r - 1/SHIP:ORBIT:SEMIMAJORAXIS)).
}

//**
// A thin wrapper for setting STEERINGMANAGER:MAXSTOPPINGTIME.
//
// PARAM _time: (in seconds)
//
// TODO: remember the previous value and allow for resetting
GLOBAL FUNCTION fn_setStoppingTime {
	PARAMETER _time.
	SET STEERINGMANAGER:MAXSTOPPINGTIME TO _time.
}

//**
// Waits for the ship to face the given vector (to within the given threshold).
//
// PARAM _vectorFunc: A function that returns the target vector (it's a function so that it can change during execution)
// PARAM _threshold: The number of degrees below which we're "facing"
GLOBAL FUNCTION fn_waitForShipToFace {
	PARAMETER _vectorFunc.
	PARAMETER _threshold.

	LOCK _error TO VANG(SHIP:FACING:VECTOR, _vectorFunc()).
	UNTIL (_error < _threshold) {
		//PRINT "Error: " + _error.
		WAIT .05.
	}
	UNLOCK _error.
}
