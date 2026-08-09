import 'package:flutter/foundation.dart';
import '../../data/model/chat_message.dart';
import '../../data/service/api_client.dart';

class ChatProvider extends ChangeNotifier {
  static const quickReplies = [
    'Como está meu risco de abandono?',
    'Me dê uma dica para hoje',
    'Qual desafio devo priorizar?',
    'Como funciona o sistema de XP?',
  ];

  final List<ChatMessage> _messages = [
    ChatMessage(
      role: ChatRole.assistant,
      content:
          'Oi! Eu sou o assistente do Level30. Posso te ajudar com dicas sobre seus desafios, '
          'explicar como o app funciona ou só dar uma força na motivação. O que você quer saber?',
      sentAt: DateTime.now(),
    ),
  ];
  bool _sending = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get sending => _sending;

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;

    final history = _messages
        .where((m) => !m.isError)
        .map((m) => {
              'role': m.role == ChatRole.user ? 'user' : 'assistant',
              'content': m.content,
            })
        .toList();

    _messages.add(ChatMessage(
      role: ChatRole.user,
      content: trimmed,
      sentAt: DateTime.now(),
    ));
    _sending = true;
    notifyListeners();

    try {
      final res = await ApiClient.instance.post('/chat', {
        'message': trimmed,
        'history': history,
      }) as Map<String, dynamic>;

      _messages.add(ChatMessage(
        role: ChatRole.assistant,
        content: res['message'] as String,
        sentAt: DateTime.now(),
      ));
    } on ApiException catch (e) {
      _messages.add(ChatMessage(
        role: ChatRole.assistant,
        content: e.message,
        sentAt: DateTime.now(),
        isError: true,
      ));
    } catch (_) {
      _messages.add(ChatMessage(
        role: ChatRole.assistant,
        content: 'Não consegui me conectar. Verifique sua internet e tente de novo.',
        sentAt: DateTime.now(),
        isError: true,
      ));
    }

    _sending = false;
    notifyListeners();
  }
}
