import 'package:flutter/material.dart';
import 'package:agentteam/core/theme/agent_colors.dart';

class AgentTypingIndicator extends StatefulWidget {
  final Color? color;

  const AgentTypingIndicator({super.key, this.color});

  @override
  State<AgentTypingIndicator> createState() => _AgentTypingIndicatorState();
}

class _AgentTypingIndicatorState extends State<AgentTypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
    });

    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0, end: -8).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();

    // Stagger the animations
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.color ?? AgentColors.orchestrator;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Avatar placeholder
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: dotColor.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.auto_awesome, size: 14, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AgentColors.card,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Agent thinking',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                ...List.generate(3, (i) {
                  return _BounceDot(
                    listenable: _animations[i],
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _animations[i].value),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Simple _BounceDot replacement using AnimatedWidget pattern
class _BounceDot extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;

  const _BounceDot({
    required super.listenable,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, null);
  }
}
