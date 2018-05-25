
IF (TRUE) {
	PRINT "Waiting for physics.".
	WAIT 2.

	//CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").

	PRINT "Go.".
	SWITCH TO 0.
	RUNPATH("marco").
}
