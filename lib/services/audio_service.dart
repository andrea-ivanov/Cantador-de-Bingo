import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Servicio de audio para cantar los números del bingo.
/// Reproduce archivos MP3 pre-grabados desde assets/audio/{número}.mp3
class AudioService {
  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;

  /// Inicializa el reproductor de audio.
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _player.setReleaseMode(ReleaseMode.stop);
    _isInitialized = true;
  }

  /// Reproduce el audio correspondiente al número dado.
  /// No bloquea la ejecución: lanza el audio y continúa (fire-and-forget).
  /// Si hay un error (archivo no encontrado, formato inválido), lo ignora
  /// silenciosamente para no bloquear el juego.
  void speakNumber(int number) {
    _playSafe(number);
  }

  Future<void> _playSafe(int number) async {
    try {
      if (!_isInitialized) await initialize();

      // Detener cualquier audio previo inmediatamente
      await _player.stop();

      // Reproducir el archivo de audio del número
      await _player.play(AssetSource('audio/$number.mp3'));
    } catch (e) {
      // Si el audio falla (archivo no encontrado, formato no soportado, etc.)
      // simplemente logueamos y continuamos — el juego no debe bloquearse
      debugPrint('AudioService: Error reproduciendo audio/$number.mp3: $e');
    }
  }

  /// Detiene la reproducción actual.
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('AudioService: Error al detener: $e');
    }
  }

  /// Libera los recursos del reproductor.
  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (e) {
      debugPrint('AudioService: Error al liberar: $e');
    }
  }
}
