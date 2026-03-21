class_name Duration

## This class represents the amount of time between two points in time along the game time time line.
## Usage:
## [codeblock]
## var instant_one = Instant.new(2024, 1, 4, 0, 0, 0)
## var instant_two = Instant.new(2024, 1, 4, 0, 0, 1)
## var duration = Duration.new(instant_one, instant_two)
## print(duration.duration_length_in_units(TimeUnit.MILLISECOND)) # Prints 1
## print(duration.duration_length_in_units(TimeUnit.SECOND)) # Prints 0
## [/codeblock]

var _start: GameTime
var _end: GameTime
var _duration_in_millisecond: int

func _init(start: GameTime, end: GameTime):
	if end.is_before(start):
		self._start = end
		self._end = start
	else:
		self._start = start
		self._end = end
	self._duration_in_millisecond = self._end.get_epoch() - self._start.get_epoch()

## Returns the start of the duration as a [GameTime]
func get_start() -> GameTime:
	return self._start

## Returns the end of the duration as a [GameTime]
func get_end() -> GameTime:
	return self._end

## Returns the length of the duration in the given unit
## Note: This will always return the difference by the amount of milliseconds between the start and end.
## EX: if there is a one day difference, it will return [code]GameTime.MILLISECONDS_IN_DAY[/code]
func duration_length_in_units(unit: TimeUnit) -> int:
	match unit:
		TimeUnit.YEAR:
			return _duration_in_millisecond / GameTime.YEAR_DIVISOR
		TimeUnit.YEARS:
			return _duration_in_millisecond / GameTime.YEAR_DIVISOR
		TimeUnit.DAY:
			return _duration_in_millisecond / GameTime.DAY_DIVISOR
		TimeUnit.DAYS:
			return _duration_in_millisecond / GameTime.DAY_DIVISOR
		TimeUnit.HOUR:
			return _duration_in_millisecond / GameTime.HOUR_DIVISOR
		TimeUnit.HOURS:
			return _duration_in_millisecond / GameTime.HOUR_DIVISOR
		TimeUnit.MINUTE:
			return _duration_in_millisecond / GameTime.MINUTE_DIVISOR
		TimeUnit.MINUTES:
			return _duration_in_millisecond / GameTime.MINUTE_DIVISOR
		TimeUnit.SECOND:
			return _duration_in_millisecond / GameTime.SECOND_DIVISOR
		TimeUnit.SECONDS:
			return _duration_in_millisecond / GameTime.SECOND_DIVISOR
		TimeUnit.MILLISECOND:
			return _duration_in_millisecond
		TimeUnit.MILLISECONDS:
			return _duration_in_millisecond
		_:
			printerr("Invalid unit " + str(unit))
			push_error("Invalid unit" + str(unit))
			return 0

## Creates a [Duration] from two [Instant] objects
static func create_from_instant(start: Instant, end: Instant) -> Duration:
	return Duration.new(GameTime.create_from_instant(start), GameTime.create_from_instant(end))

## Creates a [Duration] from a length in years, days, hours, minutes, seconds, and milliseconds added to the [param start] [Instant].
static func create_from_length(start: Instant, years: int, days: int, hours: int, minutes: int, seconds: int, milliseconds: int) -> Duration:
	var start_time: GameTime = GameTime.create_from_instant(start)
	var end: GameTime = GameTime.new(start.get_epoch())
	if years > 0:
		end = end.add_unit(years, TimeUnit.YEAR)
	if days > 0:
		end = end.add_unit(days, TimeUnit.DAY)
	if hours > 0:
		end = end.add_unit(hours, TimeUnit.HOUR)
	if minutes > 0:
		end = end.add_unit(minutes, TimeUnit.MINUTE)
	if seconds > 0:
		end = end.add_unit(seconds, TimeUnit.SECOND)
	if milliseconds > 0:
		end = end.add_unit(milliseconds, TimeUnit.MILLISECOND)

	return Duration.new(start_time, end)
