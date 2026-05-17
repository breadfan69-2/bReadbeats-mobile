import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../models/device_models.dart';
import 'neumorphic_tile.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.state});

  final FocstimConnectionState state;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (state) {
      FocstimConnectionState.disconnected => const Color(0xFF6C757D),
      FocstimConnectionState.connecting => const Color(0xFFF0A202),
      FocstimConnectionState.connected => const Color(0xFF2E933C),
      FocstimConnectionState.error => const Color(0xFFD73A49),
    };

    final String label = switch (state) {
      FocstimConnectionState.disconnected => 'Disconnected',
      FocstimConnectionState.connecting => 'Connecting',
      FocstimConnectionState.connected => 'Connected',
      FocstimConnectionState.error => 'Error',
    };

    return Chip(
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.40)),
      label: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class HostHistoryTextField extends StatelessWidget {
  const HostHistoryTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hostHistory,
    required this.onChanged,
    this.enabled = true,
    this.historyEnabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> hostHistory;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final bool historyEnabled;

  @override
  Widget build(BuildContext context) {
    final List<String> recentHosts = hostHistory
        .where((String host) => host.isNotEmpty)
        .toList(growable: false);
    final bool showHistoryButton = recentHosts.length > 1;

    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'FOC-Stim IP',
              hintText: '192.168.x.x',
            ),
          ),
        ),
        if (showHistoryButton) ...<Widget>[
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Recent IP addresses',
            enabled: enabled && historyEnabled,
            onSelected: (String value) {
              controller.value = TextEditingValue(
                text: value,
                selection: TextSelection.collapsed(offset: value.length),
              );
              focusNode.requestFocus();
              Haptics.selection();
              onChanged(value);
            },
            itemBuilder: (BuildContext context) {
              return recentHosts
                  .map(
                    (String ip) =>
                        PopupMenuItem<String>(value: ip, child: Text(ip)),
                  )
                  .toList(growable: false);
            },
            icon: const Icon(Icons.arrow_drop_down),
          ),
        ],
      ],
    );
  }
}

class TelemetryRow extends StatelessWidget {
  const TelemetryRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class LabeledSlider extends StatefulWidget {
  const LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.minTouchDuration = Duration.zero,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final Duration minTouchDuration;

  @override
  State<LabeledSlider> createState() => _LabeledSliderState();
}

class _LabeledSliderState extends State<LabeledSlider> {
  static const double _epsilon = 1e-6;
  DateTime? _dragStartTime;
  double? _draftValue;
  bool _touchGateOpen = false;
  bool _selectionEmitted = false;
  int _boundaryEdge = 0;

  bool get _hasTouchGate => widget.minTouchDuration > Duration.zero;

  double _clampValue(double value) {
    return value.clamp(widget.min, widget.max).toDouble();
  }

  bool _gateSatisfied() {
    if (!_hasTouchGate) return true;
    if (_touchGateOpen) return true;
    final DateTime? dragStartTime = _dragStartTime;
    if (dragStartTime == null) return false;
    final bool satisfied =
        DateTime.now().difference(dragStartTime) >= widget.minTouchDuration;
    if (satisfied) {
      _touchGateOpen = true;
    }
    return satisfied;
  }

  void _handleChangeStart(double value) {
    _dragStartTime = _hasTouchGate ? DateTime.now() : null;
    _touchGateOpen = false;
    _selectionEmitted = false;
    _boundaryEdge = 0;
    _draftValue = _clampValue(value);
    setState(() {});
  }

  void _emitSelectionIfNeeded() {
    if (_selectionEmitted) {
      return;
    }
    _selectionEmitted = true;
    Haptics.selection();
  }

  void _emitBoundaryIfNeeded(double value) {
    final bool atMin = (value - widget.min).abs() <= _epsilon;
    final bool atMax = (widget.max - value).abs() <= _epsilon;
    final int edge = atMin ? -1 : (atMax ? 1 : 0);
    if (edge != 0 && edge != _boundaryEdge) {
      Haptics.medium();
    }
    _boundaryEdge = edge;
  }

  void _handleChanged(double value) {
    final double clamped = _clampValue(value);
    if (!_hasTouchGate) {
      _emitSelectionIfNeeded();
      _emitBoundaryIfNeeded(clamped);
      widget.onChanged(clamped);
      return;
    }

    _draftValue = clamped;
    if (_gateSatisfied()) {
      _emitSelectionIfNeeded();
      _emitBoundaryIfNeeded(clamped);
      widget.onChanged(clamped);
    }
    setState(() {});
  }

  void _handleChangeEnd(double value) {
    if (!_hasTouchGate) {
      _dragStartTime = null;
      _touchGateOpen = false;
      _draftValue = null;
      setState(() {});
      return;
    }
    final double clamped = _clampValue(value);
    if (_gateSatisfied()) {
      _emitBoundaryIfNeeded(clamped);
      widget.onChanged(clamped);
    }
    _dragStartTime = null;
    _touchGateOpen = false;
    _draftValue = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final double effectiveValue = _draftValue == null
        ? _clampValue(widget.value)
        : _clampValue(_draftValue!);

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(widget.label)),
            Text(effectiveValue.toStringAsFixed(2)),
          ],
        ),
        Slider(
          value: effectiveValue,
          min: widget.min,
          max: widget.max,
          divisions: widget.divisions,
          onChanged: _handleChanged,
          onChangeStart: _handleChangeStart,
          onChangeEnd: _handleChangeEnd,
        ),
      ],
    );
  }
}

class LabeledRangeSlider extends StatefulWidget {
  const LabeledRangeSlider({
    super.key,
    required this.label,
    required this.values,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.displayDecimals = 0,
    this.minTouchDuration = Duration.zero,
  });

