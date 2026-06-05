import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/bingo_game.dart';
import '../services/audio_service.dart';
import 'home_screen.dart';

/// Pantalla principal del juego de Bingo.
/// Soporta modo automático y manual, con tablero, historial y controles de pausa.
class GameScreen extends StatefulWidget {
  final bool isAutomatic;
  final double intervalSeconds;

  const GameScreen({
    super.key,
    required this.isAutomatic,
    required this.intervalSeconds,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late BingoGame _game;
  late AudioService _audioService;
  Timer? _autoTimer;
  bool _isPaused = false;
  bool _isDrawing = false;

  // Animación para la bola actual
  late AnimationController _ballAnimController;
  late Animation<double> _ballScaleAnim;
  late Animation<double> _ballOpacityAnim;

  // Animación de brillo pulsante
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _game = BingoGame();
    _audioService = AudioService();
    _audioService.initialize();

    _ballAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _ballScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ballAnimController, curve: Curves.elasticOut),
    );

    _ballOpacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ballAnimController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    if (widget.isAutomatic) {
      _startAutoMode();
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _ballAnimController.dispose();
    _glowController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  void _startAutoMode() {
    _autoTimer = Timer.periodic(
      Duration(milliseconds: (widget.intervalSeconds * 1000).round()),
      (_) {
        if (!_isPaused && !_game.isFinished) {
          _drawBall();
        }
      },
    );
  }

  void _drawBall() {
    if (_isDrawing || _game.isFinished) return;
    _isDrawing = true;

    try {
      final ball = _game.drawBall();
      if (ball != null) {
        _ballAnimController.reset();
        _ballAnimController.forward();

        setState(() {});

        // Cantar el número (fire-and-forget, no bloquea)
        _audioService.speakNumber(ball);
      }
    } finally {
      _isDrawing = false;
    }

    if (_game.isFinished) {
      _autoTimer?.cancel();
      setState(() {});
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _showEndGameDialog();
      });
    }
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  void _showConfirmationDialog({
    required String title,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'No',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Sí',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEndGameDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => _EndGameDialog(
        onRestart: () {
          Navigator.of(context).pop();
          _restartGame();
        },
        onGoHome: () {
          Navigator.of(context).pop();
          _goHome();
        },
      ),
    );
  }

  void _restartGame() {
    _autoTimer?.cancel();
    setState(() {
      _game.reset();
      _isPaused = false;
      _isDrawing = false;
    });
    if (widget.isAutomatic) {
      _startAutoMode();
    }
  }

  void _goHome() {
    _autoTimer?.cancel();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  /// Devuelve el color de la bola según la decena (estilo bingo clásico).
  Color _getBallColor(int number) {
    if (number <= 10) return const Color(0xFFE53935); // Rojo
    if (number <= 20) return const Color(0xFFFF6B35); // Naranja
    if (number <= 30) return const Color(0xFFFFD700); // Amarillo
    if (number <= 40) return const Color(0xFF43A047); // Verde
    if (number <= 50) return const Color(0xFF1E88E5); // Azul
    if (number <= 60) return const Color(0xFF8E24AA); // Púrpura
    if (number <= 70) return const Color(0xFF00ACC1); // Cian
    if (number <= 80) return const Color(0xFFD81B60); // Rosa
    return const Color(0xFF00D4AA); // Teal
  }

  @override
  Widget build(BuildContext context) {
    final lastBall = _game.lastCalledBall;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A3E),
              Color(0xFF0F0F23),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Barra superior
              _buildTopBar(),

              // Bola actual y botones
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildCurrentBall(lastBall),
                    const SizedBox(width: 24),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.isAutomatic && !_game.isFinished)
                          ElevatedButton.icon(
                            onPressed: _togglePause,
                            icon: Icon(
                              _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                              size: 20,
                            ),
                            label: Text(
                              _isPaused ? 'Reanudar' : 'Pausar',
                              style: const TextStyle(
                                decoration: TextDecoration.none,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                            ),
                          ),
                        if ((!widget.isAutomatic || _isPaused) && lastBall != null) ...[
                          if (widget.isAutomatic && !_game.isFinished) const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => _audioService.speakNumber(lastBall),
                            icon: const Icon(Icons.replay_rounded, size: 20),
                            label: const Text(
                              'Repetir bola',
                              style: TextStyle(
                                decoration: TextDecoration.none,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00D4AA).withValues(alpha: 0.2),
                              foregroundColor: const Color(0xFF00D4AA),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: const Color(0xFF00D4AA).withValues(alpha: 0.4)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Información de progreso
              _buildProgressInfo(),

              const SizedBox(height: 12),

              // Tablero de bolas
              Expanded(
                child: _buildBallBoard(),
              ),

              // Historial de últimas bolas
              if (_game.calledBalls.isNotEmpty) _buildHistory(),

              // Botón manual (solo en modo manual)
              if (!widget.isAutomatic) _buildManualButton(),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Modo actual
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isAutomatic
                      ? Icons.play_circle_outline_rounded
                      : Icons.touch_app_rounded,
                  color: widget.isAutomatic
                      ? const Color(0xFF00D4AA)
                      : const Color(0xFFFF6B35),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.isAutomatic ? 'Automático' : 'Manual',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.isAutomatic) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D4AA).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${widget.intervalSeconds.toStringAsFixed(1)}s',
                      style: const TextStyle(
                        color: Color(0xFF00D4AA),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Botones de reinicio y home
          Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    _showConfirmationDialog(
                      title: '¿Estás seguro de reiniciar la partida?',
                      onConfirm: _restartGame,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Icon(
                      Icons.refresh_rounded,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    _showConfirmationDialog(
                      title: '¿Estás seguro de volver al home?',
                      onConfirm: _goHome,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Icon(
                      Icons.home_rounded,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentBall(int? lastBall) {
    Widget ballWidget;
    if (lastBall == null) {
      ballWidget = AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1 * _glowAnimation.value),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                '?',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ),
          );
        },
      );
    } else {
      final ballColor = _getBallColor(lastBall);

      ballWidget = AnimatedBuilder(
        animation: _ballAnimController,
        builder: (context, child) {
          return Opacity(
            opacity: _ballOpacityAnim.value,
            child: Transform.scale(
              scale: _ballScaleAnim.value,
              child: child,
            ),
          );
        },
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                ballColor.withValues(alpha: 0.9),
                ballColor,
                ballColor.withValues(alpha: 0.7),
              ],
              center: const Alignment(-0.3, -0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: ballColor.withValues(alpha: 0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Brillo superior
              Positioned(
                top: 15,
                left: 25,
                child: Container(
                  width: 30,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.4),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Número
              Text(
                '$lastBall',
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(1, 2),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        ballWidget,
        if (_isPaused)
          Transform.rotate(
            angle: -0.2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: const Text(
                'PAUSADO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bolas cantadas: ${_game.calledCount}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
              Text(
                'Restantes: ${_game.remainingCount}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _game.calledCount / 90,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D4AA)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBallBoard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 10,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: 90,
        itemBuilder: (context, index) {
          final number = index + 1;
          final isCalled = _game.isCalled(number);
          final isLast = _game.lastCalledBall == number;
          final ballColor = _getBallColor(number);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isCalled
                  ? ballColor.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: isLast
                    ? ballColor
                    : isCalled
                        ? ballColor.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.08),
                width: isLast ? 2 : 1,
              ),
              boxShadow: isLast
                  ? [
                      BoxShadow(
                        color: ballColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isCalled ? FontWeight.w800 : FontWeight.w500,
                  color: isCalled
                      ? ballColor
                      : Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistory() {
    final lastBalls = _game.calledBalls.reversed.take(8).toList();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Últimas bolas',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: lastBalls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final ball = lastBalls[index];
                final isFirst = index == 0;
                final color = _getBallColor(ball);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isFirst
                        ? RadialGradient(
                            colors: [
                              color.withValues(alpha: 0.8),
                              color,
                            ],
                            center: const Alignment(-0.3, -0.3),
                          )
                        : null,
                    color: isFirst ? null : color.withValues(alpha: 0.2),
                    border: Border.all(
                      color: color.withValues(alpha: isFirst ? 0.8 : 0.3),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$ball',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isFirst ? Colors.white : color,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualButton() {
    final isFinished = _game.isFinished;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: isFinished
              ? () => _showEndGameDialog()
              : _isPaused
                  ? null
                  : () => _drawBall(),
          style: ElevatedButton.styleFrom(
            backgroundColor: isFinished
                ? const Color(0xFFFFD700)
                : const Color(0xFFFF6B35),
            foregroundColor: isFinished ? Colors.black : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isFinished
                    ? Icons.emoji_events_rounded
                    : Icons.casino_rounded,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                isFinished ? '¡Juego terminado!' : 'Sacar bola',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// DIÁLOGOS
// =============================================================================



/// Diálogo de fin de juego con opciones de reiniciar y volver al inicio.
class _EndGameDialog extends StatefulWidget {
  final VoidCallback onRestart;
  final VoidCallback onGoHome;

  const _EndGameDialog({
    required this.onRestart,
    required this.onGoHome,
  });

  @override
  State<_EndGameDialog> createState() => _EndGameDialogState();
}

class _EndGameDialogState extends State<_EndGameDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A3E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
              blurRadius: 40,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animación de trofeo
            AnimatedBuilder(
              animation: _confettiController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: math.sin(_confettiController.value * math.pi * 2) * 0.1,
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFFD700).withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFFFD700),
                  size: 64,
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              '¡Juego Terminado!',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Se han cantado las 90 bolas',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),

            // Reiniciar
            _DialogButton(
              icon: Icons.refresh_rounded,
              label: 'Jugar de nuevo',
              color: const Color(0xFF00D4AA),
              onTap: widget.onRestart,
            ),
            const SizedBox(height: 12),

            // Volver al inicio
            _DialogButton(
              icon: Icons.home_rounded,
              label: 'Pantalla de inicio',
              color: const Color(0xFF1E88E5),
              onTap: widget.onGoHome,
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón estilizado para los diálogos.
class _DialogButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DialogButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _isPressed
              ? widget.color.withValues(alpha: 0.3)
              : widget.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: widget.color, size: 22),
            const SizedBox(width: 10),
            Text(
              widget.label,
              style: TextStyle(
                color: widget.color,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
