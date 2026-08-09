import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/model/chat_message.dart';
import '../../domain/provider/chat_provider.dart';
import '../widgets/level30_app_bar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _controller.clear();
    await context.read<ChatProvider>().sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ChatProvider>();
    _scrollToBottom();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const Level30AppBar(title: 'Assistente'),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: cp.messages.length + (cp.sending ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= cp.messages.length) {
                  return const _TypingBubble();
                }
                return _MessageBubble(message: cp.messages[index]);
              },
            ),
          ),
          _QuickReplies(onTap: cp.sending ? null : _send),
          _InputBar(
            controller: _controller,
            enabled: !cp.sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final bg = isUser
        ? AppColors.accent
        : message.isError
            ? AppColors.riskCritical.withAlpha(40)
            : AppColors.surface;
    final fg = isUser ? AppColors.background : AppColors.textPrimary;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 2),
            bottomRight: Radius.circular(isUser ? 2 : 14),
          ),
          border: message.isError
              ? Border.all(color: AppColors.riskCritical)
              : null,
        ),
        child: _FormattedMessage(
          text: message.content,
          style: GoogleFonts.poppins(color: fg, fontSize: 14, height: 1.35),
        ),
      ),
    );
  }
}

/// Renderiza um subconjunto simples de markdown vindo da IA: **negrito** e
/// listas com "- "/"* " no início da linha. Evita depender de um pacote de
/// markdown completo só para esses dois casos.
class _FormattedMessage extends StatelessWidget {
  final String text;
  final TextStyle style;
  const _FormattedMessage({required this.text, required this.style});

  static final _boldPattern = RegExp(r'\*\*(.+?)\*\*');

  List<InlineSpan> _parseBold(String line) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in _boldPattern.allMatches(line)) {
      if (match.start > last) {
        spans.add(TextSpan(text: line.substring(last, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      last = match.end;
    }
    if (last < line.length) spans.add(TextSpan(text: line.substring(last)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          if (line.trim().isEmpty)
            const SizedBox(height: 6)
          else
            Padding(
              padding: EdgeInsets.only(
                left: line.trimLeft().startsWith('- ') ||
                        line.trimLeft().startsWith('* ')
                    ? 12
                    : 0,
              ),
              child: Text.rich(
                TextSpan(
                  style: style,
                  children: _parseBold(
                    line.trimLeft().startsWith('- ') ||
                            line.trimLeft().startsWith('* ')
                        ? '•  ${line.trimLeft().substring(2)}'
                        : line,
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomRight: Radius.circular(14),
            bottomLeft: Radius.circular(2),
          ),
        ),
        child: const SizedBox(
          width: 20,
          height: 14,
          child: Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickReplies extends StatelessWidget {
  final void Function(String)? onTap;
  const _QuickReplies({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: ChatProvider.quickReplies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final question = ChatProvider.quickReplies[index];
          return ActionChip(
            label: Text(question,
                style: GoogleFonts.poppins(
                    color: AppColors.textPrimary, fontSize: 12)),
            backgroundColor: AppColors.surface,
            side: BorderSide(color: AppColors.primary.withAlpha(120)),
            onPressed: onTap == null ? null : () => onTap!(question),
          );
        },
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final void Function(String) onSend;

  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: enabled ? onSend : null,
                style: GoogleFonts.poppins(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Digite sua pergunta...',
                  hintStyle: GoogleFonts.poppins(color: AppColors.textSecond),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: enabled ? () => onSend(controller.text) : null,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor: AppColors.primary,
              ),
              icon: Icon(Icons.send_rounded,
                  color: enabled ? AppColors.background : AppColors.textSecond),
            ),
          ],
        ),
      ),
    );
  }
}
