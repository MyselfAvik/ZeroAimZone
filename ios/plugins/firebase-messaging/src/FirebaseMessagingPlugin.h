#ifndef FIREBASE_MESSAGING_PLUGIN_H
#define FIREBASE_MESSAGING_PLUGIN_H

#include "core/object/class_db.h"

class FirebaseMessagingPlugin : public Object {
    GDCLASS(FirebaseMessagingPlugin, Object);

    static FirebaseMessagingPlugin *singleton;

protected:
    static void _bind_methods();

public:
    static FirebaseMessagingPlugin *get_singleton();

    void checkPendingToken();
    void requestNotificationPermission();
    void fetchFCMToken();
    bool hasNotificationPermission();
    void subscribeToTopic(const String &topic);
    void unsubscribeFromTopic(const String &topic);

    FirebaseMessagingPlugin();
    ~FirebaseMessagingPlugin();
};

#endif // FIREBASE_MESSAGING_PLUGIN_H
