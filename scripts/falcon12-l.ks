@LAZYGLOBAL OFF.
CLEARSCREEN.

RUNONCEPATH("functions").

//WAIT UNTIL FALSE.

// Initial, BoostBurn, MECO, BurnBack, ReEntry, PoweredDescent
LOCAL _missionPhase IS "Initial".

// program-global definitions
LOCAL _lowerStageCPUPart IS SHIP:PARTSTAGGED("lowerStageCPU")[0].
LOCAL _oldMaxStoppingTime IS 0.
LOCAL _padGeoCoords IS LATLNG(-.067166787, -74.777452836).
LOCAL _resumeControlAfterSeparation IS TRUE.
LOCAL _returnGeoCoords IS _padGeoCoords.
LOCAL _separationStageNum IS 1.

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
		fn_waitForShipToFace({ RETURN SHIP:SRFPROGRADE:VECTOR. }, .5).

		SET _missionPhase TO "BoostBurn".
	}

	ELSE IF (_missionPhase = "BoostBurn") {
		// the below contiguous lines are unnecessary if entering directly into this phase
		LOCK THROTTLE TO 1.
		WAIT .1.

		PRINT "Locking to prograde.".
		LOCK STEERING TO SHIP:SRFPROGRADE.

		PRINT "Burning until point of no return.".
		LOCAL LOCK _lowerStageDvDetached TO fn_calculateDv(1, TRUE).
		LOCAL LOCK _dvUntilMeco TO _lowerStageDvDetached - SHIP:VELOCITY:SURFACE:MAG*2.
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
		WAIT 1.

		PRINT "Separation complete.".
		IF (_resumeControlAfterSeparation) {
			KUNIVERSE:FORCEACTIVE(_lowerStageCPUPart:SHIP).
		}

		//PRINT "Quicksaving.".
		//WAIT .5.
		//KUNIVERSE:QUICKSAVETO("mission").
		//WAIT .5.

		SET _missionPhase TO "BurnBack".
	}

	ELSE IF (_missionPhase = "BurnBack") {
		fn_setStoppingTime(3).
		PRINT "Re-orienting to engines first.".
		LOCAL LOCK _burnBackDirection TO LOOKDIRUP(HEADING(_returnGeoCoords:HEADING, 0):VECTOR, SHIP:UP:VECTOR).
		fn_flipTurnTo(_burnBackDirection, false).
		LOCK STEERING TO _burnBackDirection.

		PRINT "Ignition.".
		LOCK THROTTLE TO 1.

		// blindly burn if we're not active because TR doesn't work on non-active vessels
		IF (NOT _resumeControlAfterSeparation) {
			PRINT "Can't predict atmospheric trajectory. See ya!".
			WAIT UNTIL FALSE.
		}

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

		LOCK THROTTLE TO 0.
		PRINT "Burn complete. Error: " + ROUND(_distanceDelta) + "m.".
		UNLOCK _distance.
		UNLOCK _distanceDelta.
		WAIT 1.

		SET _missionPhase TO "ReEntry".
	}

	ELSE IF (_missionPhase = "ReEntry") {
		// the below contiguous lines are unnecessary if entering directly into this phase
		ADDONS:TR:SETTARGET(_returnGeoCoords).
		fn_setStoppingTime(1).

		PRINT "Re-orient for re-entry.".
		// flipping a full 180 is too finicky
		fn_flipTurnTo(
			LOOKDIRUP(
				VXCL(SHIP:UP:VECTOR, SHIP:RETROGRADE:VECTOR):NORMALIZED + SHIP:UP:VECTOR:NORMALIZED/2,
				SHIP:UP:VECTOR
			),
			true
		).

		RCS ON.
		LOCK _reentrySteering TO LOOKDIRUP(ADDONS:TR:PLANNEDVECTOR + ADDONS:TR:CORRECTEDVEC, SHIP:UP:VECTOR).
		LOCK STEERING TO _reentrySteering.
		fn_waitForShipToFace({ RETURN _reentrySteering:VECTOR. }, 15).

		PRINT "Deploying grid fins.".
		BRAKES ON.

		// async
		WHEN (SHIP:ALTITUDE < 20000) THEN {
			RCS OFF.
		}

		SET _missionPhase TO "PoweredDescent".
	}

	ELSE IF (_missionPhase = "PoweredDescent") {
		// the below contiguous lines are unnecessary if entering directly into this phase
		LOCK _reentrySteering TO LOOKDIRUP(ADDONS:TR:CORRECTEDVEC, SHIP:UP:VECTOR).
		LOCK STEERING TO _reentrySteering.
		WHEN (SHIP:ALTITUDE < 20000) THEN {
			RCS OFF.
		}

		PRINT "Waiting for estimated suicide burn.".
		WAIT UNTIL fn_calculateDistanceToSuicideBurn() < 0.

		PRINT "Beginning powered descent.".
		LOCAL LOCK _altitude TO SHIP:ALTITUDE - SHIP:GEOPOSITION:TERRAINHEIGHT.
		LOCAL LOCK _distanceToBurn TO fn_calculateDistanceToSuicideBurn().
		LOCAL LOCK _verticalVelocity TO SHIP:VELOCITY:SURFACE * SHIP:UP:FOREVECTOR.

		LOCAL _throttlePid IS PIDLOOP(.7, .1, .4, -.05, .05).
		SET _throttlePid:SETPOINT TO 100.

		LOCAL _throttle IS 1.
		LOCK THROTTLE TO _throttle.
		LOCAL _throttleDelta IS 0.

		LOCK STEERING TO SHIP:SRFRETROGRADE.
		WHEN (_altitude < 200) THEN {
			SET _throttlePid:SETPOINT TO -15.
				SET _throttleDelta TO _throttlePid:UPDATE(TIME:SECONDS, _verticalVelocity).
				GEAR ON.
				RCS ON.
		}
		UNTIL (SHIP:STATUS = "LANDED") {
			if (_altitude < 200) {
				SET _throttleDelta TO _throttlePid:UPDATE(TIME:SECONDS, _verticalVelocity).
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
		LOCK THROTTLE TO 0.
		LOCK STEERING TO SHIP:FACING.
		WAIT 1.

		PRINT "The Falcon has landed.".
		UNLOCK STEERING.
		RCS OFF.
		BRAKES OFF.

		PRINT "Shutting down engines.".
		LOCAL _engines IS LIST().
		LIST ENGINES IN _engines.
		FOR _e IN _engines {
			_e:SHUTDOWN.
		}

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
	LOCAL _stageIspNumerator IS 0.
	LOCAL _stageIspDenominator IS 0.
	LOCAL _stageMass IS 0.
	FOR _part IN _parts {
		SET _stageDryMass TO _stageDryMass + _part:DRYMASS.
		// check ISP > 0 because the poodles is included for some reason?
		IF (_part:HASSUFFIX("ISP") AND _part:ISP > 0) {
			SET _stageIspNumerator TO _stageIspNumerator + _part:AVAILABLETHRUST.
			SET _stageIspDenominator TO _stageIspDenominator + (_part:AVAILABLETHRUST / _part:ISP).
		}
		SET _stageMass TO _stageMass + _part:MASS.
	}
	// https://forum.kerbalspaceprogram.com/index.php?/topic/156258-burn-time-calculator/
	LOCAL _stageIsp IS _stageIspNumerator / _stageIspDenominator.

	IF (FALSE) {
		PRINT " ".
		PRINT _stageDryMass.
		PRINT _stageIsp.
		PRINT _stageMass.
		PRINT _stage.
		PRINT _parts.
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
	LOCAL _verticalAcc IS SHIP:AVAILABLETHRUST/SHIP:MASS - fn_getGravityAtAlt(SHIP:ALTITUDE).
	LOCAL _v IS SHIP:VELOCITY:SURFACE:MAG.
	LOCAL _stoppingTime IS _v / _verticalAcc.
	LOCAL _stoppingDistance IS _v * _stoppingTime - (1/2 * _verticalAcc * _stoppingTime^2).

	LOCAL _distanceToBurn IS SHIP:ALTITUDE - SHIP:GEOPOSITION:TERRAINHEIGHT - _stoppingDistance.
	RETURN _distanceToBurn.
}

LOCAL FUNCTION fn_resetStoppingTime {
	SET STEERINGMANAGER:MAXSTOPPINGTIME TO _oldMaxStoppingTime.
}
