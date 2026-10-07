#import "Include/ThetaHelper.h"
#import <UIKit/UIKit.h>

static void (*orig_screenshotSuppression)(id self, SEL _cmd);
static void hook_screenshotSuppression(id self, SEL _cmd) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_screenshotSuppression) orig_screenshotSuppression(self, _cmd);
        return;
    }
}

static void (*orig_screenshotSuppression_setProtected)(id self, SEL _cmd, BOOL isProtected);
static void hook_screenshotSuppression_setProtected(id self, SEL _cmd, BOOL isProtected) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_screenshotSuppression_setProtected) orig_screenshotSuppression_setProtected(self, _cmd, isProtected);
        return;
    }
    if (orig_screenshotSuppression_setProtected) orig_screenshotSuppression_setProtected(self, _cmd, NO);
}

static id (*orig_screenshotSuppression_initProtected)(id self, SEL _cmd, BOOL isProtected);
static id hook_screenshotSuppression_initProtected(id self, SEL _cmd, BOOL isProtected) {
    if (!ENABLED(@"Screenshot Suppression")) {
        return orig_screenshotSuppression_initProtected ? orig_screenshotSuppression_initProtected(self, _cmd, isProtected) : self;
    }
    return orig_screenshotSuppression_initProtected ? orig_screenshotSuppression_initProtected(self, _cmd, NO) : self;
}

static void (*orig_screenRecord)(id self, SEL _cmd, NSInteger state);
static void hook_screenRecord(id self, SEL _cmd, NSInteger state) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_screenRecord) orig_screenRecord(self, _cmd, state);
        return;
    }
}

// Direct Message / Disappearing media specific handlers (IGDirectVisualMessageViewerController)
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

static void (*orig_DVM_userDidTakeScreenshotNotif)(id self, SEL _cmd, id arg1);
static void hook_DVM_userDidTakeScreenshotNotif(id self, SEL _cmd, id arg1) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_DVM_userDidTakeScreenshotNotif) orig_DVM_userDidTakeScreenshotNotif(self, _cmd, arg1);
    }
}

static void (*orig_DVM_screenshotObserverDidTakeScreenshot)(id self, SEL _cmd, id arg1);
static void hook_DVM_screenshotObserverDidTakeScreenshot(id self, SEL _cmd, id arg1) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_DVM_screenshotObserverDidTakeScreenshot) orig_DVM_screenshotObserverDidTakeScreenshot(self, _cmd, arg1);
    }
}

// Direct thread view controller handlers (IGDirectThreadViewController)
static void (*orig_ThreadVC_userDidTakeScreenshotNotif)(id self, SEL _cmd, id arg1);
static void hook_ThreadVC_userDidTakeScreenshotNotif(id self, SEL _cmd, id arg1) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_ThreadVC_userDidTakeScreenshotNotif) orig_ThreadVC_userDidTakeScreenshotNotif(self, _cmd, arg1);
    }
}

static void (*orig_ThreadVC_didTakeScreenshot)(id self, SEL _cmd);
static void hook_ThreadVC_didTakeScreenshot(id self, SEL _cmd) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_ThreadVC_didTakeScreenshot) orig_ThreadVC_didTakeScreenshot(self, _cmd);
    }
}

// Direct screenshot observer handlers (IGDirectScreenshotObserver)
static void (*orig_directObs_onTakenScreenshot)(id self, SEL _cmd);
static void hook_directObs_onTakenScreenshot(id self, SEL _cmd) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_directObs_onTakenScreenshot) orig_directObs_onTakenScreenshot(self, _cmd);
    }
}

static void (*orig_directObs_didTakeScreenshot)(id self, SEL _cmd);
static void hook_directObs_didTakeScreenshot(id self, SEL _cmd) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_directObs_didTakeScreenshot) orig_directObs_didTakeScreenshot(self, _cmd);
    }
}

void THRegisterScreenshotProtectionProviderHooks(void) {
    NullHookMessageIfPresent(objc_getClass("IGScreenCaptureProtection.IGScreenCaptureProtectionViewProvider"), @selector(setIsProtected:), (void *)hook_screenshotSuppression_setProtected, &orig_screenshotSuppression_setProtected);
    NullHookMessageIfPresent(objc_getClass("IGScreenCaptureProtection.IGScreenCaptureProtectionViewProvider"), @selector(initWithIsProtected:), (void *)hook_screenshotSuppression_initProtected, &orig_screenshotSuppression_initProtected);
}

void THRegisterScreenshotObserverHook(void) {
    NullHookMessageIfPresent(objc_getClass("IGScreenshotObserver"), @selector(_onTakenScreenshot), (void *)hook_screenshotSuppression, &orig_screenshotSuppression);
    NullHookMessageIfPresent(objc_getClass("IGScreenshotObserver"), @selector(_screenCaptureStateDidChange:), (void *)hook_screenRecord, &orig_screenRecord);

    // Direct vanishing & visual media controllers
    Class dvmClass = objc_getClass("IGDirectVisualMessageViewerController");
    if (dvmClass) {
        NullHookMessageIfPresent(dvmClass, @selector(_didTakeScreenshot), (void *)hook_DVM_didTakeScreenshot, &orig_DVM_didTakeScreenshot);
        NullHookMessageIfPresent(dvmClass, @selector(userDidTakeScreenshot:), (void *)hook_DVM_userDidTakeScreenshot, &orig_DVM_userDidTakeScreenshot);
        NullHookMessageIfPresent(dvmClass, @selector(_userDidTakeScreenshotNotification:), (void *)hook_DVM_userDidTakeScreenshotNotif, &orig_DVM_userDidTakeScreenshotNotif);
        NullHookMessageIfPresent(dvmClass, @selector(_screenshotObserverDidTakeScreenshot:), (void *)hook_DVM_screenshotObserverDidTakeScreenshot, &orig_DVM_screenshotObserverDidTakeScreenshot);
    }

    Class threadVCClass = objc_getClass("IGDirectThreadViewController");
    if (threadVCClass) {
        NullHookMessageIfPresent(threadVCClass, @selector(_userDidTakeScreenshotNotification:), (void *)hook_ThreadVC_userDidTakeScreenshotNotif, &orig_ThreadVC_userDidTakeScreenshotNotif);
        NullHookMessageIfPresent(threadVCClass, @selector(_didTakeScreenshot), (void *)hook_ThreadVC_didTakeScreenshot, &orig_ThreadVC_didTakeScreenshot);
    }

    Class directScreenshotObsClass = objc_getClass("IGDirectScreenshotObserver");
    if (directScreenshotObsClass) {
        NullHookMessageIfPresent(directScreenshotObsClass, @selector(_onTakenScreenshot), (void *)hook_directObs_onTakenScreenshot, &orig_directObs_onTakenScreenshot);
        NullHookMessageIfPresent(directScreenshotObsClass, @selector(_didTakeScreenshot), (void *)hook_directObs_didTakeScreenshot, &orig_directObs_didTakeScreenshot);
    }
}