#import "Include/ThetaTweakCommon.h"

static void (*orig_hideTypingIndicator4)(id self, SEL _cmd, BOOL updateOutgoingStatusIsActive, id threadKey, id threadMetadata, NSInteger typingStatusType);
static void hook_hideTypingIndicator4(id self, SEL _cmd, BOOL updateOutgoingStatusIsActive, id threadKey, id threadMetadata, NSInteger typingStatusType) {
    if (ENABLED(@"Hide Typing Indicator") && updateOutgoingStatusIsActive) {
        return;
    }
    if (orig_hideTypingIndicator4) orig_hideTypingIndicator4(self, _cmd, updateOutgoingStatusIsActive, threadKey, threadMetadata, typingStatusType);
}

static void (*orig_hideTypingIndicator3)(id self, SEL _cmd, BOOL updateOutgoingStatusIsActive, id threadKey, NSInteger typingStatusType);
static void hook_hideTypingIndicator3(id self, SEL _cmd, BOOL updateOutgoingStatusIsActive, id threadKey, NSInteger typingStatusType) {
    if (ENABLED(@"Hide Typing Indicator") && updateOutgoingStatusIsActive) {
        return;
    }
    if (orig_hideTypingIndicator3) orig_hideTypingIndicator3(self, _cmd, updateOutgoingStatusIsActive, threadKey, typingStatusType);
}

static void (*orig_hideTypingIndicator2)(id self, SEL _cmd, BOOL updateOutgoingStatusIsActive, id threadKey);
static void hook_hideTypingIndicator2(id self, SEL _cmd, BOOL updateOutgoingStatusIsActive, id threadKey) {
    if (ENABLED(@"Hide Typing Indicator") && updateOutgoingStatusIsActive) {
        return;
    }
    if (orig_hideTypingIndicator2) orig_hideTypingIndicator2(self, _cmd, updateOutgoingStatusIsActive, threadKey);
}

void THRegisterHideTypingIndicatorHooks(void) {
    Class service = ThetaFirstClass(@[
        @"_TtC27IGDirectTypingStatusService27IGDirectTypingStatusService",
        @"IGDirectTypingStatusService",
        @"_TtC26IGDirectTypingStatusSender26IGDirectTypingStatusSender",
        @"IGDirectTypingStatusSender"
    ]);
    if (service) {
        NullHookMessageIfPresent(service, @selector(updateOutgoingStatusIsActive:threadKey:threadMetadata:typingStatusType:), (void *)hook_hideTypingIndicator4, &orig_hideTypingIndicator4);
        NullHookMessageIfPresent(service, @selector(updateOutgoingStatusIsActive:threadKey:typingStatusType:), (void *)hook_hideTypingIndicator3, &orig_hideTypingIndicator3);
        NullHookMessageIfPresent(service, @selector(updateOutgoingStatusIsActive:threadKey:), (void *)hook_hideTypingIndicator2, &orig_hideTypingIndicator2);
    }
}