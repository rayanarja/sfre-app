import '../../../../core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';

/// شاشة عرض خطط الاشتراك — للمعاينة فقط
/// الشراء حصرياً من نقاط البيع
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final api = ApiClient();
      final response = await api.dio.get('/subscription-plans');
      setState(() {
        _plans = List<Map<String, dynamic>>.from(response.data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  IconData _getPlanIcon(String name) {
    if (name.contains('عائلي')) return Icons.family_restroom_outlined;
    if (name.contains('متقدم')) return Icons.workspace_premium_outlined;
    if (name.contains('قياسي')) return Icons.bolt_outlined;
    return Icons.rocket_launch_outlined;
  }

  Color _getPlanColor(int index) {
    const colors = [Color(0xFFF57C00), Color(0xFF1976D2), Color(0xFF388E3C), Color(0xFF7B1FA2)];
    return colors[index % colors.length];
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0 ل.س';
    final n = (price is int) ? price : (price as double).toInt();
    final str = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return '${buf.toString()} ل.س';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.current.tr('sub_plans')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // معلومة مهمة
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00897B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF00897B).withOpacity(0.3)),
                    ),
                    child: Row(textDirection: TextDirection.rtl, children: [
                      const Icon(Icons.info_outline, color: Color(0xFF00897B)),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'الاشتراك يتم حصرياً من نقاط البيع المعتمدة.\nتوجه لأقرب نقطة بيع لتفعيل اشتراكك.',
                          style: TextStyle(color: Color(0xFF00897B), fontSize: 13, height: 1.5),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ]),
                  ),

                  // الخطط
                  ..._plans.asMap().entries.map((entry) {
                    final plan = entry.value;
                    final index = entry.key;
                    final color = _getPlanColor(index);
                    final isFamily = (plan['max_users'] ?? 1) > 1;

                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Row(textDirection: TextDirection.rtl, children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Icon(_getPlanIcon(plan['name'] ?? ''), color: color, size: 26),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Row(textDirection: TextDirection.rtl, children: [
                              Text(plan['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                              if (isFamily) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.group, size: 12, color: color),
                                    const SizedBox(width: 4),
                                    Text('${plan['max_users']} حسابات', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ]),
                                ),
                              ],
                            ]),
                            const SizedBox(height: 4),
                            Text('${plan['trip_limit']} رحلة / ${plan['duration_days'] ?? 30} يوم', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            if (plan['description'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(plan['description'], style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
                              ),
                          ]),
                        ),
                        Text(_formatPrice(plan['price']), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
                      ]),
                    );
                  }),

                  const SizedBox(height: 20),

                  // زر نقاط البيع
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        }
                        context.push('/pos-map');
                      },
                      icon: Icon(Icons.store, size: 20),
                      label: Text(AppLocalizations.current.tr('nearest_pos'), style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
