import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 시간 입력 창: 위에는 키보드로 숫자 입력, 아래에는 돌려서 고르는 휠
/// 둘 중 하나를 바꾸면 다른 쪽도 같이 바뀜 (24시간 기준)
Future<TimeOfDay?> showTimeInputDialog(BuildContext context, TimeOfDay initial) {
  return showDialog<TimeOfDay>(
    context: context,
    builder: (_) => _TimeInputDialog(initial: initial),
  );
}

class _TimeInputDialog extends StatefulWidget {
  const _TimeInputDialog({required this.initial});
  final TimeOfDay initial;

  @override
  State<_TimeInputDialog> createState() => _TimeInputDialogState();
}

class _TimeInputDialogState extends State<_TimeInputDialog> {
  late int _hour = widget.initial.hour;
  late int _minute = widget.initial.minute;
  late final _hourCtrl = TextEditingController(text: _two(_hour));
  late final _minuteCtrl = TextEditingController(text: _two(_minute));
  int _wheelVersion = 0; // 키보드로 바꾸면 휠을 새 값으로 다시 그림

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  /// 키보드 입력 → 휠
  void _onTyped() {
    final h = int.tryParse(_hourCtrl.text);
    final m = int.tryParse(_minuteCtrl.text);
    if (h == null || m == null || h > 23 || m > 59) return; // 입력 중이거나 범위 밖이면 무시
    if (h == _hour && m == _minute) return;
    setState(() {
      _hour = h;
      _minute = m;
      _wheelVersion++;
    });
  }

  /// 휠 → 키보드 입력칸
  void _onWheel(DateTime t) {
    setState(() {
      _hour = t.hour;
      _minute = t.minute;
      _hourCtrl.text = _two(t.hour);
      _minuteCtrl.text = _two(t.minute);
    });
  }

  Widget _field(TextEditingController ctrl, String label, int max) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
      ],
      decoration: InputDecoration(
        labelText: label,
        helperText: '0~$max',
        border: const OutlineInputBorder(),
      ),
      onTap: () => ctrl.selection =
          TextSelection(baseOffset: 0, extentOffset: ctrl.text.length), // 누르면 전체 선택
      onChanged: (_) => _onTyped(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final valid = int.tryParse(_hourCtrl.text) != null &&
        int.tryParse(_minuteCtrl.text) != null &&
        int.parse(_hourCtrl.text) <= 23 &&
        int.parse(_minuteCtrl.text) <= 59;

    return AlertDialog(
      title: const Text('알림 시간'),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _field(_hourCtrl, '시', 23)),
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 10, 8, 0),
                  child: Text(':', style: TextStyle(fontSize: 28)),
                ),
                Expanded(child: _field(_minuteCtrl, '분', 59)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: CupertinoTheme(
                data: CupertinoThemeData(brightness: Theme.of(context).brightness),
                child: CupertinoDatePicker(
                  key: ValueKey(_wheelVersion),
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: DateTime(2000, 1, 1, _hour, _minute),
                  onDateTimeChanged: _onWheel,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          onPressed: valid
              ? () => Navigator.pop(context, TimeOfDay(hour: _hour, minute: _minute))
              : null,
          child: const Text('확인'),
        ),
      ],
    );
  }
}
