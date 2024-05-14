import 'package:chat_interface/theme/ui/text_renderer/text_pattern_manager.dart';
import 'package:flutter/material.dart';

class TextRenderer extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const TextRenderer({super.key, required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    // Build text
    List<ProcessedText> processed = textPatternManager.process(text, style ?? theme.textTheme.bodyMedium!, renderPatterns: false);
    List<TextSpan> spans = [];
    for (ProcessedText span in processed) {
      spans.add(TextSpan(text: span.text, style: span.style));
    }

    // Render text
    return Text.rich(TextSpan(children: spans));
  }
}
