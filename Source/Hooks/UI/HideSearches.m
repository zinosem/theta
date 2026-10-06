static BOOL (*orig_recentSearchStore)(id self, SEL _cmd, id item);
static BOOL hook_recentSearchStore(id self, SEL _cmd, id item) {
    if (ENABLED(@"Hide Recent Searches")) {
        if ([item isKindOfClass:NSClassFromString(@"IGUser")]) {
            return NO;
        }
    }
    if (orig_recentSearchStore) {
        return orig_recentSearchStore(self, _cmd, item);
    }
    return YES;
}

void THRegisterHideSearchesRecentStoreHooks(void) {
    NullHookMessageIfPresent(objc_getClass("IGRecentSearchStore"), @selector(addItem:), (void *)hook_recentSearchStore, &orig_recentSearchStore);
}