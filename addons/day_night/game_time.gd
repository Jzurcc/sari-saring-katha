class_name GameTime

## This class is a DateTime representation of time in the game.
## This is how the [DayNightCycle] represents time and interacts with time.
## Game Time is immutable, and will always return a new GameTime object

## Equivalent to 86_400_000
const MILLISECONDS_IN_DAY: int = 86_400_000
## Equivalent to 86_400_000
const DAY_DIVISOR: int = 86_400_000
## Equivalent to 3_600_000
const HOUR_DIVISOR: int = 3_600_000
## Equivalent to 60_000
const MINUTE_DIVISOR: int = 60_000
## Equivalent to 1000
const SECOND_DIVISOR: int = 1000
## Equivalent to 24
const HOURS_IN_DAY: int = 24
## Equivalent to 60
const MINUTES_IN_HOUR: int = 60
## Equivalent to 60
const SECONDS_IN_MINUTE: int = 60
## Equivalent to 1000
const MILLISECONDS_IN_SECOND: int = 1000
const _MIN_INT: int = -9223372036854775807
const _MAX_INT: int = 9223372036854775807
## Set by the [DayNightCycle] script. Represents the number of days in a year
static var DAYS_IN_YEAR: int = -1
## Set by the [DayNightCycle] script, this is calculated from DAYS_IN_YEAR * DAY_DIVISOR
static var YEAR_DIVISOR: int = -1

## Can be negative
var _epoch:int # in milliseconds
var _year: int
var _day: int
var _hour: int
var _minute: int
var _second: int
var _millisecond: int

func _init(epoch:int):
	self._epoch = epoch
	var working_epoch: int = epoch if epoch >= 0 else epoch * -1
	self._year = working_epoch / YEAR_DIVISOR
	working_epoch -= self._year * YEAR_DIVISOR
	self._day = (working_epoch / DAY_DIVISOR)
	working_epoch -= self._day * DAY_DIVISOR
	self._hour =(working_epoch / HOUR_DIVISOR) % 24
	working_epoch -= self._hour * HOUR_DIVISOR
	self._minute = (working_epoch / MINUTE_DIVISOR) % 60
	working_epoch -= self._minute * MINUTE_DIVISOR
	self._second = (working_epoch / SECOND_DIVISOR) % 60
	working_epoch -= self._second * SECOND_DIVISOR
	self._millisecond = working_epoch

