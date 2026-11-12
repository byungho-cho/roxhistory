package com.roxhistory.notifications;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.content.pm.PackageInstaller;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import org.json.JSONObject;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URL;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.Locale;
import javax.net.ssl.HttpsURLConnection;

public final class GameApkUpdate extends BroadcastReceiver {
    private static final String PACKAGE = "com.roxhistory.demo";
    private static final String ACTION = PACKAGE + ".APK_INSTALL_RESULT";
    private static final String ROOT = "https://github.com/byungho-cho/roxhistory/releases/download/";
    private static final long MAX_BYTES = 800_000_000L;
    private static volatile String state = "idle";
    private static volatile long received;
    private static volatile boolean cancelled;
    private static File verified;
    private static String verifiedHash;
    private static long verifiedCode;
    private static String verifiedName;
    private static long verifiedSize;
    private static volatile HttpsURLConnection connection;

    private static SharedPreferences prefs(Context context) {
        return context.getSharedPreferences("roxhistory_apk_update", Context.MODE_PRIVATE);
    }

    private static long code(PackageInfo info) {
        return Build.VERSION.SDK_INT >= 28 ? info.getLongVersionCode() : info.versionCode;
    }

    private static int signingFlags() {
        return Build.VERSION.SDK_INT >= 28 ? PackageManager.GET_SIGNING_CERTIFICATES : PackageManager.GET_SIGNATURES;
    }

    private static Signature[] signers(PackageInfo info) {
        return Build.VERSION.SDK_INT >= 28
                ? info.signingInfo.getApkContentsSigners() : info.signatures;
    }

    private static String hex(byte[] bytes) {
        StringBuilder output = new StringBuilder(bytes.length * 2);
        for (byte value : bytes) output.append(String.format(Locale.ROOT, "%02x", value & 255));
        return output.toString();
    }

    private static File directory(Context context) {
        return new File(context.getFilesDir(), "apk-updates");
    }

    public static String installed(Activity activity) {
        JSONObject result = new JSONObject();
        try {
            PackageInfo info = activity.getPackageManager().getPackageInfo(activity.getPackageName(), signingFlags());
            Signature[] certificates = signers(info);
            result.put("package", info.packageName);
            result.put("code", code(info));
            result.put("version", info.versionName);
            result.put("sdk", Build.VERSION.SDK_INT);
            result.put("abis", new org.json.JSONArray(Arrays.asList(Build.SUPPORTED_ABIS)));
            if (certificates != null && certificates.length == 1) {
                result.put("signer", hex(MessageDigest.getInstance("SHA-256").digest(certificates[0].toByteArray())));
            }
            SharedPreferences store = prefs(activity);
            long pending = store.getLong("pending_code", 0);
            if (pending > 0 && code(info) >= pending) {
                store.edit().clear().apply();
                new File(directory(activity), "verified.apk").delete();
                state = "installed";
            } else if (pending > 0 && "idle".equals(state)) {
                int sessionId = store.getInt("session", -1);
                state = activity.getPackageManager().getPackageInstaller().getSessionInfo(sessionId) == null
                        ? "install_interrupted" : "install_pending";
                if ("install_interrupted".equals(state)) store.edit().clear().apply();
            } else if ("idle".equals(state)) {
                new File(directory(activity), "incoming.part").delete();
                new File(directory(activity), "verified.apk").delete();
            }
        } catch (Exception ignored) { return "{}"; }
        return result.toString();
    }

    public static boolean acceptCode(Activity activity, long candidate) {
        SharedPreferences channel = activity.getSharedPreferences("roxhistory_apk_channel", Context.MODE_PRIVATE);
        long highest = channel.getLong("highest_code", 0);
        if (candidate < highest) return false;
        if (candidate > highest) channel.edit().putLong("highest_code", candidate).apply();
        return true;
    }

    public static String snapshot() {
        return state + ":" + received;
    }

    public static boolean allowed(Activity activity) {
        return Build.VERSION.SDK_INT < 26 || activity.getPackageManager().canRequestPackageInstalls();
    }

