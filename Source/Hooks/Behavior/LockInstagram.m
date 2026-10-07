#import "Include/ThetaHelper.h"
#import "Include/SecurityViewController.h"

static BOOL isAuthenticationShowed = FALSE;

static void theta_presentLockIfEnabled(void) {
    if (!ENABLED(@"Lock Instagram") || isAuthenticationShowed) return;

    UIViewController *topController = [ThetaHelper topViewController];
    if (!topController) {
        UIWindow *window = [ThetaHelper activeKeyWindow];
        topController = window.rootViewController;
    }
    if (topController && ![topController isKindOfClass:NSClassFromString(@"SecurityViewController")]) {
        SecurityViewController *securityViewController = [SecurityViewController new];
        securityViewController.modalPresentationStyle = UIModalPresentationOverFullScreen;
        [topController presentViewController:securityViewController animated:YES completion:nil];
        isAuthenticationShowed = TRUE;
    }
}

static void (*orig_applicationDidBecomeActive)(id self, SEL _cmd, id arg1);
static void hook_applicationDidBecomeActive(id self, SEL _cmd, id arg1) {
    if (orig_applicationDidBecomeActive) orig_applicationDidBecomeActive(self, _cmd, arg1);
    theta_presentLockIfEnabled();
}

static void (*orig_applicationWillEnterForeground)(id self, SEL _cmd, id arg1);
static void hook_applicationWillEnterForeground(id self, SEL _cmd, id arg1) {
    if (orig_applicationWillEnterForeground) orig_applicationWillEnterForeground(self, _cmd, arg1);
    isAuthenticationShowed = FALSE;
}

void THRegisterLockInstagramHooks(void) {
    Class appDelegate = objc_getClass("IGInstagramAppDelegate");
    if (appDelegate) {
        NullHookMessageIfPresent(appDelegate, @selector(applicationDidBecomeActive:), (void *)hook_applicationDidBecomeActive, &orig_applicationDidBecomeActive);
        NullHookMessageIfPresent(appDelegate, @selector(applicationWillEnterForeground:), (void *)hook_applicationWillEnterForeground, &orig_applicationWillEnterForeground);
    }

    // Modern iOS scene lifecycle support: observe app becoming active directly
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(__unused NSNotification *note) {
        theta_presentLockIfEnabled();
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(__unused NSNotification *note) {
        isAuthenticationShowed = FALSE;
    }];
}