import 'character.dart';
import 'story.dart';
import 'style.dart';

class Project {

  final String id;

  final String title;

  final String idea;

  final String language;

  final Style style;

  final String imageModel;

  final String llmModel;

  final DateTime createdAt;

  Story? story;

  final List<Character> characters;

  Project({

    required this.id,

    required this.title,

    required this.idea,

    required this.language,

    required this.style,

    required this.imageModel,

    required this.llmModel,

    required this.createdAt,

    this.story,

    this.characters = const [],

  });

}