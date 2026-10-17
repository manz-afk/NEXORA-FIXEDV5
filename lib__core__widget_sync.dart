import 'package:home_widget/home_widget.dart';
import 'api.dart';

Future<void> syncWidget() async {
  try {
    final d = await Api.get('/api/dashboard');
    final news = d['news'] as List;
    await HomeWidget.saveWidgetData<String>('w_title', 'Nexvora • ${d['tools']} fitur');
    await HomeWidget.saveWidgetData<String>('w_text', news.isNotEmpty ? '${news[0]['title']}' : 'Favorit ${d['favorites']} • Riwayat ${d['history']}');
    await HomeWidget.updateWidget(androidName: 'NexvoraWidgetProvider');
  } catch (_) {}
}
