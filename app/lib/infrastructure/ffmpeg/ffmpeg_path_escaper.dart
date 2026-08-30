class FFmpegPathEscaper {
  /// Escapes paths for use in FFmpeg filter graphs (e.g. subtitles filter)
  static String escapeFilterPath(String path) {
    // FFmpeg filter paths must have backslashes and colons escaped,
    // and generally forward slashes work best across platforms.
    return path.replaceAll('\\', '/').replaceAll(':', '\\:');
  }

  /// Escapes paths for use in FFmpeg concat demuxer lists
  static String escapeConcatPath(String path) {
    // For concat list, forward slashes are required, and we wrap the path in single quotes in the file,
    // so we need to escape single quotes if they exist in the filename.
    return path.replaceAll('\\', '/').replaceAll("'", "'\\''");
  }
}
