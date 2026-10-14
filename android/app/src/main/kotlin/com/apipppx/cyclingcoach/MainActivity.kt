package com.apipppx.cyclingcoach

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Kanal notifikasi HARUS ada sebelum foreground service start (Android 8+).
        // Plugin flutter_background_service tidak membuatkan kanal kustom
        // (hanya kanal default). Tanpa ini startForeground melempar
        // "Bad notification for startForeground" → force close saat Mulai Rekam.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = getSystemService(NotificationManager::class.java)
            if (mgr.getNotificationChannel("cycling_track") == null) {
                mgr.createNotificationChannel(
                    NotificationChannel(
                        "cycling_track",
                        "Perekaman GPS",
                        NotificationManager.IMPORTANCE_LOW,
                    ).apply {
                        description = "Notifikasi perekaman rute sepeda"
                    },
                )
            }
        }
    }
}
