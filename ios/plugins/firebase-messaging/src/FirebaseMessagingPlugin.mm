#import "FirebaseMessagingPlugin.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <FirebaseCore/FirebaseCore.h>
#import <FirebaseMessaging/FirebaseMessaging.h>
#import <UserNotifications/UserNotifications.h>
#include "core/config/project_settings.h"
#include "core/config/engine.h"

@interface MessagingDelegateHelper : NSObject <FIRMessagingDelegate>
@property (nonatomic, assign) FirebaseMessagingPlugin *plugin;
@end

@implementation MessagingDelegateHelper
- (void)messaging:(FIRMessaging *)messaging didReceiveRegistrationToken:(NSString *)fcmToken {
    if (self.plugin && fcmToken) {
        self.plugin->emit_signal("fcm_token_received", String([fcmToken UTF8String]));
    }
}
@end

FirebaseMessagingPlugin *FirebaseMessagingPlugin::singleton = nullptr;
static MessagingDelegateHelper *delegateHelper = nil;

FirebaseMessagingPlugin *FirebaseMessagingPlugin::get_singleton() {
    return singleton;
}

void FirebaseMessagingPlugin::_bind_methods() {
    ClassDB::bind_method(D_METHOD("checkPendingToken"), &FirebaseMessagingPlugin::checkPendingToken);
    ClassDB::bind_method(D_METHOD("requestNotificationPermission"), &FirebaseMessagingPlugin::requestNotificationPermission);
    ClassDB::bind_method(D_METHOD("fetchFCMToken"), &FirebaseMessagingPlugin::fetchFCMToken);
    ClassDB::bind_method(D_METHOD("hasNotificationPermission"), &FirebaseMessagingPlugin::hasNotificationPermission);
    ClassDB::bind_method(D_METHOD("subscribeToTopic", "topic"), &FirebaseMessagingPlugin::subscribeToTopic);
    ClassDB::bind_method(D_METHOD("unsubscribeFromTopic", "topic"), &FirebaseMessagingPlugin::unsubscribeFromTopic);

    ADD_SIGNAL(MethodInfo("fcm_token_received", PropertyInfo(Variant::STRING, "token")));
    ADD_SIGNAL(MethodInfo("fcm_message_received", PropertyInfo(Variant::STRING, "title"), PropertyInfo(Variant::STRING, "body"), PropertyInfo(Variant::STRING, "data")));
    ADD_SIGNAL(MethodInfo("notification_permission_result", PropertyInfo(Variant::BOOL, "granted")));
}

FirebaseMessagingPlugin::FirebaseMessagingPlugin() {
    singleton = this;
    if ([FIRApp defaultApp] == nil) {
        [FIRApp configure];
    }
    
    // Set up Messaging Delegate
    if (!delegateHelper) {
        delegateHelper = [[MessagingDelegateHelper alloc] init];
    }
    delegateHelper.plugin = this;
    [FIRMessaging messaging].delegate = delegateHelper;
}

FirebaseMessagingPlugin::~FirebaseMessagingPlugin() {
    singleton = nullptr;
    if (delegateHelper) {
        delegateHelper.plugin = nullptr;
    }
}

void FirebaseMessagingPlugin::checkPendingToken() {
    NSString *token = [FIRMessaging messaging].FCMToken;
    if (token) {
        emit_signal("fcm_token_received", String([token UTF8String]));
    }
}

void FirebaseMessagingPlugin::requestNotificationPermission() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge)
                              completionHandler:^(BOOL granted, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (FirebaseMessagingPlugin::get_singleton()) {
                    FirebaseMessagingPlugin::get_singleton()->emit_signal("notification_permission_result", granted);
                }
            });
        }];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    });
}

void FirebaseMessagingPlugin::fetchFCMToken() {
    [[FIRMessaging messaging] tokenWithCompletion:^(NSString * _Nullable token, NSError * _Nullable error) {
        if (token) {
            NSLog(@"[FirebaseMessagingPlugin] FCM Token: %@", token);
            if (FirebaseMessagingPlugin::get_singleton()) {
                FirebaseMessagingPlugin::get_singleton()->emit_signal("fcm_token_received", String([token UTF8String]));
            }
        } else {
            NSLog(@"[FirebaseMessagingPlugin] Failed to fetch FCM Token: %@", error);
        }
    }];
    
    NSData *apnsToken = [FIRMessaging messaging].APNSToken;
    if (apnsToken) {
        const char *data = (const char *)[apnsToken bytes];
        NSMutableString *tokenStr = [NSMutableString string];
        for (NSUInteger i = 0; i < [apnsToken length]; i++) {
            [tokenStr appendFormat:@"%02.2hhx", data[i]];
        }
        NSLog(@"[FirebaseMessagingPlugin] APNs Device Token: %@", tokenStr);
    } else {
        NSLog(@"[FirebaseMessagingPlugin] APNs Device Token is nil.");
    }
}

bool FirebaseMessagingPlugin::hasNotificationPermission() {
    __block BOOL isAuthorized = NO;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
        isAuthorized = (settings.authorizationStatus == UNAuthorizationStatusAuthorized);
        dispatch_semaphore_signal(sem);
    }];
    
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC));
    return isAuthorized;
}

void FirebaseMessagingPlugin::subscribeToTopic(const String &topic) {
    NSString *topicNS = [NSString stringWithUTF8String:topic.utf8().get_data()];
    [[FIRMessaging messaging] subscribeToTopic:topicNS completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[FirebaseMessagingPlugin] Failed to subscribe to topic %@: %@", topicNS, error);
        } else {
            NSLog(@"[FirebaseMessagingPlugin] Successfully subscribed to topic: %@", topicNS);
        }
    }];
}

void FirebaseMessagingPlugin::unsubscribeFromTopic(const String &topic) {
    NSString *topicNS = [NSString stringWithUTF8String:topic.utf8().get_data()];
    [[FIRMessaging messaging] unsubscribeFromTopic:topicNS completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[FirebaseMessagingPlugin] Failed to unsubscribe from topic %@: %@", topicNS, error);
        } else {
            NSLog(@"[FirebaseMessagingPlugin] Successfully unsubscribed from topic: %@", topicNS);
        }
    }];
}

// Godot module registration entrypoints
void register_firebase_messaging_types() {
    ClassDB::register_class<FirebaseMessagingPlugin>();
    FirebaseMessagingPlugin *plugin = memnew(FirebaseMessagingPlugin);
    Engine::get_singleton()->add_singleton(Engine::Singleton("FirebaseMessagingPlugin", plugin));
}

void unregister_firebase_messaging_types() {
    FirebaseMessagingPlugin *plugin = FirebaseMessagingPlugin::get_singleton();
    if (plugin) {
        Engine::get_singleton()->remove_singleton("FirebaseMessagingPlugin");
        memdelete(plugin);
    }
}

