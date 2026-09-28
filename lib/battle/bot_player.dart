/// String hash that is identical on every device (String.hashCode is not).
int stableHash(String s) =>
    s.codeUnits.fold(0, (h, c) => (h * 31 + c) & 0x7fffffff);

/// Friendly random guest names for bots.
String botName(int seed) => 'Guest_${100 + (seed.abs() % 900)}';
