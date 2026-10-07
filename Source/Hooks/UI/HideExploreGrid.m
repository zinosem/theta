#import "Include/ThetaTweakCommon.h"

static void (*orig_hideExploreGrid)(id self, SEL _cmd);
static void hook_hideExploreGrid(id self, SEL _cmd) {
    if (orig_hideExploreGrid) orig_hideExploreGrid(self, _cmd);

    if (ENABLED(@"Hide Explore Grid")) {
        UIResponder *responder = self;
        while ((responder = [responder nextResponder])) {
            if ([responder isKindOfClass:[UIViewController class]]) {
                break;
            }
        }
        if (responder) {
            NSString *className = NSStringFromClass([responder class]);
            if ([className containsString:@"ExploreGridViewController"] ||
                [className containsString:@"ExploreViewController"]) {
                [self setHidden:YES];
            }
        }
    }
}

void THRegisterHideExploreGridHooks(void) {
    Class collectionView = ThetaFirstClass(@[
        @"IGListCollectionView",
        @"_TtC20IGListCollectionView20IGListCollectionView"
    ]);
    if (collectionView) {
        NullHookMessageIfPresent(collectionView, @selector(layoutSubviews), (void *)hook_hideExploreGrid, &orig_hideExploreGrid);
    }
}