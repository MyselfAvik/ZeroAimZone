#ifndef FIREBASE_CRASHLYTICS_PLUGIN_H
#define FIREBASE_CRASHLYTICS_PLUGIN_H

#include "core/object/class_db.h"

class FirebaseCrashlyticsPlugin : public Object {
    GDCLASS(FirebaseCrashlyticsPlugin, Object);

    static FirebaseCrashlyticsPlugin *singleton;

protected:
    static void _bind_methods();

public:
    static FirebaseCrashlyticsPlugin *get_singleton();

    void log(const String &message);
    void setUserId(const String &user_id);
    void setCustomKey(const String &key, const String &value);
    void setCustomKeyInt(const String &key, int value);
    void setCustomKeyBool(const String &key, bool value);
    void setCustomKeyFloat(const String &key, float value);
    void crash();

    FirebaseCrashlyticsPlugin();
    ~FirebaseCrashlyticsPlugin();
};

#endif // FIREBASE_CRASHLYTICS_PLUGIN_H
