import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/haptics.dart';
import '../../providers/connection_provider.dart';
import '../../widgets/neumorphic_tile.dart';
import 'tile_button.dart';

class CarrierSliderTile extends StatefulWidget {
  const CarrierSliderTile({required this.onOpenDetail, super.key});

  final VoidCallback onOpenDetail;

  @override
  State<CarrierSliderTile> createState() => _CarrierSliderTileState();
}

class _CarrierSliderTileState extends State<CarrierSliderTile> {
  double _dragAccumulator = 0;
  double _dragStartHz = 0;
  bool _dragActive = false;
  int _carrierBoundaryEdge = 0;

  bool _carrierLocked = true;
  bool _pulseLocked = true;

  double _pulseDragAccumulator = 0;
  double _pulseDragStartHz = 0;
  bool _pulseDragActive = false;
  int _pulseBoundaryEdge = 0;

  static const double _deadZone = 20.0;

  @override
  Widget build(BuildContext context) {
    final ConnectionProvider c = context.watch<ConnectionProvider>();
    final double rangeSpan = c.carrierMaxHz - c.carrierMinHz;
    final double fraction = rangeSpan > 0
        ? (c.carrierHz - c.carrierMinHz) / rangeSpan
        : 0;

    return GestureDetector(
      onLongPress: widget.onOpenDetail,
      child: NeumorphicTile(
        depth: 6,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                children: <Widget>[
                  GestureDetector(
                    onTap: () {
                      setState(() => _carrierLocked = !_carrierLocked);
                      if (_carrierLocked) {
                        Haptics.medium();
                      } else {
                        Haptics.light();
                      }
                    },
                    child: Icon(
                      _carrierLocked ? Icons.lock : Icons.electric_bolt,
                      size: 22,
                      color: _carrierLocked ? Colors.redAccent : kAccentCyan,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'WAVEFORM',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${c.carrierHz.toStringAsFixed(0)} Hz',
                    style: const TextStyle(
                      color: kAccentCyan,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  HomeTileButton(
                    icon: Icons.more_horiz,
                    size: 20,
                    onPressed: widget.onOpenDetail,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onHorizontalDragStart: _carrierLocked
                  ? (_) {
                      Haptics.medium();
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('Carrier frequency is locked'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                    }
                  : (_) {
                      _dragAccumulator = 0;
                      _dragStartHz = c.carrierHz;
                      _dragActive = false;
                      _carrierBoundaryEdge = 0;
                    },
              onHorizontalDragUpdate: _carrierLocked
                  ? null
                  : (DragUpdateDetails d) {
                      _dragAccumulator += d.delta.dx;
                      if (!_dragActive) {
                        if (_dragAccumulator.abs() < _deadZone) {
                          return;
                        }
                        _dragActive = true;
                        Haptics.selection();
                      }
                      final double screenW =
                          MediaQuery.of(context).size.width - 32;
                      final double hzPerPixel = rangeSpan / screenW;
                      final double effectiveDrag =
                          _dragAccumulator - _deadZone * _dragAccumulator.sign;
                      final double newHz =
                          (_dragStartHz + effectiveDrag * hzPerPixel).clamp(
                        c.carrierMinHz,
                        c.carrierMaxHz,
                      );
                      final int edge = newHz == c.carrierMinHz
                          ? -1
                          : (newHz == c.carrierMaxHz ? 1 : 0);
                      if (edge != 0 && edge != _carrierBoundaryEdge) {
                        Haptics.medium();
                      }
                      _carrierBoundaryEdge = edge;
                      c.setCarrierHz(newHz);
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: LayoutBuilder(
                  builder: (BuildContext ctx, BoxConstraints constraints) {
                    const double thumbW = 14;
                    final double trackW = constraints.maxWidth;
                    final double pos =
                        fraction.clamp(0.0, 1.0) * (trackW - thumbW);
                    return SizedBox(
                      height: thumbW,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: <Widget>[
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: kNeumorphicDarker,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Positioned(
                            left: pos,
                            child: Container(
                              width: thumbW,
                              height: thumbW,
                              decoration: BoxDecoration(
                                color: kAccentCyan,
                                shape: BoxShape.circle,
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: kAccentCyan.withValues(alpha: 0.4),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    c.carrierMinHz.toStringAsFixed(0),
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  const Text(
                    '← drag →',
                    style: TextStyle(color: Colors.white24, fontSize: 10),
                  ),
                  Text(
                    c.carrierMaxHz.toStringAsFixed(0),
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(
                children: <Widget>[
                  if (c.manualPulseMode)
                    GestureDetector(
                      onTap: () {
                        setState(() => _pulseLocked = !_pulseLocked);
                        if (_pulseLocked) {
                          Haptics.medium();
                        } else {
                          Haptics.light();
                        }
                      },
                      child: Icon(
                        _pulseLocked ? Icons.lock : Icons.electric_bolt,
                        size: 18,
                        color:
                            _pulseLocked ? Colors.redAccent : Colors.amberAccent,
                      ),
                    )
                  else
                    const Icon(
                      Icons.music_note,
                      size: 18,
                      color: Colors.white38,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    c.manualPulseMode ? 'PULSE' : 'PULSE (auto)',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${c.liveEffectivePulseHz.toStringAsFixed(1)} Hz',
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            if (c.manualPulseMode) ...<Widget>[
              GestureDetector(
                onHorizontalDragStart: _pulseLocked
                    ? (_) {
                        Haptics.medium();
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text('Pulse frequency is locked'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                      }
                    : (_) {
                        _pulseDragAccumulator = 0;
                        _pulseDragStartHz = c.manualPulseHz;
                        _pulseDragActive = false;
                        _pulseBoundaryEdge = 0;
                      },
                onHorizontalDragUpdate: _pulseLocked
                    ? null
                    : (DragUpdateDetails d) {
                        _pulseDragAccumulator += d.delta.dx;
                        if (!_pulseDragActive) {
                          if (_pulseDragAccumulator.abs() < _deadZone) {
                            return;
                          }
                          _pulseDragActive = true;
                          Haptics.selection();
                        }
                        final double pulseSpan = c.pulseMaxHz - c.pulseMinHz;
                        final double screenW =
                            MediaQuery.of(context).size.width - 32;
                        final double hzPerPixel =
                            pulseSpan > 0 ? pulseSpan / screenW : 0;
                        final double effectiveDrag = _pulseDragAccumulator -
                            _deadZone * _pulseDragAccumulator.sign;
                        final double newHz =
                            (_pulseDragStartHz + effectiveDrag * hzPerPixel)
                                .clamp(c.pulseMinHz, c.pulseMaxHz);
                        final int edge = newHz == c.pulseMinHz
                            ? -1
                            : (newHz == c.pulseMaxHz ? 1 : 0);
                        if (edge != 0 && edge != _pulseBoundaryEdge) {
                          Haptics.medium();
                        }
                        _pulseBoundaryEdge = edge;
                        c.setManualPulseHz(newHz);
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: LayoutBuilder(
                    builder: (BuildContext ctx, BoxConstraints constraints) {
                      const double thumbW = 12;
                      final double trackW = constraints.maxWidth;
                      final double pulseSpan = c.pulseMaxHz - c.pulseMinHz;
                      final double pulseFraction = pulseSpan > 0
                          ? (c.manualPulseHz - c.pulseMinHz) / pulseSpan
                          : 0;
                      final double pos =
                          pulseFraction.clamp(0.0, 1.0) * (trackW - thumbW);
                      return SizedBox(
                        height: thumbW,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: <Widget>[
                            Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: kNeumorphicDarker,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Positioned(
                              left: pos,
                              child: Container(
                                width: thumbW,
                                height: thumbW,
                                decoration: BoxDecoration(
                                  color: Colors.amberAccent,
                                  shape: BoxShape.circle,
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: Colors.amberAccent.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      c.pulseMinHz.toStringAsFixed(0),
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                    const Text(
                      '← drag →',
                      style: TextStyle(color: Colors.white24, fontSize: 10),
                    ),
                    Text(
                      c.pulseMaxHz.toStringAsFixed(0),
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ] else
              const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
