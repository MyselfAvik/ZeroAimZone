#include "meta_sdk.h"

#import "drivers/apple_embedded/godot_app_delegate.h"
#import "drivers/apple_embedded/godot_view_controller.h"



#import <Foundation/Foundation.h>

// Import Meta iOS SDK headers
#if defined(__OBJC__)
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#endif

MetaSdk *MetaSdk::instance = NULL;

void MetaSdk::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize"), &MetaSdk::initialize);
    ClassDB::bind_method(D_METHOD("logEvent"), &MetaSdk::logEvent);
    ClassDB::bind_method(D_METHOD("setUserId"), &MetaSdk::setUserId);
    ClassDB::bind_method(D_METHOD("getMetaIdentity"), &MetaSdk::getMetaIdentity);
    ClassDB::bind_method(D_METHOD("setDebugEnabled"), &MetaSdk::setDebugEnabled);
    ClassDB::bind_method(D_METHOD("handleFirstLaunch"), &MetaSdk::handleFirstLaunch);
    ClassDB::bind_method(D_METHOD("isReady"), &MetaSdk::isReady);
    ADD_SIGNAL(MethodInfo("sdk_initialized"));
}

MetaSdk::MetaSdk() {
    ERR_FAIL_COND(instance != NULL);
    instance = this;
}

MetaSdk::~MetaSdk() {
    instance = NULL;
}

MetaSdk *MetaSdk::get_singleton() {
	return instance;
}

void MetaSdk::initialize(String app_id, String client_token) {
    NSString *ns_app_id = [NSString stringWithUTF8String:app_id.utf8().get_data()];
    NSString *ns_client_token = [NSString stringWithUTF8String:client_token.utf8().get_data()];
    if (ns_app_id.length > 0) {
        [FBSDKSettings sharedSettings].appID = ns_app_id;
    }
    if (ns_client_token.length > 0) {
        [FBSDKSettings sharedSettings].clientToken = ns_client_token;
    }
    
    // 1. Initialize Facebook Application Delegate session
    #if defined(__OBJC__)
    [[FBSDKApplicationDelegate sharedInstance] application:[UIApplication sharedApplication] didFinishLaunchingWithOptions:nil];
    
    // 2. Enable Advertiser Tracking for ATT attribution
    [FBSDKSettings sharedSettings].isAdvertiserTrackingEnabled = YES;
    
    // 3. Enable network & app event debug logging
    [[FBSDKSettings sharedSettings] enableLoggingBehavior:FBSDKLoggingBehaviorAppEvents];
    [[FBSDKSettings sharedSettings] enableLoggingBehavior:FBSDKLoggingBehaviorNetworkRequests];
    #endif

    NSLog(@"[MetaSDKPlugin] iOS Facebook SDK App ID set to: %@, Client Token configured, ApplicationDelegate initialized.", ns_app_id);
    // iOS init is synchronous, signal immediately
    emit_signal("sdk_initialized");
}

bool MetaSdk::isReady() {
    // iOS SDK uses class methods, so it's always ready after initialize()
    return true;
}

void MetaSdk::logEvent(String event_name, Dictionary params) {
    NSString *ns_event_name = [NSString stringWithUTF8String:event_name.utf8().get_data()];
    NSMutableDictionary *ns_params = [[NSMutableDictionary alloc] init];
    
    // Convert Godot Dictionary to NSDictionary
    Array keys = params.keys();
    for (int i = 0; i < keys.size(); i++) {
        String key = keys[i];
        Variant value = params[key];
        
        NSString *ns_key = [NSString stringWithUTF8String:key.utf8().get_data()];
        id ns_value = nil;
        
        switch (value.get_type()) {
            case Variant::STRING: {
                String str_val = value;
                ns_value = [NSString stringWithUTF8String:str_val.utf8().get_data()];
            } break;
            case Variant::INT: {
                int int_val = value;
                ns_value = [NSNumber numberWithInt:int_val];
            } break;
            case Variant::FLOAT: {
                float float_val = value;
                ns_value = [NSNumber numberWithFloat:float_val];
            } break;
            case Variant::BOOL: {
                bool bool_val = value;
                ns_value = [NSNumber numberWithBool:bool_val];
            } break;
            default: {
                String str_val = value.stringify();
                ns_value = [NSString stringWithUTF8String:str_val.utf8().get_data()];
            } break;
        }
        
        if (ns_value) {
            [ns_params setObject:ns_value forKey:ns_key];
        }
    }
    
    [FBSDKAppEvents logEvent:ns_event_name parameters:ns_params];
    
    // Explicitly flush events to Meta servers immediately
    #if defined(__OBJC__)
    SEL flushSel = NSSelectorFromString(@"flush");
    if ([FBSDKAppEvents respondsToSelector:flushSel]) {
        [FBSDKAppEvents performSelector:flushSel];
    } else {
        SEL sharedSel = NSSelectorFromString(@"shared");
        if ([FBSDKAppEvents respondsToSelector:sharedSel]) {
            id shared = [FBSDKAppEvents performSelector:sharedSel];
            if ([shared respondsToSelector:flushSel]) {
                [shared performSelector:flushSel];
            }
        }
    }
    #endif

    NSLog(@"[MetaSDKPlugin] iOS Logged and Flushed Meta App Event: %@ with params: %@", ns_event_name, ns_params);
}

void MetaSdk::setUserId(String user_id) {
    current_user_id = user_id;
    NSString *ns_user_id = [NSString stringWithUTF8String:user_id.utf8().get_data()];
    [FBSDKAppEvents setUserID:ns_user_id];
    NSLog(@"[MetaSDKPlugin] iOS Set Meta user ID: %@", ns_user_id);
}

String MetaSdk::getMetaIdentity() {
    if (!current_user_id.is_empty()) {
        return current_user_id;
    }
    #if defined(__OBJC__)
    SEL selector = NSSelectorFromString(@"anonymousID");
    if ([FBSDKAppEvents respondsToSelector:selector]) {
        NSString *ns_anon_id = [FBSDKAppEvents performSelector:selector];
        if (ns_anon_id) {
            return String(ns_anon_id.UTF8String);
        }
    }
    #endif
    return "";
}

void MetaSdk::setDebugEnabled(bool enabled) {
    #if defined(__OBJC__)
    if (enabled) {
        [[FBSDKSettings sharedSettings] enableLoggingBehavior:FBSDKLoggingBehaviorAppEvents];
    } else {
        [[FBSDKSettings sharedSettings] disableLoggingBehavior:FBSDKLoggingBehaviorAppEvents];
    }
    NSLog(@"[MetaSDKPlugin] iOS Facebook SDK debug behavior set to: %d", enabled);
    #endif
}

void MetaSdk::handleFirstLaunch(String first_event, String second_event) {
    #if defined(__OBJC__)
    NSString *ns_first_event = [NSString stringWithUTF8String:first_event.utf8().get_data()];
    NSString *ns_second_event = [NSString stringWithUTF8String:second_event.utf8().get_data()];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL firstLaunchDone = [defaults boolForKey:@"MetaSdkFirstLaunchDone"];
    
    if (!firstLaunchDone) {
        [FBSDKAppEvents logEvent:ns_first_event];
        NSLog(@"[MetaSDKPlugin] iOS First launch detected — logged event: %@", ns_first_event);
        [defaults setBool:YES forKey:@"MetaSdkFirstLaunchDone"];
        [defaults synchronize];
    } else {
        [FBSDKAppEvents logEvent:ns_second_event];
        NSLog(@"[MetaSDKPlugin] iOS Returning launch — logged event: %@", ns_second_event);
    }
    #endif
}
