#ifndef FIREBASE_ANALYTICS_PLUGIN_H
#define FIREBASE_ANALYTICS_PLUGIN_H

#include "core/object/class_db.h"

class FirebaseAnalyticsPlugin : public Object {
    GDCLASS(FirebaseAnalyticsPlugin, Object);

    static FirebaseAnalyticsPlugin *singleton;

protected:
    static void _bind_methods();

public:
    static FirebaseAnalyticsPlugin *get_singleton();

    void logEvent(const String &name, const Dictionary &params);
    void setUserId(const String &user_id);
    void setUserProperty(const String &name, const String &value);
    void setAnalyticsCollectionEnabled(bool enabled);

    FirebaseAnalyticsPlugin();
    ~FirebaseAnalyticsPlugin();
};

#endif // FIREBASE_ANALYTICS_PLUGIN_H
