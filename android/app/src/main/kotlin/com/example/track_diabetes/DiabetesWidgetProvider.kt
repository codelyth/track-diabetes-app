package com.example.track_diabetes

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.time.Duration
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

class DiabetesWidgetProvider : HomeWidgetProvider() {

    private data class PlannedReminder(
        val date: ZonedDateTime,
        val label: String
    )

    private val locale = Locale.forLanguageTag("tr-TR")

    private val timeFormatter =
        DateTimeFormatter.ofPattern("HH:mm", locale)

    private val dateFormatter =
        DateTimeFormatter.ofPattern("dd.MM.yyyy", locale)

    private val shortDateFormatter =
        DateTimeFormatter.ofPattern("dd.MM · HH:mm", locale)

    private val headerFormatter =
        DateTimeFormatter.ofPattern("d MMMM", locale)

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(
                context.packageName,
                R.layout.diabetes_widget
            )

            val zone = ZoneId.systemDefault()
            val now = ZonedDateTime.now(zone)

            setDefaults(views, now)

            try {
                val raw = widgetData.getString(
                    "diabetes_widget_snapshot",
                    null
                )

                if (raw != null) {
                    bindSnapshot(views, JSONObject(raw), now, zone)
                }
            } catch (_: Exception) {
                setDefaults(views, now)

                views.setTextViewText(
                    R.id.widget_footer,
                    "Veriler gösterilemedi. Uygulamayı açın."
                )
            }

