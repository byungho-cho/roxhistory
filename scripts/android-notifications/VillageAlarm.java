package com.roxhistory.notifications;

import android.Manifest;
import android.app.Activity;
import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import org.json.JSONException;
import org.json.JSONObject;
import java.util.Iterator;

public final class VillageAlarm extends BroadcastReceiver {
    private static final String CHANNEL = "village_events";
    private static final String PREFS = "roxhistory_village_alarms";
    private static final int FLAGS = PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE;
    private static final long RETENTION_MS = 7L * 24 * 60 * 60 * 1000;

    public static void requestPermission(Activity activity) {
        activity.runOnUiThread(() -> {
            if (Build.VERSION.SDK_INT >= 33 &&
                    activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                            != PackageManager.PERMISSION_GRANTED &&
                    !prefs(activity).getBoolean("permissionAsked", false)) {
                prefs(activity).edit().putBoolean("permissionAsked", true).apply();
                activity.requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 1870);
            }
        });
    }

    private static SharedPreferences prefs(Context context) {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    private static JSONObject parse(String text) {
        try { return new JSONObject(text); }
        catch (JSONException ex) { return new JSONObject(); }
    }

    private static PendingIntent alarm(Context context, String id) {
        Intent intent = new Intent(context, VillageAlarm.class);
        intent.setData(new Uri.Builder().scheme("roxhistory-alarm").authority("village")
                .appendPath(id).build());
        return PendingIntent.getBroadcast(context, 0, intent, FLAGS);
    }

    public static synchronized void synchronize(Activity activity, String encoded) {
        replaceSchedule(activity.getApplicationContext(), encoded);
    }

    private static void replaceSchedule(Context context, String encoded) {
        SharedPreferences settings = prefs(context);
        JSONObject previous = parse(settings.getString("scheduled", "{}"));
        JSONObject next = parse(encoded);
        AlarmManager alarms = context.getSystemService(AlarmManager.class);
        long now = System.currentTimeMillis();
        SharedPreferences.Editor changes = settings.edit().putString("scheduled", encoded);
        for (String key : settings.getAll().keySet()) {
            if (key.startsWith("delivered:") && settings.getLong(key, 0) < now - RETENTION_MS) {
                changes.remove(key);
            }
        }
        changes.commit();
        Iterator<String> oldKeys = previous.keys();
        while (oldKeys.hasNext()) {
            String id = oldKeys.next();
            if (!next.has(id)) alarms.cancel(alarm(context, id));
        }
        Iterator<String> keys = next.keys();
        while (keys.hasNext()) {
            String id = keys.next();
            if (settings.contains("delivered:" + id)) continue;
            JSONObject job = next.optJSONObject(id);
            if (job != null) alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,
                    Math.max(now, job.optLong("at")), alarm(context, id));
        }
    }

    public static synchronized void completed(Activity activity, String id, String title, String body) {
        deliver(activity.getApplicationContext(), id, title, body);
    }

    private static synchronized void deliver(Context context, String id, String title, String body) {
        SharedPreferences settings = prefs(context);
        String receipt = "delivered:" + id;
        if (settings.contains(receipt)) return;
        NotificationManager notifications = context.getSystemService(NotificationManager.class);
        if (Build.VERSION.SDK_INT >= 26) {
            notifications.createNotificationChannel(new NotificationChannel(
                    CHANNEL, "마을 소식", NotificationManager.IMPORTANCE_DEFAULT));
        }
        if (!notifications.areNotificationsEnabled()) return;
        Notification.Builder builder = Build.VERSION.SDK_INT >= 26
                ? new Notification.Builder(context, CHANNEL) : new Notification.Builder(context);
        Intent launch = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        if (launch != null) builder.setContentIntent(PendingIntent.getActivity(context, 0, launch, FLAGS));
        builder.setSmallIcon(android.R.drawable.ic_dialog_info).setContentTitle(title)
                .setContentText(body).setAutoCancel(true);
        try {
            notifications.notify(id, 0, builder.build());
            settings.edit().putLong(receipt, System.currentTimeMillis()).commit();
        } catch (SecurityException ignored) {
            // OS permission can change between the permission check and posting.
        }
    }

    @Override public void onReceive(Context context, Intent intent) {
        synchronized (VillageAlarm.class) {
            if (Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction()) ||
                    Intent.ACTION_TIME_CHANGED.equals(intent.getAction())) {
                replaceSchedule(context, prefs(context).getString("scheduled", "{}"));
                return;
            }
            Uri data = intent.getData();
            if (data == null) return;
            String id = data.getLastPathSegment();
            JSONObject job = parse(prefs(context).getString("scheduled", "{}")).optJSONObject(id);
            if (job != null && System.currentTimeMillis() >= job.optLong("at")) {
                deliver(context, id, job.optString("title"), job.optString("body"));
            }
        }
    }
}
