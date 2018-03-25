@LAZYGLOBAL OFF.
CLEARSCREEN.

// Initial, ToOrbit
LOCAL _missionPhase IS "Initial".

// program-global definitions
LOCAL _desiredAltitude IS 100000.

LOCAL _done IS FALSE.
UNTIL (_done) {
	IF (_missionPhase = "Initial") {
		PRINT "Waiting for signal from lower stage.".
		WAIT UNTIL NOT CORE:MESSAGES:EMPTY.

		// separation/engine
		STAGE.
		WAIT 1.

		SET _missionPhase TO "ToOrbit".
	}

	ELSE IF (_missionPhase = "ToOrbit") {
		LOCK STEERING TO SHIP:PROGRADE.
		LOCK THROTTLE TO .1.

		WAIT 5.
		LOCK THROTTLE TO 1.

		LOCAL _initialAltitude IS SHIP:ALTITUDE.
		LOCAL LOCK _verticalSpeed TO SHIP:VELOCITY:ORBIT * SHIP:UP:FOREVECTOR.
		LOCAL _initialVerticalSpeed IS _verticalSpeed.
		

		LOCAL _pitchPid IS PIDLOOP(.01, 0.01, 0.01, -.05, .05).
		SET _pitchPid:SETPOINT TO fn_getIdealVerticalSpeed().
		LOCAL _pitch IS 1.
		PRINT SHIP:PROGRADE + " " + SHIP:UP:FOREVECTOR.
		LOCK STEERING TO LOOKDIRUP(SHIP:PROGRADE:FOREVECTOR, SHIP:UP:FOREVECTOR) + R(0, _pitch, 0).
		LOCAL _pitchDelta IS 0.

		UNTIL (SHIP:APOAPSIS > _desiredAltitude) {
			PRINT "set:   " + _pitchPid:SETPOINT.
			PRINT "in:    " + _pitchPid:INPUT.
			PRINT "pitch: " + _pitch.


			SET _pitchDelta TO _pitchPid:UPDATE(TIME:SECONDS, _verticalSpeed).
			SET _pitch TO MIN(20, MAX(_pitch + _pitchDelta, -20)).

			WAIT .01.
		}





		LOCAL FUNCTION fn_getIdealVerticalSpeed {
			LOCAL _m IS (0 - _initialVerticalSpeed) / (_desiredAltitude - _initialAltitude).
			LOCAL _x IS SHIP:APOAPSIS.
			LOCAL _b IS -_m * _desiredAltitude.
			LOCAL _y IS _m * _x + _b.
			RETURN _y.
		}
	}
}
