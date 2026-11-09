import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/insulin_repository.dart';
import '../domain/insulin_entry.dart';

class AddInsulinScreen extends StatefulWidget {
  const AddInsulinScreen({super.key, required this.userId, this.initialEntry});

  final String userId;
  final InsulinEntry? initialEntry;

  @override
  State<AddInsulinScreen> createState() => _AddInsulinScreenState();
}

class _AddInsulinScreenState extends State<AddInsulinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _doseController = TextEditingController();
  final _noteController = TextEditingController();

  late final InsulinRepository _repository;

  InsulinKind? _kind;
  DateTime _administeredAt = DateTime.now();
  bool _isSaving = false;
  bool get _isEditing => widget.initialEntry != null;

  @override
  void initState() {
    super.initState();

    _repository = InsulinRepository(userId: widget.userId);

    final entry = widget.initialEntry;

    if (entry != null) {
      _nameController.text = entry.insulinName;
      _kind = entry.kind;

      final doseText = entry.doseUnits == entry.doseUnits.truncateToDouble()
          ? entry.doseUnits.toStringAsFixed(0)
          : entry.doseUnits.toString();

      _doseController.text = doseText.replaceAll('.', ',');
      _administeredAt = entry.administeredAt.toLocal();
      _noteController.text = entry.note;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String get _dateLabel {
    return '${_two(_administeredAt.day)}.'
        '${_two(_administeredAt.month)}.${_administeredAt.year}';
  }

  String get _timeLabel {
    return '${_two(_administeredAt.hour)}:'
        '${_two(_administeredAt.minute)}';
  }

  double? _parseDose(String text) {
    return double.tryParse(text.trim().replaceAll(',', '.'));
  }

  String _kindLabel(InsulinKind kind) {
    return switch (kind) {
      InsulinKind.bolus => 'Hızlı etkili (Bolus)',
      InsulinKind.basal => 'Uzun etkili (Bazal)',
      InsulinKind.other => 'Diğer',
    };
  }

  Widget _insulinOption(String name, InsulinKind kind) {
    final selected =
        _nameController.text.trim().toLowerCase() == name.toLowerCase() &&
        _kind == kind;

    return ChoiceChip(
      label: Text(name),
      selected: selected,
      selectedColor: AppColors.lavender,
      onSelected: (isSelected) {
        setState(() {
          if (isSelected) {
            _nameController.text = name;
            _kind = kind;
          } else {
            _nameController.clear();
            _kind = null;
          }
        });
      },
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _administeredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Uygulama tarihini seçin',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );

    if (selected == null || !mounted) return;

    setState(() {
      _administeredAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _administeredAt.hour,
        _administeredAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_administeredAt),
      helpText: 'Uygulama saatini seçin',
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
      _administeredAt = DateTime(
        _administeredAt.year,
        _administeredAt.month,
        _administeredAt.day,
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

    final kind = _kind;

    if (kind == null) {
      _showMessage('İnsülin türünü seçin.');
      return;
    }

    if (_administeredAt.isAfter(DateTime.now())) {
      _showMessage('Uygulama zamanı gelecekte olamaz.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final entry = widget.initialEntry;
      final dose = _parseDose(_doseController.text)!;

      if (entry == null) {
        await _repository.addEntry(
          insulinName: _nameController.text,
          kind: kind,
          doseUnits: dose,
          administeredAt: _administeredAt,
          note: _noteController.text,
        );
      } else {
        await _repository.updateEntry(
          id: entry.id,
          insulinName: _nameController.text,
          kind: kind,
          doseUnits: dose,
          administeredAt: _administeredAt,
          note: _noteController.text,
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      if (!mounted) return;

      final message = switch (error.code) {
        'permission-denied' =>
          'Kayıt izni alınamadı. Oturumunuzu ve '
              'Firestore kurallarını kontrol edin.',
        'not-found' =>
          'Bu kayıt artık bulunamıyor. Kayıtlar ekranına geri dönün.',
        _ => 'Kayıt tamamlanamadı. Bağlantınızı kontrol edip tekrar deneyin.',
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

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(
            _isEditing ? 'İnsülin kaydını düzenle' : 'İnsülin uygulaması ekle',
          ),
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
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.lavender,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Yalnızca yaptığınız enjeksiyonu kaydedin. '
                            'Bu ekran doz hesaplamaz ve '
                            'planlanan uygulama oluşturmaz.',
                            style: TextStyle(height: 1.5),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'İnsülin seçin',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Hızlı etkili (Bolus)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _insulinOption(
                                    'Novorapid',
                                    InsulinKind.bolus,
                                  ),
                                  _insulinOption('Humalog', InsulinKind.bolus),
                                  _insulinOption('Fiasp', InsulinKind.bolus),
                                  _insulinOption('Apidra', InsulinKind.bolus),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Uzun etkili (Bazal)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _insulinOption('Lantus', InsulinKind.basal),
                                  _insulinOption('Toujeo', InsulinKind.basal),
                                  _insulinOption('Tresiba', InsulinKind.basal),
                                  _insulinOption('Levemir', InsulinKind.basal),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Listede yoksa adını ve türünü '
                                'aşağıdan girebilirsiniz.',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _nameController,
                                maxLength: 100,
                                textInputAction: TextInputAction.next,
                                onChanged: (_) {
                                  setState(() {});
                                },
                                decoration: const InputDecoration(
                                  labelText: 'İnsülin adı',
                                  hintText: 'Kullandığınız insülinin adı',
                                  prefixIcon: Icon(Icons.medication_outlined),
                                ),
                                validator: (value) {
                                  final name = value?.trim() ?? '';

                                  if (name.isEmpty) {
                                    return 'İnsülin adını girin.';
                                  }

                                  if (name.length > 100) {
                                    return 'En fazla 100 karakter girin.';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<InsulinKind>(
                                key: ValueKey(_kind),
                                initialValue: _kind,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'İnsülin türü',
                                ),
                                items: InsulinKind.values.map((kind) {
                                  return DropdownMenuItem<InsulinKind>(
                                    value: kind,
                                    child: Text(_kindLabel(kind)),
                                  );
                                }).toList(),
                                onChanged: (kind) {
                                  setState(() => _kind = kind);
                                },
                                validator: (kind) {
                                  return kind == null
                                      ? 'İnsülin türünü seçin.'
                                      : null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _doseController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Uygulanan miktar',
                            suffixText: 'ünite',
                          ),
                          validator: (text) {
                            final value = _parseDose(text ?? '');

                            if (value == null ||
                                !value.isFinite ||
                                value <= 0) {
                              return 'Sıfırdan büyük bir miktar girin.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Gerçek uygulama zamanı',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
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
                              setState(() {
                                _administeredAt = DateTime.now();
                              });
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
                          ),
                          validator: (text) {
                            if ((text?.trim().length ?? 0) > 1000) {
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
                                : 'Yapılan uygulamayı kaydet',
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