## Adds an amount of time to this time.
## Usage:[br]
## [codeblock]
## var some_time = GameTime.new(0)
## var one_day = some_time.add_unit(1, GameTime.TimeUnit.DAYS)
## var ten_years = some_time.add_unit(10, GameTime.TimeUnit.YEARS)
## var three_hours = some_time.add_unit(180, GameTime.TimeUnit.MINUTES)
## [/codeblock]
func add_unit(amount: int, unit: String) -> GameTime:
	if amount < 0:
		push_error("Cannot add invalid amount: " + str(amount))
		return null
	if (unit == TimeUnit.YEARS) or (unit == TimeUnit.YEAR):
		return GameTime.new(min(self.get_epoch() + (amount * YEAR_DIVISOR), _MAX_INT))
	if (unit == TimeUnit.DAYS) or (unit == TimeUnit.DAY):
		var number_of_years_to_add: int = floor(amount / GameTime.DAYS_IN_YEAR)
		var number_of_days_to_add: int = amount % GameTime.DAYS_IN_YEAR
		var new_date: GameTime = GameTime.new(self.get_epoch())
		if number_of_years_to_add > 0:
			new_date = new_date.add_unit(number_of_years_to_add, TimeUnit.YEARS)
		return GameTime.new(min(new_date.get_epoch() + (number_of_days_to_add * DAY_DIVISOR), _MAX_INT))
	if (unit == TimeUnit.HOURS) or (unit == TimeUnit.HOUR):
		var number_of_days_to_add: int = floor(amount / GameTime.HOURS_IN_DAY)
		var number_of_hours_to_add: int = amount % GameTime.HOURS_IN_DAY
		var new_date: GameTime = GameTime.new(self.get_epoch())
		if number_of_days_to_add > 0:
			new_date = new_date.add_unit(number_of_days_to_add, TimeUnit.DAYS)
		return GameTime.new(min(new_date.get_epoch() + (number_of_hours_to_add * HOUR_DIVISOR), _MAX_INT))
	if (unit == TimeUnit.MINUTES) or (unit == TimeUnit.MINUTE):
		var number_of_hours_to_add: int = floor(amount / GameTime.MINUTES_IN_HOUR)
		var number_of_minutes_to_add: int = amount % GameTime.MINUTES_IN_HOUR
		var new_date: GameTime = GameTime.new(self.get_epoch())
		if number_of_hours_to_add > 0:
			new_date = new_date.add_unit(number_of_hours_to_add, TimeUnit.HOURS)
		return GameTime.new(min(new_date.get_epoch() + (number_of_minutes_to_add * MINUTE_DIVISOR), _MAX_INT))
	if (unit == TimeUnit.SECONDS) or (unit == TimeUnit.SECOND):
		var number_of_minutes_to_add: int = floor(amount / GameTime.SECONDS_IN_MINUTE)
		var number_of_seconds_to_add: int = amount % GameTime.SECONDS_IN_MINUTE
		var new_date: GameTime = GameTime.new(self.get_epoch())
		if number_of_minutes_to_add > 0:
			new_date = new_date.add_unit(number_of_minutes_to_add, TimeUnit.MINUTES)
		return GameTime.new(new_date.get_epoch() + (number_of_seconds_to_add * SECOND_DIVISOR))
	if (unit == TimeUnit.MILLISECONDS) or (unit == TimeUnit.MILLISECOND):
		var number_of_seconds_to_add: int = floor(amount / GameTime.MILLISECONDS_IN_SECOND)
		var number_of_milliseconds_to_add: int = amount % GameTime.MILLISECONDS_IN_SECOND
		var new_date: GameTime = GameTime.new(self.get_epoch())
		if number_of_seconds_to_add > 0:
			new_date = new_date.add_unit(number_of_seconds_to_add, TimeUnit.SECONDS)
		return GameTime.new(min(new_date.get_epoch() + (number_of_milliseconds_to_add), _MAX_INT))
	push_error("Invalid unit: " + unit)
	return null

## Subtracts an amount of time from this time.
## Usage:[br]
## [codeblock]
## var some_time = GameTime.new(0)
## var one_day = some_time.subtract_unit(1, GameTime.TimeUnit.DAYS)
## var ten_years = some_time.subtract_unit(10, GameTime.TimeUnit.YEARS)
## var three_hours = some_time.subtract_unit(180, GameTime.TimeUnit.MINUTES)
## [/codeblock]
func subtract_unit(amount: int, unit: String) -> GameTime:
	if amount < 0:
		push_error("Cannot add invalid amount: " + str(amount))
		return null
	if (unit == TimeUnit.YEARS) or (unit == TimeUnit.YEAR):
		return GameTime.new(max(self.get_epoch() - (amount * YEAR_DIVISOR),_MIN_INT))
	if (unit == TimeUnit.DAYS) or (unit == TimeUnit.DAY):
		var number_of_years_to_subtract: int = floor(amount / GameTime.DAYS_IN_YEAR)
		var number_of_days_to_subtract: int = amount % GameTime.DAYS_IN_YEAR
		var new_date: GameTime = GameTime.new(self.get_epoch())
		if number_of_years_to_subtract > 0:
			new_date = new_date.subtract_unit(number_of_years_to_subtract, TimeUnit.YEARS)
		return GameTime.new(max(new_date.get_epoch() - (number_of_days_to_subtract * DAY_DIVISOR),_MIN_INT))
	if (unit == TimeUnit.HOURS) or (unit == TimeUnit.HOUR):
		var number_of_days_to_subtract: int = floor(amount / GameTime.HOURS_IN_DAY)
		var number_of_hours_to_subtract: int = amount % GameTime.HOURS_IN_DAY
		var new_date: GameTime = GameTime.new(self.get_epoch())
		if number_of_days_to_subtract > 0:
			new_date = new_date.subtract_unit(number_of_days_to_subtract, TimeUnit.DAYS)
		return GameTime.new(max(new_date.get_epoch() - (number_of_hours_to_subtract * HOUR_DIVISOR),_MIN_INT))
	if (unit == TimeUnit.MINUTES) or (unit == TimeUnit.MINUTE):
		var number_of_hours_to_subtract: int = floor(amount / GameTime.MINUTES_IN_HOUR)
		var number_of_minutes_to_subtract: int = amount % GameTime.MINUTES_IN_HOUR
		var new_date: GameTime = GameTime.new(self.get_epoch())
		if number_of_hours_to_subtract > 0:
			new_date = new_date.subtract_unit(number_of_hours_to_subtract, TimeUnit.HOURS)
		return GameTime.new(max(new_date.get_epoch() - (number_of_minutes_to_subtract * MINUTE_DIVISOR),_MIN_INT))
	if (unit == TimeUnit.SECONDS) or (unit == TimeUnit.SECOND):
		var number_of_minutes_to_subtract: int = floor(amount / GameTime.SECONDS_IN_MINUTE)
		var number_of_seconds_to_subtract: int = amount % GameTime.SECONDS_IN_MINUTE
		var new_date: GameTime = GameTime.new(self.get_epoch())
		if number_of_minutes_to_subtract > 0:
			new_date = new_date.subtract_unit(number_of_minutes_to_subtract, TimeUnit.MINUTES)
		return GameTime.new(max(new_date.get_epoch() - (number_of_seconds_to_subtract * SECOND_DIVISOR),_MIN_INT))
	if (unit == TimeUnit.MILLISECONDS) or (unit == TimeUnit.MILLISECOND):
		var number_of_seconds_to_subtract: int = floor(amount / GameTime.MILLISECONDS_IN_SECOND)
		var number_of_milliseconds_to_subtract: int = amount % GameTime.MILLISECONDS_IN_SECOND
		var new_date: GameTime = GameTime.new(self.get_epoch())
		if number_of_seconds_to_subtract > 0:
			new_date = new_date.subtract_unit(number_of_seconds_to_subtract, TimeUnit.SECONDS)
		return GameTime.new(max(new_date.get_epoch() - (number_of_milliseconds_to_subtract),_MIN_INT))
	push_error("Invalid unit: " + unit)
	return null

