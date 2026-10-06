#import "Include/SettingsViewController.h"
#import "Include/ThetaTweakCommon.h"
#import <objc/runtime.h>

static void (*orig_tabbar)(id self, SEL _cmd, id sender);
static void (*orig_layoutTabBar)(id self, SEL _cmd);

static const void *kThetaMessengerSettingsLPKey = &kThetaMessengerSettingsLPKey;

@interface ThetaMessengerSettingsLongPressTarget : NSObject
@end

@implementation ThetaMessengerSettingsLongPressTarget

- (void)handleDMLongPress:(UILongPressGestureRecognizer *)gr {
    if (gr.state != UIGestureRecognizerStateBegan) {
        return;
    }
    [ThetaHelper presentSettings];
}

@end

static ThetaMessengerSettingsLongPressTarget *theta_messengerSettingsLPTarget(void) {
    static ThetaMessengerSettingsLongPressTarget *target;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        target = [ThetaMessengerSettingsLongPressTarget new];
    });
    return target;
}

static void theta_detachMessengerSettingsLongPressFromDirectInbox(id tabBarController) {
    UIView *dm = nil;
    @try {
        dm = [tabBarController valueForKey:@"_directInboxButton"];
    } @catch (__unused NSException *e) {
    }
    if (![dm isKindOfClass:[UIView class]]) {
        return;
    }
    UILongPressGestureRecognizer *existing = objc_getAssociatedObject(dm, kThetaMessengerSettingsLPKey);
    if (existing) {
        [dm removeGestureRecognizer:existing];
        objc_setAssociatedObject(dm, kThetaMessengerSettingsLPKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void theta_attachMessengerSettingsLongPressToDirectInboxIfNeeded(id tabBarController) {
    if (!ENABLED(@"Messenger Mode")) {
        theta_detachMessengerSettingsLongPressFromDirectInbox(tabBarController);
        return;
    }
    UIView *dm = nil;
    @try {
        dm = [tabBarController valueForKey:@"_directInboxButton"];
    } @catch (__unused NSException *e) {
    }
    if (![dm isKindOfClass:[UIView class]]) {
        return;
    }
    if (objc_getAssociatedObject(dm, kThetaMessengerSettingsLPKey)) {
        return;
    }
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:theta_messengerSettingsLPTarget()
                                                                                      action:@selector(handleDMLongPress:)];
    lp.minimumPressDuration = 0.5;
    [dm addGestureRecognizer:lp];
    objc_setAssociatedObject(dm, kThetaMessengerSettingsLPKey, lp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void hook_layoutTabBar(id self, SEL _cmd) {
    orig_layoutTabBar(self, _cmd);
    theta_attachMessengerSettingsLongPressToDirectInboxIfNeeded(self);
}

static void hook_tabbar(id self, SEL _cmd, id sender) {
    if ([sender isKindOfClass:[UIGestureRecognizer class]]) {
        UIGestureRecognizer *gr = (UIGestureRecognizer *)sender;
        if (gr.state != UIGestureRecognizerStateBegan) {
            return;
        }
    }
    if (ENABLED(@"Messenger Mode")) {
        if (orig_tabbar) {
            orig_tabbar(self, _cmd, sender);
        }
        return;
    }
    [ThetaHelper presentSettings];
}

void THRegisterTabBarHooks(void) {
    Class cls = objc_getClass("IGTabBarController");
    NullHookMessageEx(cls, @selector(_homeButtonLongPressed:), (void *)hook_tabbar, &orig_tabbar);
    NullHookMessageEx(cls, @selector(_layoutTabBar), (void *)hook_layoutTabBar, &orig_layoutTabBar);
}
