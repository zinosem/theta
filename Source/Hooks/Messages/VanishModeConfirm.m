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

static void (*orig_handleBottomSwipeableScrollUpdate)(id self, SEL _cmd);
static void hook_handleBottomSwipeableScrollUpdate(id self, SEL _cmd) {
    theta_runVanishModeConfirmation(^{ if (orig_handleBottomSwipeableScrollUpdate) orig_handleBottomSwipeableScrollUpdate(self, _cmd); });
}

void THRegisterVanishModeConfirmationHooks(void) {
    Class c = objc_getClass("IGDirectDisappearingModeSwipeHandler");
    if (!c)
        return;
    NullHookMessageEx(c, @selector(handleBottomSwipeableScrollUpdate), (void *)hook_handleBottomSwipeableScrollUpdate,
                      &orig_handleBottomSwipeableScrollUpdate);
}