            val launchIntent = Intent(
                context,
                MainActivity::class.java
            ).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                widgetId,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                    PendingIntent.FLAG_IMMUTABLE
            )

            views.setOnClickPendingIntent(
                R.id.diabetes_widget_root,
                pendingIntent
            )

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun setDefaults(
        views: RemoteViews,
        now: ZonedDateTime
    ) {
        views.setTextViewText(
            R.id.widget_header_date,
            now.format(headerFormatter)
        )

        views.setTextViewText(R.id.widget_glucose_value, "—")
        views.setTextViewText(R.id.widget_glucose_type, "Giriş yapın")
        views.setTextViewText(R.id.widget_glucose_date, "")

        views.setTextViewText(R.id.widget_average_value, "—")
        views.setTextViewText(R.id.widget_average_count, "Giriş yapın")

        views.setTextViewText(R.id.widget_reminder_time, "—")
        views.setTextViewText(R.id.widget_reminder_type, "Giriş yapın")
        views.setTextViewText(R.id.widget_reminder_date, "")

        views.setTextViewText(
            R.id.widget_footer,
            "Görüntülemek için giriş yapın."
        )
    }

    private fun bindSnapshot(
        views: RemoteViews,
        snapshot: JSONObject,
        now: ZonedDateTime,
        zone: ZoneId
    ) {
        if (!snapshot.optBoolean("signedIn", false)) return

        views.setTextViewText(
            R.id.widget_footer,
            "Son ölçüm henüz yok"
        )

        bindLastReading(views, snapshot, now, zone)
        bindAverage(views, snapshot, now, zone)
        bindReminder(views, snapshot, now, zone)
    }

    private fun bindLastReading(
        views: RemoteViews,
        snapshot: JSONObject,
        now: ZonedDateTime,
        zone: ZoneId
    ) {
        when {
            snapshot.optBoolean("glucoseError") -> {
                views.setTextViewText(
                    R.id.widget_glucose_type,
                    "Veri alınamadı"
                )
                views.setTextViewText(
                    R.id.widget_footer,
                    "Ölçümleri görmek için uygulamayı açın."
                )
            }

            !snapshot.optBoolean("glucoseReady") -> {
                views.setTextViewText(
                    R.id.widget_glucose_type,
                    "Yükleniyor"
                )
                views.setTextViewText(
                    R.id.widget_footer,
                    "Ölçümler yükleniyor"
                )
            }

            else -> {
                val reading = snapshot.optJSONObject("reading")

                if (reading == null) {
                    views.setTextViewText(
                        R.id.widget_glucose_type,
                        "Henüz ölçüm yok"
                    )
                    return
                }

                val measuredAt = Instant.ofEpochMilli(
                    reading.getLong("measuredAtMs")
                ).atZone(zone)

                val label = when (reading.optString("type")) {
                    "fasting" -> "Açlık"
                    "postMeal" -> "Tokluk"
                    else -> "Ölçüm"
                }

                views.setTextViewText(
                    R.id.widget_glucose_value,
                    reading.getInt("valueMgDl").toString()
                )

                views.setTextViewText(
                    R.id.widget_glucose_type,
                    label
                )

                views.setTextViewText(
                    R.id.widget_glucose_date,
                    if (measuredAt.toLocalDate() == now.toLocalDate()) {
                        measuredAt.format(timeFormatter)
                    } else {
                        measuredAt.format(shortDateFormatter)
                    }
                )

                views.setTextViewText(
                    R.id.widget_footer,
                    relativeReadingTime(measuredAt, now)
                )
            }
        }
    }

    private fun bindAverage(
        views: RemoteViews,
        snapshot: JSONObject,
        now: ZonedDateTime,
        zone: ZoneId
    ) {
        if (snapshot.optBoolean("todayError")) {
            views.setTextViewText(
                R.id.widget_average_count,
                "Veri alınamadı"
            )
            return
        }

        if (!snapshot.optBoolean("todayReady")) {
            views.setTextViewText(
                R.id.widget_average_count,
                "Yükleniyor"
            )
            return
        }

        val readings = snapshot.optJSONArray("todayReadings")

        var total = 0.0
        var count = 0

        if (readings != null) {
            for (index in 0 until readings.length()) {
                val reading = readings.getJSONObject(index)

                val measuredAt = Instant.ofEpochMilli(
                    reading.getLong("measuredAtMs")
                ).atZone(zone)

                // Gece yarısından sonra önceki günün ortalamasını
                // bugünün değeri olarak göstermeyiz.
                if (measuredAt.toLocalDate() != now.toLocalDate()) {
                    continue
                }

                val value = reading.getDouble("valueMgDl")

                if (!value.isFinite() || value <= 0.0) continue

                total += value
                count++
            }
        }

        if (count == 0) {
            views.setTextViewText(
                R.id.widget_average_count,
                "Henüz ölçüm yok"
            )
            return
        }

        views.setTextViewText(
            R.id.widget_average_value,
            String.format(locale, "%.1f", total / count)
        )

        views.setTextViewText(
            R.id.widget_average_count,
            "$count ölçüm"
        )
    }

    private fun bindReminder(
        views: RemoteViews,
        snapshot: JSONObject,
        now: ZonedDateTime,
        zone: ZoneId
    ) {
        if (snapshot.optBoolean("reminderError")) {
            views.setTextViewText(
                R.id.widget_reminder_type,
                "Veri alınamadı"
            )
            return
        }

        if (!snapshot.optBoolean("reminderReady")) {
            views.setTextViewText(
                R.id.widget_reminder_type,
                "Yükleniyor"
            )
            return
        }

        val next = findNextReminder(snapshot, now, zone)

        if (next == null) {
            views.setTextViewText(
                R.id.widget_reminder_type,
                "Aktif plan yok"
            )
            return
        }

        views.setTextViewText(
            R.id.widget_reminder_time,
            next.date.format(timeFormatter)
        )

        views.setTextViewText(
            R.id.widget_reminder_type,
            next.label
        )

        val dayLabel = when (next.date.toLocalDate()) {
            now.toLocalDate() -> "Bugün"
            now.toLocalDate().plusDays(1) -> "Yarın"
            else -> next.date.format(dateFormatter)
        }

        views.setTextViewText(
            R.id.widget_reminder_date,
            dayLabel
        )
    }

    private fun relativeReadingTime(
        measuredAt: ZonedDateTime,
        now: ZonedDateTime
    ): String {
        val minutes = Duration.between(measuredAt, now).toMinutes()

        return when {
            minutes < 0 ->
                "Son ölçüm: ${measuredAt.format(shortDateFormatter)}"

            minutes < 1 ->
                "Son ölçüm az önce"

            minutes < 60 ->
                "Son ölçüm $minutes dk önce"

            minutes < 1440 ->
                "Son ölçüm ${minutes / 60} sa önce"

            else ->
                "Son ölçüm: ${measuredAt.format(shortDateFormatter)}"
        }
    }

    private fun findNextReminder(
        snapshot: JSONObject,
        now: ZonedDateTime,
        zone: ZoneId
    ): PlannedReminder? {
        var next: PlannedReminder? = null

        val reminders = snapshot.optJSONArray("reminders")

        if (reminders != null) {
            for (index in 0 until reminders.length()) {
                val reminder = reminders.getJSONObject(index)
                val days = reminder.getJSONArray("weekdays")

                val hour = reminder.getInt("hour")
                val minute = reminder.getInt("minute")
                val label = typeLabel(reminder.getString("type"))

                for (dayIndex in 0 until days.length()) {
                    val weekday = days.getInt(dayIndex)

                    val daysAhead =
                        (weekday - now.dayOfWeek.value + 7) % 7

                    var candidate = now.toLocalDate()
                        .plusDays(daysAhead.toLong())
                        .atTime(LocalTime.of(hour, minute))
                        .atZone(zone)

                    if (!candidate.isAfter(now)) {
                        candidate = candidate.plusWeeks(1)
                    }

                    if (next == null || candidate.isBefore(next.date)) {
                        next = PlannedReminder(candidate, label)
                    }
                }
            }
        }

        val snoozes = snapshot.optJSONArray("snoozes")

        if (snoozes != null) {
            for (index in 0 until snoozes.length()) {
                val snooze = snoozes.getJSONObject(index)

                val date = Instant.ofEpochMilli(
                    snooze.getLong("scheduledAtMs")
                ).atZone(zone)

                if (!date.isAfter(now)) continue

                if (next == null || date.isBefore(next.date)) {
                    next = PlannedReminder(
                        date,
                        "${typeLabel(snooze.getString("type"))} · Ertelenen"
                    )
                }
            }
        }

        return next
    }

    private fun typeLabel(type: String): String {
        return when (type) {
            "fasting" -> "Açlık ölçümü"
            "postMeal" -> "Tokluk ölçümü"
            "insulin" -> "İnsülin"
            else -> "Hatırlatıcı"
        }
    }
}