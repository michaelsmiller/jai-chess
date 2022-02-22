// get_current_file_time() returns time in 100s of ns, or 0.1 microseconds
// divide by 10_000 to get milliseconds.

Timer :: struct {
  start : u64;
  end   : u64;
}

start_timer :: (timer : *Timer) {
  timer.start = get_current_file_time();
}

stop_timer :: (timer : *Timer) {
  timer.end = get_current_file_time();
}

// milliseconds
get_millis :: (timer : *Timer) -> u64 {
  assert(timer.end > timer.start);
  dt := timer.end - timer.start;
  return dt / 10_000;
}

// seconds, in floating point
get_seconds :: (timer : *Timer) -> float {
  ms := get_millis(timer);
  return cast(float) ms * 0.001;
}

#scope_file;

#import "Time";
