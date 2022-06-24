// get_current_file_time() returns time in 100s of ns, or 0.1 microseconds
// divide by 10_000 to get milliseconds.
Timer :: struct {
  start : Apollo_Time;
  end   : Apollo_Time;
}

start_timer :: (timer : *Timer) {
  // timer.start = get_current_file_time();
  timer.start = current_time_consensus();
}

stop_timer :: (timer : *Timer) {
  // timer.end = get_current_file_time();
  timer.end = current_time_consensus();
}

// milliseconds
get_millis :: (timer : *Timer) -> s64 {
  assert(timer.end > timer.start);
  dt := timer.end - timer.start;
  millis, _ := to_milliseconds(dt);
  return millis;
}

get_seconds :: (timer : *Timer) -> float {
  millis := get_millis(timer);
  return (cast(float) millis) * 0.001;
}

// random conversions

to_hex :: (x : $T) -> string {
  return sprint("0x%", formatInt(x, base=16));
}

#scope_file;

#import "Basic"; // string
