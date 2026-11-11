import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/reminder_repository.dart';
import '../domain/reminder.dart';

class AddReminderScreen extends StatefulWidget {
  const AddReminderScreen({
    super.key,
    required this.userId,
    this.initialReminder,
  });

  final String userId;
  final Reminder? initialReminder;

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();

  late final ReminderRepository _repository;
  late TimeOfDay _time;
  late Set<int> _weekdays;

  ReminderType _type = ReminderType.fasting;
  bool _isSaving = false;

  bool get _isEditing => widget.initialReminder != null;

  static const _dayLabels = {
    1: 'Pzt',
    2: 'Sal',
    3: 'Çar',
    4: 'Per',
    5: 'Cum',
    6: 'Cmt',
    7: 'Paz',
  };

  @override
  void initState() {
    super.initState();

    _repository = ReminderRepository(userId: widget.userId);

    final reminder = widget.initialReminder;

    _type = reminder?.type ?? ReminderType.fasting;

    _time = reminder == null
        ? TimeOfDay.now()
        : TimeOfDay(hour: reminder.hour, minute: reminder.minute);

    _weekdays = reminder?.weekdays.toSet() ?? {1, 2, 3, 4, 5, 6, 7};
    _noteController.text = reminder?.note ?? '';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (!mounted || selected == null) return;

    setState(() => _time = selected);
  }

  void _selectDays(Set<int> days) {
    setState(() => _weekdays = {...days});
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final formIsValid = _formKey.currentState!.validate();

    if (_weekdays.isEmpty) {
      _showMessage('En az bir tekrar günü seçin.');
      return;
    }

    if (!formIsValid) return;

    FocusScope.of(context).unfocus();

    final days = _weekdays.toList()..sort();

    setState(() => _isSaving = true);

    try {
      final reminder = widget.initialReminder;

      if (reminder == null) {
        await _repository.addReminder(
          type: _type,
          hour: _time.hour,
          minute: _time.minute,
          weekdays: days,
          note: _noteController.text,
          isEnabled: false,
        );
      } else {
        await _repository.updateReminder(
          reminderId: reminder.id,
          type: _type,
          hour: _time.hour,
          minute: _time.minute,
          weekdays: days,
          note: _noteController.text,
          isEnabled: reminder.isEnabled,
        );
      }

      if (!mounted) return;

      setState(() => _isSaving = false);
      Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      debugPrint('Hatırlatıcı kaydedilemedi: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() => _isSaving = false);
      _showMessage(
        'Hatırlatıcı kaydedilemedi. '
        'İnternet bağlantınızı kontrol edip tekrar deneyin.',
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final hour = _time.hour.toString().padLeft(2, '0');
    final minute = _time.minute.toString().padLeft(2, '0');

    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditing ? 'Hatırlatıcıyı Düzenle' : 'Hatırlatıcı Ekle',
          ),
          automaticallyImplyLeading: !_isSaving,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.lavender,
                        child: Icon(
                          Icons.notifications_active_outlined,
                          color: AppColors.primary,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Takibinizi planlayın',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Hatırlatma türünü, saati ve tekrar günlerini seçin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, height: 1.5),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _FieldLabel('Hatırlatma türü'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<ReminderType>(
                              initialValue: _type,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.notifications_outlined),
                              ),
                              items: ReminderType.values.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(type.label),
                                );
                              }).toList(),
                              onChanged: _isSaving
                                  ? null
                                  : (value) {
                                      if (value == null) return;

                                      setState(() => _type = value);
                                    },
                            ),
                            const SizedBox(height: 24),
                            const _FieldLabel('Saat'),
                            const SizedBox(height: 8),
                            Material(
                              color: AppColors.field,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: _isSaving ? null : _selectTime,
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.schedule,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          '$hour:$minute',
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.text,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.edit_outlined,
                                        color: AppColors.muted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '24 saat biçimi · Cihazın yerel saatine göre.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const _FieldLabel('Tekrar günleri'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                TextButton(
                                  onPressed: _isSaving
                                      ? null
                                      : () =>
                                            _selectDays({1, 2, 3, 4, 5, 6, 7}),
                                  child: const Text('Her gün'),
                                ),
                                TextButton(
                                  onPressed: _isSaving
                                      ? null
                                      : () => _selectDays({1, 2, 3, 4, 5}),
                                  child: const Text('Hafta içi'),
                                ),
                                TextButton(
                                  onPressed: _isSaving
                                      ? null
                                      : () => _selectDays({6, 7}),
                                  child: const Text('Hafta sonu'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _dayLabels.entries.map((entry) {
                                return FilterChip(
                                  label: Text(entry.value),
                                  selected: _weekdays.contains(entry.key),
                                  selectedColor: AppColors.lavender,
                                  onSelected: _isSaving
                                      ? null
                                      : (selected) {
                                          setState(() {
                                            if (selected) {
                                              _weekdays.add(entry.key);
                                            } else {
                                              _weekdays.remove(entry.key);
                                            }
                                          });
                                        },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),
                            const _FieldLabel('Açıklama (isteğe bağlı)'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _noteController,
                              enabled: !_isSaving,
                              minLines: 2,
                              maxLines: 4,
                              maxLength: 200,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                hintText: 'Kendiniz için kısa bir not...',
                                alignLabelWithHint: true,
                              ),
                              validator: (value) {
                                if ((value ?? '').trim().length > 200) {
                                  return 'En fazla 200 karakter yazın.';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _isSaving ? null : _save,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.check),
                              label: Text(
                                _isSaving
                                    ? 'Kaydediliyor...'
                                    : _isEditing
                                    ? 'Değişiklikleri Kaydet'
                                    : 'Hatırlatıcıyı Kaydet',
                              ),
                            ),
                            if (_isSaving) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'Sunucu onayı bekleniyor. '
                                'Bağlantı yoksa işlem uzayabilir.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
    );
  }
}