## Returns whether this point in time is before year zero.
## Year zero is considedred to be after year zero.
## [code]true[/code] if this point in time is before year zero, [code]false[/code] otherwise
func is_before_year_zero() -> bool:
	return get_epoch() < 0

## Returns a new GameTime with the specified amount for the specified unit.
## [param should_clamp] specifies whether to cap the amount being set or to take the modulus of the amount being set. Defaults to [code]false[/code]
## Usage:[br]
## [codeblock]
## var some_time = GameTime.new(0)
## var one_day = some_time.set_unit(1, GameTime.TimeUnit.DAYS)
## var twenty_three_hours = some_time.set_unit(28, GameTime.TimeUnit.HOURS, true)
## var four_hours = some_time.set_unit(28, GameTime.TimeUnit.HOURS, false)
## [/codeblock]
func set_unit(amount: int, unit: String, should_clamp: bool = false) -> GameTime:
	if amount < 0:
		push_error("Cannot set invalid amount: " + str(amount))
		return null
	if should_clamp:
		if (unit == TimeUnit.YEARS) or (unit == TimeUnit.YEAR):
			return GameTime.create_from_instant(Instant.new(amount, get_day(), get_hour(), get_minute(), get_second(), get_millisecond()))
		if (unit == TimeUnit.DAYS) or (unit == TimeUnit.DAY):
			return GameTime.create_from_instant(Instant.new(get_year(), min(amount,GameTime.DAYS_IN_YEAR -1), get_hour(), get_minute(), get_second(), get_millisecond()))
		if (unit == TimeUnit.HOURS) or (unit == TimeUnit.HOUR):
			return GameTime.create_from_instant(Instant.new(get_year(), get_day(),  min(amount,GameTime.HOURS_IN_DAY -1), get_minute(), get_second(), get_millisecond()))
		if (unit == TimeUnit.MINUTES) or (unit == TimeUnit.MINUTE):
			return GameTime.create_from_instant(Instant.new(get_year(), get_day(), get_hour(),  min(amount,GameTime.MINUTES_IN_HOUR -1), get_second(), get_millisecond()))
		if (unit == TimeUnit.SECONDS) or (unit == TimeUnit.SECOND):
			return GameTime.create_from_instant(Instant.new(get_year(), get_day(), get_hour(), get_minute(), min(amount,GameTime.SECONDS_IN_MINUTE -1), get_millisecond()))
		if (unit == TimeUnit.MILLISECONDS) or (unit == TimeUnit.MILLISECOND):
			return GameTime.create_from_instant(Instant.new(get_year(), get_day(), get_hour() , get_minute(), get_second(), min(amount,GameTime.MILLISECONDS_IN_SECOND -1)))
	else:
		if (unit == TimeUnit.YEARS) or (unit == TimeUnit.YEAR):
			return GameTime.create_from_instant(Instant.new(amount, get_day(), get_hour(), get_minute(), get_second(), get_millisecond()))
		if (unit == TimeUnit.DAYS) or (unit == TimeUnit.DAY):
			return GameTime.create_from_instant(Instant.new(get_year(), amount % GameTime.DAYS_IN_YEAR, get_hour(), get_minute(), get_second(), get_millisecond()))
		if (unit == TimeUnit.HOURS) or (unit == TimeUnit.HOUR):
			return GameTime.create_from_instant(Instant.new(get_year(), get_day(),  amount % GameTime.HOURS_IN_DAY, get_minute(), get_second(), get_millisecond()))
		if (unit == TimeUnit.MINUTES) or (unit == TimeUnit.MINUTE):
			return GameTime.create_from_instant(Instant.new(get_year(), get_day(), get_hour(),  amount % GameTime.MINUTES_IN_HOUR, get_second(), get_millisecond()))
		if (unit == TimeUnit.SECONDS) or (unit == TimeUnit.SECOND):
			return GameTime.create_from_instant(Instant.new(get_year(), get_day(), get_hour(), get_minute(), amount % GameTime.SECONDS_IN_MINUTE, get_millisecond()))
		if (unit == TimeUnit.MILLISECONDS) or (unit == TimeUnit.MILLISECOND):
			return GameTime.create_from_instant(Instant.new(get_year(), get_day(), get_hour() , get_minute(), get_second(), amount % GameTime.MILLISECONDS_IN_SECOND))

	push_error("Invalid unit: " + unit)
	return null

