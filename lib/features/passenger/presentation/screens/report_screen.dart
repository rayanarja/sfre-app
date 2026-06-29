import '../../../../core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/models/user_model.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String _selectedType = 'complaint';
  String? _selectedBusId;
  List<Map<String, dynamic>> _buses = [];
  bool _isLoading = false;
  bool _loadingBuses = true;

  final List<Map<String, dynamic>> _reportTypes = [
    {'type': 'complaint', 'title': 'شكوى', 'icon': Icons.report_problem_outlined, 'color': Color(0xFFD32F2F)},
    {'type': 'suggestion', 'title': 'اقتراح', 'icon': Icons.lightbulb_outline, 'color': Color(0xFF1976D2)},
    {'type': 'incident', 'title': 'حادثة', 'icon': Icons.warning_amber_outlined, 'color': Color(0xFFF57C00)},
  ];

  @override
  void initState() {
    super.initState();
    _loadBuses();
  }

  Future<void> _loadBuses() async {
    try {
      final api = ApiClient();
      final response = await api.dio.get('/buses');
      setState(() {
        _buses = List<Map<String, dynamic>>.from(response.data);
        _loadingBuses = false;
      });
    } catch (e) {
      setState(() => _loadingBuses = false);
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBusId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.current.tr('please_select_bus')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_data');
      final user = UserModel.fromJson(jsonDecode(userJson!));

      final api = ApiClient();
      await api.dio.post(
        '/reports',
        data: {
          'user_id': user.id,
          'bus_id': int.parse(_selectedBusId!),
          'type': _selectedType,
          'description': _descriptionController.text.trim(),
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم إرسال تقريرك بنجاح!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      context.pop();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.current.tr('error')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppLocalizations.current.tr('report_problem')),
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'نوع التقرير',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: null,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: _reportTypes.map((type) {
                  final isSelected = _selectedType == type['type'];
                  final color = type['color'] as Color;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedType = type['type']),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? color : const Color(0xFFE5E7EB),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(type['icon'] as IconData, color: color, size: 24),
                            const SizedBox(height: 4),
                            Text(
                              type['title'],
                              style: TextStyle(
                                color: isSelected ? color : AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              const Text(
                'اختر الباص *',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: null,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 8),

              _loadingBuses
                  ? Center(child: CircularProgressIndicator())
                  : Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: Text(AppLocalizations.current.tr('select_bus')),
                          value: _selectedBusId,
                          items: _buses.map((bus) {
                            return DropdownMenuItem<String>(
                              value: bus['bus_id'].toString(),
                              child: Text(
                                'باص ${bus['plate_number']}',
                                textDirection: TextDirection.rtl,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => _selectedBusId = value),
                        ),
                      ),
                    ),

              const SizedBox(height: 20),

              const Text(
                'وصف المشكلة *',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: null,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 8),

              TextFormField(
                controller: _descriptionController,
                textDirection: TextDirection.rtl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: AppLocalizations.current.tr('describe_problem'),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء كتابة وصف للمشكلة';
                  }
                  if (value.length < 10) {
                    return 'الوصف يجب أن يكون 10 أحرف على الأقل';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isLoading ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Theme.of(context).cardColor,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(AppLocalizations.current.tr('send_report')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}