import 'package:flutter/material.dart';

class TemperatureSlider extends StatelessWidget {
  final double temperature;
  final void Function(double) onChanged;
  final Color color;

  const TemperatureSlider({
    super.key,
    required this.onChanged,
    required this.temperature,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Slider(
          value: temperature,
          // ChatGPT max and min values
          min: 0,
          max: 2,
          divisions: 20,
          onChanged: onChanged,
          activeColor: color,
          inactiveColor: color.withValues(alpha: 0.5),
        ),
        Text(temperature.toStringAsFixed(1)),
      ],
    );
  }
}
