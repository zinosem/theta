#import <objc/runtime.h>
#import <stdlib.h>

static void (*orig_deviceLockedStatusLogger)(id self, SEL _cmd, id source, id ndid, id extra);
static void hook_deviceLockedStatusLogger(id self, SEL _cmd, id source, id ndid, id extra) {
    NSLog(@"device status logger returning nothing");
    return;
}

static void (*orig_forcedLogoutPushHandler)(id self, SEL _cmd, id userID, id token, id authLoginType);
static void hook_forcedLogoutPushHandler(id self, SEL _cmd, id userID, id token, id authLoginType) {
    NSLog(@"forced logout push handler returning nothing");
    return;
}

static void (*orig_handleForcedLogoutLoginPush)(id self, SEL _cmd, id push, id presentedUserSession, id deviceSession, id appNavigationHandler, id completion);
static void hook_handleForcedLogoutLoginPush(id self, SEL _cmd, id push, id presentedUserSession, id deviceSession, id appNavigationHandler, id completion) {
    NSLog(@"handle forced logout login push returning nothing");
    if (completion) {
        ((void (^)(void))completion)();
    }
    return;
}

void THRegisterDeferredDBBHooks(void) {
    SEL sel = @selector(queryAndLogDeviceLockedStatusWithSource:ndid:extra:);
    const char *classNames[] = {
        "_TtC24DeviceLockedStatusLogger26IGDeviceLockedStatusLogger",
        "IGDeviceLockedStatusLogger",
        NULL
    };
    for (int i = 0; classNames[i]; i++) {
        Class c = objc_getClass(classNames[i]);
        if (c && class_getInstanceMethod(c, sel)) {
            NullHookMessageEx(c, sel, (void *)hook_deviceLockedStatusLogger, (void *)&orig_deviceLockedStatusLogger);
            break;
        }
    }

    SEL selPush = @selector(_handleForcedLogoutLoginPush:presentedUserSession:deviceSession:appNavigationHandler:completion:);
    SEL selForce = @selector(handleForceLogoutLoginWithUserID:token:authLoginType:);

    BOOL didHookPush = NO;
    BOOL didHookForce = NO;
    const char *pushHandlerNames[] = {
        "_TtC17IGPushCoordinator25IGForcedLogoutPushHandler",
        "IGForcedLogoutPushHandler",
        NULL
    };
    for (int i = 0; pushHandlerNames[i]; i++) {
        Class pushHandler = objc_getClass(pushHandlerNames[i]);
        if (!pushHandler) continue;
        if (!didHookForce && class_getInstanceMethod(pushHandler, selForce)) {
            NullHookMessageIfPresent(pushHandler, selForce, (void *)hook_forcedLogoutPushHandler, (void *)&orig_forcedLogoutPushHandler);
            didHookForce = YES;
        }
        if (!didHookPush && class_getInstanceMethod(pushHandler, selPush)) {
            NullHookMessageIfPresent(pushHandler, selPush, (void *)hook_handleForcedLogoutLoginPush, (void *)&orig_handleForcedLogoutLoginPush);
            didHookPush = YES;
        }
    }
}