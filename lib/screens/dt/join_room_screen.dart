import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/dt_catalog.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'dt_game_screen.dart';

/// "Join Room": enter the 4-digit code from a friend (or paste it). When the
/// 4th digit is in, it joins the friend's Draw Together room.
class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  String? _error;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _last = '';
  void _onChanged() {
    final t = _text.text;
    if (t == _last) return; // selection/focus changes only
    _last = t;
    setState(() {
      if (t.isNotEmpty) _error = null;
    });
    if (t.length == 4) _join(t);
  }

  Future<void> _join(String code) async {
    if (_joining) return;
    _joining = true;
    AppScope.read(context).tap();
    _focus.unfocus();
    final result = await Navigator.of(context).push(fadeRoute(DtGameScreen(
      template: kDtTemplates.first, // replaced by the friend's picture
      joinCode: code,
    )));
    if (!mounted) return;
    _joining = false;
    _text.clear();
    if (result == 'notFound') {
      setState(() => _error = tr(context, 'roomNotFound'));
      _focus.requestFocus();
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final digits = (data?.text ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (!mounted || digits.isEmpty) return;
    final code = digits.length > 4 ? digits.substring(0, 4) : digits;
    _text.value = TextEditingValue(
        text: code, selection: TextSelection.collapsed(offset: code.length));
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context);
    final code = _text.text;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  const BackCircle(),
                  Expanded(
                    child: Center(
                      heightFactor: 1,
                      child: OutlinedText(tr(context, 'joinRoom'),
                          size: 26,
                          fill: AppColors.titleBlue,
                          stroke: Colors.white,
                          strokeWidth: 5),
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
            ),
            const SizedBox(height: 70),
            Text(tr(context, 'enterRoomCode'),
                style: nunito(24, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(tr(context, 'roomCodeSub'),
                style: nunito(14,
                    weight: FontWeight.w600, color: AppColors.textSoft)),
            const SizedBox(height: 26),
            // Four boxes over an invisible text field.
            GestureDetector(
              onTap: () {
                if (_focus.hasFocus) {
                  // Keyboard was dismissed: bring it back.
                  SystemChannels.textInput.invokeMethod('TextInput.show');
                } else {
                  _focus.requestFocus();
                }
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: 0,
                    child: SizedBox(
                      width: 1,
                      height: 1,
                      child: TextField(
                        controller: _text,
                        focusNode: _focus,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        autofocus: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: const InputDecoration(counterText: ''),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 4; i++)
                        AnimatedBuilder(
                          animation: _focus,
                          builder: (_, __) {
                            final active = _focus.hasFocus &&
                                (i == code.length ||
                                    (i == 3 && code.length == 4));
                            return Container(
                              width: 58,
                              height: 66,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _error != null
                                      ? const Color(0xFFE5484D)
                                      : active
                                          ? const Color(0xFF3A8EF0)
                                          : const Color(0xFFE6E8EB),
                                  width: active ? 2 : 1.4,
                                ),
                              ),
                              child: i < code.length
                                  ? Text(code[i],
                                      style: nunito(28,
                                          weight: FontWeight.w800))
                                  : active
                                      ? Container(
                                          width: 2,
                                          height: 28,
                                          color: const Color(0xFF3A8EF0))
                                      : null,
                            );
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: nunito(14,
                        weight: FontWeight.w700,
                        color: const Color(0xFFE5484D))),
              ),
            ],
            const SizedBox(height: 26),
            Pressable(
              onTap: _paste,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE6E8EB)),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 6,
                        offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.content_paste_rounded,
                        size: 20, color: Color(0xFF1677FF)),
                    const SizedBox(width: 8),
                    Text(tr(context, 'pasteClipboard'),
                        style: nunito(16,
                            weight: FontWeight.w800,
                            color: const Color(0xFF1677FF))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
