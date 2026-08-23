import 'package:flutter/material.dart';
import '../../models/job.dart';
import '../../main.dart';

class LiveProgressTracker extends StatefulWidget {
  final List<Job> jobs;

  const LiveProgressTracker({super.key, required this.jobs});

  @override
  State<LiveProgressTracker> createState() => _LiveProgressTrackerState();
}

class _LiveProgressTrackerState extends State<LiveProgressTracker> {
  void _onJobUpdate(Job job) {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    noema.bootstrap.jobEvents.subscribe(_onJobUpdate);
  }

  @override
  void dispose() {
    noema.bootstrap.jobEvents.unsubscribe(_onJobUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.jobs.isEmpty) {
      return const SizedBox.shrink();
    }

    // Only show jobs that are not completely pending yet (so we don't spam the UI instantly)
    // or just show all of them. Let's show all grouped by type or just in a list.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Live Progress",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...widget.jobs.map((job) => _buildJobItem(job)),
      ],
    );
  }

  Widget _buildJobItem(Job job) {
    IconData icon;
    Color color;

    switch (job.status) {
      case JobStatus.pending:
      case JobStatus.queued:
        icon = Icons.schedule;
        color = Colors.grey;
        break;
      case JobStatus.running:
        icon = Icons.autorenew;
        color = Colors.blue;
        break;
      case JobStatus.completed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case JobStatus.failed:
        icon = Icons.error;
        color = Colors.red;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getJobTitle(job),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '${(job.progress * 100).toInt()}%',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: job.status == JobStatus.queued || job.status == JobStatus.pending ? null : job.progress,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            color: color,
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  String _getJobTitle(Job job) {
    if (job.metadata.containsKey("title")) {
      return job.metadata["title"];
    }
    switch (job.type) {
      case 'image':
        return 'Generating Image';
      case 'audio':
        return 'Synthesizing Voiceover';
      case 'video_compile':
        return 'Compiling Final Video';
      default:
        return 'Processing task...';
    }
  }
}
