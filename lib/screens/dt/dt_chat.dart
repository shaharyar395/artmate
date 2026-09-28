import 'package:flutter/material.dart';

import '../../battle/battle_data.dart' show SeatState;
import '../../core/app_config.dart';
import '../../core/app_state.dart';
import '../../core/catalog.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../dt/dt_session.dart';
import '../../widgets/common.dart';

/// Emoji on the React sheet (same set as the reference app).
const List<String> kReactEmoji = [
  '❤️', '😂', '👏', '🎨', '🔥', '⭐', '😮', '🌈', '💯', '👋', '😠',
];

/// Ready-made phrases (translation keys).
const List<String> kPhraseKeys = [
  'ph1', 'ph2', 'ph3', 'ph4', 'ph5', 'ph6', 'ph7', 'ph8',
];

/// Chat sheet: "● 1 friend still drawing", messages (or "No messages yet"),
/// quick emoji ❤️ 😂 👏 🎨 +, and "Say something..." with send.
/// Stays open while chatting; messages from the partner appear live.
Future<void> showDtChatSheet(BuildContext context, DtSession session) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    barrierColor: Colors.black.withOpacity(0.35),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => _ChatSheet(session: session),
  );
}

class _ChatSheet extends StatefulWidget {
  const _ChatSheet({required this.session});
  final DtSession session;

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final TextEditingController _text = TextEditingController();
  final ScrollController _list = ScrollController();

  DtSession get _s => widget.session;
  bool get _canType =>
      _s.withFriend || AppConfig.allowTextChatWithStrangers;

  @override
  void initState() {
    super.initState();
    _s.log.addListener(_scrollDown);
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _s.log.removeListener(_scrollDown);
    _text.dispose();
    _list.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_list.hasClients) {
        _list.animateTo(_list.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut);
      }
    });
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    AppScope.read(context).tap();
    _s.sendChat(text);
  }

  Future<void> _react() async {
    AppScope.read(context).tap();
    final pick = await showReactSheet(context);
    if (pick != null && mounted) _send(pick);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final me = AppScope.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ---------------------------------------- status
            ValueListenableBuilder<SeatState>(
              valueListenable: _s.partnerState,
              builder: (_, st, __) {
                final done = st.finished;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: done
                              ? const Color(0xFF3A8EF0)
                              : AppColors.switchGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                          done
                              ? tr(context, 'friendDone')
                              : tr(context, 'friendStillDrawing', {'n': '1'}),
                          style: nunito(13,
                              weight: FontWeight.w700,
                              color: done
                                  ? const Color(0xFF3A8EF0)
                                  : AppColors.switchGreen)),
                    ],
                  ),
                );
              },
            ),
            // ---------------------------------------- messages
            SizedBox(
              height: 230,
              child: ValueListenableBuilder<List<(int, String)>>(
                valueListenable: _s.log,
                builder: (_, log, __) {
                  if (log.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tr(context, 'noMessages'),
                              style: nunito(16, weight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(tr(context, 'sayHi'),
                              style: nunito(13,
                                  weight: FontWeight.w500,
                                  color: AppColors.sub)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: _list,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    itemCount: log.length,
                    itemBuilder: (_, i) {
                      final (seat, text) = log[i];
                      final mine = seat == _s.mySeat;
                      return _Message(
                        text: text,
                        mine: mine,
                        name: mine ? tr(context, 'you') : _s.partner.name,
                        avatar: mine ? me.avatarIndex : _s.partner.avatar,
                      );
                    },
                  );
                },
              ),
            ),
            // ---------------------------------------- quick emoji
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  for (final e in const ['❤️', '😂', '👏', '🎨'])
                    GestureDetector(
                      onTap: () => _send(e),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Emoji(e, size: 26),
                      ),
                    ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _react,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                          color: Color(0xFFEAF3FF), shape: BoxShape.circle),
                      child: const Icon(Icons.add_rounded,
                          color: Color(0xFF3A8EF0)),
                    ),
                  ),
                ],
              ),
            ),
            // ---------------------------------------- input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F3F5),
                        borderRadius: BorderRadius.circular(23),
                      ),
                      child: _canType
                          ? TextField(
                              controller: _text,
                              maxLength: 80,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (v) {
                                _send(v);
                                _text.clear();
                              },
                              style: nunito(15, weight: FontWeight.w600),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                counterText: '',
                                isCollapsed: true,
                                hintText: tr(context, 'saySomething'),
                                hintStyle: nunito(15,
                                    weight: FontWeight.w500,
                                    color: const Color(0xFFA0A4AA)),
                              ),
                            )
                          : GestureDetector(
                              onTap: _react,
                              child: Text(tr(context, 'emojiOnly'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: nunito(13,
                                      weight: FontWeight.w600,
                                      color: const Color(0xFFA0A4AA))),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      if (!_canType) {
                        _react();
                        return;
                      }
                      _send(_text.text);
                      _text.clear();
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _text.text.trim().isNotEmpty
                            ? const Color(0xFF3A8EF0)
                            : const Color(0xFFEAF3FF),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.send_rounded,
                          size: 22,
                          color: _text.text.trim().isNotEmpty
                              ? Colors.white
                              : const Color(0xFF8DBBF5)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    required this.mine,
    required this.name,
    required this.avatar,
  });
  final String text;
  final bool mine;
  final String name;
  final int avatar;

  @override
  Widget build(BuildContext context) {
    final bubble = Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFF3A8EF0) : const Color(0xFFF2F3F5),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Text(text,
            style: nunito(15,
                weight: FontWeight.w600,
                color: mine ? Colors.white : const Color(0xFF2A2A2A))),
      ),
    );
    final face = Emoji(kAvatars[avatar % kAvatars.length], size: 24);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 34),
            child: Text(name,
                style: nunito(11,
                    weight: FontWeight.w700, color: AppColors.sub)),
          ),
          Row(
            mainAxisAlignment:
                mine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: mine
                ? [bubble, const SizedBox(width: 6), face]
                : [face, const SizedBox(width: 6), bubble],
          ),
        ],
      ),
    );
  }
}

