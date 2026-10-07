#import "Include/ThetaHelper.h"

static void theta_runCallConfirmation(NSString *description, void (^invokeOrig)(void)) {
    if (!ENABLED(@"Call Confirmation")) {
        invokeOrig();
        return;
    }
    [ThetaHelper showCustomAlertWithActions:@"✋ Woah! Hold up!" description:description actions:@[
        @{ @"title": @"Yes, call them!", @"handler": ^(id sender) { invokeOrig(); } },
        @{ @"title": @"No, cancel.", @"handler": ^(id sender) { } },
    ]];
}

static void (*orig_audioCallConfirmation)(id self, SEL _cmd, id arg1);
static void hook_audioCallConfirmation(id self, SEL _cmd, id arg1) {
    theta_runCallConfirmation(@"Are you sure you want to call this user?", ^{ if (orig_audioCallConfirmation) orig_audioCallConfirmation(self, _cmd, arg1); });
}

static void (*orig_videoCallConfirmation)(id self, SEL _cmd, id arg1);
static void hook_videoCallConfirmation(id self, SEL _cmd, id arg1) {
    theta_runCallConfirmation(@"Are you sure you want to video call this user?", ^{ if (orig_videoCallConfirmation) orig_videoCallConfirmation(self, _cmd, arg1); });
}

static void (*orig_audioCallConfirmation2)(id self, SEL _cmd);
static void hook_audioCallConfirmation2(id self, SEL _cmd) {
    theta_runCallConfirmation(@"Are you sure you want to call this user?", ^{ if (orig_audioCallConfirmation2) orig_audioCallConfirmation2(self, _cmd); });
}

static void (*orig_videoCallConfirmation2)(id self, SEL _cmd);
static void hook_videoCallConfirmation2(id self, SEL _cmd) {
    theta_runCallConfirmation(@"Are you sure you want to video call this user?", ^{ if (orig_videoCallConfirmation2) orig_videoCallConfirmation2(self, _cmd); });
}

void THRegisterCallConfirmationHooks(void) {
    Class klass = objc_getClass("IGDirectThreadCallButtonsCoordinator");
    if (klass) {
        NullHookMessageIfPresent(klass, @selector(_didTapAudioButton:), (void *)hook_audioCallConfirmation, &orig_audioCallConfirmation);
        NullHookMessageIfPresent(klass, @selector(_didTapVideoButton:), (void *)hook_videoCallConfirmation, &orig_videoCallConfirmation);
        NullHookMessageIfPresent(klass, @selector(_didTapAudioButton), (void *)hook_audioCallConfirmation2, &orig_audioCallConfirmation2);
        NullHookMessageIfPresent(klass, @selector(_didTapVideoButton), (void *)hook_videoCallConfirmation2, &orig_videoCallConfirmation2);
    }
}
