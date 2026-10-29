extends Node3D
## A racing track that isn't the frontier circus (the Circus Maximus in
## Rome, whose stands and spina rome.gd builds): just where its racing line
## runs, for the simulation. Named like circus_grounds.gd's constants so the
## sim driver reads both the same way.

@export var CENTER := Vector3.ZERO
## The racing line's straights run this far either side of the centre; the
## turns have this radius.
@export var HALF := 20.0
@export var RADIUS := 10.0
