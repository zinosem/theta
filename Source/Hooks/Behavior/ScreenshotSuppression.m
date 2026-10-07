#import "Include/ThetaHelper.h"
#import <UIKit/UIKit.h>

#pragma mark - UIScreen isCaptured Hook (System-wide screen recording deception)

static BOOL (*orig_screen_isCaptured)(id self, SEL _cmd);
static BOOL hook_screen_isCaptured(id self, SEL _cmd) {
    if (ENABLED(@"Screenshot Suppression")) {
        return NO;
    }
    return orig_screen_isCaptured ? orig_screen_isCaptured(self, _cmd) : NO;
}

static BOOL (*orig_screen_captured)(id self, SEL _cmd);
static BOOL hook_screen_captured(id self, SEL _cmd) {
    if (ENABLED(@"Screenshot Suppression")) {
        return NO;
    }
    return orig_screen_captured ? orig_screen_captured(self, _cmd) : NO;
}

static BOOL (*orig_screen_privateIsCaptured)(id self, SEL _cmd);
static BOOL hook_screen_privateIsCaptured(id self, SEL _cmd) {
    if (ENABLED(@"Screenshot Suppression")) {
        return NO;
    }
    return orig_screen_privateIsCaptured ? orig_screen_privateIsCaptured(self, _cmd) : NO;
}

static void (*orig_screen_setCaptured)(id self, SEL _cmd, BOOL captured);
static void hook_screen_setCaptured(id self, SEL _cmd, BOOL captured) {
    if (ENABLED(@"Screenshot Suppression")) {
        if (orig_screen_setCaptured) orig_screen_setCaptured(self, _cmd, NO);
        return;
    }
    if (orig_screen_setCaptured) orig_screen_setCaptured(self, _cmd, captured);
}

static id (*orig_screen_mirroredScreen)(id self, SEL _cmd);
static id hook_screen_mirroredScreen(id self, SEL _cmd) {
    if (ENABLED(@"Screenshot Suppression")) {
        return nil;
    }
    return orig_screen_mirroredScreen ? orig_screen_mirroredScreen(self, _cmd) : nil;
}

#pragma mark - IGScreenCaptureProtectionViewProvider Hooks

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

static BOOL (*orig_screenshotSuppression_isProtected)(id self, SEL _cmd);
static BOOL hook_screenshotSuppression_isProtected(id self, SEL _cmd) {
    if (!ENABLED(@"Screenshot Suppression")) {
        return orig_screenshotSuppression_isProtected ? orig_screenshotSuppression_isProtected(self, _cmd) : NO;
    }
    return NO;
}

#pragma mark - IGScreenshotObserver Hooks

static void (*orig_screenshotSuppression)(id self, SEL _cmd);
static void hook_screenshotSuppression(id self, SEL _cmd) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_screenshotSuppression) orig_screenshotSuppression(self, _cmd);
        return;
    }
}

static void (*orig_screenRecord)(id self, SEL _cmd, id state);
static void hook_screenRecord(id self, SEL _cmd, id state) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_screenRecord) orig_screenRecord(self, _cmd, state);
        return;
    }
}

static void (*orig_screenRecordNotif)(id self, SEL _cmd, id notif);
static void hook_screenRecordNotif(id self, SEL _cmd, id notif) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_screenRecordNotif) orig_screenRecordNotif(self, _cmd, notif);
        return;
    }
}

static void (*orig_screenCapturedDidChange)(id self, SEL _cmd);
static void hook_screenCapturedDidChange(id self, SEL _cmd) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_screenCapturedDidChange) orig_screenCapturedDidChange(self, _cmd);
        return;
    }
}

#pragma mark - Direct Message / Disappearing media (IGDirectVisualMessageViewerController)

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

static void (*orig_DVM_screenCaptureStateDidChange)(id self, SEL _cmd, id arg1);
static void hook_DVM_screenCaptureStateDidChange(id self, SEL _cmd, id arg1) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_DVM_screenCaptureStateDidChange) orig_DVM_screenCaptureStateDidChange(self, _cmd, arg1);
    }
}

static void (*orig_DVM_screenshotObserverDidSeeScreenRecord)(id self, SEL _cmd, id arg1);
static void hook_DVM_screenshotObserverDidSeeScreenRecord(id self, SEL _cmd, id arg1) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_DVM_screenshotObserverDidSeeScreenRecord) orig_DVM_screenshotObserverDidSeeScreenRecord(self, _cmd, arg1);
    }
}

static void (*orig_DVM_screenshotObserverDidChangeScreenCaptureState)(id self, SEL _cmd, id arg1, id arg2);
static void hook_DVM_screenshotObserverDidChangeScreenCaptureState(id self, SEL _cmd, id arg1, id arg2) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_DVM_screenshotObserverDidChangeScreenCaptureState) orig_DVM_screenshotObserverDidChangeScreenCaptureState(self, _cmd, arg1, arg2);
    }
}

