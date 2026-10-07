static void (*orig_hideCreateGroupButton)(id self, SEL _cmd, id button);
static void hook_hideCreateGroupButton(id self, SEL _cmd, id button) {
    if (!ENABLED(@"Hide \"Create Group\" Button")) {
        if (orig_hideCreateGroupButton) orig_hideCreateGroupButton(self, _cmd, button);
        return;
    }
}

static void (*orig_hideCreateGroupButton2)(id self, SEL _cmd, BOOL enabled, BOOL animated);
static void hook_hideCreateGroupButton2(id self, SEL _cmd, BOOL enabled, BOOL animated) {
    if (!ENABLED(@"Hide \"Create Group\" Button")) {
        if (orig_hideCreateGroupButton2) orig_hideCreateGroupButton2(self, _cmd, enabled, animated);
        return;
    }
}

static void (*orig_hideCreateGroupButton3)(id self, SEL _cmd);
static void hook_hideCreateGroupButton3(id self, SEL _cmd) {
    if (orig_hideCreateGroupButton3) orig_hideCreateGroupButton3(self, _cmd);
    if (ENABLED(@"Hide \"Create Group\" Button")) {
        [self setHidden:YES];
    }
}

void THRegisterHideCreateGroupButtonHooks(void) {
    Class bottomButtons = ThetaFirstClass(@[
        @"_TtC12IGShareSheet27IGSharesheetBottomButtonsView",
        @"IGShareSheet.IGSharesheetBottomButtonsView"
    ]);
    NullHookMessageIfPresent(bottomButtons, @selector(secondaryButtonTappedWithButton:), (void *)hook_hideCreateGroupButton, &orig_hideCreateGroupButton);

    Class bottomContainer = ThetaFirstClass(@[
        @"_TtC12IGShareSheet39IGShareSheetBottomButtonsViewContainer",
        @"IGShareSheet.IGShareSheetBottomButtonsViewContainer"
    ]);
    NullHookMessageIfPresent(bottomContainer, @selector(setSecondaryButtonEnabled:animated:), (void *)hook_hideCreateGroupButton2, &orig_hideCreateGroupButton2);

    Class facepile = ThetaFirstClass(@[
        @"_TtC12IGShareSheet45IGShareSheetCreateOrSendToGroupFacepileButton",
        @"IGShareSheet.IGShareSheetCreateOrSendToGroupFacepileButton"
    ]);
    NullHookMessageIfPresent(facepile, @selector(layoutSubviews), (void *)hook_hideCreateGroupButton3, &orig_hideCreateGroupButton3);
}