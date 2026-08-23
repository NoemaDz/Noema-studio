import 'package:flutter/material.dart';

class ProjectInspector extends StatelessWidget {
  final Widget child;

  const ProjectInspector({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}