#pragma mark - Direct thread view controller handlers (IGDirectThreadViewController)

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

static void (*orig_ThreadVC_screenCaptureStateDidChange)(id self, SEL _cmd, id arg1);
static void hook_ThreadVC_screenCaptureStateDidChange(id self, SEL _cmd, id arg1) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_ThreadVC_screenCaptureStateDidChange) orig_ThreadVC_screenCaptureStateDidChange(self, _cmd, arg1);
    }
}

static void (*orig_ThreadVC_screenCaptureStateDidChangeNotif)(id self, SEL _cmd, id arg1);
static void hook_ThreadVC_screenCaptureStateDidChangeNotif(id self, SEL _cmd, id arg1) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_ThreadVC_screenCaptureStateDidChangeNotif) orig_ThreadVC_screenCaptureStateDidChangeNotif(self, _cmd, arg1);
    }
}

static void (*orig_ThreadVC_screenCapturedDidChange)(id self, SEL _cmd);
static void hook_ThreadVC_screenCapturedDidChange(id self, SEL _cmd) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_ThreadVC_screenCapturedDidChange) orig_ThreadVC_screenCapturedDidChange(self, _cmd);
    }
}

static void (*orig_ThreadVC_userDidScreenRecord)(id self, SEL _cmd, id arg1);
static void hook_ThreadVC_userDidScreenRecord(id self, SEL _cmd, id arg1) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_ThreadVC_userDidScreenRecord) orig_ThreadVC_userDidScreenRecord(self, _cmd, arg1);
    }
}

static void (*orig_ThreadVC_screenshotObserverDidSeeScreenRecord)(id self, SEL _cmd, id arg1);
static void hook_ThreadVC_screenshotObserverDidSeeScreenRecord(id self, SEL _cmd, id arg1) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_ThreadVC_screenshotObserverDidSeeScreenRecord) orig_ThreadVC_screenshotObserverDidSeeScreenRecord(self, _cmd, arg1);
    }
}

static void (*orig_ThreadVC_screenshotObserverDidChangeScreenCaptureState)(id self, SEL _cmd, id arg1, id arg2);
static void hook_ThreadVC_screenshotObserverDidChangeScreenCaptureState(id self, SEL _cmd, id arg1, id arg2) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_ThreadVC_screenshotObserverDidChangeScreenCaptureState) orig_ThreadVC_screenshotObserverDidChangeScreenCaptureState(self, _cmd, arg1, arg2);
    }
}

#pragma mark - Direct screenshot observer handlers (IGDirectScreenshotObserver)

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

static void (*orig_directObs_screenCaptureStateDidChange)(id self, SEL _cmd, id arg1);
static void hook_directObs_screenCaptureStateDidChange(id self, SEL _cmd, id arg1) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_directObs_screenCaptureStateDidChange) orig_directObs_screenCaptureStateDidChange(self, _cmd, arg1);
    }
}

static void (*orig_directObs_screenCapturedDidChange)(id self, SEL _cmd);
static void hook_directObs_screenCapturedDidChange(id self, SEL _cmd) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_directObs_screenCapturedDidChange) orig_directObs_screenCapturedDidChange(self, _cmd);
    }
}

static void (*orig_directObs_screenshotObserverDidSeeScreenRecord)(id self, SEL _cmd, id arg1);
static void hook_directObs_screenshotObserverDidSeeScreenRecord(id self, SEL _cmd, id arg1) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_directObs_screenshotObserverDidSeeScreenRecord) orig_directObs_screenshotObserverDidSeeScreenRecord(self, _cmd, arg1);
    }
}

#pragma mark - Generic Vanish / Ephemeral Screenshot Tracker Handlers

static void (*orig_tracker_onTakenScreenshot)(id self, SEL _cmd);
static void hook_tracker_onTakenScreenshot(id self, SEL _cmd) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_tracker_onTakenScreenshot) orig_tracker_onTakenScreenshot(self, _cmd);
    }
}

static void (*orig_tracker_didTakeScreenshot)(id self, SEL _cmd);
static void hook_tracker_didTakeScreenshot(id self, SEL _cmd) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_tracker_didTakeScreenshot) orig_tracker_didTakeScreenshot(self, _cmd);
    }
}

static void (*orig_tracker_screenCaptureStateDidChange)(id self, SEL _cmd, id arg1);
static void hook_tracker_screenCaptureStateDidChange(id self, SEL _cmd, id arg1) {
    if (!ENABLED(@"Screenshot Suppression")) {
        if (orig_tracker_screenCaptureStateDidChange) orig_tracker_screenCaptureStateDidChange(self, _cmd, arg1);
    }
}

