#import "FirebaseCrashlyticsPlugin.h"
#import <Foundation/Foundation.h>
#import <FirebaseCore/FirebaseCore.h>
#import <FirebaseCrashlytics/FirebaseCrashlytics.h>
#include "core/config/project_settings.h"
#include "core/config/engine.h"

FirebaseCrashlyticsPlugin *FirebaseCrashlyticsPlugin::singleton = nullptr;

FirebaseCrashlyticsPlugin *FirebaseCrashlyticsPlugin::get_singleton() {
    return singleton;
}

void FirebaseCrashlyticsPlugin::_bind_methods() {
    ClassDB::bind_method(D_METHOD("log", "message"), &FirebaseCrashlyticsPlugin::log);
    ClassDB::bind_method(D_METHOD("setUserId", "user_id"), &FirebaseCrashlyticsPlugin::setUserId);
    ClassDB::bind_method(D_METHOD("setCustomKey", "key", "value"), &FirebaseCrashlyticsPlugin::setCustomKey);
    ClassDB::bind_method(D_METHOD("setCustomKeyInt", "key", "value"), &FirebaseCrashlyticsPlugin::setCustomKeyInt);
    ClassDB::bind_method(D_METHOD("setCustomKeyBool", "key", "value"), &FirebaseCrashlyticsPlugin::setCustomKeyBool);
    ClassDB::bind_method(D_METHOD("setCustomKeyFloat", "key", "value"), &FirebaseCrashlyticsPlugin::setCustomKeyFloat);
    ClassDB::bind_method(D_METHOD("crash"), &FirebaseCrashlyticsPlugin::crash);
}

FirebaseCrashlyticsPlugin::FirebaseCrashlyticsPlugin() {
    singleton = this;
    if ([FIRApp defaultApp] == nil) {
        [FIRApp configure];
    }
}

FirebaseCrashlyticsPlugin::~FirebaseCrashlyticsPlugin() {
    singleton = nullptr;
}

void FirebaseCrashlyticsPlugin::log(const String &message) {
    NSString *messageNS = [NSString stringWithUTF8String:message.utf8().get_data()];
    [[FIRCrashlytics crashlytics] log:@"%@", messageNS];
}

void FirebaseCrashlyticsPlugin::setUserId(const String &user_id) {
    NSString *userIdNS = [NSString stringWithUTF8String:user_id.utf8().get_data()];
    [[FIRCrashlytics crashlytics] setUserID:userIdNS];
}

void FirebaseCrashlyticsPlugin::setCustomKey(const String &key, const String &value) {
    NSString *keyNS = [NSString stringWithUTF8String:key.utf8().get_data()];
    NSString *valueNS = [NSString stringWithUTF8String:value.utf8().get_data()];
    [[FIRCrashlytics crashlytics] setCustomValue:valueNS forKey:keyNS];
}

void FirebaseCrashlyticsPlugin::setCustomKeyInt(const String &key, int value) {
    NSString *keyNS = [NSString stringWithUTF8String:key.utf8().get_data()];
    [[FIRCrashlytics crashlytics] setCustomValue:@(value) forKey:keyNS];
}

void FirebaseCrashlyticsPlugin::setCustomKeyBool(const String &key, bool value) {
    NSString *keyNS = [NSString stringWithUTF8String:key.utf8().get_data()];
    [[FIRCrashlytics crashlytics] setCustomValue:@(value) forKey:keyNS];
}

void FirebaseCrashlyticsPlugin::setCustomKeyFloat(const String &key, float value) {
    NSString *keyNS = [NSString stringWithUTF8String:key.utf8().get_data()];
    [[FIRCrashlytics crashlytics] setCustomValue:@(value) forKey:keyNS];
}

void FirebaseCrashlyticsPlugin::crash() {
    // Force a native crash for verification
    [[FIRCrashlytics crashlytics] crash];
}

// Godot module registration entrypoints
void register_firebase_crashlytics_types() {
    ClassDB::register_class<FirebaseCrashlyticsPlugin>();
    FirebaseCrashlyticsPlugin *plugin = memnew(FirebaseCrashlyticsPlugin);
    Engine::get_singleton()->add_singleton(Engine::Singleton("FirebaseCrashlyticsPlugin", plugin));
}

void unregister_firebase_crashlytics_types() {
    FirebaseCrashlyticsPlugin *plugin = FirebaseCrashlyticsPlugin::get_singleton();
    if (plugin) {
        Engine::get_singleton()->remove_singleton("FirebaseCrashlyticsPlugin");
        memdelete(plugin);
    }
}