## Returns [code]true[/code] if the other time is the same unit as this time, [code]false[/code] otherwise
## See [method is_same_time] if you want to check equality between two points in time
## Usage:[br]
## [codeblock]
## var some_time = GameTime.new(0)
## var other_time = GameTime.new(999)
## if some_time.is_same_unit(other_time, GameTime.TimeUnit.DAYS):
##     print("this does NOT happen")
## if some_time.is_same_unit(other_time, GameTime.TimeUnit.MILLISECONDS):
##     print("this does happen")
## [/codeblock]
func is_same_unit(other_time: GameTime, unit: String) -> bool:
	if other_time == null:
		push_error("Cannot compare to null time")
		return false
	if is_before_year_zero() != other_time.is_before_year_zero():
		return false
	if (unit == TimeUnit.YEARS) or (unit == TimeUnit.YEAR):
		return self.get_year() == other_time.get_year()
	if (unit == TimeUnit.DAYS) or (unit == TimeUnit.DAY):
		return self.get_day() == other_time.get_day()
	if (unit == TimeUnit.HOURS) or (unit == TimeUnit.HOUR):
		return self.get_hour() == other_time.get_hour()
	if (unit == TimeUnit.MINUTES) or (unit == TimeUnit.MINUTE):
		return self.get_minute() == other_time.get_minute()
	if (unit == TimeUnit.SECONDS) or (unit == TimeUnit.SECOND):
		return self.get_second() == other_time.get_second()
	if (unit == TimeUnit.MILLISECONDS) or (unit == TimeUnit.MILLISECOND):
		return self.get_millisecond() == other_time.get_millisecond()
	push_error("Invalid unit: " + unit)
	return false

