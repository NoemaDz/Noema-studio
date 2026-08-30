import 'package:flutter/material.dart';
import '../../core/errors/crash_logger.dart';

class ErrorBoundary extends StatefulWidget {
  final Widget child;

  const ErrorBoundary({super.key, required this.child});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  FlutterErrorDetails? _errorDetails;
  Key _childKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _registerCustomErrorWidget();
  }

  void _registerCustomErrorWidget() {
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (mounted) {
        setState(() {
          _errorDetails = details;
        });
      }
      CrashLogger.logCrash(
        details.exception,
        details.stack,
        context: 'WIDGET_BUILD_ERROR',
      );
      if (oldHandler != null) oldHandler(details);
    };
  }

  void _resetErrorState() {
    setState(() {
      _errorDetails = null;
      _childKey =
          UniqueKey(); // Forces unmount and remount of child widget tree
    });
  }

  Widget _buildErrorCard(FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF0A0F1E),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF141B2D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.redAccent.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                "UI Error Encountered",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text("Recover Subtree"),
                onPressed: _resetErrorState,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorDetails != null) {
      return _buildErrorCard(_errorDetails!);
    }
    return KeyedSubtree(key: _childKey, child: widget.child);
  }
}
