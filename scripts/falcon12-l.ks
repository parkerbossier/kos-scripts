@LAZYGLOBAL OFF.
CLEARSCREEN.

WAIT UNTIL FALSE.

// Initial, MECO, BoostBurn, BurnBack, Re-entry
LOCAL _missionPhase IS "Initial".

// program-global definitions
LOCAL _lowerStageCPUPart IS SHIP:PARTSTAGGED("lowerStageCPU")[0].
LOCAL _lowerStageSecondaryEngines IS SHIP:PARTSTAGGED("lowerStageSecondaryEngine").
LOCAL _oldMaxStoppingTime IS 0.
LOCAL _padGeoCoords IS LATLNG(-.0972561023715436, -74.5576754947717).
LOCAL _resumeControlAfterSeparation IS FALSE.
LOCAL _returnGeoCoords IS _padGeoCoords.

LOCAL _done IS FALSE.
UNTIL (_done) {

	IF (_missionPhase = "Initial") {
		PRINT "Throttle up. Guidance set.".
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
		fn_waitForShipToFace({ RETURN SHIP:SRFPROGRADE:FOREVECTOR. }, .5).

		PRINT "Locking to prograde.".
		LOCK STEERING TO SHIP:SRFPROGRADE.

		SET _missionPhase TO "BoostBurn".
	}

	ELSE IF (_missionPhase = "BoostBurn") {
		PRINT "Burning until point of no return.".
		LOCAL LOCK _lowerStageDvDetached TO fn_calculateDv(2, true).
		LOCAL LOCK _dvUntilMeco TO _lowerStageDvDetached - SHIP:VELOCITY:SURFACE:MAG*2 - 500.
		WAIT UNTIL _dvUntilMeco <= 0.
		UNLOCK _dvUntilMeco.
		UNLOCK _lowerStageDvDetached.

		SET _missionPhase TO "MECO".
	}

	ELSE IF (_missionPhase = "MECO") {
		PRINT "MECO.".
		LOCK THROTTLE TO 0.
		WAIT 1.

		// we need to signal the upper stage so that it can control staging
		// (because inter-vessel commsunication is broken)
		PRINT "Transfering staging control to upper stage.".
		LOCAL _upperStageCPU IS PROCESSOR("upperStageCPU").
		_upperStageCPU:CONNECTION:SENDMESSAGE(TRUE).

		// wait until we know staging is done
		WAIT 2.

		PRINT "Separation complete.".
		IF (_resumeControlAfterSeparation) {
			KUNIVERSE:FORCEACTIVE(_lowerStageCPUPart:SHIP).
		}

		SET _missionPhase TO "BurnBack".
	}

	ELSE IF (_missionPhase = "BurnBack") {
		PRINT "Re-orienting to engines first.".
		LOCK STEERING TO HEADING(_returnGeoCoords:HEADING, 0).
		RCS ON.
		fn_setStoppingTime(4).
		fn_waitForShipToFace({ RETURN STEERING:VECTOR. }, 5).
		fn_resetStoppingTime().

		PRINT "Ignition.".
		LOCK THROTTLE TO 1.
		RCS OFF.

		PRINT "Burning until target intercept.".
		ADDONS:TR:SETTARGET(_returnGeoCoords).
		LOCAL LOCK _distance TO (ADDONS:TR:IMPACTPOS:POSITION - _returnGeoCoords:POSITION):MAG.
		LOCAL _prevDistance IS _distance.
		LOCAL LOCK _distanceDelta TO _distance - _prevDistance.
		UNTIL (_distanceDelta > 0) { //} AND _distance > 1000) {
			SET _prevDistance TO _distance.
			// using .1 so that we don't have noise ruin our stopping condition
			WAIT .1.
		}

		PRINT "Burn complete. Error: " + _distanceDelta + ".".
		LOCK THROTTLE TO 0.
		UNLOCK _distance.
		UNLOCK _distanceDelta.
		WAIT 1.

		PRINT "Deactivating secondary engine.".
		fn_forEach(_lowerStageSecondaryEngines, { PARAMETER _eng. _eng:SHUTDOWN(). }).

		SET _missionPhase TO "Re-entry".
	}

	ELSE IF (_missionPhase = "Re-entry") {
		// the below contiguous lines are unnecessary if entering directly into this phase
		ADDONS:TR:SETTARGET(_returnGeoCoords).

		PRINT "Re-orient for re-entry.".
		LOCK STEERING TO LOOKDIRUP(ADDONS:TR:PLANNEDVECTOR + ADDONS:TR:CORRECTEDVEC, SHIP:UP:FOREVECTOR).
		RCS ON.
		fn_setStoppingTime(4).
		fn_waitForShipToFace({ RETURN STEERING:FOREVECTOR. }, 5).
		fn_resetStoppingTime().

		// async
		WHEN (SHIP:ALTITUDE < 20000) THEN {
			PRINT "Switching attitude control to grid fins.".
			RCS OFF.
			BRAKES ON.
		}

		PRINT "Waiting for estimated suicide burn.".
		Wait UNTIL fn_calculateDistanceToSuicideBurn() < 0.

		PRINT "Beginning powered descent.".
		LOCAL LOCK _altitude TO SHIP:ALTITUDE - SHIP:GEOPOSITION:TERRAINHEIGHT.
		LOCAL LOCK _distanceToBurn TO fn_calculateDistanceToSuicideBurn().
		//LOCAL LOCK STEERING TO SHIP:SRFRETROGRADE.
		LOCAL LOCK _verticalVelocity TO SHIP:VELOCITY:SURFACE * SHIP:UP:FOREVECTOR.

		LOCAL _throttlePid IS PIDLOOP(.01, 0.01, 0.01, -.05, .05).
		SET _throttlePid:SETPOINT TO 0.

		LOCAL _throttle IS .1.
		LOCK THROTTLE TO _throttle.
		LOCAL _throttleDelta IS 0.

		UNTIL (SHIP:STATUS = "LANDED") {
			// slow the descent at 800m
			if (_altitude < 800) {
				SET _throttlePid:SETPOINT TO -10.
				SET _throttlePid:KP TO .2.
				//SET _throttlePid:KI TO .1.
				SET _throttleDelta TO _throttlePid:UPDATE(TIME:SECONDS, _verticalVelocity).
				GEAR ON.
				RCS ON.
			}
			ELSE {
				SET _throttleDelta TO _throttlePid:UPDATE(TIME:SECONDS, _distanceToBurn).
			}

			SET _throttle TO MIN(1, MAX(_throttle + _throttleDelta, 0)).

			// 5m is close enough
			IF (_altitude < 5) {
				BREAK.
			}

			WAIT .01.
		}

		PRINT "Touchdown. Stabilizing.".
		SET THROTTLE TO 0.
		WAIT .01.
		UNLOCK THROTTLE.
		LOCK STEERING TO SHIP:UP.
		WAIT 1.

		PRINT "The Falcon has landed.".
		UNLOCK STEERING.
		RCS OFF.
		BRAKES OFF.

		SET _done TO TRUE.

		// no need to unlock the recently created LOCKs because we're done
	}
}





