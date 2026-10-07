#import "Include/ThetaHelper.h"

static void (*orig_followConfirmation)(id self, SEL _cmd);
static void (*orig_followConfirmation_arg)(id self, SEL _cmd, id sender);

static void theta_handleFollowConfirmation(id self, void (^proceedBlock)(void)) {
    if (!ENABLED(@"Follow Confirmation")) {
        if (proceedBlock) proceedBlock();
        return;
    }

    NSInteger userFollowStatus = 2; // Default to Not Following (triggers confirmation)
    @try {
        id user = nil;
        if ([self respondsToSelector:@selector(user)]) {
            user = [self performSelector:@selector(user)];
        } else if ([self respondsToSelector:@selector(valueForKey:)]) {
            user = [self valueForKey:@"user"];
        }
        if (user) {
            id statusVal = nil;
            if ([user respondsToSelector:@selector(followStatus)]) {
                statusVal = [user valueForKey:@"followStatus"];
            } else if ([user respondsToSelector:@selector(valueForKey:)]) {
                statusVal = [user valueForKey:@"followStatus"];
            }
            if (statusVal) {
                userFollowStatus = [statusVal integerValue];
            }
        }
    } @catch (__unused NSException *e) {
        userFollowStatus = 2;
    }

    // Status 3 is Already Following, Status 4 is Requested.
    // If not already following (Status == 2 or <= 2), prompt before following.
    if (userFollowStatus == 2 || userFollowStatus == 0 || userFollowStatus == 1) {
        [ThetaHelper showCustomAlertWithActions:@"✋ Woah! Hold up!" description:@"Are you sure you want to follow this user?" actions:@[
            @{
                @"title": @"Yes, follow them!",
                @"handler": ^(__unused id sender) {
                    if (proceedBlock) proceedBlock();
                }
            },
            @{
                @"title": @"No, I'm good.",
                @"handler": ^(__unused id sender) {
                    // Do nothing, cancel
                }
            }
        ]];
    } else {
        if (proceedBlock) proceedBlock();
    }
}

static void hook_followConfirmation(id self, SEL _cmd) {
    theta_handleFollowConfirmation(self, ^{
        if (orig_followConfirmation) orig_followConfirmation(self, _cmd);
    });
}

static void hook_followConfirmation_arg(id self, SEL _cmd, id sender) {
    theta_handleFollowConfirmation(self, ^{
        if (orig_followConfirmation_arg) orig_followConfirmation_arg(self, _cmd, sender);
    });
}

void THRegisterFollowConfirmationHooks(void) {
    Class followController = ThetaFirstClass(@[
        @"_TtC16IGFollowController18IGFollowController",
        @"IGFollowController"
    ]);
    if (followController) {
        NullHookMessageIfPresent(followController, @selector(_didPressFollowButton), (void *)hook_followConfirmation, &orig_followConfirmation);
        NullHookMessageIfPresent(followController, @selector(didPressFollowButton), (void *)hook_followConfirmation, &orig_followConfirmation);
        NullHookMessageIfPresent(followController, @selector(_didPressFollowButton:), (void *)hook_followConfirmation_arg, &orig_followConfirmation_arg);
        NullHookMessageIfPresent(followController, @selector(didPressFollowButton:), (void *)hook_followConfirmation_arg, &orig_followConfirmation_arg);
    }
}