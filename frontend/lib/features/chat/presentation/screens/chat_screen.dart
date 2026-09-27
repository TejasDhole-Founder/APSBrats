import 'package:apsbrat_frontend/features/chat/data/chat_models.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_repository.dart';
import 'package:apsbrat_frontend/features/chat/presentation/chat_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _bodyController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadOlder);
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadOlder() {
    if (_scrollController.position.pixels <= 120) {
      ref.read(chatControllerProvider(widget.conversationId).notifier).loadOlder();
    }
  }

  void _send() {
    final text = _bodyController.text.trim();
    if (text.isEmpty) return;
    _bodyController.clear();
    ref.read(chatControllerProvider(widget.conversationId).notifier).send(text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider(widget.conversationId));

    // The conversations list is usually already loaded (Messages tab loads
    // it) -- reuse it just to show a name in the header instead of adding a
    // GET-one-conversation endpoint for this alone.
    final conversations = ref.watch(conversationsProvider).maybeWhen(
          data: (list) => list,
          orElse: () => const <Conversation>[],
        );
    final match = conversations.where((c) => c.id == widget.conversationId);
    final title = match.isNotEmpty ? match.first.person.name : 'Chat';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          if (state.loadingOlder)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: state.loading
                ? const Center(child: CircularProgressIndicator())
                : state.messages.isEmpty
                    ? const Center(child: Text('Say hi 👋'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: state.messages.length,
                        itemBuilder: (context, index) {
                          final message = state.messages[index];
                          return _MessageBubble(
                            message: message,
                            pending: state.pendingIds.contains(message.id),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bodyController,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.pending});

  final ChatMessage message;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Opacity(
        opacity: pending ? 0.6 : 1,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: message.mine
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(message.body),
        ),
      ),
    );
  }
}