//
//
// FUNCTION DECLARATIONS
//
//


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

LOCAL FUNCTION fn_calculateDistanceToSuicideBurn {
	// negative means down
	LOCAL _verticalAcc IS SHIP:AVAILABLETHRUST/SHIP:MASS - fn_getGravityAt(SHIP:ALTITUDE).
	// TODO: why 2?
	LOCAL _verticalVelocity2 IS SHIP:VELOCITY:SURFACE * SHIP:UP:FOREVECTOR.
	LOCAL _stoppingTime IS (0 - _verticalVelocity2) / _verticalAcc.
	LOCAL _burnHeight IS (-_verticalVelocity2 / 2) * _stoppingTime.

	RETURN SHIP:ALTITUDE - SHIP:GEOPOSITION:TERRAINHEIGHT - _burnHeight.
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

LOCAL FUNCTION fn_forEach {
	PARAMETER _list.
	PARAMETER _lambda.

	FOR _item IN _list {
		_lambda(_item).
	}
}

LOCAL FUNCTION fn_getGravityAt {
	// TODO: why 2?
	PARAMETER _altitude2.

	LOCAL _gravity IS SHIP:BODY:MU / (_altitude2 + SHIP:BODY:RADIUS)^2.
	RETURN _gravity.
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

LOCAL FUNCTION fn_resetStoppingTime {
	SET STEERINGMANAGER:MAXSTOPPINGTIME TO _oldMaxStoppingTime.
}

LOCAL FUNCTION fn_setStoppingTime {
	PARAMETER _value.

	SET _oldMaxStoppingTime TO STEERINGMANAGER:MAXSTOPPINGTIME.
	SET STEERINGMANAGER:MAXSTOPPINGTIME TO _value.
}

LOCAL FUNCTION fn_vectorDistance {
	PARAMETER _v1.
	PARAMETER _v2.

	LOCAL _d IS SQRT((_v2:X - _v1:X)^2 + (_v2:Y - _v1:Y)^2 + (_v2:Z - _v1:Z)^2).
	RETURN _d.
}

//** Waits for the ship to face
LOCAL FUNCTION fn_waitForShipToFace {
	PARAMETER _toVectorFunc.
	PARAMETER _threshold.

	LOCK _a TO _toVectorFunc().
	LOCK _error TO VANG(SHIP:FACING:FOREVECTOR, _a).
	UNTIL (_error < _threshold) {
		//PRINT "Error: " + _error.
		WAIT .05.
	}
	UNLOCK _error.
}
