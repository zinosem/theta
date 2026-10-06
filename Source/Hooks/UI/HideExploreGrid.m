static void (*orig_hideExploreGrid)(id self, SEL _cmd);
static void hook_hideExploreGrid(id self, SEL _cmd) {
    orig_hideExploreGrid(self, _cmd);

    if (ENABLED(@"Hide Explore Grid")) {
        UIResponder *responder = self;
        while ((responder = [responder nextResponder])) {
            if ([responder isKindOfClass:[UIViewController class]]) {
                break;
            }
        }
        if ([responder isKindOfClass:NSClassFromString(@"IGExploreGridViewController")]) {
            [self setHidden:YES];
        }
    }
}

void THRegisterHideExploreGridHooks(void) {
    NullHookMessageEx(objc_getClass("IGListCollectionView"), @selector(layoutSubviews), (void *)hook_hideExploreGrid, &orig_hideExploreGrid);
}