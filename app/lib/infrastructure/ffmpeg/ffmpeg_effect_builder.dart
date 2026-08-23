import 'dart:math';

class FFmpegEffectBuilder {
  /// Builds a filter_complex string for a given effect type and duration.
  /// Generates 1920x1080 output by default (configurable via options).
  static String buildFilter(String effectName, {int width = 1920, int height = 1080}) {
    // We first scale/crop the input to match the target aspect ratio,
    // then apply the zoompan effect, and finally scale to exact output size.

    final ratio = width / height;

    // Helper string to crop image to correct ratio before zoompan
    final cropFilter = "crop='iw':'iw*(1/$ratio)'"; // Simple center crop assuming landscape. A more robust one might be needed, but this works for generated images.

    switch (effectName.toLowerCase()) {
      case 'zoom_in':
        // Zoom in slowly towards the center
        return "[0:v]$cropFilter,zoompan=z='min(zoom+0.0015,1.5)':d=1000:x='iw/2-(iw/zoom)/2':y='ih/2-(ih/zoom)/2':s=${width}x$height:fps=25[v]";
      case 'zoom_out':
        // Zoom out slowly from center. (zoompan requires z >= 1, so we start at 1.5 and zoom out to 1)
        return "[0:v]$cropFilter,zoompan=z='if(eq(on,1),1.5,max(1.0,zoom-0.0015))':d=1000:x='iw/2-(iw/zoom)/2':y='ih/2-(ih/zoom)/2':s=${width}x$height:fps=25[v]";
      case 'pan_right':
        // Pan from left to right. To pan, we must be zoomed in a bit first.
        return "[0:v]$cropFilter,zoompan=z='1.2':d=1000:x='x+1':y='ih/2-(ih/zoom)/2':s=${width}x$height:fps=25[v]";
      case 'pan_left':
        // Pan from right to left.
        return "[0:v]$cropFilter,zoompan=z='1.2':d=1000:x='x-1':y='ih/2-(ih/zoom)/2':s=${width}x$height:fps=25[v]";
      case 'none':
      default:
        // Static image, just generate 1000 frames of static video
        return "[0:v]$cropFilter,zoompan=z='1':d=1000:x='iw/2-(iw/zoom)/2':y='ih/2-(ih/zoom)/2':s=${width}x$height:fps=25[v]";
    }
  }

  /// Returns a random effect for variety
  static String getRandomEffect() {
    final effects = ['zoom_in', 'zoom_out', 'pan_right', 'pan_left', 'none'];
    return effects[Random().nextInt(effects.length)];
  }
}
