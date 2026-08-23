import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';

class DependencyManager {
  static final DependencyManager instance = DependencyManager._internal();
  DependencyManager._internal();

  String _gitPath = 'git';
  String _ffmpegPath = 'ffmpeg';

  String get gitPath => _gitPath;
  String get ffmpegPath => _ffmpegPath;

  Future<void> ensureDependencies(Function(String) onProgress) async {
    final supportDir = await getApplicationSupportDirectory();
    final binDir = Directory(p.join(supportDir.path, 'noema', 'bin'));
    if (!await binDir.exists()) {
      await binDir.create(recursive: true);
    }

    // 1. Check/Install Git
    bool hasGit = await _checkCommand('git', ['--version']);
    if (hasGit) {
      _gitPath = 'git';
      onProgress("System Git found.");
    } else {
      onProgress("System Git not found. Checking local portable Git...");
      final localGitPath = _getPortableGitPath(binDir.path);
      if (await File(localGitPath).exists()) {
        _gitPath = localGitPath;
        onProgress("Portable Git found locally.");
      } else {
        await _downloadPortableGit(binDir.path, onProgress);
        _gitPath = localGitPath;
      }
    }

    // 2. Check/Install FFmpeg
    bool hasFfmpeg = await _checkCommand('ffmpeg', ['-version']);
    if (hasFfmpeg) {
      _ffmpegPath = 'ffmpeg';
      onProgress("System FFmpeg found.");
    } else {
      onProgress("System FFmpeg not found. Checking local portable FFmpeg...");
      final localFfmpegPath = _getPortableFfmpegPath(binDir.path);
      if (await File(localFfmpegPath).exists()) {
        _ffmpegPath = localFfmpegPath;
        onProgress("Portable FFmpeg found locally.");
      } else {
        await _downloadPortableFfmpeg(binDir.path, onProgress);
        _ffmpegPath = localFfmpegPath;
      }
    }
  }

  Future<bool> _checkCommand(String cmd, List<String> args) async {
    try {
      final result = await Process.run(cmd, args);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  String _getPortableGitPath(String binPath) {
    if (Platform.isWindows) {
      return p.join(binPath, 'git', 'cmd', 'git.exe');
    }
    // On Linux/Mac we assume git is available or we put a static binary directly in bin
    return p.join(binPath, 'git', 'git');
  }

  String _getPortableFfmpegPath(String binPath) {
    if (Platform.isWindows) {
      return p.join(binPath, 'ffmpeg', 'bin', 'ffmpeg.exe');
    }
    return p.join(binPath, 'ffmpeg', 'ffmpeg');
  }

  Future<void> _downloadPortableGit(String binPath, Function(String) onProgress) async {
    if (Platform.isWindows) {
      onProgress("Downloading Portable Git for Windows...");
      const url = "https://github.com/git-for-windows/git/releases/download/v2.41.0.windows.1/MinGit-2.41.0-64-bit.zip";
      final zipFile = File(p.join(binPath, "mingit.zip"));
      await _downloadFile(url, zipFile);
      
      onProgress("Extracting Git...");
      final extractPath = p.join(binPath, "git");
      await extractFileToDisk(zipFile.path, extractPath);
      await zipFile.delete();
    } else {
      throw Exception("Git is not installed! Please install Git on your system first (e.g., sudo apt install git).");
    }
  }

  Future<void> _downloadPortableFfmpeg(String binPath, Function(String) onProgress) async {
    if (Platform.isWindows) {
      onProgress("Downloading FFmpeg for Windows...");
      const url = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip";
      final zipFile = File(p.join(binPath, "ffmpeg.zip"));
      await _downloadFile(url, zipFile);
      
      onProgress("Extracting FFmpeg...");
      final extractPath = p.join(binPath, "ffmpeg_extracted");
      await extractFileToDisk(zipFile.path, extractPath);
      
      // Move contents of inner folder to 'ffmpeg'
      final innerFolder = Directory(extractPath).listSync().firstWhere((e) => e is Directory) as Directory;
      final finalFfmpegDir = Directory(p.join(binPath, 'ffmpeg'));
      if (await finalFfmpegDir.exists()) {
        await finalFfmpegDir.delete(recursive: true);
      }
      await innerFolder.rename(finalFfmpegDir.path);
      await Directory(extractPath).delete();
      await zipFile.delete();
    } else if (Platform.isLinux) {
      onProgress("Downloading FFmpeg for Linux...");
      const url = "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz";
      final tarFile = File(p.join(binPath, "ffmpeg.tar.xz"));
      await _downloadFile(url, tarFile);
      
      onProgress("Extracting FFmpeg...");
      // Use system tar for tar.xz files
      try {
        await Process.run('tar', ['-xf', tarFile.path, '-C', binPath]);
        final extractedDirs = Directory(binPath).listSync().whereType<Directory>().where((d) => p.basename(d.path).startsWith('ffmpeg'));
        if (extractedDirs.isNotEmpty) {
           final innerFolder = extractedDirs.first;
           final finalFfmpegDir = Directory(p.join(binPath, 'ffmpeg'));
           await innerFolder.rename(finalFfmpegDir.path);
        }
      } catch (e) {
         onProgress("Error extracting FFmpeg. Please install manually.");
         throw Exception("Failed to extract FFmpeg");
      }
      await tarFile.delete();
    } else {
      throw Exception("Please install FFmpeg manually via Homebrew: brew install ffmpeg");
    }
  }

  Future<void> _downloadFile(String url, File target) async {
    final request = await http.Client().send(http.Request('GET', Uri.parse(url)));
    final sink = target.openWrite();
    await request.stream.pipe(sink);
    await sink.flush();
    await sink.close();
  }
}
