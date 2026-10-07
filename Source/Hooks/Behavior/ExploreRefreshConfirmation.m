#import "Include/ThetaHelper.h"

static void (*orig_exploreRefresh)(id self, SEL _cmd, id arg1);
static void (*orig_exploreRefresh_noarg)(id self, SEL _cmd);

static void theta_promptExploreRefresh(id self, void (^proceed)(void)) {
    if (!ENABLED(@"Explore Refresh Confirmation")) {
        if (proceed) proceed();
        return;
    }

    [ThetaHelper showCustomAlertWithActions:@"✋ Woah! Hold up!" description:@"Are you sure you want to refresh the Explore page?" actions:@[
        @{
            @"title": @"Yes, refresh it!",
            @"handler": ^(__unused id sender) {
                if (proceed) proceed();
                if (ENABLED(@"Show Banners")) {
                    [ThetaHelper showToastWithTitle:@"Refreshing now!" subtitle:@"This will only take a second." icon:[ThetaHelper imageFromEmojiString:@"🔄" width:60] autoHide:4 openURL:nil];
                }
            }
        },
        @{
            @"title": @"No, I'm good.",
            @"handler": ^(__unused id sender) {
            }
        }
    ]];
}

static void hook_exploreRefresh(id self, SEL _cmd, id arg1) {
    theta_promptExploreRefresh(self, ^{
        if (orig_exploreRefresh) orig_exploreRefresh(self, _cmd, arg1);
    });
}

static void hook_exploreRefresh_noarg(id self, SEL _cmd) {
    theta_promptExploreRefresh(self, ^{
        if (orig_exploreRefresh_noarg) orig_exploreRefresh_noarg(self, _cmd);
    });
}

void THRegisterExploreRefreshConfirmationHooks(void) {
    Class exploreVC = ThetaFirstClass(@[
        @"_TtC9IGExplore27IGExploreGridViewController",
        @"_TtC11IGExploreUI27IGExploreGridViewController",
        @"IGExploreGridViewController",
        @"_TtC9IGExplore23IGExploreViewController",
        @"IGExploreViewController"
    ]);
    if (exploreVC) {
        NullHookMessageIfPresent(exploreVC, @selector(_handleRefreshControlTriggered:), (void *)hook_exploreRefresh, &orig_exploreRefresh);
        NullHookMessageIfPresent(exploreVC, @selector(handleRefreshControlTriggered:), (void *)hook_exploreRefresh, &orig_exploreRefresh);
        NullHookMessageIfPresent(exploreVC, @selector(_handleRefreshControlTriggered), (void *)hook_exploreRefresh_noarg, &orig_exploreRefresh_noarg);
        NullHookMessageIfPresent(exploreVC, @selector(handleRefreshControlTriggered), (void *)hook_exploreRefresh_noarg, &orig_exploreRefresh_noarg);
    }
}