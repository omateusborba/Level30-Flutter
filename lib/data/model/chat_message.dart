enum ChatRole { user, assistant }

class ChatMessage {
  final ChatRole role;
  final String content;
  final DateTime sentAt;
  final bool isError;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.sentAt,
    this.isError = false,
  });
}
