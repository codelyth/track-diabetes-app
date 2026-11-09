import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../data/glucose_repository.dart';
import '../domain/glucose_reading.dart';

class AddGlucoseScreen extends StatefulWidget {
  const AddGlucoseScreen({
    super.key,
    required this.userId,
    this.initialReading,
  });

  final String userId;
  final GlucoseReading? initialReading;

  @override
  State<AddGlucoseScreen> createState() => _AddGlucoseScreenState();
}

class _AddGlucoseScreenState extends State<AddGlucoseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _noteController = TextEditingController();

  late final GlucoseRepository _repository;

  GlucoseType? _type;
  DateTime _measuredAt = DateTime.now();
  bool _isSaving = false;

  bool get _isEditing => widget.initialReading != null;

  @override
  void initState() {
    super.initState();

    _repository = GlucoseRepository(userId: widget.userId);

    final reading = widget.initialReading;

    if (reading != null) {
      _valueController.text = reading.valueMgDl.toString();
      _noteController.text = reading.note;
      _type = reading.type;
      _measuredAt = reading.measuredAt.toLocal();
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String get _dateLabel {
    return '${_two(_measuredAt.day)}.'
        '${_two(_measuredAt.month)}.${_measuredAt.year}';
  }

  String get _timeLabel {
    return '${_two(_measuredAt.hour)}:${_two(_measuredAt.minute)}';
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _measuredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Ölçüm tarihini seçin',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );

    if (selected == null || !mounted) return;

    setState(() {
      _measuredAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _measuredAt.hour,
        _measuredAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_measuredAt),
      helpText: 'Ölçüm saatini seçin',
      cancelText: 'İptal',
      confirmText: 'Seç',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (selected == null || !mounted) return;

    setState(() {
      _measuredAt = DateTime(
        _measuredAt.year,
        _measuredAt.month,
        _measuredAt.day,
        selected.hour,
        selected.minute,
      );
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_isSaving) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final type = _type;

    if (type == null) {
      _showMessage('Açlık veya tokluk seçin.');
      return;
    }

    if (_measuredAt.isAfter(DateTime.now())) {
      _showMessage('Ölçüm zamanı gelecekte olamaz.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final value = int.parse(_valueController.text.trim());
      final initialReading = widget.initialReading;

      if (initialReading == null) {
        await _repository.addReading(
          valueMgDl: value,
          type: type,
          measuredAt: _measuredAt,
          note: _noteController.text,
        );
      } else {
        await _repository.updateReading(
          id: initialReading.id,
          valueMgDl: value,
          type: type,
          measuredAt: _measuredAt,
          note: _noteController.text,
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      if (!mounted) return;

      final message = switch (error.code) {
        'permission-denied' =>
          'Kayıt izni alınamadı. Oturumunuzu ve Firestore '
              'kurallarını kontrol edin.',
        'not-found' =>
          'Bu ölçüm artık bulunamıyor. Kayıtlar ekranına geri dönün.',
        _ => 'Ölçüm kaydedilemedi. Bağlantınızı kontrol edip tekrar deneyin.',
      };

      _showMessage(message);
    } catch (_) {
      if (!mounted) return;

      _showMessage('İşlem tamamlanamadı. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _label(String text) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(_isEditing ? 'Ölçümü düzenle' : 'Ölçüm ekle'),
          automaticallyImplyLeading: !_isSaving,
        ),
        body: SafeArea(
          child: AbsorbPointer(
            absorbing: _isSaving,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _label('Kan şekeri değeri'),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _valueController,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Değer girin',
                                  suffixText: 'mg/dL',
                                ),
                                validator: (value) {
                                  final number = int.tryParse(
                                    value?.trim() ?? '',
                                  );

                                  if (number == null || number <= 0) {
                                    return 'Sıfırdan büyük bir tam sayı girin.';
                                  }

                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _label('Ölçüm türü'),
                        const SizedBox(height: 12),
                        SegmentedButton<GlucoseType>(
                          emptySelectionAllowed: true,
                          segments: const [
                            ButtonSegment(
                              value: GlucoseType.fasting,
                              label: Text('Açlık'),
                              icon: Icon(Icons.water_drop_outlined),
                            ),
                            ButtonSegment(
                              value: GlucoseType.postMeal,
                              label: Text('Tokluk'),
                              icon: Icon(Icons.restaurant_outlined),
                            ),
                          ],
                          selected: {?_type},
                          onSelectionChanged: (selection) {
                            setState(() {
                              _type = selection.isEmpty
                                  ? null
                                  : selection.first;
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        _label('Ölçüm zamanı'),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(_dateLabel),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _pickTime,
                          icon: const Icon(Icons.schedule),
                          label: Text(_timeLabel),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              setState(() => _measuredAt = DateTime.now());
                            },
                            child: const Text('Şimdi'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _noteController,
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 1000,
                          decoration: const InputDecoration(
                            labelText: 'Not (isteğe bağlı)',
                            alignLabelWithHint: true,
                            hintText: 'Ölçümle ilgili bir not ekleyin',
                          ),
                          validator: (value) {
                            if ((value?.trim().length ?? 0) > 1000) {
                              return 'Not en fazla 1000 karakter olabilir.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(
                            _isSaving
                                ? 'Kaydediliyor...'
                                : _isEditing
                                ? 'Değişiklikleri kaydet'
                                : 'Kaydet',
                          ),
                        ),
                        if (_isSaving) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Sunucu onayı bekleniyor. Çevrimdışıysanız '
                            'bağlantı geldiğinde işlem devam eder.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('İptal'),
                        ),
                      ],
                    ),
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
