import 'package:flutter/material.dart';

import '../../core/accounting.dart';
import '../../core/labels_ar.dart';
import '../../core/numbers.dart';
import 'production_controller.dart';

const Color _green = Color(0xFF0E6B58);
const Color _greenSoft = Color(0xFFE3F1ED);
const Color _pageBackground = Color(0xFFF5F6F4);
const Color _textPrimary = Color(0xFF1B2421);
const Color _textSecondary = Color(0xFF5B6761);
const Color _border = Color(0xFFD9DEDB);

/// شاشة الإنتاج اليومي: عدد الجوالات أولاً، ثم عيش كل جوال في خانته المرقمة،
/// والمجموع والمتوسط والفرق عن المفروض (حسب التصميم المعتمد).
///
/// تملك [controller] وتتخلص منه عند إغلاقها. الحفظ تلقائي مع كل تعديل.
class ProductionScreen extends StatefulWidget {
  const ProductionScreen({
    super.key,
    required this.controller,
    required this.onOpenSettings,
  });

  final ProductionController controller;

  /// يفتح شاشة الإعدادات (عند عدم اكتمال الأسعار).
  final Future<void> Function() onOpenSettings;

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.ensureLoaded();
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    await widget.onOpenSettings();
    if (mounted) {
      await widget.controller.openDay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: _pageBackground,
          appBar: _buildAppBar(controller),
          body: SafeArea(child: _body(controller)),
        );
      },
    );
  }

  /// الترويسة الخضراء: العنوان والتاريخ بالعربية، وسهما اليوم السابق والتالي
  /// (لا بعد اليوم، ولا قبل بداية الوكيل).
  PreferredSizeWidget _buildAppBar(ProductionController controller) {
    final date = controller.date;
    final subtitle = date.isEmpty
        ? null
        : '${arabicDateLabel(date)}${controller.isToday ? ' · اليوم' : ''}';
    final canMove = !controller.loading;
    return AppBar(
      backgroundColor: _green,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 68,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'الإنتاج اليومي',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFFD7EFE8),
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'اليوم السابق',
          color: Colors.white,
          disabledColor: Colors.white38,
          onPressed:
              canMove && controller.canGoPrevious ? () => controller.goToPrevious() : null,
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(
          tooltip: 'اليوم التالي',
          color: Colors.white,
          disabledColor: Colors.white38,
          onPressed: canMove && controller.canGoNext ? () => controller.goToNext() : null,
          icon: const Icon(Icons.chevron_left),
        ),
      ],
    );
  }

  Widget _body(ProductionController controller) {
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.loadFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                controller.error ?? 'تعذر تحميل اليوم',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => controller.load(),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    final day = controller.day;
    final summary = controller.summary;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (controller.error != null)
          _ErrorBanner(
            message: controller.error!,
            onClose: controller.dismissError,
          ),
        if (day == null || summary == null)
          _NotOpened(controller: controller, onOpenSettings: _openSettings)
        else ...[
          _StatsCard(summary: summary, target: day.targetPerSack),
          if (summary.sacks > 0) ...[
            const SizedBox(height: 12),
            _DiffCard(summary: summary, target: day.targetPerSack),
          ],
          if (day.isLocked) ...[
            const SizedBox(height: 12),
            const _LockedBanner(),
          ],
          const SizedBox(height: 12),
          _SacksCard(controller: controller, locked: day.isLocked),
        ],
      ],
    );
  }
}

/// بطاقة بيضاء بحواف مدوّرة كما في التصميم.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E8E6)),
      ),
      child: child,
    );
  }
}

InputDecoration _boxDecoration({String? hint}) {
  final normal = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: _border),
  );
  return InputDecoration(
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    border: normal,
    enabledBorder: normal,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _green, width: 1.6),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB42318)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: Color(0xFFB42318))),
          ),
          IconButton(
            tooltip: 'إخفاء',
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Color(0xFFB42318)),
          ),
        ],
      ),
    );
  }
}

/// اليوم المعروض لم يُفتح بعد.
class _NotOpened extends StatelessWidget {
  const _NotOpened({required this.controller, required this.onOpenSettings});

