package com.roxhistory.notifications;

import android.Manifest;
import android.app.Activity;
import android.app.Application;
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
import android.os.Bundle;
import android.os.Debug;
import android.os.PowerManager;
import org.json.JSONException;
import org.json.JSONObject;
import java.util.Iterator;

public final class VillageAlarm extends BroadcastReceiver {
    private static final String CHANNEL = "village_events";
    private static final String PREFS = "roxhistory_village_alarms";
    private static final int FLAGS = PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE;
    private static final long RETENTION_MS = 7L * 24 * 60 * 60 * 1000;
    private static boolean foreground;
    private static Activity observedActivity;

    public static synchronized void observeActivity(Activity activity) {
        foreground = true;
        if (observedActivity == activity) return;
        observedActivity = activity;
        activity.getApplication().registerActivityLifecycleCallbacks(new Application.ActivityLifecycleCallbacks() {
            @Override public void onActivityStarted(Activity current) {
                if (current == activity) setForeground(current, true);
            }
            @Override public void onActivityStopped(Activity current) {
                if (current == activity) setForeground(current, false);
            }
            @Override public void onActivityDestroyed(Activity current) {
                if (current != activity) return;
                setForeground(current, false);
                current.getApplication().unregisterActivityLifecycleCallbacks(this);
                synchronized (VillageAlarm.class) {
                    if (observedActivity == current) observedActivity = null;
                }
            }
            @Override public void onActivityCreated(Activity current, Bundle state) {}
            @Override public void onActivityResumed(Activity current) {}
            @Override public void onActivityPaused(Activity current) {}
            @Override public void onActivitySaveInstanceState(Activity current, Bundle state) {}
        });
    }

    private static synchronized void setForeground(Activity activity, boolean visible) {
        if (activity != observedActivity || foreground == visible) return;
        if (!visible) {
            // A delayed system alarm may still be queued for an event that fell due on screen.
            Context context = activity.getApplicationContext();
            SharedPreferences settings = prefs(context);
            JSONObject scheduled = parse(settings.getString("scheduled", "{}"));
            SharedPreferences.Editor receipts = settings.edit();
            long now = System.currentTimeMillis();
            Iterator<String> keys = scheduled.keys();
            while (keys.hasNext()) {
                String id = keys.next();
                JSONObject job = scheduled.optJSONObject(id);
                if (job != null && job.optLong("at") <= now) receipts.putLong("delivered:" + id, now);
            }
            receipts.commit();
        }
        foreground = visible;
    }

    public static String diagnosticSample(Activity activity) {
        Debug.MemoryInfo memory = new Debug.MemoryInfo();
        Debug.getMemoryInfo(memory);
        JSONObject sample = new JSONObject();
        try {
            sample.put("process_pss_kib", memory.getTotalPss());
            sample.put("process_cpu_total_ms", android.os.Process.getElapsedCpuTime());
            if (Build.VERSION.SDK_INT >= 29) {
                sample.put("thermal_status", activity.getSystemService(PowerManager.class).getCurrentThermalStatus());
            }
        } catch (JSONException ignored) {}
        return sample.toString();
    }

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
        if (foreground) {
            settings.edit().putLong(receipt, System.currentTimeMillis()).commit();
            return;
        }
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
        int icon = context.getResources().getIdentifier("ic_village_notice", "drawable", context.getPackageName());
        builder.setSmallIcon(icon != 0 ? icon : android.R.drawable.ic_dialog_info).setContentTitle(title)
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