## Returns [code]true[/code] if the other time is the same time as this time, [code]false[/code] otherwise
## [param granularity] determines the granularity of the comparison. Defaults to [code]GameTime.TimeUnit.MILLISECONDS[/code]
## Usage:[br]
## [codeblock]
## var some_time = GameTime.new(0)
## var other_time = GameTime.new(999)
## if some_time.is_same_time(other_time, GameTime.TimeUnit.DAYS):
##     print("this does happen")
## if some_time.is_same_time(other_time, GameTime.TimeUnit.MILLISECONDS):
##     print("this does NOT happen")
## if some_time.is_same_time(other_time):
##     print("this does NOT happen")
## [/codeblock]
func is_same_time(other_time: GameTime, granularity: String = TimeUnit.MILLISECOND) -> bool:
	if other_time == null:
		push_error("Cannot compare to null time")
		return false
	if is_before_year_zero() != other_time.is_before_year_zero():
		return false
	if (granularity == TimeUnit.YEARS) or (granularity == TimeUnit.YEAR):
		return self.get_year() == other_time.get_year()
	if (granularity == TimeUnit.DAYS) or (granularity == TimeUnit.DAY):
		return (self.get_day() == other_time.get_day()) && (self.get_year() == other_time.get_year())
	if (granularity == TimeUnit.HOURS) or (granularity == TimeUnit.HOUR):
		return (self.get_hour() == other_time.get_hour()) && (self.get_day() == other_time.get_day()) && (self.get_year() == other_time.get_year())
	if (granularity == TimeUnit.MINUTES) or (granularity == TimeUnit.MINUTE):
		return (self.get_minute() == other_time.get_minute()) && (self.get_hour() == other_time.get_hour()) && (self.get_day() == other_time.get_day()) && (self.get_year() == other_time.get_year())
	if (granularity == TimeUnit.SECONDS) or (granularity == TimeUnit.SECOND):
		return (self.get_second() == other_time.get_second()) && (self.get_minute() == other_time.get_minute()) && (self.get_hour() == other_time.get_hour()) && (self.get_day() == other_time.get_day()) && (self.get_year() == other_time.get_year())
	if (granularity == TimeUnit.MILLISECONDS) or (granularity == TimeUnit.MILLISECOND):
		return self.get_epoch() == other_time.get_epoch()
	push_error("Invalid unit: " + granularity)
	return false

## Returns [code]true[/code] if this time is today, [code]false[/code] otherwise
## The [param today] parameter is used to determine whether this time is today or not
func is_today(today: GameTime) -> bool:
	return self.is_same_time(today, TimeUnit.DAYS)

## Returns [code]true[/code] if this time is after the other time, [code]false[/code] otherwise
func is_after(other_time: GameTime) -> bool:
	if other_time == null:
		push_error("Cannot compare to null time")
		return false
	return self.get_epoch() > other_time.get_epoch()

## Returns [code]true[/code] if this time is after or same as the other time, [code]false[/code] otherwise
## [param granularity] determines the granularity of the comparison. Defaults to [code]GameTime.TimeUnit.MILLISECONDS[/code]
func is_after_or_same(other_time: GameTime, granularity: String = TimeUnit.MILLISECOND) -> bool:
	if other_time == null:
		push_error("Cannot compare to null time")
		return false
	return self.is_after(other_time) or self.is_same_time(other_time, granularity)

## Returns [code]true[/code] if this time is before the other time, [code]false[/code] otherwise
func is_before(other_time: GameTime) -> bool:
	if other_time == null:
		push_error("Cannot compare to null time")
		return false
	return self.get_epoch() < other_time.get_epoch()

## Returns [code]true[/code] if this time is before or same as the other time, [code]false[/code] otherwise
## [param granularity] determines the granularity of the comparison. Defaults to [code]GameTime.TimeUnit.MILLISECONDS[/code]
func is_before_or_same(other_time: GameTime, granularity: String = TimeUnit.MILLISECOND) -> bool:
	if other_time == null:
		push_error("Cannot compare to null time")
		return false
	return self.is_before(other_time) or self.is_same_time(other_time, granularity)

## Returns the epoch of this point in time
func get_epoch() -> int:
	return _epoch

## Returns the year in which this point in time falls
func get_year() -> int:
	return _year

## Returns the millisecond in which this point in time falls
func get_millisecond() -> int:
	return _second

## Returns the second in which this point in time falls
func get_second() -> int:
	return _second

## Returns the minute in which this point in time falls
func get_minute() -> int:
	return _minute

## Returns the hour in which this point in time falls
func get_hour() -> int:
	return _hour

## Returns the day in which this point in time falls
func get_day() -> int:
	return _day

## Returns an instant representation of this time
func to_instant() -> Instant:
	return Instant.new(self.get_year(), self.get_day(), self.get_hour(), self.get_minute(), self.get_second(), self.get_millisecond(), self.is_before_year_zero())

## Returns a string representation of this time
func get_time_as_string() -> String:
	return str(get_hour()) + ":" + str(get_minute()) + ":" + str(get_second()) + ":" + str(get_millisecond())

