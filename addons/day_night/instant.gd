class_name Instant

## This class represents a point in time along the game time time line.
## It will automatically convert the point in time to what year, day, hour, minute, second, millisecond, and if it is before or after year 0 it is representing
## [br][br] NOTE: Year zero is considered to be after year 0[br][br]
## Usage:
## [codeblock]
## # The values that represent the point in time
## var year = 2024
## var day = 1
## var hour = 4
## var minute = 0
## var second = 59
## var millisecond = 700
## # This means it is before year 0 and defaults to false if not specified
## var is_negative = true
## # Creates the instant before year 0
## var instant_example_before = Instant.new(year, day, hour, minute, second, millisecond, is_negative)
## # Creates the instant after year 0
## var instant_example_after = Instant.new(year, day, hour, minute, second, millisecond)
## # Prints the second
## print(str(instant_example_before.second)) # Prints 59
## print(str(instant_example_after.second)) # Prints 59
## # Prints if before or after year 0
## print(str(instant_example_before.is_before_year_zero())) # Prints true
## print(str(instant_example_after.is_before_year_zero())) # Prints false
## [/codeblock]

var _epoch:int
var _year: int
var _day: int
var _hour: int
var _minute: int
var _second: int
var _millisecond: int
var _is_negative: bool

func _init(year: int, days: int, hours: int, minutes: int, seconds: int, milliseconds: int, is_negative: bool = false):
	self._year = abs(year)
	self._day = abs(days)
	self._hour = abs(hours)
	self._minute = abs(minutes)
	self._second = abs(seconds)
	self._millisecond = abs(milliseconds)
	var year_milliseconds: int = self._year * GameTime.YEAR_DIVISOR
	var days_milliseconds: int = self._day * GameTime.DAY_DIVISOR
	var hours_milliseconds: int = self._hour * GameTime.HOUR_DIVISOR
	var minutes_milliseconds: int = self._minute * GameTime.MINUTE_DIVISOR
	var seconds_milliseconds: int = self._second * GameTime.SECOND_DIVISOR

	self._is_negative = is_negative
	self._epoch = year_milliseconds + days_milliseconds + hours_milliseconds + minutes_milliseconds + seconds_milliseconds + milliseconds

## Returns the place on the time line this point in time falls on. Ranging from -9223372036854775807 to 9223372036854775807
func get_epoch() -> int:
	if is_before_year_zero():
		return -1 * self._epoch
	return self._epoch

## Returns the year in which this point in time falls
func get_year() -> int:
	return self._year

## Returns the day in which this point in time falls
func get_day() -> int:
	return self._day

## Returns the hour in which this point in time falls
func get_hour() -> int:
	return self._hour

## Returns the minute in which this point in time falls
func get_minute() -> int:
	return self._minute

## Returns the second in which this point in time falls
func get_second() -> int:
	return self._second

## Returns the millisecond in which this point in time falls
func get_millisecond() -> int:
	return self._millisecond

## Returns whether this point in time is before year zero.
## Year zero is considedred to be after year zero.
## [code]true[/code] if this point in time is before year zero, [code]false[/code] otherwise
func is_before_year_zero() -> bool:
	return self._is_negative


