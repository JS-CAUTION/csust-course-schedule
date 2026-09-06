import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 学期第一天选择器。
///
/// - 日历模式：自绘月历，周起始日固定为周日（日一二三四五六）。
/// - 输入模式：年 / 月 / 日 三段独立输入，输入满自动跳格，无需输入斜杠。
Future<DateTime?> showSemesterDayPicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _SemesterDayPickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

class _SemesterDayPickerDialog extends StatefulWidget {
  const _SemesterDayPickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_SemesterDayPickerDialog> createState() =>
      _SemesterDayPickerDialogState();
}

class _SemesterDayPickerDialogState extends State<_SemesterDayPickerDialog> {
  static const List<String> _weekdayLabels = ['日', '一', '二', '三', '四', '五', '六'];

  late DateTime _selectedDate;
  bool _inputMode = false;

  late int _displayedYear;
  late int _displayedMonth;

  late final TextEditingController _yearController;
  late final TextEditingController _monthController;
  late final TextEditingController _dayController;

  final FocusNode _yearFocus = FocusNode();
  final FocusNode _monthFocus = FocusNode();
  final FocusNode _dayFocus = FocusNode();

  String? _errorText;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _displayedYear = _selectedDate.year;
    _displayedMonth = _selectedDate.month;
    _yearController = TextEditingController(text: _selectedDate.year.toString());
    _monthController =
        TextEditingController(text: _selectedDate.month.toString());
    _dayController = TextEditingController(text: _selectedDate.day.toString());
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    _yearFocus.dispose();
    _monthFocus.dispose();
    _dayFocus.dispose();
    super.dispose();
  }

  void _syncControllersFromSelected() {
    _yearController.text = _selectedDate.year.toString();
    _monthController.text = _selectedDate.month.toString();
    _dayController.text = _selectedDate.day.toString();
  }

  DateTime? _parseInput() {
    final int? year = int.tryParse(_yearController.text);
    final int? month = int.tryParse(_monthController.text);
    final int? day = int.tryParse(_dayController.text);
    if (year == null || month == null || day == null) return null;
    final DateTime date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) return null;
    return date;
  }

  void _toggleMode() {
    final bool wasInputMode = _inputMode;
    setState(() {
      if (wasInputMode) {
        final DateTime? parsed = _parseInput();
        if (parsed != null &&
            !parsed.isBefore(widget.firstDate) &&
            !parsed.isAfter(widget.lastDate)) {
          _selectedDate = parsed;
        }
        _errorText = null;
      } else {
        _syncControllersFromSelected();
      }
      _inputMode = !wasInputMode;
      _displayedYear = _selectedDate.year;
      _displayedMonth = _selectedDate.month;
    });

    if (wasInputMode) {
      // 切回日历时先收起键盘，避免键盘收起动画期间高度不足导致的溢出闪烁。
      FocusManager.instance.primaryFocus?.unfocus();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _yearFocus.requestFocus();
      });
    }
  }

  void _handleOk() {
    if (_inputMode) {
      final DateTime? parsed = _parseInput();
      if (parsed == null ||
          parsed.isBefore(widget.firstDate) ||
          parsed.isAfter(widget.lastDate)) {
        setState(() {
          _errorText =
              '请输入有效日期（${widget.firstDate.year}/${widget.firstDate.month}/${widget.firstDate.day}'
              ' ~ ${widget.lastDate.year}/${widget.lastDate.month}/${widget.lastDate.day}）';
        });
        return;
      }
      Navigator.pop(context, parsed);
      return;
    }
    Navigator.pop(context, _selectedDate);
  }

  void _handleCancel() {
    Navigator.pop(context);
  }

  // ── 输入模式：三段数字输入 ──

  Widget _buildSegment({
    required TextEditingController controller,
    required FocusNode focusNode,
    required int maxLength,
    required String hint,
    VoidCallback? onFilled,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLength),
      ],
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) {
        if (_errorText != null) setState(() => _errorText = null);
        if (value.length == maxLength) onFilled?.call();
      },
      onSubmitted: (_) => onFilled?.call(),
    );
  }

  Widget _buildInputMode() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: _buildSegment(
                controller: _yearController,
                focusNode: _yearFocus,
                maxLength: 4,
                hint: '2026',
                onFilled: () => _monthFocus.requestFocus(),
              ),
            ),
            const SizedBox(width: 6),
            const Text('年'),
            const SizedBox(width: 6),
            Expanded(
              child: _buildSegment(
                controller: _monthController,
                focusNode: _monthFocus,
                maxLength: 2,
                hint: '8',
                onFilled: () => _dayFocus.requestFocus(),
              ),
            ),
            const SizedBox(width: 6),
            const Text('月'),
            const SizedBox(width: 6),
            Expanded(
              child: _buildSegment(
                controller: _dayController,
                focusNode: _dayFocus,
                maxLength: 2,
                hint: '13',
              ),
            ),
            const SizedBox(width: 6),
            const Text('日'),
          ],
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorText!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  // ── 日历模式：自绘月历（周日开头） ──

  void _changeDisplayedMonth(int delta) {
    int month = _displayedMonth + delta;
    int year = _displayedYear;
    while (month < 1) {
      month += 12;
      year -= 1;
    }
    while (month > 12) {
      month -= 12;
      year += 1;
    }
    year = year.clamp(widget.firstDate.year, widget.lastDate.year);
    if (year == widget.firstDate.year && month < widget.firstDate.month) {
      month = widget.firstDate.month;
    }
    if (year == widget.lastDate.year && month > widget.lastDate.month) {
      month = widget.lastDate.month;
    }
    setState(() {
      _displayedYear = year;
      _displayedMonth = month;
    });
  }

  Widget _buildCalendarMode() {
    final int daysInMonth = DateTime(_displayedYear, _displayedMonth + 1, 0).day;
    final int leadingBlanks = DateTime(_displayedYear, _displayedMonth, 1).weekday % 7;
    final DateTime today = DateTime.now();

    final List<Widget> cells = [];
    for (int i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (int day = 1; day <= daysInMonth; day++) {
      final DateTime date = DateTime(_displayedYear, _displayedMonth, day);
      final bool enabled =
          !date.isBefore(widget.firstDate) && !date.isAfter(widget.lastDate);
      final bool isSelected = date.year == _selectedDate.year &&
          date.month == _selectedDate.month &&
          date.day == _selectedDate.day;
      final bool isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      cells.add(
        _dayCell(date, enabled: enabled, isSelected: isSelected, isToday: isToday),
      );
    }
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    final List<int> years = [
      for (int y = widget.firstDate.year; y <= widget.lastDate.year; y++) y,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changeDisplayedMonth(-1),
            ),
            DropdownButton<int>(
              value: _displayedYear,
              items: [
                for (final int y in years)
                  DropdownMenuItem<int>(value: y, child: Text('$y')),
              ],
              onChanged: (int? y) {
                if (y == null) return;
                int month = _displayedMonth;
                if (y == widget.firstDate.year && month < widget.firstDate.month) {
                  month = widget.firstDate.month;
                }
                if (y == widget.lastDate.year && month > widget.lastDate.month) {
                  month = widget.lastDate.month;
                }
                setState(() {
                  _displayedYear = y;
                  _displayedMonth = month;
                });
              },
            ),
            const Text('年'),
            DropdownButton<int>(
              value: _displayedMonth,
              items: [
                for (int m = 1; m <= 12; m++)
                  DropdownMenuItem<int>(value: m, child: Text('$m')),
              ],
              onChanged: (int? m) {
                if (m == null) return;
                setState(() => _displayedMonth = m);
              },
            ),
            const Text('月'),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _changeDisplayedMonth(1),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final String label in _weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          children: cells,
        ),
      ],
    );
  }

  Widget _dayCell(
    DateTime date, {
    required bool enabled,
    required bool isSelected,
    required bool isToday,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color background = isSelected
        ? scheme.primary
        : isToday
            ? scheme.primaryContainer
            : Colors.transparent;
    final Color foreground = isSelected
        ? scheme.onPrimary
        : isToday
            ? scheme.onPrimaryContainer
            : enabled
                ? Colors.black87
                : Colors.black26;

    return GestureDetector(
      onTap: enabled ? () => setState(() => _selectedDate = date) : null,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Text(
          '${date.day}',
          style: TextStyle(
            color: foreground,
            fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '选择学期第一天',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: _inputMode ? '日历' : '输入',
                      icon: Icon(
                        _inputMode ? Icons.calendar_today : Icons.edit_outlined,
                      ),
                      onPressed: _toggleMode,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_inputMode)
                  _buildInputMode()
                else
                  _buildCalendarMode(),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _handleCancel,
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: _handleOk,
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
