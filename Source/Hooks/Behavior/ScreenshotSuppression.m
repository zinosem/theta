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