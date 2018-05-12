@LAZYGLOBAL OFF.
CLEARSCREEN.

RUNONCEPATH("functions").

// #region edl

// situation:
// heading into duna's atmosphere heatshield first (retrograde)

// AwaitingAtmo, AwaitingBackJettison, AwaitingLandingBurn
LOCAL _missionPhase IS "AwaitingAtmo".

LOCAL _done IS FALSE.
UNTIL _done {
	IF (_missionPhase = "AwaitingAtmo") {
		SAS OFF.
		RCS ON.
		LOCK STEERING TO SHIP:RETROGRADE.
		LOCK THROTTLE TO 0.

		PRINT "Waiting for atmo.".
		WAIT UNTIL SHIP:ALTITUDE <= SHIP:BODY:ATM:HEIGHT.

		PRINT "Jettisoning cruise stage.".
		STAGE.

		WAIT UNTIL SHIP:ALTITUDE < 20000.

		PRINT "Switching to surface mode.".
		LOCK STEERING TO SHIP:SRFRETROGRADE.

		LOCAL LOCK _altitude TO SHIP:ALTITUDE - SHIP:GEOPOSITION:TERRAINHEIGHT.
		WAIT UNTIL _altitude <= 5000.

		PRINT "Deploying parachutes.".
		STAGE.
		WAIT 7.

		PRINT "Jettisoning heat shield.".
		STAGE.

		SET _missionPhase TO "AwaitingBackJettison".
	}

	ELSE IF (_missionPhase = "AwaitingBackJettison") {
		LOCAL LOCK _altitude TO SHIP:ALTITUDE - SHIP:GEOPOSITION:TERRAINHEIGHT.
		WAIT UNTIL _altitude <= 2500.

		PRINT "Jettisoning back shell.".
		STAGE.
		RCS OFF.

		// let the stage happen before calculating dV et al
		WAIT .001.

		SET _missionPhase TO "AwaitingLandingBurn".
	}

	ELSE IF (_missionPhase = "AwaitingLandingBurn") {
		fn_suicideBurnLanding(
			20,
			50,
			-3,
			LIST(.3, -1, .4),
			-1
		).

		PRINT "Touchdown.".
		LOCK THROTTLE TO 0.
		UNLOCK STEERING.

		PRINT "Shutting down engines.".
		LOCAL _engines IS LIST().
		LIST ENGINES IN _engines.
		FOR _e IN _engines {
			_e:SHUTDOWN.
		}

		SET _done TO TRUE.
	}
}


//** Returns dV of the entire remaining vessel,
//** so don't call this until the lander is all that's left!
LOCAL FUNCTION fn_claculateLanderDv {
	LOCAL _stageDryMass IS 0.
	LOCAL _stageIspNumerator IS 0.
	LOCAL _stageIspDenominator IS 0.
	LOCAL _stageMass IS 0.
	FOR _part IN SHIP:PARTS {
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

	RETURN _stageIsp * 9.8 * LN(_stageMass / _stageDryMass).
}



// #endregion

WAIT UNTIL FALSE.



// #region arm parts

LOCAL _armAxes IS LIST(
	//** Shoulder rotation. Positive is counterclockwise.
	SHIP:PARTSTAGGED("arm-axis-0")[0],
	//** Shoulder hinge. Positive is away from the ship when the shoulder rotation is 0.
	SHIP:PARTSTAGGED("arm-axis-1")[0],
	//** Elbow rotation. Negative is away from the ship when all other axes are 0.
	SHIP:PARTSTAGGED("arm-axis-2")[0],
	//** Elbow rotation. Negative is away from the ship when all other axes are 0.
	SHIP:PARTSTAGGED("arm-axis-3")[0]
).

//** Shoulder (deck axis). Positive is counterclockwise.
LOCAL _armAxis0 IS SHIP:PARTSTAGGED("arm-axis-0")[0].
//** Shoulder rotation. Positive is away from the ship when the shoulder rotation is 0.
LOCAL _armAxis1 IS SHIP:PARTSTAGGED("arm-axis-1")[0].
//** Elbow rotation. Positive is away from the ship when all other axes are 0.
LOCAL _armAxis2 IS SHIP:PARTSTAGGED("arm-axis-2")[0].
//** Elbow rotation. Positive is away from the ship when all other axes are 0.
LOCAL _armAxis3 IS SHIP:PARTSTAGGED("arm-axis-3")[0].
//** The claaaawwwwwwww
LOCAL _armClaw IS SHIP:PARTSTAGGED("arm-claw").

// #endregion

// #region arm axis locations

LOCAL _armLocationStowed IS LIST(-26, -90, 180, -55.5).
LOCAL _armLocationPickupSeis IS LIST(140.17, -33.16, 153.05, -58.47).
LOCAL _armLocationDropSeis IS LIST(0, 48.24, 115.5, -14.71).

// #endregion

LOCAL FUNCTION _fn_arm_move_to {
	PARAMETER _armAxesValues.
	PARAMETER _speed.

	FOR _i IN LIST(0, 1, 2, 3) {
		LOCAL _armAxis IS _armAxes[_i].
		LOCAL _servo IS ADDONS:IR:PARTSERVOS(_armAxis)[0].
		_servo:MOVETO(_armAxesValues[_i], _speed).
	}
}

//_fn_arm_move_to(_armLocationStowed, 1).

_fn_arm_move_to(_armLocationPickupSeis, 1).

//_fn_arm_move_to(_armLocationDropSeis, 1).
