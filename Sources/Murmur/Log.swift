import os

/// Murmur's log, readable with:
///   /usr/bin/log show --last 10m --predicate 'subsystem == "com.judelewis.murmur"'
/// Only Fn timings and what Murmur did are logged: never other keys or dictated words.
let log = Logger(subsystem: "com.judelewis.murmur", category: "app")
