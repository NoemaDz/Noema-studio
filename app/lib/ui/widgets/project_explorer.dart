import 'package:flutter/material.dart';

import '../../core/noema_project.dart';

import 'project_overview.dart';
import 'scene_list.dart';
import 'character_list.dart';
import 'project_images.dart';
import 'explorer_section.dart';

class ProjectExplorer extends StatelessWidget {
  final NoemaProject project;

  const ProjectExplorer({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            ExplorerSection(
              title: "Project",
              icon: Icons.folder,
              child: ProjectOverview(project: project),
            ),

            ExplorerSection(
              title: "Characters",
              icon: Icons.people,
              child: CharacterList(characters: project.characters),
            ),

            ExplorerSection(
              title: "Scenes",
              icon: Icons.movie,
              child: SceneList(scenes: project.story.scenes),
            ),

            ExplorerSection(
              title: "Images",
              icon: Icons.image,
              child: ProjectImages(images: project.images),
            ),
          ],
        );
      },
    );
  }
}
