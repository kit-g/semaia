import 'package:flutter/material.dart';

class ExpandedLoader extends StatelessWidget {
  const ExpandedLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: Loader(),
    );
  }
}

class Loader extends StatelessWidget {
  const Loader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: .5),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