  final ProductionController controller;
  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          const Icon(Icons.event_note_outlined, size: 56, color: _textSecondary),
          const SizedBox(height: 12),
          const Text(
            'لم يُفتح هذا اليوم بعد',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          if (controller.needsSettings) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF0D5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'أدخل سعر الشباك وسعر التوزيع في الإعدادات أولاً، ثم يُفتح اليوم.',
                style: TextStyle(color: Color(0xFF7A4B00)),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => onOpenSettings(),
              child: const Text('فتح الإعدادات'),
            ),
          ] else
            FilledButton.icon(
              onPressed: () => controller.openDay(),
              icon: const Icon(Icons.add),
              label: const Text('فتح اليوم'),
            ),
        ],
      ),
    );
  }
}

class _LockedBanner extends StatelessWidget {
  const _LockedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF0D5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, color: Color(0xFF7A4B00)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              lockedDayMessage,
              style: TextStyle(color: Color(0xFF7A4B00), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// المجموع الكلي والمتوسط والمستهدف (ثلاث خانات كما في التصميم).
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.summary, required this.target});

  final ProductionSummary summary;
  final int target;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              label: 'المجموع الكلي',
              value: formatThousands(summary.total),
              caption: 'عيشة',
            ),
          ),
          Expanded(
            child: _Stat(
              label: 'المتوسط',
              value: formatAverage(summary.average),
              caption: 'للجوال',
              highlight: true,
            ),
          ),
          Expanded(
            child: _Stat(
              label: 'المستهدف',
              value: formatThousands(target),
              caption: 'للجوال',
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.caption,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String caption;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: _textSecondary)),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: highlight ? _green : _textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(caption, style: const TextStyle(fontSize: 11, color: _textSecondary)),
      ],
    );
  }
}

/// سطر الفرق عن المفروض، وتحته «المفروض 9,000 (10 جوالات × 900)» والفرق بالرقم.
class _DiffCard extends StatelessWidget {
  const _DiffCard({required this.summary, required this.target});

  final ProductionSummary summary;
  final int target;

  @override
  Widget build(BuildContext context) {
    final diff = summary.diff;
    final Color background;
    final Color foreground;
    if (diff > 0) {
      background = _greenSoft;
      foreground = _green;
    } else if (diff < 0) {
      background = const Color(0xFFFDF0D5);
      foreground = const Color(0xFF7A4B00);
    } else {
      background = const Color(0xFFEDF0EE);
      foreground = _textPrimary;
    }
    final badge = diff > 0 ? '+${formatThousands(diff)}' : formatThousands(diff);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productionDiffLabel(diff),
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'المفروض ${formatThousands(summary.expected)} '
                  '(${sacksCountLabel(summary.sacks)} × ${formatThousands(target)})',
                  style: TextStyle(color: foreground, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              badge,
              style: TextStyle(
                color: foreground,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة «القطعيات»: عدد الجوالات، ثم خانات مرقمة لعيش كل جوال.
class _SacksCard extends StatelessWidget {
  const _SacksCard({required this.controller, required this.locked});

  final ProductionController controller;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    if (locked) {
      for (final entry in controller.sacks) {
        rows.add(
          _SackRow(
            key: ValueKey<int>(entry.seq),
            seq: entry.seq,
            loaves: entry.loaves,
            editable: false,
            isLast: false,
            onChanged: (_) {},
            onCleared: () {},
          ),
        );
      }
    } else {
      final count = controller.rowCount;
      for (var seq = 1; seq <= count; seq++) {
        rows.add(
          _SackRow(
            key: ValueKey<int>(seq),
            seq: seq,
            loaves: controller.loavesOf(seq),
            editable: true,
            isLast: seq == count,
            onChanged: (value) => controller.setLoaves(seq, value),
            onCleared: () => controller.clearSack(seq),
          ),
        );
      }
    }

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'القطعيات',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (!locked) _CountField(controller: controller),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  locked
                      ? 'لا جوالات مسجلة في هذا اليوم'
                      : 'اكتب عدد الجوالات لتظهر خانات القطعيات',
                  style: const TextStyle(color: _textSecondary),
                ),
              ),
            )
          else ...[
            const SizedBox(height: 8),
            ...rows,
          ],
          if (!locked && rows.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: controller.rowCount >= maxSacksPerDay
                    ? null
                    : () {
                        // نغلق لوحة المفاتيح فيتحدّث رقم «عدد الجوالات» بالعدد الجديد.
                        FocusScope.of(context).unfocus();
                        controller.addRow();
                      },
                icon: const Icon(Icons.add),
                label: const Text('إضافة جوال'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _green,
                  side: const BorderSide(color: _green),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// خانة «عدد الجوالات». كل رقم صالح يظهر فوراً كخانات مرقمة.
class _CountField extends StatefulWidget {
  const _CountField({required this.controller});

  final ProductionController controller;

  @override
  State<_CountField> createState() => _CountFieldState();
}

class _CountFieldState extends State<_CountField> {
  late final TextEditingController _text = TextEditingController(text: _wanted());
  final FocusNode _focus = FocusNode();

  String _wanted() {
    final count = widget.controller.rowCount;
    return count > 0 ? count.toString() : '';
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    _focus.addListener(_sync);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _focus.removeListener(_sync);
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  /// يطابق نص الخانة مع العدد الفعلي حين لا يكتب المستخدم فيها (بعد «إضافة جوال»
  /// أو عند رفض عدد أقل من آخر جوال معبّأ).
  void _sync() {
    if (_focus.hasFocus) {
      return;
    }
    final want = _wanted();
    if (_text.text != want) {
      _text.text = want;
    }
  }

  void _changed(String value) {
    final parsed = parseWholeNumber(value);
    if (parsed != null) {
      widget.controller.setSackCount(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final filled = controller.filledCount;
    final total = controller.rowCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'عدد الجوالات',
                style: TextStyle(fontSize: 14, color: _textPrimary),
              ),
            ),
            SizedBox(
              width: 96,
              child: TextField(
                key: const ValueKey<String>('sack-count'),
                controller: _text,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
                onChanged: _changed,
                decoration: _boxDecoration(hint: 'مثلاً 10'),
              ),
            ),
          ],
        ),
        if (total > filled)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'سُجّل $filled من $total',
              style: const TextStyle(fontSize: 12, color: _textSecondary),
            ),
          ),
      ],
    );
  }
}

