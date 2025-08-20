import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double velocity;
  final Duration pauseDuration;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.velocity = 50.0,
    this.pauseDuration = const Duration(seconds: 1),
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late ScrollController _scrollController;
  bool _needsScrolling = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    _scrollController = ScrollController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfScrollingNeeded();
    });
  }

  void _checkIfScrollingNeeded() {
    if (_scrollController.hasClients) {
      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      if (maxScrollExtent > 0) {
        setState(() {
          _needsScrolling = true;
        });
        _startScrolling();
      }
    }
  }

  void _startScrolling() {
    if (!_needsScrolling) return;
    
    _animation = Tween<double>(
      begin: 0.0,
      end: _scrollController.position.maxScrollExtent,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));

    _animation.addListener(() {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_animation.value);
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(widget.pauseDuration, () {
          if (mounted) {
            _controller.reset();
            Future.delayed(widget.pauseDuration, () {
              if (mounted) {
                _controller.forward();
              }
            });
          }
        });
      }
    });

    Future.delayed(widget.pauseDuration, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        overflow: TextOverflow.visible,
      ),
    );
  }
}
