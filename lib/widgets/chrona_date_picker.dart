import 'package:flutter/material.dart';

import '../utils/focus_formatters.dart';
import '../models/task.dart';

class ChronaDatePickerDialog extends StatefulWidget {
  const ChronaDatePickerDialog({
    super.key,
    required this.initialDate,
    this.showRelativeActions = true,
    this.confirmLabel = '转赴其时',
  });

  final DateTime initialDate;
  final bool showRelativeActions;
  final String confirmLabel;

  @override
  State<ChronaDatePickerDialog> createState() => _ChronaDatePickerDialogState();
}

class _ChronaDatePickerDialogState extends State<ChronaDatePickerDialog> {
  static final DateTime _firstDate = DateTime(2000);
  static final DateTime _lastDate = DateTime(2100, 12, 31);

  late DateTime _selectedDate;
  bool _inputMode = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = startOfDay(widget.initialDate);
  }

  void _selectInputDate(DateTime value) {
    setState(() => _selectedDate = startOfDay(value));
  }

  void _returnToToday() {
    Navigator.of(context).pop(startOfDay(DateTime.now()));
  }

  void _returnToLastYear() {
    Navigator.of(context).pop(_sameDayLastYear(_selectedDate));
  }

  void _confirm(BuildContext formContext) {
    final form = Form.of(formContext);
    if (_inputMode && !form.validate()) return;
    form.save();
    Navigator.of(context).pop(_selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    const colorScheme = ColorScheme.light(
      primary: Color(0xFF111111),
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: Color(0xFF111111),
    );

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: colorScheme,
        datePickerTheme: const DatePickerThemeData(
          headerBackgroundColor: Colors.white,
          headerForegroundColor: Color(0xFF111111),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ),
      ),
      child: Form(
        child: Builder(
          builder: (formContext) => Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            child: SizedBox(
              width: 360,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatFocusDate(_selectedDate),
                              style: const TextStyle(
                                color: Color(0xFF111111),
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: _inputMode ? '日历' : '输入日期',
                            onPressed: () => setState(
                              () => _inputMode = !_inputMode,
                            ),
                            icon: Icon(
                              _inputMode
                                  ? Icons.calendar_today_outlined
                                  : Icons.edit_outlined,
                              color: const Color(0xFF111111),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_inputMode)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                        child: InputDatePickerFormField(
                          initialDate: _selectedDate,
                          firstDate: _firstDate,
                          lastDate: _lastDate,
                          autofocus: true,
                          onDateSubmitted: _selectInputDate,
                          onDateSaved: _selectInputDate,
                        ),
                      )
                    else
                      CalendarDatePicker(
                        initialDate: _selectedDate,
                        firstDate: _firstDate,
                        lastDate: _lastDate,
                        currentDate: DateTime.now(),
                        onDateChanged: _selectInputDate,
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (widget.showRelativeActions) ...[
                            TextButton(
                              onPressed: _returnToLastYear,
                              child: const Text('去年今日'),
                            ),
                            TextButton(
                              onPressed: _returnToToday,
                              child: const Text('回到今朝'),
                            ),
                          ],
                          TextButton(
                            onPressed: () => _confirm(formContext),
                            child: Text(widget.confirmLabel),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

DateTime _sameDayLastYear(DateTime date) {
  final year = date.year - 1;
  final lastDayOfMonth = DateTime(year, date.month + 1, 0).day;
  final day = date.day > lastDayOfMonth ? lastDayOfMonth : date.day;
  return DateTime(year, date.month, day);
}