#pragma mark - Registration

void THRegisterScreenshotProtectionProviderHooks(void) {
    Class providerCls = ThetaFirstClass(@[
        @"IGScreenCaptureProtection.IGScreenCaptureProtectionViewProvider",
        @"_TtC25IGScreenCaptureProtection37IGScreenCaptureProtectionViewProvider"
    ]);
    if (providerCls) {
        NullHookMessageIfPresent(providerCls, @selector(setIsProtected:), (void *)hook_screenshotSuppression_setProtected, &orig_screenshotSuppression_setProtected);
        NullHookMessageIfPresent(providerCls, @selector(initWithIsProtected:), (void *)hook_screenshotSuppression_initProtected, &orig_screenshotSuppression_initProtected);
        NullHookMessageIfPresent(providerCls, NSSelectorFromString(@"isProtected"), (void *)hook_screenshotSuppression_isProtected, &orig_screenshotSuppression_isProtected);
    }
}

void THRegisterScreenshotObserverHook(void) {
    // 1. Hook UIScreen isCaptured (system-wide screen recording detection)
    Class screenCls = [UIScreen class];
    if (screenCls) {
        NullHookMessageIfPresent(screenCls, @selector(isCaptured), (void *)hook_screen_isCaptured, &orig_screen_isCaptured);
        NullHookMessageIfPresent(screenCls, NSSelectorFromString(@"captured"), (void *)hook_screen_captured, &orig_screen_captured);
        NullHookMessageIfPresent(screenCls, NSSelectorFromString(@"_isCaptured"), (void *)hook_screen_privateIsCaptured, &orig_screen_privateIsCaptured);
        NullHookMessageIfPresent(screenCls, NSSelectorFromString(@"_setCaptured:"), (void *)hook_screen_setCaptured, &orig_screen_setCaptured);
        NullHookMessageIfPresent(screenCls, @selector(mirroredScreen), (void *)hook_screen_mirroredScreen, &orig_screen_mirroredScreen);
    }

    // 2. Hook IGScreenshotObserver
    Class obsClass = objc_getClass("IGScreenshotObserver");
    if (obsClass) {
        NullHookMessageIfPresent(obsClass, @selector(_onTakenScreenshot), (void *)hook_screenshotSuppression, &orig_screenshotSuppression);
        NullHookMessageIfPresent(obsClass, @selector(_screenCaptureStateDidChange:), (void *)hook_screenRecord, &orig_screenRecord);
        NullHookMessageIfPresent(obsClass, NSSelectorFromString(@"_screenCaptureStateDidChangeNotification:"), (void *)hook_screenRecordNotif, &orig_screenRecordNotif);
        NullHookMessageIfPresent(obsClass, NSSelectorFromString(@"_screenCapturedDidChange"), (void *)hook_screenCapturedDidChange, &orig_screenCapturedDidChange);
    }

    // 3. Direct visual media controllers
    Class dvmClass = objc_getClass("IGDirectVisualMessageViewerController");
    if (dvmClass) {
        NullHookMessageIfPresent(dvmClass, @selector(_didTakeScreenshot), (void *)hook_DVM_didTakeScreenshot, &orig_DVM_didTakeScreenshot);
        NullHookMessageIfPresent(dvmClass, @selector(userDidTakeScreenshot:), (void *)hook_DVM_userDidTakeScreenshot, &orig_DVM_userDidTakeScreenshot);
        NullHookMessageIfPresent(dvmClass, @selector(_userDidTakeScreenshotNotification:), (void *)hook_DVM_userDidTakeScreenshotNotif, &orig_DVM_userDidTakeScreenshotNotif);
        NullHookMessageIfPresent(dvmClass, @selector(_screenshotObserverDidTakeScreenshot:), (void *)hook_DVM_screenshotObserverDidTakeScreenshot, &orig_DVM_screenshotObserverDidTakeScreenshot);
        NullHookMessageIfPresent(dvmClass, NSSelectorFromString(@"_screenCaptureStateDidChange:"), (void *)hook_DVM_screenCaptureStateDidChange, &orig_DVM_screenCaptureStateDidChange);
        NullHookMessageIfPresent(dvmClass, NSSelectorFromString(@"screenshotObserverDidSeeScreenRecord:"), (void *)hook_DVM_screenshotObserverDidSeeScreenRecord, &orig_DVM_screenshotObserverDidSeeScreenRecord);
        NullHookMessageIfPresent(dvmClass, NSSelectorFromString(@"screenshotObserver:didChangeScreenCaptureState:"), (void *)hook_DVM_screenshotObserverDidChangeScreenCaptureState, &orig_DVM_screenshotObserverDidChangeScreenCaptureState);
    }

    // 4. Direct thread view controller (Vanish / Ephemeral mode DM thread)
    Class threadVCClass = objc_getClass("IGDirectThreadViewController");
    if (threadVCClass) {
        NullHookMessageIfPresent(threadVCClass, @selector(_userDidTakeScreenshotNotification:), (void *)hook_ThreadVC_userDidTakeScreenshotNotif, &orig_ThreadVC_userDidTakeScreenshotNotif);
        NullHookMessageIfPresent(threadVCClass, @selector(_didTakeScreenshot), (void *)hook_ThreadVC_didTakeScreenshot, &orig_ThreadVC_didTakeScreenshot);
        NullHookMessageIfPresent(threadVCClass, NSSelectorFromString(@"_screenCaptureStateDidChange:"), (void *)hook_ThreadVC_screenCaptureStateDidChange, &orig_ThreadVC_screenCaptureStateDidChange);
        NullHookMessageIfPresent(threadVCClass, NSSelectorFromString(@"_screenCaptureStateDidChangeNotification:"), (void *)hook_ThreadVC_screenCaptureStateDidChangeNotif, &orig_ThreadVC_screenCaptureStateDidChangeNotif);
        NullHookMessageIfPresent(threadVCClass, NSSelectorFromString(@"_screenCapturedDidChange"), (void *)hook_ThreadVC_screenCapturedDidChange, &orig_ThreadVC_screenCapturedDidChange);
        NullHookMessageIfPresent(threadVCClass, NSSelectorFromString(@"_userDidScreenRecord:"), (void *)hook_ThreadVC_userDidScreenRecord, &orig_ThreadVC_userDidScreenRecord);
        NullHookMessageIfPresent(threadVCClass, NSSelectorFromString(@"screenshotObserverDidSeeScreenRecord:"), (void *)hook_ThreadVC_screenshotObserverDidSeeScreenRecord, &orig_ThreadVC_screenshotObserverDidSeeScreenRecord);
        NullHookMessageIfPresent(threadVCClass, NSSelectorFromString(@"screenshotObserver:didChangeScreenCaptureState:"), (void *)hook_ThreadVC_screenshotObserverDidChangeScreenCaptureState, &orig_ThreadVC_screenshotObserverDidChangeScreenCaptureState);
    }

    // 5. Direct screenshot observer
    Class directScreenshotObsClass = objc_getClass("IGDirectScreenshotObserver");
    if (directScreenshotObsClass) {
        NullHookMessageIfPresent(directScreenshotObsClass, @selector(_onTakenScreenshot), (void *)hook_directObs_onTakenScreenshot, &orig_directObs_onTakenScreenshot);
        NullHookMessageIfPresent(directScreenshotObsClass, @selector(_didTakeScreenshot), (void *)hook_directObs_didTakeScreenshot, &orig_directObs_didTakeScreenshot);
        NullHookMessageIfPresent(directScreenshotObsClass, NSSelectorFromString(@"_screenCaptureStateDidChange:"), (void *)hook_directObs_screenCaptureStateDidChange, &orig_directObs_screenCaptureStateDidChange);
        NullHookMessageIfPresent(directScreenshotObsClass, NSSelectorFromString(@"_screenCapturedDidChange"), (void *)hook_directObs_screenCapturedDidChange, &orig_directObs_screenCapturedDidChange);
        NullHookMessageIfPresent(directScreenshotObsClass, NSSelectorFromString(@"screenshotObserverDidSeeScreenRecord:"), (void *)hook_directObs_screenshotObserverDidSeeScreenRecord, &orig_directObs_screenshotObserverDidSeeScreenRecord);
    }

    // 6. Generic Vanish/Disappearing screenshot trackers if present
    Class trackerClass = ThetaFirstClass(@[
        @"IGDirectScreenshotTracker",
        @"IGDirectDisappearingModeScreenshotTracker",
        @"IGDirectThreadVanishModeScreenshotObserver",
        @"IGDirectThreadScreenshotObserver"
    ]);
    if (trackerClass) {
        NullHookMessageIfPresent(trackerClass, @selector(_onTakenScreenshot), (void *)hook_tracker_onTakenScreenshot, &orig_tracker_onTakenScreenshot);
        NullHookMessageIfPresent(trackerClass, @selector(_didTakeScreenshot), (void *)hook_tracker_didTakeScreenshot, &orig_tracker_didTakeScreenshot);
        NullHookMessageIfPresent(trackerClass, NSSelectorFromString(@"_screenCaptureStateDidChange:"), (void *)hook_tracker_screenCaptureStateDidChange, &orig_tracker_screenCaptureStateDidChange);
    }
}