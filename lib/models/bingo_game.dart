import 'dart:math';

/// Modelo del juego de Bingo.
/// Gestiona el estado de las 90 bolas, el historial y la lógica de extracción.
class BingoGame {
  final List<int> _remainingBalls = [];
  final List<int> _calledBalls = [];
  final Random _random = Random();

  BingoGame() {
    reset();
  }

  /// Bolas que ya han salido, en orden.
  List<int> get calledBalls => List.unmodifiable(_calledBalls);

  /// Número de bolas restantes.
  int get remainingCount => _remainingBalls.length;

  /// Total de bolas llamadas.
  int get calledCount => _calledBalls.length;

  /// Indica si el juego ha terminado (todas las bolas han salido).
  bool get isFinished => _remainingBalls.isEmpty;

  /// La última bola que salió, o null si no ha salido ninguna.
  int? get lastCalledBall =>
      _calledBalls.isNotEmpty ? _calledBalls.last : null;

  /// Comprueba si un número ya ha sido cantado.
  bool isCalled(int number) => _calledBalls.contains(number);

  /// Extrae una bola aleatoria de las restantes.
  /// Devuelve el número extraído, o null si no quedan bolas.
  int? drawBall() {
    if (_remainingBalls.isEmpty) return null;

    final index = _random.nextInt(_remainingBalls.length);
    final ball = _remainingBalls.removeAt(index);
    _calledBalls.add(ball);
    return ball;
  }

  /// Reinicia el juego con las 90 bolas.
  void reset() {
    _remainingBalls.clear();
    _calledBalls.clear();
    for (int i = 1; i <= 90; i++) {
      _remainingBalls.add(i);
    }
  }
}
