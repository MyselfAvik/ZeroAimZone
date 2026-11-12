#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface GodotAppDelegateHook : NSObject
@end

@implementation GodotAppDelegateHook

// Swizzled method for failure
- (void)swizzled_application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"[AppDelegateHook] didFailToRegisterForRemoteNotificationsWithError: %@", error);
    // Call original (which was swapped to the swizzled selector)
    [self swizzled_application:application didFailToRegisterForRemoteNotificationsWithError:error];
}

// Swizzled method for success
- (void)swizzled_application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    const char *data = (const char *)[deviceToken bytes];
    NSMutableString *tokenStr = [NSMutableString string];
    for (NSUInteger i = 0; i < [deviceToken length]; i++) {
        [tokenStr appendFormat:@"%02.2hhx", data[i]];
    }
    NSLog(@"[AppDelegateHook] didRegisterForRemoteNotificationsWithDeviceToken: %@", tokenStr);
    
    // Pass to Firebase dynamically
    Class messagingClass = NSClassFromString(@"FIRMessaging");
    if (messagingClass) {
        id messagingInstance = [messagingClass performSelector:NSSelectorFromString(@"messaging")];
        if (messagingInstance) {
            SEL setAPNSTokenSelector = NSSelectorFromString(@"setAPNSToken:");
            if ([messagingInstance respondsToSelector:setAPNSTokenSelector]) {
                [messagingInstance performSelector:setAPNSTokenSelector withObject:deviceToken];
                NSLog(@"[AppDelegateHook] Manually set APNs Token on FIRMessaging!");
            }
        }
    }
    
    [self swizzled_application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
}

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class godotAppDelegateClass = objc_getClass("SwiftUI.AppDelegate");
        if (!godotAppDelegateClass) {
            godotAppDelegateClass = objc_getClass("GodotAppDelegate");
        }
        if (!godotAppDelegateClass) {
            godotAppDelegateClass = objc_getClass("AppDelegate");
        }
        
        if (!godotAppDelegateClass) {
            int numClasses = objc_getClassList(NULL, 0);
            if (numClasses > 0) {
                Class *classes = (Class *)malloc(sizeof(Class) * numClasses);
                numClasses = objc_getClassList(classes, numClasses);
                for (int i = 0; i < numClasses; i++) {
                    const char *className = class_getName(classes[i]);
                    if (strstr(className, "AppDelegate") != NULL || strstr(className, "AppController") != NULL) {
                        NSLog(@"[AppDelegateHook] Found potential delegate class: %s", className);
                        if (!godotAppDelegateClass) {
                            godotAppDelegateClass = classes[i];
                        }
                    }
                }
                free(classes);
            }
        }
        
        if (godotAppDelegateClass) {
            NSLog(@"[AppDelegateHook] Hooking delegate class: %s", class_getName(godotAppDelegateClass));
            // Swizzle didFailToRegister
            SEL failSel = @selector(application:didFailToRegisterForRemoteNotificationsWithError:);
            SEL swizzledFailSel = @selector(swizzled_application:didFailToRegisterForRemoteNotificationsWithError:);
            
            Method failMethod = class_getInstanceMethod(godotAppDelegateClass, failSel);
            Method swizzledFailMethod = class_getInstanceMethod([GodotAppDelegateHook class], swizzledFailSel);
            
            if (failMethod) {
                class_addMethod(godotAppDelegateClass, swizzledFailSel, method_getImplementation(failMethod), method_getTypeEncoding(failMethod));
                class_replaceMethod(godotAppDelegateClass, failSel, method_getImplementation(swizzledFailMethod), method_getTypeEncoding(swizzledFailMethod));
                NSLog(@"[AppDelegateHook] Successfully hooked didFailToRegisterForRemoteNotificationsWithError");
            } else {
                IMP hookImp = imp_implementationWithBlock(^(id self, UIApplication *app, NSError *err) {
                    NSLog(@"[AppDelegateHook] didFailToRegisterForRemoteNotificationsWithError: %@", err);
                });
                class_addMethod(godotAppDelegateClass, failSel, hookImp, "v@:@@");
                NSLog(@"[AppDelegateHook] Added didFailToRegisterForRemoteNotificationsWithError");
            }
            
            // Swizzle didRegister
            SEL successSel = @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:);
            SEL swizzledSuccessSel = @selector(swizzled_application:didRegisterForRemoteNotificationsWithDeviceToken:);
            
            Method successMethod = class_getInstanceMethod(godotAppDelegateClass, successSel);
            Method swizzledSuccessMethod = class_getInstanceMethod([GodotAppDelegateHook class], swizzledSuccessSel);
            
            if (successMethod) {
                class_addMethod(godotAppDelegateClass, swizzledSuccessSel, method_getImplementation(successMethod), method_getTypeEncoding(successMethod));
                class_replaceMethod(godotAppDelegateClass, successSel, method_getImplementation(swizzledSuccessMethod), method_getTypeEncoding(swizzledSuccessMethod));
                NSLog(@"[AppDelegateHook] Successfully hooked didRegisterForRemoteNotificationsWithDeviceToken");
            } else {
                IMP hookImp = imp_implementationWithBlock(^(id self, UIApplication *app, NSData *token) {
                    const char *data = (const char *)[token bytes];
                    NSMutableString *tokenStr = [NSMutableString string];
                    for (NSUInteger i = 0; i < [token length]; i++) {
                        [tokenStr appendFormat:@"%02.2hhx", data[i]];
                    }
                    NSLog(@"[AppDelegateHook] didRegisterForRemoteNotificationsWithDeviceToken: %@", tokenStr);
                    
                    // Pass to Firebase dynamically
                    Class messagingClass = NSClassFromString(@"FIRMessaging");
                    if (messagingClass) {
                        id messagingInstance = [messagingClass performSelector:NSSelectorFromString(@"messaging")];
                        if (messagingInstance) {
                            SEL setAPNSTokenSelector = NSSelectorFromString(@"setAPNSToken:");
                            if ([messagingInstance respondsToSelector:setAPNSTokenSelector]) {
                                [messagingInstance performSelector:setAPNSTokenSelector withObject:token];
                                NSLog(@"[AppDelegateHook] Manually set APNs Token on FIRMessaging!");
                            }
                        }
                    }
                });
                class_addMethod(godotAppDelegateClass, successSel, hookImp, "v@:@@");
                NSLog(@"[AppDelegateHook] Added didRegisterForRemoteNotificationsWithDeviceToken");
            }
        } else {
            NSLog(@"[AppDelegateHook] Error: Could not find GodotAppDelegate class");
        }
    });
}

@end
