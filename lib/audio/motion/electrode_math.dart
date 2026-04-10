import 'dart:math';

List<double> constrain4pAmplitudes(
  double a,
  double b,
  double c,
  double d,
) {
  a = a.clamp(0.0, double.infinity);
  b = b.clamp(0.0, double.infinity);
  c = c.clamp(0.0, double.infinity);
  d = d.clamp(0.0, double.infinity);

  for (int i = 0; i < 4; i++) {
    final double sum = a + b + c + d;
    a = min(a, sum - a);
    b = min(b, sum - b);
    c = min(c, sum - c);
    d = min(d, sum - d);
  }

  final double mx = <double>[
    a,
    b,
    c,
    d,
  ].reduce((double x, double y) => x > y ? x : y);
  if (mx > 1e-9) {
    a /= mx;
    b /= mx;
    c /= mx;
    d /= mx;
  }
  return <double>[
    a.clamp(0.0, 1.0),
    b.clamp(0.0, 1.0),
    c.clamp(0.0, 1.0),
    d.clamp(0.0, 1.0),
  ];
}
