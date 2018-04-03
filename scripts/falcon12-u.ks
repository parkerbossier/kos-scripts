@LAZYGLOBAL OFF.
CLEARSCREEN.

// TODO: move RCS down

RUNONCEPATH("functions").

// Initial, SlowStart, ToApo, Circularize, Deorbit
LOCAL _missionPhase IS "SlowStart".

// program-global definitions
LOCAL _targetAltitude IS 100000.

LOCAL _done IS FALSE.
UNTIL (_done) {
	IF (_missionPhase = "Initial") {
		PRINT "Waiting for signal from lower stage.".
		WAIT UNTIL NOT CORE:MESSAGES:EMPTY.
		CORE:MESSAGES:POP().

		PRINT "Stage separation and engine activation.".
		STAGE.

		// keep our distance
		WAIT 2.

		SET _missionPhase TO "SlowStart".
	}

	ELSE IF (_missionPhase = "SlowStart") {
		PRINT "Beginning low thrust separation increase.".
		LOCK STEERING TO SHIP:PROGRADE.
		LOCK THROTTLE TO .1.
		WAIT 3.

		SET _missionPhase TO "ToApo".
	}

	ELSE IF (_missionPhase = "ToApo") {
		// redundant if starting with "Initial"
		LOCK STEERING TO SHIP:PROGRADE.

		// we'll hit vacuum before we finish burning, so async
		WHEN (SHIP:ALTITUDE > SHIP:BODY:ATM:HEIGHT) THEN {
			PRINT "Jettisoning fairing.".
			STAGE.
		}

		PRINT "Burning until target apoapsis.".
		LOCK THROTTLE TO 1.
		WAIT UNTIL SHIP:APOAPSIS > _targetAltitude.
		LOCK THROTTLE TO 0.

		// wait for things to settle down
		WAIT .01.

		SET _missionPhase TO "Circularize".
	}

	ELSE IF (_missionPhase = "Circularize") {
		PRINT "Waiting for vacuum.".
		WAIT UNTIL SHIP:ALTITUDE > SHIP:BODY:ATM:HEIGHT.
		WAIT 1.

		PRINT "Creating circularization node.".
		LOCAL _targetSpeed IS SQRT(SHIP:BODY:MU / (_targetAltitude + SHIP:BODY:RADIUS)).
		LOCAL _circularizationDv IS _targetSpeed - fn_orbitalSpeedAtAlt(SHIP:APOAPSIS).
		LOCAL _node IS NODE(TIME:SECONDS + ETA:APOAPSIS, 0, 0, _circularizationDv).
		ADD _node.
		WAIT .01.

		fn_executeNextNode().

		PRINT "Target orbit achieved.".
		WAIT 2.

		PRINT "Detaching payload".
		STAGE.

		SET _missionPhase TO "Deorbit".
	}

	ELSE IF (_missionPhase = "Deorbit") {
		PRINT "Re-orienting for deorbit burn.".
		LOCAL _steering IS SHIP:RETROGRADE:VECTOR.
		LOCK STEERING TO _steering.
		fn_waitForShipToFace({ RETURN _steering. }, 5).

		PRINT "Throttle up.".
		LOCK THROTTLE TO 1.
		WAIT 5.

		PRINT "I am now trash.".

		SET _done TO TRUE.
	}
}
