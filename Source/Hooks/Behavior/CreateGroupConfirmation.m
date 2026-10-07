#import "Include/ThetaHelper.h"

static void theta_runCreateGroupConfirmation(void (^invokeOrig)(void)) {
    if (!ENABLED(@"Create Group Confirmation")) {
        invokeOrig();
        return;
    }
    [ThetaHelper showCustomAlertWithActions:@"✋ Woah! Hold up!" description:@"Are you sure you want to create a group?" actions:@[
        @{ @"title": @"Yes, create it!", @"handler": ^(id sender) { invokeOrig(); } },
        @{ @"title": @"No, cancel.", @"handler": ^(id sender) { } },
    ]];
}

static void (*orig_createGroupConfirmation)(id self, SEL _cmd, id arg1);
static void hook_createGroupConfirmation(id self, SEL _cmd, id arg1) {
    theta_runCreateGroupConfirmation(^{ if (orig_createGroupConfirmation) orig_createGroupConfirmation(self, _cmd, arg1); });
}

void THRegisterCreateGroupConfirmationHooks(void) {
    Class bottomButtons = ThetaFirstClass(@[
        @"_TtC12IGShareSheet27IGSharesheetBottomButtonsView",
        @"IGShareSheet.IGSharesheetBottomButtonsView",
        @"IGSharesheetBottomButtonsView"
    ]);
    if (bottomButtons) {
        NullHookMessageIfPresent(bottomButtons, @selector(secondaryButtonTappedWithButton:), (void *)hook_createGroupConfirmation, &orig_createGroupConfirmation);
    }
}
