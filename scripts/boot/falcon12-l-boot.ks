
IF (TRUE) {
	PRINT "Waiting for physics.".
	WAIT 2.

	CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
	WAIT 5.

	PRINT "Go.".
	SWITCH TO 0.
	RUNPATH("falcon12-l").
}
