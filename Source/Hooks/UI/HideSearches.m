#import "Include/ThetaTweakCommon.h"

static void (*orig_recentSearchStore_addItem)(id self, SEL _cmd, id item);
static void hook_recentSearchStore_addItem(id self, SEL _cmd, id item) {
    if (ENABLED(@"Hide Recent Searches")) {
        return;
    }
    if (orig_recentSearchStore_addItem) {
        orig_recentSearchStore_addItem(self, _cmd, item);
    }
}

static void (*orig_recentSearchStore_addItems)(id self, SEL _cmd, id items);
static void hook_recentSearchStore_addItems(id self, SEL _cmd, id items) {
    if (ENABLED(@"Hide Recent Searches")) {
        return;
    }
    if (orig_recentSearchStore_addItems) {
        orig_recentSearchStore_addItems(self, _cmd, items);
    }
}

static NSArray *(*orig_recentSearchStore_recentSearches)(id self, SEL _cmd);
static NSArray *hook_recentSearchStore_recentSearches(id self, SEL _cmd) {
    if (ENABLED(@"Hide Recent Searches")) {
        return @[];
    }
    return orig_recentSearchStore_recentSearches ? orig_recentSearchStore_recentSearches(self, _cmd) : @[];
}

static NSArray *(*orig_recentSearchStore_items)(id self, SEL _cmd);
static NSArray *hook_recentSearchStore_items(id self, SEL _cmd) {
    if (ENABLED(@"Hide Recent Searches")) {
        return @[];
    }
    return orig_recentSearchStore_items ? orig_recentSearchStore_items(self, _cmd) : @[];
}

void THRegisterHideSearchesRecentStoreHooks(void) {
    Class store = ThetaFirstClass(@[
        @"IGRecentSearchStore",
        @"_TtC19IGRecentSearchStore19IGRecentSearchStore"
    ]);
    if (store) {
        NullHookMessageIfPresent(store, @selector(addItem:), (void *)hook_recentSearchStore_addItem, &orig_recentSearchStore_addItem);
        NullHookMessageIfPresent(store, @selector(addItems:), (void *)hook_recentSearchStore_addItems, &orig_recentSearchStore_addItems);
        NullHookMessageIfPresent(store, @selector(recentSearches), (void *)hook_recentSearchStore_recentSearches, &orig_recentSearchStore_recentSearches);
        NullHookMessageIfPresent(store, @selector(items), (void *)hook_recentSearchStore_items, &orig_recentSearchStore_items);
    }
}