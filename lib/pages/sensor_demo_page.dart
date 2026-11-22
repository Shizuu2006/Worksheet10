import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SensorDemoPage extends StatefulWidget {
  const SensorDemoPage({super.key});

  @override
  State<SensorDemoPage> createState() => _SensorDemoPageState();
}

class _SensorDemoPageState extends State<SensorDemoPage> {
  StreamSubscription<UserAccelerometerEvent>? _subscription;
  String _reading = 'Gerakkan ponsel secara perlahan.';
  double _x = 0;
  double _y = 0;
  double _z = 0;
  bool _sensorAvailable = true;

  @override
  void initState() {
    super.initState();
    try {
      _subscription = userAccelerometerEventStream().listen(
        (event) {
          if (!mounted) return;
          setState(() {
            _x = event.x;
            _y = event.y;
            _z = event.z;
            _sensorAvailable = true;
            _reading =
                'Sensor aktif — gerakkan atau putar perangkat untuk '
                'mengamati perubahan nilai.';
          });
        },
        onError: (Object error) {
          if (!mounted) return;
          setState(() {
            _sensorAvailable = false;
            _reading = 'Sensor tidak tersedia: $error';
          });
        },
        cancelOnError: true,
      );
    } catch (error) {
      _sensorAvailable = false;
      _reading = 'Sensor tidak tersedia: $error';
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final magnitude = sqrt(_x * _x + _y * _y + _z * _z);
    final movement = magnitude < 0.15
        ? 'Perangkat relatif diam'
        : 'Perangkat sedang bergerak';

    return Scaffold(
      appBar: AppBar(title: const Text('Demo Accelerometer')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.sensors, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    _sensorAvailable ? movement : 'Sensor tidak tersedia',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _reading,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _AxisCard(label: 'Sumbu X', value: _x, color: Colors.red),
          const SizedBox(height: 8),
          _AxisCard(label: 'Sumbu Y', value: _y, color: Colors.green),
          const SizedBox(height: 8),
          _AxisCard(label: 'Sumbu Z', value: _z, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'Catatan: user accelerometer tidak termasuk percepatan gravitasi.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AxisCard extends StatelessWidget {
  const _AxisCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color,
            foregroundColor: Colors.white,
            child: const Icon(Icons.screen_rotation),
          ),
          title: Text(label),
          trailing: Text(
            '${value.toStringAsFixed(2)} m/s²',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
}
