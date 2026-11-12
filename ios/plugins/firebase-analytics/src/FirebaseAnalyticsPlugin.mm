#import "FirebaseAnalyticsPlugin.h"
#import <Foundation/Foundation.h>
#import <FirebaseCore/FirebaseCore.h>
#import <FirebaseAnalytics/FirebaseAnalytics.h>
#include "core/config/project_settings.h"
#include "core/config/engine.h"

FirebaseAnalyticsPlugin *FirebaseAnalyticsPlugin::singleton = nullptr;

FirebaseAnalyticsPlugin *FirebaseAnalyticsPlugin::get_singleton() {
    return singleton;
}

void FirebaseAnalyticsPlugin::_bind_methods() {
    ClassDB::bind_method(D_METHOD("logEvent", "name", "params"), &FirebaseAnalyticsPlugin::logEvent);
    ClassDB::bind_method(D_METHOD("setUserId", "user_id"), &FirebaseAnalyticsPlugin::setUserId);
    ClassDB::bind_method(D_METHOD("setUserProperty", "name", "value"), &FirebaseAnalyticsPlugin::setUserProperty);
    ClassDB::bind_method(D_METHOD("setAnalyticsCollectionEnabled", "enabled"), &FirebaseAnalyticsPlugin::setAnalyticsCollectionEnabled);
}

FirebaseAnalyticsPlugin::FirebaseAnalyticsPlugin() {
    singleton = this;
    if ([FIRApp defaultApp] == nil) {
        [FIRApp configure];
    }
}

FirebaseAnalyticsPlugin::~FirebaseAnalyticsPlugin() {
    singleton = nullptr;
}

static NSDictionary *convert_dictionary(const Dictionary &dict) {
    NSMutableDictionary *nsDict = [NSMutableDictionary dictionary];
    Array keys = dict.keys();
    for (int i = 0; i < keys.size(); i++) {
        String key = keys[i];
        NSString *keyNS = [NSString stringWithUTF8String:key.utf8().get_data()];
        Variant val = dict[key];
        
        switch (val.get_type()) {
            case Variant::INT:
                [nsDict setObject:@((int64_t)val) forKey:keyNS];
                break;
            case Variant::FLOAT:
                [nsDict setObject:@((double)val) forKey:keyNS];
                break;
            case Variant::BOOL:
                [nsDict setObject:@((bool)val) forKey:keyNS];
                break;
            case Variant::STRING: {
                String valStr = val;
                NSString *valNS = [NSString stringWithUTF8String:valStr.utf8().get_data()];
                [nsDict setObject:valNS forKey:keyNS];
                break;
            }
            default:
                break;
        }
    }
    return nsDict;
}

void FirebaseAnalyticsPlugin::logEvent(const String &name, const Dictionary &params) {
    NSString *nameNS = [NSString stringWithUTF8String:name.utf8().get_data()];
    NSDictionary *paramsNS = convert_dictionary(params);
    [FIRAnalytics logEventWithName:nameNS parameters:paramsNS];
}

void FirebaseAnalyticsPlugin::setUserId(const String &user_id) {
    NSString *userIdNS = [NSString stringWithUTF8String:user_id.utf8().get_data()];
    [FIRAnalytics setUserID:userIdNS];
}

void FirebaseAnalyticsPlugin::setUserProperty(const String &name, const String &value) {
    NSString *nameNS = [NSString stringWithUTF8String:name.utf8().get_data()];
    NSString *valueNS = [NSString stringWithUTF8String:value.utf8().get_data()];
    [FIRAnalytics setUserPropertyString:valueNS forName:nameNS];
}

void FirebaseAnalyticsPlugin::setAnalyticsCollectionEnabled(bool enabled) {
    [FIRAnalytics setAnalyticsCollectionEnabled:enabled];
}

// Godot module registration entrypoints
void register_firebase_analytics_types() {
    ClassDB::register_class<FirebaseAnalyticsPlugin>();
    FirebaseAnalyticsPlugin *plugin = memnew(FirebaseAnalyticsPlugin);
    Engine::get_singleton()->add_singleton(Engine::Singleton("FirebaseAnalyticsPlugin", plugin));
}

void unregister_firebase_analytics_types() {
    FirebaseAnalyticsPlugin *plugin = FirebaseAnalyticsPlugin::get_singleton();
    if (plugin) {
        Engine::get_singleton()->remove_singleton("FirebaseAnalyticsPlugin");
        memdelete(plugin);
    }
}

