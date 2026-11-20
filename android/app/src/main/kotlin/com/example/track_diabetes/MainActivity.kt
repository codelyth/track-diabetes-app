package com.example.track_diabetes

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "track_diabetes/notification_actions"

        private const val CONSUMED_EXTRA =
            "com.example.track_diabetes.NOTIFICATION_ACTION_CONSUMED"

        private const val SELECT_NOTIFICATION = "SELECT_NOTIFICATION"
        private const val SELECT_FOREGROUND_NOTIFICATION =
            "SELECT_FOREGROUND_NOTIFICATION"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "consumeNotificationAction" -> {
                    val currentIntent = intent

                    if (currentIntent == null) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    val isNotificationIntent =
                        currentIntent.action == SELECT_NOTIFICATION ||
                            currentIntent.action == SELECT_FOREGROUND_NOTIFICATION

                    if (!isNotificationIntent) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    val expectedId =
                        call.argument<Number>("notificationId")?.toInt()

                    val expectedPayload = call.argument<String>("payload")
                    val expectedActionId =
                        call.argument<String>("actionId").orEmpty()

                    val actualId =
                        currentIntent.getIntExtra("notificationId", 0)

                    val actualPayload =
                        currentIntent.getStringExtra("payload")

                    val actualActionId =
                        currentIntent.getStringExtra("actionId").orEmpty()

                    val matches =
                        (expectedId == null || expectedId == actualId) &&
                            expectedPayload == actualPayload &&
                            expectedActionId == actualActionId

                    if (!matches) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    if (currentIntent.getBooleanExtra(CONSUMED_EXTRA, false)) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    // Android Intent üzerinde tutulur.
                    // Dart hot restart yapılsa da bu bilgi korunur.
                    currentIntent.putExtra(CONSUMED_EXTRA, true)

                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        // Kullanıcının yeni bir bildirim tıklaması yeni bir işlemdir.
        intent.removeExtra(CONSUMED_EXTRA)
        setIntent(intent)

        super.onNewIntent(intent)
    }
}