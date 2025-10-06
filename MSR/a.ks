CLEARSCREEN.

PRINT "starting a.ks".

// LOCAL winchPart IS SHIP:PARTSTAGGED("winch")[0].
// LOCAL winchModule IS winchPart:GETMODULE("KASLinkWinch").
// PRINT winchModule:ALLFIELDS.
// PRINT winchModule:ALLEVENTS.

// LOCAL FUNCTION extendSkyCrane {
// 	PRINT "Extending sky crane".
// 	LOCAL LOCK winchLength TO winchModule:GETFIELD("deployed cable length").
// 	winchModule:DOEVENT("extend cable").
// 	WAIT UNTIL winchLength > 5.
// 	winchModule:DOEVENT("stop extending").
// 	PRINT "Sky crane extended".
// }

// WAIT 3.
// PRINT "Detaching sky crane".
// winchModule:DOEVENT("detach connector").

LOCAL hoverPid IS PIDLOOP(1, 0, .5, 0, 1).
SET hoverPid:SETPOINT TO 100.

LOCAL pidThrottle IS .5.
LOCK THROTTLE TO pidThrottle.

LOCAL targetLat IS SHIP:LATITUDE.
LOCAL targetLon IS SHIP:LONGITUDE.
// the amount to angle towards north
LOCAL latPid IS PIDLOOP(1, 0, .5, -45, 45).
SET latPid:SETPOINT TO targetLat.
LOCAL LOCK a TO 1.

// steer heading up and facing south
LOCK STEERING TO LOOKDIRUP(SHIP:UP:VECTOR, -SHIP:NORTH:VECTOR).
// SAS ON.

UNTIL FALSE {
	PRINT "alt: " + SHIP:ALTITUDE + " lat: " + SHIP:LATITUDE.

	LOCAL throttlePidUpdate IS hoverPid:UPDATE(TIME:SECONDS, SHIP:ALTITUDE).
	SET pidThrottle TO throttlePidUpdate.

	// LOCAL latPidUpdate IS latPid:UPDATE(TIME:SECONDS, SHIP:LATITUDE).
	WAIT 0.
}
