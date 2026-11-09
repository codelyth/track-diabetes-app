import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/hba1c_repository.dart';

class AddHba1cScreen extends StatefulWidget {
  const AddHba1cScreen({super.key, required this.userId});

  final String userId;

  @override
  State<AddHba1cScreen> createState() => _AddHba1cScreenState();
}

class _AddHba1cScreenState extends State<AddHba1cScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _noteController = TextEditingController();

  late final Hba1cRepository _repository;

  DateTime _testDate = DateUtils.dateOnly(DateTime.now());
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repository = Hba1cRepository(userId: widget.userId);
  }

  @override
  void dispose() {
    _valueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double? _parseValue(String text) {
    return double.tryParse(text.trim().replaceAll(',', '.'));
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String get _dateLabel {
    return '${_two(_testDate.day)}.'
        '${_two(_testDate.month)}.${_testDate.year}';
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _testDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Tahlil tarihini seçin',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );

    if (selected == null || !mounted) return;

    setState(() => _testDate = selected);
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

    setState(() => _isSaving = true);

    try {
      await _repository.addResult(
        valuePercent: _parseValue(_valueController.text)!,
        testDate: _testDate,
        note: _noteController.text,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      if (!mounted) return;

      _showMessage(
        error.code == 'permission-denied'
            ? 'Kayıt izni alınamadı. Firestore kurallarını kontrol edin.'
            : 'Sonuç kaydedilemedi. Bağlantınızı kontrol edip tekrar deneyin.',
      );
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
          title: const Text('HbA1c sonucu ekle'),
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
                            'Laboratuvar raporunuzdaki HbA1c sonucunu '
                            'yüzde (%) olarak girin. Bu değer şeker '
                            'ölçümlerinden hesaplanmaz.',
                            style: TextStyle(height: 1.5),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'HbA1c sonucu',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _valueController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Örn. 6,8',
                            suffixText: '%',
                          ),
                          validator: (text) {
                            final value = _parseValue(text ?? '');

                            if (value == null ||
                                !value.isFinite ||
                                value <= 0 ||
                                value > 100) {
                              return '0 ile 100 arasında, sıfırdan büyük '
                                  'bir yüzde girin.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Tahlil tarihi',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(_dateLabel),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _noteController,
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 1000,
                          decoration: const InputDecoration(
                            labelText: 'Not (isteğe bağlı)',
                            alignLabelWithHint: true,
                            hintText: 'Sonuçla ilgili bir not ekleyin',
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
                            _isSaving ? 'Kaydediliyor...' : 'Sonucu kaydet',
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
