import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../api/client.dart';
import '../../theme/soul_theme.dart';
import 'live_speech.dart';

/// A box you can type into or talk into.
///
/// The mic on the right opens the same live connection the capture screen
/// uses, and the words land in the box as they are said, after whatever was
/// typed. Tap the mic again to stop. Small enough to sit under a question.
class SpeechField extends StatefulWidget {
  const SpeechField({
    super.key,
    required this.controller,
    this.hint = 'Say or type anything about it',
    this.focusNode,
    this.maxLines = 10,
  });

  final TextEditingController controller;
  final String hint;

  /// So the screen around it can put the keyboard away, which is what the
  /// cue card does before it sends.
  final FocusNode? focusNode;

  /// Room for a paragraph by default. A card in a list wants less.
  final int maxLines;

  @override
  State<SpeechField> createState() => _SpeechFieldState();
}

class _SpeechFieldState extends State<SpeechField> {
  final _recorder = AudioRecorder();
  final _api = SoulApi.fromEnvironment();

  /// The box does not have focus while somebody is speaking, and a field
  /// with no focus does not follow its own caret. Without this the words
  /// land under the bottom edge and the speaker watches a box that has
  /// stopped moving.
  final _scroll = ScrollController();
  LiveSpeech? _live;
  StreamSubscription<Uint8List>? _audio;
  bool _recording = false;
  bool _busy = false;
  String _before = '';
  String _committed = '';
  String _partial = '';

  @override
  void dispose() {
    _audio?.cancel();
    _live?.close();
    _recorder.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_busy) return;
    if (_recording) {
      await _stop();
      return;
    }
    if (!await _recorder.hasPermission()) return;
    setState(() => _busy = true);
    try {
      final live = LiveSpeech(token: await _api.speechToken());
      await live.connect();
      _live = live;
      _before = widget.controller.text.trimRight();
      _committed = '';
      _partial = '';
      live.transcripts.listen((t) {
        if (!mounted) return;
        setState(() {
          if (t.committed) {
            _committed = _join(_committed, t.text);
            _partial = '';
          } else {
            _partial = t.text;
          }
          _show();
        });
      }, onError: (Object _) {});
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      _audio = stream.listen(live.send);
      if (!mounted) return;
      setState(() {
        _recording = true;
        _busy = false;
      });
    } catch (error) {
      _api.event('speech_failed', {'stage': 'field', 'error': error.runtimeType.toString()});
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    setState(() {
      _recording = false;
      _busy = true;
    });
    await _audio?.cancel();
    _audio = null;
    await _recorder.stop();
    final live = _live;
    _live = null;
    if (live != null) {
      await live.finish(const Duration(milliseconds: 2500));
      await live.close();
    }
    if (!mounted) return;
    setState(() {
      if (_partial.isNotEmpty) {
        _committed = _join(_committed, _partial);
        _partial = '';
      }
      _show();
      _busy = false;
    });
  }

  static String _join(String a, String b) {
    if (a.isEmpty) return b.trim();
    if (b.trim().isEmpty) return a;
    return '$a ${b.trim()}';
  }

  void _show() {
    final text = _join(_join(_before, _committed), _partial);
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _toBottom();
  }

  /// Hold the newest words in view.
  ///
  /// After the frame, because the box has not laid the new line out yet and
  /// the extent to scroll to does not exist until it has. Jump rather than
  /// animate: a new word arrives every few hundred milliseconds and an
  /// animation started before the last one finished reads as a shake.
  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SoulColors.s1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _recording ? SoulColors.clay : SoulColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              scrollController: _scroll,
              minLines: 1,
              // Room for a paragraph rather than a sentence. Somebody
              // speaking their answer fills four lines in about fifteen
              // seconds and then cannot see any of what they have said.
              maxLines: widget.maxLines,
              style: const TextStyle(
                fontFamily: SoulType.sans,
                fontSize: 16,
                height: 1.4,
                color: SoulColors.text,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: widget.hint,
                hintStyle: SoulType.secondary.copyWith(fontSize: 16),
              ),
            ),
          ),
          IconButton(
            onPressed: _toggle,
            tooltip: _recording ? 'Stop' : 'Speak',
            icon: Icon(
              _recording ? Icons.stop_circle_outlined : Icons.mic_none,
              size: 24,
              color: _recording ? SoulColors.clay : SoulColors.text2,
            ),
          ),
        ],
      ),
    );
  }
}
