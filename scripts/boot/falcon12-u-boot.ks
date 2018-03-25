IF (TRUE) {
	PRINT "Waiting for physics.".
	WAIT 1.

	CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").

	PRINT "Go.".
	SWITCH TO 0.
	RUNPATH("falcon12-u").
}
