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
  });

  final TextEditingController controller;
  final String hint;

  @override
  State<SpeechField> createState() => _SpeechFieldState();
}

class _SpeechFieldState extends State<SpeechField> {
  final _recorder = AudioRecorder();
  final _api = SoulApi.fromEnvironment();
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
              minLines: 1,
              maxLines: 4,
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