/// "React" sheet with Emoji / Phrase tabs. Returns what to send.
Future<String?> showReactSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => const _ReactSheet(),
  );
}

class _ReactSheet extends StatefulWidget {
  const _ReactSheet();

  @override
  State<_ReactSheet> createState() => _ReactSheetState();
}

class _ReactSheetState extends State<_ReactSheet> {
  bool _phrases = false;

  Widget _tab(String icon, String label, bool sel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF3A8EF0) : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Emoji(icon, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: nunito(16,
                    weight: FontWeight.w700,
                    color: sel ? Colors.white : const Color(0xFF6B6B6B))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Text(tr(context, 'react'),
                style: nunito(20, weight: FontWeight.w800)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3F5),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _tab('😀', tr(context, 'emojiTab'), !_phrases, () {
                    AppScope.read(context).tap();
                    setState(() => _phrases = false);
                  }),
                  _tab('💬', tr(context, 'phraseTab'), _phrases, () {
                    AppScope.read(context).tap();
                    setState(() => _phrases = true);
                  }),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (!_phrases)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final e in kReactEmoji)
                    GestureDetector(
                      onTap: () => Navigator.pop(context, e),
                      child: Container(
                        width: 50,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFECEEF1)),
                        ),
                        child: Emoji(e, size: 26),
                      ),
                    ),
                ],
              )
            else
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final k in kPhraseKeys)
                    GestureDetector(
                      onTap: () => Navigator.pop(context, tr(context, k)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F7FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFD6E6FF)),
                        ),
                        child: Text(tr(context, k),
                            style: nunito(15,
                                weight: FontWeight.w700,
                                color: const Color(0xFF2A5FB0))),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
