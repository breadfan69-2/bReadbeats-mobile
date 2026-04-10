import 'package:breadbeats_mobile/audio/motion/adaptive_lead.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'AdaptiveLead observe converges lead upward for positive phase error',
    () {
      final AdaptiveLead lead = AdaptiveLead(baseLead: 0.0);

      for (int i = 0; i < 8; i += 1) {
        lead.observe(120.0);
      }

      expect(lead.observationCount, 8);
      expect(lead.leadMs, greaterThan(0.0));
    },
  );

  test(
    'AdaptiveLead observe converges lead downward for negative phase error',
    () {
      final AdaptiveLead lead = AdaptiveLead(baseLead: 55.0);

      for (int i = 0; i < 8; i += 1) {
        lead.observe(-120.0);
      }

      expect(lead.leadMs, lessThan(55.0));
    },
  );

  test('AdaptiveLead ignores phase errors below noise floor', () {
    final AdaptiveLead lead = AdaptiveLead(baseLead: 10.0);

    for (int i = 0; i < 8; i += 1) {
      lead.observe(20.0);
    }

    expect(lead.leadMs, closeTo(10.0, 1e-12));
  });

  test('AdaptiveLead waits for minimum observations before correction', () {
    final AdaptiveLead lead = AdaptiveLead(baseLead: 0.0);

    lead.observe(200.0);
    lead.observe(200.0);

    expect(lead.observationCount, 2);
    expect(lead.leadMs, closeTo(0.0, 1e-12));
  });

  test('AdaptiveLead reset restores base lead and clears counters', () {
    final AdaptiveLead lead = AdaptiveLead(baseLead: 25.0);

    for (int i = 0; i < 6; i += 1) {
      lead.observe(150.0);
    }
    expect(lead.leadMs, greaterThan(25.0));

    lead.reset();

    expect(lead.leadMs, closeTo(25.0, 1e-12));
    expect(lead.observationCount, 0);
  });

  test('AdaptiveLead clamps lead to configured bounds', () {
    final AdaptiveLead highLead = AdaptiveLead(baseLead: 0.0);
    for (int i = 0; i < 200; i += 1) {
      highLead.observe(2000.0);
    }
    expect(highLead.leadMs, lessThanOrEqualTo(200.0));

    final AdaptiveLead lowLead = AdaptiveLead(baseLead: 0.0);
    for (int i = 0; i < 200; i += 1) {
      lowLead.observe(-2000.0);
    }
    expect(lowLead.leadMs, greaterThanOrEqualTo(-50.0));
  });
}
