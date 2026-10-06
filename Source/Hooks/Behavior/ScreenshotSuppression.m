#import "Include/ThetaHelper.h"
#import <UIKit/UIKit.h>

static void (*orig_screenshotSuppression)(id self, SEL _cmd);
static void hook_screenshotSuppression(id self, SEL _cmd) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_screenshotSuppression) orig_screenshotSuppression(self, _cmd);
        return;
    }
}

static void (*orig_screenshotSuppression2)(id self, SEL _cmd, BOOL isProtected);
static void hook_screenshotSuppression2(id self, SEL _cmd, BOOL isProtected) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_screenshotSuppression2) orig_screenshotSuppression2(self, _cmd, isProtected);
        return;
    }
    
    if (orig_screenshotSuppression2) orig_screenshotSuppression2(self, _cmd, NO);
}

static void (*orig_screenRecord)(id self, SEL _cmd, id state);
static void hook_screenRecord(id self, SEL _cmd, id state) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_screenRecord) orig_screenRecord(self, _cmd, state);
        return;
    }
}

// Global NSNotificationCenter suppression
static void (*orig_NC_postNotificationName_object_userInfo)(id self, SEL _cmd, NSNotificationName aName, id anObject, NSDictionary *aUserInfo);
static void hook_NC_postNotificationName_object_userInfo(id self, SEL _cmd, NSNotificationName aName, id anObject, NSDictionary *aUserInfo) {
    if (ENABLED(@"Screenshot Suppression")) {
        if ([aName isEqualToString:UIApplicationUserDidTakeScreenshotNotification] ||
            [aName isEqualToString:UIScreenCapturedDidChangeNotification]) {
            if (ENABLED(@"Show Banners")) {
                static NSTimeInterval lastToastTime = 0;
                NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
                if (now - lastToastTime > 3.0) {
                    lastToastTime = now;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [ThetaHelper showToastWithTitle:@"Screenshot Suppressed"
                                               subtitle:@"Notification blocked for other users."
                                                   icon:[UIImage systemImageNamed:@"camera.badge.ellipsis"]
                                               autoHide:3
                                                openURL:nil];
                    });
                }
            }
            return;
        }
    }
    if (orig_NC_postNotificationName_object_userInfo)
        orig_NC_postNotificationName_object_userInfo(self, _cmd, aName, anObject, aUserInfo);
}

static void (*orig_NC_postNotification)(id self, SEL _cmd, NSNotification *notification);
static void hook_NC_postNotification(id self, SEL _cmd, NSNotification *notification) {
    if (ENABLED(@"Screenshot Suppression") && notification) {
        if ([notification.name isEqualToString:UIApplicationUserDidTakeScreenshotNotification] ||
            [notification.name isEqualToString:UIScreenCapturedDidChangeNotification]) {
            return;
        }
    }
    if (orig_NC_postNotification)
        orig_NC_postNotification(self, _cmd, notification);
}

// Direct Message / Disappearing media specific handlers
static void (*orig_DVM_didTakeScreenshot)(id self, SEL _cmd);
static void hook_DVM_didTakeScreenshot(id self, SEL _cmd) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_DVM_didTakeScreenshot) orig_DVM_didTakeScreenshot(self, _cmd);
    }
}

static void (*orig_DVM_userDidTakeScreenshot)(id self, SEL _cmd, id arg1);
static void hook_DVM_userDidTakeScreenshot(id self, SEL _cmd, id arg1) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_DVM_userDidTakeScreenshot) orig_DVM_userDidTakeScreenshot(self, _cmd, arg1);
    }
}

void THRegisterScreenshotProtectionProviderHooks(void) {
    NullHookMessageIfPresent(objc_getClass("IGScreenCaptureProtection.IGScreenCaptureProtectionViewProvider"), @selector(setIsProtected:), (void *)hook_screenshotSuppression2, &orig_screenshotSuppression2);
    NullHookMessageIfPresent(objc_getClass("IGScreenCaptureProtection.IGScreenCaptureProtectionViewProvider"), @selector(initWithIsProtected:), (void *)hook_screenshotSuppression2, &orig_screenshotSuppression2);
}

void THRegisterScreenshotObserverHook(void) {
    NullHookMessageIfPresent(objc_getClass("IGScreenshotObserver"), @selector(_onTakenScreenshot), (void *)hook_screenshotSuppression, &orig_screenshotSuppression);
    NullHookMessageIfPresent(objc_getClass("IGScreenshotObserver"), @selector(_screenCaptureStateDidChange:), (void *)hook_screenRecord, &orig_screenRecord);

    // Global interception on NSNotificationCenter
    NullHookMessageIfPresent([NSNotificationCenter class], @selector(postNotificationName:object:userInfo:), (void *)hook_NC_postNotificationName_object_userInfo, &orig_NC_postNotificationName_object_userInfo);
    NullHookMessageIfPresent([NSNotificationCenter class], @selector(postNotification:), (void *)hook_NC_postNotification, &orig_NC_postNotification);

    // Direct vanishing & visual media controllers
    Class dvmClass = objc_getClass("IGDirectVisualMessageViewerController");
    if (dvmClass) {
        NullHookMessageIfPresent(dvmClass, @selector(_didTakeScreenshot), (void *)hook_DVM_didTakeScreenshot, &orig_DVM_didTakeScreenshot);
        NullHookMessageIfPresent(dvmClass, @selector(userDidTakeScreenshot:), (void *)hook_DVM_userDidTakeScreenshot, &orig_DVM_userDidTakeScreenshot);
        NullHookMessageIfPresent(dvmClass, @selector(_userDidTakeScreenshotNotification:), (void *)hook_DVM_userDidTakeScreenshot, &orig_DVM_userDidTakeScreenshot);
        NullHookMessageIfPresent(dvmClass, @selector(_screenshotObserverDidTakeScreenshot:), (void *)hook_DVM_userDidTakeScreenshot, &orig_DVM_userDidTakeScreenshot);
    }

    Class threadVCClass = objc_getClass("IGDirectThreadViewController");
    if (threadVCClass) {
        NullHookMessageIfPresent(threadVCClass, @selector(_userDidTakeScreenshotNotification:), (void *)hook_DVM_userDidTakeScreenshot, &orig_DVM_userDidTakeScreenshot);
        NullHookMessageIfPresent(threadVCClass, @selector(_didTakeScreenshot), (void *)hook_DVM_didTakeScreenshot, &orig_DVM_didTakeScreenshot);
    }

    Class directScreenshotObsClass = objc_getClass("IGDirectScreenshotObserver");
    if (directScreenshotObsClass) {
        NullHookMessageIfPresent(directScreenshotObsClass, @selector(_onTakenScreenshot), (void *)hook_screenshotSuppression, &orig_screenshotSuppression);
        NullHookMessageIfPresent(directScreenshotObsClass, @selector(_didTakeScreenshot), (void *)hook_screenshotSuppression, &orig_screenshotSuppression);
    }
}