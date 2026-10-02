class ChatMessage {
  final String text;
  final bool isBot;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.isBot,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'isBot': isBot,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        text: j['text'] as String,
        isBot: j['isBot'] as bool,
        timestamp: DateTime.parse(j['timestamp'] as String),
      );
}