    public static void openPermission(Activity activity) {
        if (Build.VERSION.SDK_INT >= 26) activity.runOnUiThread(() -> {
            try {
                activity.startActivity(new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:" + activity.getPackageName())));
            } catch (RuntimeException ignored) { state = "permission_failed"; }
        });
    }

    public static synchronized boolean download(Activity activity, String version, long targetCode,
            long size, String hash) {
        if ("downloading".equals(state) || "verifying".equals(state) || "install_pending".equals(state)) return false;
        if (!version.matches("[0-9]{1,4}\\.[0-9]{1,4}\\.[0-9]{1,4}") ||
                !hash.matches("[a-f0-9]{64}") || size <= 0 || size > MAX_BYTES || targetCode <= 0) return false;
        Context context = activity.getApplicationContext();
        File directory = directory(context);
        if ((!directory.isDirectory() && !directory.mkdirs()) || directory.getUsableSpace() < size * 2 + 32_000_000L) {
            state = "space";
            return false;
        }
        verified = null;
        cancelled = false;
        received = 0;
        state = "downloading";
        new Thread(() -> receive(context, directory, version, targetCode, size, hash), "RoxApkDownload").start();
        return true;
    }

    private static void receive(Context context, File directory, String version, long targetCode, long size, String hash) {
        File part = new File(directory, "incoming.part");
        File finalFile = new File(directory, "verified.apk");
        HttpsURLConnection active = null;
        String terminal = "download_failed";
        try {
            URL url = new URL(ROOT + "v" + version + "/Roxhistory_" + version + ".apk");
            for (int redirects = 0; ; redirects++) {
                active = (HttpsURLConnection) url.openConnection();
                connection = active;
                if (cancelled) throw new IllegalStateException();
                connection.setConnectTimeout(15000);
                connection.setReadTimeout(30000);
                connection.setInstanceFollowRedirects(false);
                connection.setRequestProperty("Accept-Encoding", "identity");
                int status = connection.getResponseCode();
                if (status == 200) break;
                if (status < 300 || status >= 400 || redirects >= 4) throw new IllegalStateException();
                URL next = new URL(url, connection.getHeaderField("Location"));
                String host = next.getHost();
                if (!"https".equals(next.getProtocol()) || next.getUserInfo() != null ||
                        (next.getPort() != -1 && next.getPort() != 443) ||
                        !("release-assets.githubusercontent.com".equals(host) || "objects.githubusercontent.com".equals(host))) {
                    throw new IllegalStateException();
                }
                connection.disconnect();
                url = next;
            }
            long deadline = android.os.SystemClock.elapsedRealtime() + 30 * 60 * 1000L;
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            try (InputStream input = connection.getInputStream(); FileOutputStream output = new FileOutputStream(part)) {
                byte[] buffer = new byte[128 * 1024];
                for (int count; (count = input.read(buffer)) != -1;) {
                    if (cancelled || android.os.SystemClock.elapsedRealtime() > deadline || received + count > size) {
                        throw new IllegalStateException();
                    }
                    output.write(buffer, 0, count);
                    digest.update(buffer, 0, count);
                    received += count;
                }
                output.getFD().sync();
            }
            if (cancelled) throw new IllegalStateException();
            state = "verifying";
            if (received != size || !hex(digest.digest()).equals(hash) ||
                    !matchesPackage(context, part, targetCode, version)) throw new SecurityException();
            if (finalFile.exists() && !finalFile.delete()) throw new IllegalStateException();
            if (cancelled || !part.renameTo(finalFile)) throw new IllegalStateException();
            verified = finalFile;
            verifiedHash = hash;
            verifiedCode = targetCode;
            verifiedName = version;
            verifiedSize = size;
            terminal = "ready";
        } catch (Exception ignored) {
            part.delete();
            terminal = cancelled ? "cancelled" : "download_failed";
        } finally {
            if (active != null) active.disconnect();
            connection = null;
            state = terminal;
        }
    }

    private static boolean matchesPackage(Context context, File file, long targetCode, String version) throws Exception {
        PackageManager manager = context.getPackageManager();
        PackageInfo installed = manager.getPackageInfo(PACKAGE, signingFlags());
        PackageInfo archive = manager.getPackageArchiveInfo(file.getAbsolutePath(), signingFlags());
        if (archive == null || !PACKAGE.equals(archive.packageName) || code(archive) != targetCode ||
                targetCode <= code(installed) || !version.equals(archive.versionName) ||
                archive.applicationInfo.minSdkVersion > Build.VERSION.SDK_INT) return false;
        boolean supported = false;
        try (java.util.zip.ZipFile apk = new java.util.zip.ZipFile(file)) {
            for (String abi : Build.SUPPORTED_ABIS) {
                if (apk.getEntry("lib/" + abi + "/libgodot_android.so") != null) supported = true;
            }
        }
        if (!supported) return false;
        Signature[] current = signers(installed);
        Signature[] next = signers(archive);
        return current != null && next != null && current.length == 1 && Arrays.equals(current, next);
    }

    public static void cancel() {
        if ("downloading".equals(state) || "verifying".equals(state)) {
            cancelled = true;
            HttpsURLConnection active = connection;
            if (active != null) new Thread(active::disconnect, "RoxApkCancel").start();
        }
    }

    public static synchronized boolean install(Activity activity) {
        if (verified == null || !verified.isFile() || !allowed(activity) ||
                !("ready".equals(state) || "install_failed".equals(state) || "install_cancelled".equals(state))) return false;
        state = "install_pending";
        Context context = activity.getApplicationContext();
        new Thread(() -> commitInstall(context), "RoxApkInstall").start();
        return true;
    }

    private static void commitInstall(Context context) {
        PackageInstaller installer = context.getPackageManager().getPackageInstaller();
        int id = -1;
        try {
            if (verified.length() != verifiedSize || !matchesPackage(context, verified, verifiedCode, verifiedName)) {
                throw new SecurityException();
            }
            PackageInstaller.SessionParams params = new PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL);
            params.setAppPackageName(PACKAGE);
            params.setSize(verifiedSize);
            if (Build.VERSION.SDK_INT >= 31) params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_REQUIRED);
            id = installer.createSession(params);
            try (PackageInstaller.Session session = installer.openSession(id);
                 InputStream input = new FileInputStream(verified);
                 OutputStream output = session.openWrite("base.apk", 0, verifiedSize)) {
                MessageDigest digest = MessageDigest.getInstance("SHA-256");
                byte[] bytes = new byte[128 * 1024];
                for (int count; (count = input.read(bytes)) != -1;) {
                    digest.update(bytes, 0, count);
                    output.write(bytes, 0, count);
                }
                if (!verifiedHash.equals(hex(digest.digest()))) throw new SecurityException();
                session.fsync(output);
                output.close();
                if (!prefs(context).edit().putLong("pending_code", verifiedCode).putInt("session", id).commit()) {
                    throw new IllegalStateException();
                }
                Intent callback = new Intent(context, GameApkUpdate.class).setAction(ACTION).putExtra("rox_session", id);
                int flags = PendingIntent.FLAG_UPDATE_CURRENT;
                if (Build.VERSION.SDK_INT >= 31) flags |= PendingIntent.FLAG_MUTABLE;
                session.commit(PendingIntent.getBroadcast(context, id, callback, flags).getIntentSender());
            }
        } catch (Exception ignored) {
            if (id >= 0) try { installer.abandonSession(id); } catch (Exception ignoredAgain) { }
            prefs(context).edit().clear().apply();
            state = "install_failed";
        }
    }

    @Override public void onReceive(Context context, Intent intent) {
        if (!ACTION.equals(intent.getAction()) ||
                intent.getIntExtra("rox_session", -1) != prefs(context).getInt("session", -2)) return;
        int status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE);
        if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            Intent confirmation = intent.getParcelableExtra(Intent.EXTRA_INTENT);
            try {
                if (confirmation == null) throw new IllegalStateException();
                context.startActivity(confirmation.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            } catch (RuntimeException ignored) {
                prefs(context).edit().clear().apply();
                state = "install_failed";
            }
        } else if (status != PackageInstaller.STATUS_SUCCESS) {
            prefs(context).edit().clear().apply();
            state = status == PackageInstaller.STATUS_FAILURE_ABORTED ? "install_cancelled" : "install_failed";
        }
    }
}
