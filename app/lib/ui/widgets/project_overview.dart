import 'package:flutter/material.dart';

import '../../core/noema_project.dart';

class ProjectOverview extends StatelessWidget {
  final NoemaProject project;

  const ProjectOverview({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    project.story.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            ListTile(
              leading: const Icon(Icons.movie),
              title: const Text("Scenes"),
              trailing: Text("${project.story.scenes.length}"),
            ),

            ListTile(
              leading: const Icon(Icons.people),
              title: const Text("Characters"),
              trailing: Text("${project.characters.length}"),
            ),

            ListTile(
              leading: const Icon(Icons.image),
              title: const Text("Images"),
              trailing: Text("${project.images.length}"),
            ),

            ListTile(
              leading: const Icon(Icons.work_outline),
              title: const Text("Jobs"),
              trailing: Text("${project.jobIds.length}"),
            ),

            ListTile(
              leading: const Icon(Icons.task_alt),
              title: const Text("Tasks"),
              trailing: Text("${project.tasks.length}"),
            ),

            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text("Style"),
              trailing: Text(project.style.name),
            ),
          ],
        ),
      ),
    );
  }
}
