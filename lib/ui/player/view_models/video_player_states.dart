sealed class VideoPlayerState {
  const VideoPlayerState();
}

class VideoPlayerIdle extends VideoPlayerState {
  const VideoPlayerIdle();
}

class VideoPlayerLoading extends VideoPlayerState {
  const VideoPlayerLoading();
}

class VideoPlayerPlaying extends VideoPlayerState {
  const VideoPlayerPlaying();
}

class VideoPlayerError extends VideoPlayerState {
  final String message;
  const VideoPlayerError({required this.message});
}
