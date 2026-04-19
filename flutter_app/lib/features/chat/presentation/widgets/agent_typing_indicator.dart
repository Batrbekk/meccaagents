import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:agentteam/core/theme/agent_colors.dart';

class AgentTypingIndicator extends StatefulWidget {
  final String? agentSlug;
  final Color? color;

  const AgentTypingIndicator({super.key, this.agentSlug, this.color});

  @override
  State<AgentTypingIndicator> createState() => _AgentTypingIndicatorState();
}

class _AgentTypingIndicatorState extends State<AgentTypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  // Three dot colors per the design spec
  static const List<Color> _dotColors = [
    Color(0xFF9CA3AF),
    Color(0xFFB4B9C2),
    Color(0xFFD1D5DB),
  ];

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
      return Tween<double>(begin: 0, end: -6).animate(
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
    final slug = widget.agentSlug;
    final agentColor = slug != null
        ? AgentColors.forAgent(slug)
        : (widget.color ?? AgentColors.orchestrator);
    final agentName = slug != null
        ? AgentColors.displayName(slug)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Agent avatar — 28x28 circle with initial
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: agentColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: slug != null
                  ? Text(
                      agentName!.isNotEmpty ? agentName[0].toUpperCase() : '?',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          // Bubble with agent name + dots
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Agent name label above bubble (matching agent message style)
              if (agentName != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    agentName,
                    style: GoogleFonts.inter(
                      color: agentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              // Typing bubble
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    return _BounceDot(
                      listenable: _animations[i],
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _animations[i].value),
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: i == 0 ? 0 : 6,
                            ),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _dotColors[i],
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ),
            ],
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