## Returns a string representation of this date
func get_date_as_string() -> String:
	var year: int = get_year() if not is_before_year_zero() else get_year() * -1
	var day: int = get_day() if not is_before_year_zero() else get_day() * -1
	return str(year) + "-" + str(day)

## Returns a string representation of this date and time
func get_date_time_as_string() -> String:
	return get_date_as_string() + " - " + get_time_as_string()

## Returns [code]true[/code] if [param time] is in the range [param start] and [param end], [code]false[/code] otherwise.
## If [param start] is [code]null[/code] or [param end] is [code]null[/code], an error will be logged and [code]false[/code] will be returned
## If [param start] is after [param end], an error will be logged and [code]false[/code] will be returned
static func is_in_range(time: GameTime, start: GameTime, end: GameTime) -> bool:
	if (start == null) or (end == null):
		push_error("Invalid time range: Must speficy start and end time")
		return false
	if start == null:
		push_error("Invalid time range: Must speficy start time")
		return false
	if end == null:
		push_error("Invalid time range: Must speficy end time")
		return false
	if start.is_after(end):
		push_error("Invalid time range: Start time must be before end time")
		return false
	return time.is_after_or_same(start) && time.is_before_or_same(end)

## Returns a random time in the range [param start] and [param end]
## If [param start] is [code]null[/code] or [param end] is [code]null[/code], an error will be logged and [code]null[/code] will be returned
## If [param start] is after [param end], an error will be logged and [code]null[/code] will be returned
static func random_time_in_range(start: GameTime, end: GameTime) -> GameTime:
	if (start == null) or (end == null):
		push_error("Invalid time range: Must speficy start and end time")
		return null
	if start == null:
		push_error("Invalid time range: Must speficy start time")
		return null
	if end == null:
		push_error("Invalid time range: Must speficy end time")
		return null
	if start.is_after(end):
		push_error("Invalid time range: Start time must be before end time")
		return null
	var max_epoch: int = abs(end.get_epoch()) - start.get_epoch()
	var random: int = randi_range(0, max_epoch)
	return GameTime.new(start.get_epoch() + random)

## Returns a [GameTime] from an [Instant]
static func create_from_instant(time: Instant) -> GameTime:
	return GameTime.new(time.get_epoch())

## Returns a new [GameTime] that is lerped between [param a] and [param b]
static func lerp_time(a: GameTime, b: GameTime, weight: float) -> GameTime:
	return GameTime.new(GameTime.lerp(a, b, weight))

## Returns a [float] that is lerped between [param a] and [param b]
static func lerp(a: GameTime, b: GameTime, weight: float) -> float:
	var a_epoch: int = a.get_epoch()
	var b_epoch: int = b.get_epoch()
	return lerp(a_epoch, b_epoch, weight)

## Returns a [float] that is lerped between [param start_time] and [param end_time]
## If [param current_time] in not in the range [param start_time] and [param end_time], an error will be logged and [code]0.0[/code] will be returned
## Plese use [method GameTime.lerp] if you do not want an error if the [param current_time] is not in the range
static func percent_between(current_time: GameTime, start_time: GameTime, end_time: GameTime) -> float:
	if not GameTime.is_in_range(current_time, start_time, end_time):
		push_error("Cannot get percentage of time outside of range. Current " + current_time.get_date_time_as_string() + " - A: " + start_time.get_date_time_as_string() + " - B: " + end_time.get_date_time_as_string())
		return 0
	var current: int = current_time.get_epoch()
	var start: int = start_time.get_epoch()
	var end: int = end_time.get_epoch()
	var percent_range: int = end - start
	if percent_range == 0:
		return 0.0  # Handle zero range case (avoid division by zero)

	return clampf(float(current - start) / float(percent_range),0,1)

## Returns an inverted [float] that is lerped between [param start_time] and [param end_time]
## If [param current_time] in not in the range [param start_time] and [param end_time], an error will be logged and [code]0.0[/code] will be returned
## Plese use [method GameTime.lerp] if you do not want an error if the [param current_time] is not in the range and invert it yourself (1.0 - GameTime.lerp(...))
static func inverted_percent_between(current_time: GameTime, start_time: GameTime, end_time: GameTime) -> float:
	var percent: float = percent_between(current_time, start_time, end_time)
	return 1.0 - percent

