# Menyesuaikan project Android hasil `flutter create`:
# nama app, izin, queries (TTS/STT), FlutterFragmentActivity + tema AppCompat (fingerprint),
# minSdk 24 (ffmpeg/ML Kit), dan widget layar utama (lewati dengan NO_WIDGET=1).
import glob, os, re, sys

android = sys.argv[1]
manifest = os.path.join(android, 'app/src/main/AndroidManifest.xml')
no_widget = os.environ.get('NO_WIDGET', '1') == '1'
t = open(manifest).read()

# --- manifest ---
t = re.sub(r'android:label="[^"]*"', 'android:label="Nexvora"', t, count=1)
lines = ''
for x in ['INTERNET', 'READ_MEDIA_IMAGES', 'READ_MEDIA_VIDEO', 'READ_MEDIA_AUDIO']:
    if 'android.permission.' + x not in t:
        lines += '    <uses-permission android:name="android.permission.%s"/>\n' % x
if 'READ_EXTERNAL_STORAGE' not in t:
    lines += '    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>\n'
if 'WRITE_EXTERNAL_STORAGE' not in t:
    lines += '    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>\n'
q = ('<intent><action android:name="android.intent.action.TTS_SERVICE"/></intent>\n'
     '        <intent><action android:name="android.speech.RecognitionService"/></intent>\n'
     '        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>\n')
if '<queries>' in t:
    t = t.replace('<queries>', '<queries>\n        ' + q, 1)
else:
    lines += '    <queries>\n        ' + q + '    </queries>\n'
t = t.replace('<application', lines + '    <application', 1)
if 'usesCleartextTraffic' not in t:
    t = t.replace('<application', '<application android:usesCleartextTraffic="true"', 1)
RECEIVER = """    <receiver android:name=".NexvoraWidgetProvider" android:exported="true">
            <intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE"/></intent-filter>
            <meta-data android:name="android.appwidget.provider" android:resource="@xml/nexvora_widget_info"/>
        </receiver>
    </application>"""
if not no_widget and 'NexvoraWidgetProvider' not in t:
    t = t.replace('</application>', RECEIVER, 1)
open(manifest, 'w').write(t)

# --- MainActivity -> FlutterFragmentActivity ---
pkg_dir, pkg = None, None
for f in glob.glob(os.path.join(android, 'app/src/main/**/MainActivity.*'), recursive=True):
    s = open(f).read()
    open(f, 'w').write(s.replace('FlutterActivity', 'FlutterFragmentActivity'))
    pkg_dir = os.path.dirname(f)
    m = re.search(r'package\s+([\w.]+)', s)
    pkg = m.group(1) if m else None

# --- tema AppCompat untuk BiometricPrompt ---
for f in glob.glob(os.path.join(android, 'app/src/main/res/values*/styles.xml')):
    s = open(f).read()
    s = s.replace('@android:style/Theme.Light.NoTitleBar', 'Theme.AppCompat.Light.NoActionBar').replace('@android:style/Theme.Black.NoTitleBar', 'Theme.AppCompat.NoActionBar')
    open(f, 'w').write(s)

# --- minSdk 24 ---
for f in glob.glob(os.path.join(android, 'app/build.gradle*')):
    s = open(f).read()
    open(f, 'w').write(re.sub(r'flutter\.minSdkVersion', '24', s))

# --- compileSdk 36 (library baru butuh compileSdk >= 36) ---
def _bump(m):
    v = m.group(2)
    if v.isdigit() and int(v) >= 36:
        return m.group(0)
    return m.group(1) + '36'
for f in glob.glob(os.path.join(android, 'app/build.gradle*')):
    s = open(f).read()
    s = re.sub(r'(compileSdk(?:Version)?\s*=?\s*)(flutter\.compileSdkVersion|\d+)', _bump, s)
    open(f, 'w').write(s)

# --- widget layar utama ---
KOTLIN = """package PKG

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class NexvoraWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.nexvora_widget).apply {
                setTextViewText(R.id.w_title, widgetData.getString("w_title", "Nexvora") ?: "Nexvora")
                setTextViewText(R.id.w_text, widgetData.getString("w_text", "Buka app untuk memuat data") ?: "")
                val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: Intent()
                val pi = PendingIntent.getActivity(context, 0, launch, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
                setOnClickPendingIntent(R.id.w_root, pi)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
"""
LAYOUT = """<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/w_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="14dp"
    android:background="@drawable/nexvora_widget_bg">
    <TextView
        android:id="@+id/w_title"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:textColor="#EDEDF4"
        android:textSize="16sp"
        android:textStyle="bold"
        android:text="Nexvora" />
    <TextView
        android:id="@+id/w_text"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="6dp"
        android:textColor="#A0A0AC"
        android:textSize="13sp"
        android:maxLines="3"
        android:text="Buka app untuk memuat data" />
    <TextView
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:gravity="end"
        android:textColor="#80808C"
        android:textSize="10sp"
        android:text="by manz" />
</LinearLayout>
"""
BG = """<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <gradient android:angle="315" android:startColor="#2E2E33" android:centerColor="#151517" android:endColor="#050506" />
    <corners android:radius="18dp" />
</shape>
"""
INFO = """<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="250dp"
    android:minHeight="110dp"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/nexvora_widget"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen" />
"""
if not no_widget and pkg_dir and pkg:
    res = os.path.join(android, 'app/src/main/res')
    for d in ['layout', 'drawable', 'xml']:
        os.makedirs(os.path.join(res, d), exist_ok=True)
    open(os.path.join(pkg_dir, 'NexvoraWidgetProvider.kt'), 'w').write(KOTLIN.replace('PKG', pkg))
    open(os.path.join(res, 'layout/nexvora_widget.xml'), 'w').write(LAYOUT)
    open(os.path.join(res, 'drawable/nexvora_widget_bg.xml'), 'w').write(BG)
    open(os.path.join(res, 'xml/nexvora_widget_info.xml'), 'w').write(INFO)
print('android dipatch', '(tanpa widget)' if no_widget else '(dengan widget)')
