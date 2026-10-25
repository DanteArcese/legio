extends RefCounted
## Converts real elapsed time into whole game ticks.
##
## Game logic only advances on ticks; rendering runs every frame. Leftover
## time carries over so tick spacing stays even regardless of frame rate.

const DEFAULT_TICK_LENGTH := 0.6
## Cap on ticks run in one frame, so a long stall doesn't fast-forward the game.
const MAX_CATCH_UP_TICKS := 5

var tick_length := DEFAULT_TICK_LENGTH:
	set(value):
		assert(value > 0.0, "tick_length must be positive")
		tick_length = value
		_accumulated = minf(_accumulated, tick_length)

var _accumulated := 0.0


## Adds elapsed time and returns how many ticks should run now.
func advance(delta: float) -> int:
	_accumulated += delta
	var ticks := int(_accumulated / tick_length)
	_accumulated -= ticks * tick_length
	if ticks > MAX_CATCH_UP_TICKS:
		ticks = MAX_CATCH_UP_TICKS
		_accumulated = 0.0
	return ticks


## Fraction of the way to the next tick (0..1), for smoothing visuals.
func progress() -> float:
	return _accumulated / tick_length
