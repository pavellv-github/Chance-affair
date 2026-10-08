# device_calendar: R8 ломает retrieveCalendars() без этого правила.
-keep class com.builttoroam.devicecalendar.** { *; }
# flutter_local_notifications: сериализация запланированных уведомлений через Gson.
-keep class com.dexterous.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
