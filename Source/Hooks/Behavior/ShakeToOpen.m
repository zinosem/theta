static void (*orig_shakeToOpen)(id self, SEL _cmd, int arg1);
static void hook_shakeToOpen(id self, SEL _cmd, int arg1) {
    @try {
        if (!ENABLED(@"Shake To Open")) {
            orig_shakeToOpen(self, _cmd, arg1);
            return;
        }
        
        if (arg1 == 1) {
            [ThetaHelper presentSettings];
        }
    } @catch (NSException *exception) {
        NSLog(@"Error in shake to open: %@", exception);
        // Fallback to original behavior
        orig_shakeToOpen(self, _cmd, arg1);
    }
}

void THRegisterShakeToOpenHooks(void) {
    NullHookMessageEx(objc_getClass("UIMotionEvent"), @selector(setShakeState:), (void *)hook_shakeToOpen, &orig_shakeToOpen);
}