#import "Include/ThetaHelper.h"

static BOOL sVanishAlertShowing = NO;

static void theta_runVanishModeConfirmation(void (^invokeOrig)(void)) {
    if (!ENABLED(@"Disappearing DM Confirmation")) {
        invokeOrig();
        return;
    }
    if (sVanishAlertShowing) return;
    sVanishAlertShowing = YES;
    [ThetaHelper showCustomAlertWithActions:@"✋ Woah! Hold up!" description:@"Are you sure you want to toggle disappearing messages?" actions:@[
        @{
            @"title": @"Yes",
            @"handler": ^(__unused id sender) {
                sVanishAlertShowing = NO;
                invokeOrig();
            }
        },
        @{
            @"title": @"No",
            @"handler": ^(__unused id sender) {
                sVanishAlertShowing = NO;
            }
        }
    ]];
}

static void (*orig_handleBottomSwipeableScrollUpdate0)(id self, SEL _cmd);
static void hook_handleBottomSwipeableScrollUpdate0(id self, SEL _cmd) {
    if (!ENABLED(@"Disappearing DM Confirmation")) {
        if (orig_handleBottomSwipeableScrollUpdate0) orig_handleBottomSwipeableScrollUpdate0(self, _cmd);
        return;
    }
    theta_runVanishModeConfirmation(^{
        if (orig_handleBottomSwipeableScrollUpdate0) orig_handleBottomSwipeableScrollUpdate0(self, _cmd);
    });
}

static void (*orig_handleBottomSwipeableScrollUpdate1)(id self, SEL _cmd, id update);
static void hook_handleBottomSwipeableScrollUpdate1(id self, SEL _cmd, id update) {
    if (!ENABLED(@"Disappearing DM Confirmation")) {
        if (orig_handleBottomSwipeableScrollUpdate1) orig_handleBottomSwipeableScrollUpdate1(self, _cmd, update);
        return;
    }
    theta_runVanishModeConfirmation(^{
        if (orig_handleBottomSwipeableScrollUpdate1) orig_handleBottomSwipeableScrollUpdate1(self, _cmd, update);
    });
}

void THRegisterVanishModeConfirmationHooks(void) {
    Class c = ThetaFirstClass(@[
        @"_TtC32IGDirectDisappearingModeUI34IGDirectDisappearingModeSwipeHandler",
        @"_TtC35IGDirectDisappearingModeSwipeHandler35IGDirectDisappearingModeSwipeHandler",
        @"IGDirectDisappearingModeSwipeHandler"
    ]);
    if (!c)
        return;

    NullHookMessageIfPresent(c, @selector(handleBottomSwipeableScrollUpdate),
        (void *)hook_handleBottomSwipeableScrollUpdate0,
        &orig_handleBottomSwipeableScrollUpdate0);
    NullHookMessageIfPresent(c, @selector(handleBottomSwipeableScrollUpdate:),
        (void *)hook_handleBottomSwipeableScrollUpdate1,
        &orig_handleBottomSwipeableScrollUpdate1);
}
