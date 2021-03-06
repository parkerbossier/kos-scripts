@LAZYGLOBAL OFF.
CLEARSCREEN.

RUNONCEPATH("functions").

// AG1: Toggle comms
// AG2: Arm/disarm the claw
// AG3: Release the claw
// AG4: Release SEIS winch
// AG5: Release HP3 winch
// AG6: "I have released the arm manually"
// AG7: Next camera
// AG8: Control from upper stage
// AG9: Deploy MarCO panels and comms

LOCAL _hingeSpeed IS .5.

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



// TODO:
// - Move fairing to before upper stage activation


// #region mission loop

// AwaitingEjectionBurn, DeployMarco, AwaitingAtmo, AwaitingBackJettison, AwaitingLandingBurn, DeployExperiments
LOCAL _missionPhase IS "AwaitingAtmo".

LOCAL _done IS FALSE.
UNTIL _done {
	IF (_missionPhase = "AwaitingEjectionBurn") {
		PRINT "Hit AG6 to execute next node.".
		fn_waitOnAG6().
		fn_executeNextNode().
		RCS ON.
		SAS ON.

		// for stability
		WAIT 5.

		SET _missionPhase TO "DeployMarco".
	}

	ELSE IF (_missionPhase = "DeployMarco") {
		LOCAL _marcoACpu IS PROCESSOR("marco-a-cpu").
		LOCAL _marcoAPusher IS SHIP:PARTSTAGGED("marco-a-pusher")[0].
		LOCAL _marcoBCpu IS PROCESSOR("marco-b-cpu").
		LOCAL _marcoBPusher IS SHIP:PARTSTAGGED("marco-b-pusher")[0].

		PRINT "Ejecting MarCO.".
		_marcoACpu:CONNECTION:SENDMESSAGE("ejection start").
		_marcoBCpu:CONNECTION:SENDMESSAGE("ejection start").
		WAIT 1.
		STAGE.
		WAIT 1.
		ADDONS:IR:PARTSERVOS(_marcoAPusher)[0]:MOVETO(.3, 1).
		ADDONS:IR:PARTSERVOS(_marcoBPusher)[0]:MOVETO(.3, 1).
		WAIT UNTIL fn_servoPartIsCloseEnough(_marcoAPusher, .3).

		SET _missionPhase TO "AwaitingAtmo".
	}

	ELSE IF (_missionPhase = "AwaitingAtmo") {
		PRINT "Hit AG6 when inside Duna's SOI.".
		fn_waitOnAG6().

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
		PANELS ON.
		WAIT 5.

		// start forcing the claw to point straight down
		LOCAL _allowArmClawPointing IS FALSE.
		LOCAL LOCK _armClawAngle TO
			180
			- fn_getHingePartServo(_armAxes[1]):POSITION
			- fn_getHingePartServo(_armAxes[2]):POSITION.
		ON _armClawAngle {
			// we're checking _allowArmClawPointing here (as opposed to killing the ON)
			// so that we can toggle _allowArmClawPointing at will
			IF (_allowArmClawPointing) {
				fn_getHingePartServo(_armAxes[3]):MOVETO(_armClawAngle, 1).
			}
			RETURN TRUE.
		}

		{
			PRINT "Deploying SEIS.".

			// move the arm clear of the deck
			fn_moveArmTo(LIST(FALSE, -90 + 15, 180 - 15)).

			SET _allowArmClawPointing TO TRUE.

			// hover over seis
			fn_moveArmTo(LIST(92.46, -19.79, 143.73)).

			// arm the arm
			TOGGLE AG2.
			WAIT 3.

			// grab seis
			fn_moveArmTo(LIST(FALSE, -11.39, 149.36)).
			WAIT 1.

			// release seis winch
			AG4 ON.
			WAIT 1.

			// lift it clear of the deck
			fn_moveArmTo(LIST(FALSE, -26.97, 135.97)).

			// move to deployment
			fn_moveArmTo(LIST(14.66, 64.3, 85.17)).
			WAIT 1.

			// "release"
			PRINT "Release the claw manualy and hit AG6.".
			fn_waitOnAG6().

			// give room for the arm to disarm
			fn_moveArmTo(LIST(FALSE, 58.38, FALSE)).

			// disarm the arm to kill the graphical glitch
			TOGGLE AG2.
		}

		{
			PRINT "Deploying SEIS cover.".

			// waypoint so we don't hit the solar panels
			fn_moveArmTo(LIST(FALSE, 6.83, 106.29)).

			// hover over cover
			fn_moveArmTo(LIST(146.38, FALSE, FALSE)).

			// re-arm the arm
			TOGGLE AG2.
			WAIT 3.

			// decouple the cover
			STAGE.
			WAIT 1.

			// grab cover
			fn_moveArmTo(LIST(FALSE, 11.15, 111.87)).
			WAIT 1.

			// lift it clear of the deck
			fn_moveArmTo(LIST(FALSE, 1.68, 98.5)).

			// rotate
			fn_moveArmTo(LIST(14.66, FALSE, FALSE)).

			// move to deployment
			fn_moveArmTo(LIST(FALSE, 50.69, 92.95)).

			// "release"
			PRINT "Release the claw manualy and hit AG6.".
			fn_waitOnAG6().

			// give room for the arm to disarm
			fn_moveArmTo(LIST(FALSE, 44.93, FALSE)).

			// disarm the arm to kill the graphical glitch
			TOGGLE AG2.
		}

		{
			PRINT "Deploying HP3".

			// waypoints so we don't hit the solar panels
			fn_moveArmTo(LIST(FALSE, 8, 119.23)).
			fn_moveArmTo(LIST(166.02, FALSE, FALSE)).

			// hover over hp3
			fn_moveArmTo(LIST(FALSE, 3.46, FALSE)).

			// re-arm the arm
			TOGGLE AG2.
			WAIT 3.

			// grab hp3
			fn_moveArmTo(LIST(FALSE, 11.11, 124.38)).
			WAIT 1.

			// release hp3 winch
			AG5 ON.
			WAIT 1.

			// lift it clear of the deck
			fn_moveArmTo(LIST(FALSE, -5.9, 103.97)).

			// rotate
			fn_moveArmTo(LIST(-41.42, FALSE, FALSE)).

			// move to deployment
			fn_moveArmTo(LIST(FALSE, 66.21, 80.37)).
			WAIT 1.

			// "release"
			PRINT "Release the claw manualy and hit AG6.".
			fn_waitOnAG6().

			// give room for the arm to disarm
			fn_moveArmTo(LIST(FALSE, 58.38, FALSE)).

			// disarm the arm to kill the graphical glitch
			TOGGLE AG2.
		}

		PRINT "Moving arm clear of the LaRRI.".
		SET _allowArmClawPointing TO FALSE.
		fn_getHingePartServo(_armAxes[3]):MOVETO(45, _hingeSpeed).
		fn_moveArmTo(LIST(-31.36, -83.57, 180)).

		// deploy comms
		AG1 ON.

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

	FOR _i IN LIST(0, 1, 2) {
		LOCAL _armAxis IS _armAxes[_i].
		LOCAL _servo IS ADDONS:IR:PARTSERVOS(_armAxis)[0].
		LOCAL _value IS _armAxesValues[_i].
		IF (_value <> FALSE) {
			_servo:MOVETO(_armAxesValues[_i], _hingeSpeed).
		}
	}

	LOCAL LOCK _moveComplete TO fn_each(
		LIST(0, 1, 2),
		{
			PARAMETER _i.
			
			LOCAL _armAxis IS _armAxes[_i].
			LOCAL _value IS _armAxesValues[_i].
			IF (_value = FALSE) {
				RETURN TRUE.
			}
			ELSE {
				RETURN fn_servoPartIsCloseEnough(_armAxis, _value).
			}
		}
	).

	WAIT UNTIL _moveComplete.
}

LOCAL FUNCTION fn_servoPartIsCloseEnough {
	PARAMETER _part.
	PARAMETER _target.

	LOCAL _servo IS ADDONS:IR:PARTSERVOS(_part)[0].
	LOCAL _threshold IS .001.

	RETURN ABS(_servo:POSITION - _target) < _threshold.
}

LOCAL FUNCTION fn_waitOnAG6 {
	LOCAL _hit IS FALSE.
	ON AG6 {
		SET _hit TO TRUE.
	}
	WAIT UNTIL _hit.
}

// #endregion
