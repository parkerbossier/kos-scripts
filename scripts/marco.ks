@LAZYGLOBAL OFF.
CLEARSCREEN.

RUNONCEPATH("functions").

// AG9: Deploy MarCO panels and comms

PRINT "Waiting for ejection message.".
WAIT UNTIL NOT CORE:MESSAGES:EMPTY.

PRINT "Waiting for sufficient range.".
WAIT 20.

PRINT "Deploying.".
AG9 ON.