  final String label;
  final RangeValues values;
  final double min;
  final double max;
  final int? divisions;
  final int displayDecimals;
  final ValueChanged<RangeValues> onChanged;
  final Duration minTouchDuration;

  @override
  State<LabeledRangeSlider> createState() => _LabeledRangeSliderState();
}

class _LabeledRangeSliderState extends State<LabeledRangeSlider> {
  static const double _epsilon = 1e-6;
  DateTime? _dragStartTime;
  RangeValues? _draftValues;
  bool _touchGateOpen = false;
  bool _selectionEmitted = false;
  int _boundaryEdge = 0;

  bool get _hasTouchGate => widget.minTouchDuration > Duration.zero;

  RangeValues _clampValues(RangeValues values) {
    final double first = values.start.clamp(widget.min, widget.max).toDouble();
    final double second = values.end.clamp(widget.min, widget.max).toDouble();
    final double lower = first <= second ? first : second;
    final double upper = first <= second ? second : first;
    return RangeValues(lower, upper);
  }

  bool _gateSatisfied() {
    if (!_hasTouchGate) return true;
    if (_touchGateOpen) return true;
    final DateTime? dragStartTime = _dragStartTime;
    if (dragStartTime == null) return false;
    final bool satisfied =
        DateTime.now().difference(dragStartTime) >= widget.minTouchDuration;
    if (satisfied) {
      _touchGateOpen = true;
    }
    return satisfied;
  }

  void _handleChangeStart(RangeValues values) {
    _dragStartTime = _hasTouchGate ? DateTime.now() : null;
    _touchGateOpen = false;
    _selectionEmitted = false;
    _boundaryEdge = 0;
    _draftValues = _clampValues(values);
    setState(() {});
  }

  void _emitSelectionIfNeeded() {
    if (_selectionEmitted) {
      return;
    }
    _selectionEmitted = true;
    Haptics.selection();
  }

  void _emitBoundaryIfNeeded(RangeValues values) {
    final bool atMin = (values.start - widget.min).abs() <= _epsilon;
    final bool atMax = (widget.max - values.end).abs() <= _epsilon;
    final int edge = atMin ? -1 : (atMax ? 1 : 0);
    if (edge != 0 && edge != _boundaryEdge) {
      Haptics.medium();
    }
    _boundaryEdge = edge;
  }

  void _handleChanged(RangeValues values) {
    final RangeValues clamped = _clampValues(values);
    if (!_hasTouchGate) {
      _emitSelectionIfNeeded();
      _emitBoundaryIfNeeded(clamped);
      widget.onChanged(clamped);
      return;
    }

    _draftValues = clamped;
    if (_gateSatisfied()) {
      _emitSelectionIfNeeded();
      _emitBoundaryIfNeeded(clamped);
      widget.onChanged(clamped);
    }
    setState(() {});
  }

  void _handleChangeEnd(RangeValues values) {
    if (!_hasTouchGate) {
      _dragStartTime = null;
      _touchGateOpen = false;
      _draftValues = null;
      setState(() {});
      return;
    }
    final RangeValues clamped = _clampValues(values);
    if (_gateSatisfied()) {
      _emitBoundaryIfNeeded(clamped);
      widget.onChanged(clamped);
    }
    _dragStartTime = null;
    _touchGateOpen = false;
    _draftValues = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final RangeValues effectiveValues = _draftValues == null
        ? _clampValues(widget.values)
        : _clampValues(_draftValues!);

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(widget.label)),
            Text(
              '${effectiveValues.start.toStringAsFixed(widget.displayDecimals)} – '
              '${effectiveValues.end.toStringAsFixed(widget.displayDecimals)}',
            ),
          ],
        ),
        RangeSlider(
          values: effectiveValues,
          min: widget.min,
          max: widget.max,
          divisions: widget.divisions,
          labels: RangeLabels(
            effectiveValues.start.toStringAsFixed(widget.displayDecimals),
            effectiveValues.end.toStringAsFixed(widget.displayDecimals),
          ),
          onChanged: _handleChanged,
          onChangeStart: _handleChangeStart,
          onChangeEnd: _handleChangeEnd,
        ),
      ],
    );
  }
}

class ElectrodeIntensityMeter extends StatelessWidget {
  const ElectrodeIntensityMeter({
    super.key,
    required this.levels,
    required this.labels,
    required this.active,
    this.colors = kElectrodeColors,
  });

  final List<double> levels;
  final List<String> labels;
  final bool active;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final int count = levels.length < labels.length
        ? levels.length
        : labels.length;
    if (count == 0) {
      return const SizedBox.shrink();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List<Widget>.generate(count, (int index) {
        final double level = levels[index].clamp(0.0, 1.0);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == count - 1 ? 0 : 8),
            child: _ElectrodeBar(
              label: labels[index],
              value: level,
              active: active,
              color: index < colors.length
                  ? colors[index]
                  : kElectrodeColors[0],
            ),
          ),
        );
      }),
    );
  }
}

class _ElectrodeBar extends StatelessWidget {
  const _ElectrodeBar({
    required this.label,
    required this.value,
    required this.active,
    required this.color,
  });

  final String label;
  final double value;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final Color fillColor = active
        ? color
        : Theme.of(context).colorScheme.outline;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          height: 118,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            height: value * 112,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: color),
        ),
        Text(
          value.toStringAsFixed(2),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Scaffold wrapper for detail screens with a consistent dark neumorphic look.
class DetailScreenScaffold extends StatelessWidget {
  const DetailScreenScaffold({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: const Color(0xFFE0E0E0),
        title: Text(title),
        elevation: 0,
      ),
      body: SafeArea(child: child),
    );
  }
}
