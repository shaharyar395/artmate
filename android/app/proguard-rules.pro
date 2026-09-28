# AdMob starts WorkManager before Flutter. Room loads WorkDatabase_Impl with
# Class.newInstance(), and R8 was dropping that constructor, so the app died
# on launch with "Failed to create an instance of androidx.work.impl.WorkDatabase".
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}
-keep class androidx.work.impl.** { *; }
-keep class androidx.work.WorkManagerInitializer { *; }
