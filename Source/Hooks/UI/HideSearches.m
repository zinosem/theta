static void (*orig_recentSearchStore)(id self, SEL _cmd, id item);
static void hook_recentSearchStore(id self, SEL _cmd, id item) {
    if (ENABLED(@"Hide Recent Searches")) {
        if ([item isKindOfClass:NSClassFromString(@"IGUser")]) {
            return;
        }
    }
    if (orig_recentSearchStore) {
        orig_recentSearchStore(self, _cmd, item);
    }
}

void THRegisterHideSearchesRecentStoreHooks(void) {
    NullHookMessageIfPresent(objc_getClass("IGRecentSearchStore"), @selector(addItem:), (void *)hook_recentSearchStore, &orig_recentSearchStore);
}