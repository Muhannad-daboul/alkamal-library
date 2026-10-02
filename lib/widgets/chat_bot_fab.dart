import 'package:flutter/material.dart';
import '../main.dart';
import 'chat_bot_sheet.dart';

class DraggableChatBotFab extends StatefulWidget {
  const DraggableChatBotFab({super.key});

  @override
  State<DraggableChatBotFab> createState() => _DraggableChatBotFabState();
}

class _DraggableChatBotFabState extends State<DraggableChatBotFab> {
  Offset? _position;
  BoxConstraints _bounds = const BoxConstraints();
  bool _dragging = false;
  bool _overDelete = false;
  bool _dismissed = false;

  static const double _fabSize = 56;
  static const double _margin = 16;
  static const double _deleteSize = 54;
  static const double _deletePadBottom = 28;
  static const double _deleteHitRadius = 48;

  // ارتفاع المنطقة الآمنة العلوية (شريط الساعة) — يُحدَّث في build
  double _safeTop = 0;

  double get _minY => _safeTop + _margin;

  Offset _deleteCenter() => Offset(
        _bounds.maxWidth / 2,
        _bounds.maxHeight - _deletePadBottom - _deleteSize / 2,
      );

  bool _checkOverDelete(Offset fabPos) {
    final fabCenter = Offset(fabPos.dx + _fabSize / 2, fabPos.dy + _fabSize / 2);
    return (fabCenter - _deleteCenter()).distance < _deleteHitRadius;
  }

  void _onPanStart(DragStartDetails _) =>
      setState(() => _dragging = true);

  void _onPanUpdate(DragUpdateDetails d) {
    // من فوق: ما يتجاوز المنطقة الآمنة. من تحت: مسموح حتى الحافة ليصل delete zone
    final newX = (_position!.dx + d.delta.dx)
        .clamp(0.0, _bounds.maxWidth - _fabSize);
    final newY = (_position!.dy + d.delta.dy)
        .clamp(_minY, _bounds.maxHeight - _fabSize);
    final newPos = Offset(newX, newY);
    setState(() {
      _position = newPos;
      _overDelete = _checkOverDelete(newPos);
    });
  }

  void _onPanEnd(DragEndDetails _) {
    if (_overDelete) {
      setState(() {
        _dismissed = true;
        _dragging = false;
        _overDelete = false;
      });
      return;
    }
    // snap إلى أقرب زاوية
    final w = _bounds.maxWidth;
    final h = _bounds.maxHeight;
    final cx = _position!.dx + _fabSize / 2;
    final cy = _position!.dy + _fabSize / 2;
    setState(() {
      _position = Offset(
        cx < w / 2 ? _margin : w - _fabSize - _margin,
        cy < h / 2 ? _minY : h - _fabSize - _margin,
      );
      _dragging = false;
    });
  }

  void _openSheet() {
    if (_dragging) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ChatBotSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    _safeTop = MediaQuery.of(context).padding.top;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        _bounds = constraints;
        _position ??= Offset(
          _margin,
          constraints.maxHeight - _fabSize - _margin,
        );
        // إعادة ضبط بعد تغيّر الأبعاد (بدون تدخل أثناء السحب)
        if (!_dragging) {
          _position = Offset(
            _position!.dx.clamp(_margin, constraints.maxWidth - _fabSize - _margin),
            _position!.dy.clamp(_minY, constraints.maxHeight - _fabSize - _margin),
          );
        }

        return SizedBox.expand(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── delete zone ──
              if (_dragging)
                Positioned(
                  bottom: _deletePadBottom,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _overDelete ? 66 : _deleteSize,
                      height: _overDelete ? 66 : _deleteSize,
                      decoration: BoxDecoration(
                        color: _overDelete
                            ? Colors.red.shade600
                            : Colors.red.shade300,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withAlpha(_overDelete ? 100 : 50),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              // ── FAB ──
              ValueListenableBuilder<bool>(
                valueListenable: lectureSelectionActiveNotifier,
                builder: (context, lifted, _) {
                  return AnimatedPositioned(
                    duration: _dragging
                        ? Duration.zero
                        : const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    left: _position!.dx,
                    top: _position!.dy - (lifted ? 80 : 0),
                    child: GestureDetector(
                      onTap: _openSheet,
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: AnimatedScale(
                        scale: _overDelete ? 0.75 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: Material(
                          color: Colors.transparent,
                          elevation: 6,
                          shape: const CircleBorder(),
                          child: Container(
                            width: _fabSize,
                            height: _fabSize,
                            decoration: BoxDecoration(
                              color: _overDelete
                                  ? Colors.red.shade600
                                  : Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(50),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              _overDelete
                                  ? Icons.delete_outline_rounded
                                  : Icons.help_outline_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// النسخة القديمة — مُحتفظ بها لعدم كسر شاشات أخرى.
class ChatBotFab extends StatelessWidget {
  const ChatBotFab({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: lectureSelectionActiveNotifier,
      builder: (context, lifted, _) {
        return AnimatedSlide(
          offset: lifted ? const Offset(0, -1.4) : Offset.zero,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: FloatingActionButton(
            heroTag: 'chatbot_fab',
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const ChatBotSheet(),
            ),
            child: const Icon(Icons.help_outline_rounded),
          ),
        );
      },
    );
  }
}
