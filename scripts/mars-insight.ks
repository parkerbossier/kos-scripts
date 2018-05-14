@LAZYGLOBAL OFF.
CLEARSCREEN.

RUNONCEPATH("functions").

// AG1: Toggle comms
// AG2: Arm/disarm the claw
// AG3: Release the claw
// AG4: Release SEIS winch
// AG5: Release HP3 winch
// AG6: "I have released the arm manually"

//WAIT UNTIL FALSE.

// Duna surface gravity: 2.94
// Kerbin surface gravity: 9.81
// Hack gravity: .3


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
LOCAL _armClaw IS SHIP:PARTSTAGGED("arm-claw").

// #endregion


// #region mission loop

// AwaitingAtmo, AwaitingBackJettison, AwaitingLandingBurn, DeployExperiments
LOCAL _missionPhase IS "DeployExperiments".

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
		PRINT "Arming parachutes.".
		STAGE.

		WAIT UNTIL SHIP:ALTITUDE < 17000.
		PRINT "Switching to surface mode.".
		LOCK STEERING TO SHIP:SRFRETROGRADE.

		LOCAL LOCK _altitude TO SHIP:ALTITUDE - SHIP:GEOPOSITION:TERRAINHEIGHT.

		// wait for chutes to deploy
		WAIT UNTIL _altitude <= 5000.

		// wait for chutes to fully deploy
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
			LIST(.3, FALSE, .4),
			FALSE
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

		SET _missionPhase TO "DeployExperiments".
	}

	ELSE IF (_missionPhase = "DeployExperiments") {
		// deploy comms
		//TOGGLE AG1.
		//WAIT 5.

		//WAIT UNTIL FALSE.

		PANELS ON.
		WAIT 5.

		// start forcing the claw to point straight down
		LOCAL LOCK _armClawAngle TO
			180
			- fn_getHingePartServo(_armAxes[1]):POSITION
			- fn_getHingePartServo(_armAxes[2]):POSITION.
		ON _armClawAngle {
			fn_getHingePartServo(_armAxes[3]):MOVETO(_armClawAngle, 1).
			RETURN TRUE.
		}

		// deploy seis
		{
			// move the arm clear of the deck
			fn_moveArmTo(LIST(FALSE, -75, FALSE, FALSE)).

			// hover over seis
			fn_moveArmTo(LIST(92.46, -19.79, 143.73, -54.22)).

			// arm the arm
			TOGGLE AG2.
			WAIT 3.

			// grab seis
			fn_moveArmTo(LIST(92.46, -11.98, 149.14, -43.14)).
			WAIT 1.

			// release seis winch
			AG4 ON.
			WAIT 1.

			// lift it up
			fn_moveArmTo(LIST(FALSE, -30.38, 139.94, -71.05)).

			// move to deployment
			fn_moveArmTo(LIST(20.96, 64.34, 82.27, -35.02)).
			WAIT 1.

			// "release"
			fn_waitOnAG6().

			// give room for the arm to disarm
			fn_moveArmTo(LIST(FALSE, 54.67, FALSE, FALSE)).

			// disarm the arm to avoid the graphical glitch
			TOGGLE AG2.
		}

		// deploy seis cover
		{
			// hover over cover
			fn_moveArmTo(LIST(146.38, 6, 105.66, -66.66)).

			// re-arm the arm
			TOGGLE AG2.
			WAIT 3.

			// decouple the cover
			STAGE.
			WAIT 1.

			// grab cover
			fn_moveArmTo(LIST(FALSE, 11.18, 111.07, -57.86)).
			WAIT 1.

			// lift it up
			fn_moveArmTo(LIST(FALSE, 13.49, 81.74, -83.56)).
		}

		// move it 

		//LOCAL _armLocationPickupSeis IS LIST(94.2, -19.09, 157.76, -39.21).
		//LOCAL _armLocationDropSeis IS LIST(0, 48.24, 115.5, -14.71).

		//fn_moveArmTo(_armLocationPickupSeis, 1).

		//fn_moveArmTo(_armLocationPickupSeis, 1).

		//fn_moveArmTo(_armLocationDropSeis, 1).


		LOCAL _armLocationStowed IS LIST(-4, -90, 180, 0).

		SET _done TO TRUE.

		
	}
}

// #endregion



// #region mission-specific functions

LOCAL FUNCTION fn_getHingePartServo {
	PARAMETER _part.

	LOCAL _servo IS ADDONS:IR:PARTSERVOS(_part)[0].
	RETURN _servo.
}

LOCAL FUNCTION fn_moveArmTo {
	PARAMETER _armAxesValues.
	LOCAL _speed IS .5.

	FOR _i IN LIST(0, 1, 2) {
		LOCAL _armAxis IS _armAxes[_i].
		LOCAL _servo IS ADDONS:IR:PARTSERVOS(_armAxis)[0].
		LOCAL _value IS _armAxesValues[_i].
		IF (_value <> FALSE) {
			_servo:MOVETO(_armAxesValues[_i], _speed).
		}
	}

	LOCAL LOCK _moveComplete TO fn_each(
		LIST(0, 1, 2),
		{
			PARAMETER _i.
			
			LOCAL _armAxis IS _armAxes[_i].
			LOCAL _servo IS ADDONS:IR:PARTSERVOS(_armAxis)[0].
			LOCAL _value IS _armAxesValues[_i].
			IF (_value = FALSE) {
				RETURN TRUE.
			}
			ELSE {
				RETURN fn_isCloseEnough(_servo:POSITION, _armAxesValues[_i]).
			}
		}
	).

	WAIT UNTIL _moveComplete.

	LOCAL FUNCTION fn_isCloseEnough {
		PARAMETER _a.
		PARAMETER _b.

		LOCAL _threshold IS .001.

		RETURN ABS(_a - _b) < _threshold.
	}
}

LOCAL FUNCTION fn_waitOnAG6 {
	PRINT "Please release the claw manually and then hit AG6.".
	LOCAL _hit IS FALSE.
	ON AG6 {
		SET _hit TO TRUE.
	}
	WAIT UNTIL _hit.
}

// #endregion