/// صف جوال: دائرة رقمه وخانة عيشه. كل رقم صالح يُحفظ فوراً، وتفريغ الخانة
/// يلغي الجوال. زر «التالي» في لوحة المفاتيح ينتقل إلى خانة الجوال التالي.
class _SackRow extends StatefulWidget {
  const _SackRow({
    super.key,
    required this.seq,
    required this.loaves,
    required this.editable,
    required this.isLast,
    required this.onChanged,
    required this.onCleared,
  });

  final int seq;

  /// القيمة المحفوظة، أو null إن كانت الخانة فارغة.
  final int? loaves;
  final bool editable;
  final bool isLast;
  final ValueChanged<int> onChanged;
  final VoidCallback onCleared;

  @override
  State<_SackRow> createState() => _SackRowState();
}

class _SackRowState extends State<_SackRow> {
  late final TextEditingController _text =
      TextEditingController(text: widget.loaves?.toString() ?? '');
  final FocusNode _focus = FocusNode();

  /// آخر قيمة أرسلناها للحفظ (null = فارغة). نقارن بها (لا بالمقروءة من القاعدة)
  /// لأن القراءة تتأخر عن الكتابة: لو كتب المستخدم 9 ثم 90 ثم عاد إلى القيمة
  /// الأصلية بسرعة لوجب إرسالها، وإلا بقيت الخانة مخالفة للمحفوظ.
  late int? _sent = widget.loaves;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  /// عند ترك الخانة نعيد كتابة المحفوظ: يُصلح نصاً غير صالح، ويوحّد الأرقام
  /// العربية (٩٠٥) إلى 905.
  void _onFocusChanged() {
    if (_focus.hasFocus) {
      return;
    }
    final want = _sent?.toString() ?? '';
    if (_text.text != want) {
      _text.text = want;
    }
  }

  void _changed(String value) {
    if (value.trim().isEmpty) {
      if (_sent != null) {
        _sent = null;
        widget.onCleared();
      }
      return;
    }
    final parsed = parseWholeNumber(value);
    if (parsed != null && parsed != _sent) {
      _sent = parsed;
      widget.onChanged(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _greenSoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              widget.seq.toString(),
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: widget.editable
                ? TextField(
                    controller: _text,
                    focusNode: _focus,
                    keyboardType: TextInputType.number,
                    textInputAction:
                        widget.isLast ? TextInputAction.done : TextInputAction.next,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                    onChanged: _changed,
                    decoration: _boxDecoration(),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: _border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      formatThousands(widget.loaves ?? 0),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
