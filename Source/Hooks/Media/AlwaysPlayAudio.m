#import "Include/ThetaTweakCommon.h"
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

static BOOL (*orig_setCategory_error)(AVAudioSession *self, SEL _cmd, AVAudioSessionCategory category, NSError **outError);
static BOOL hook_setCategory_error(AVAudioSession *self, SEL _cmd, AVAudioSessionCategory category, NSError **outError) {
    if (ENABLED(@"Always Play Audio")) {
        if ([category isEqualToString:AVAudioSessionCategoryAmbient] || 
            [category isEqualToString:AVAudioSessionCategorySoloAmbient]) {
            category = AVAudioSessionCategoryPlayback;
        }
    }
    if (orig_setCategory_error) {
        return orig_setCategory_error(self, _cmd, category, outError);
    }
    return YES;
}

static BOOL (*orig_setCategory_options_error)(AVAudioSession *self, SEL _cmd, AVAudioSessionCategory category, AVAudioSessionCategoryOptions options, NSError **outError);
static BOOL hook_setCategory_options_error(AVAudioSession *self, SEL _cmd, AVAudioSessionCategory category, AVAudioSessionCategoryOptions options, NSError **outError) {
    if (ENABLED(@"Always Play Audio")) {
        if ([category isEqualToString:AVAudioSessionCategoryAmbient] || 
            [category isEqualToString:AVAudioSessionCategorySoloAmbient]) {
            category = AVAudioSessionCategoryPlayback;
            options |= AVAudioSessionCategoryOptionMixWithOthers;
        }
    }
    if (orig_setCategory_options_error) {
        return orig_setCategory_options_error(self, _cmd, category, options, outError);
    }
    return YES;
}

static BOOL (*orig_setCategory_mode_options_error)(AVAudioSession *self, SEL _cmd, AVAudioSessionCategory category, AVAudioSessionMode mode, AVAudioSessionCategoryOptions options, NSError **outError);
static BOOL hook_setCategory_mode_options_error(AVAudioSession *self, SEL _cmd, AVAudioSessionCategory category, AVAudioSessionMode mode, AVAudioSessionCategoryOptions options, NSError **outError) {
    if (ENABLED(@"Always Play Audio")) {
        if ([category isEqualToString:AVAudioSessionCategoryAmbient] || 
            [category isEqualToString:AVAudioSessionCategorySoloAmbient]) {
            category = AVAudioSessionCategoryPlayback;
            options |= AVAudioSessionCategoryOptionMixWithOthers;
        }
    }
    if (orig_setCategory_mode_options_error) {
        return orig_setCategory_mode_options_error(self, _cmd, category, mode, options, outError);
    }
    return YES;
}

void THRegisterAlwaysPlayAudioHooks(void) {
    Class avSessionCls = [AVAudioSession class];
    if (!avSessionCls) return;

    NullHookMessageEx(avSessionCls, @selector(setCategory:error:), (void *)hook_setCategory_error, &orig_setCategory_error);
    NullHookMessageEx(avSessionCls, @selector(setCategory:withOptions:error:), (void *)hook_setCategory_options_error, &orig_setCategory_options_error);
    NullHookMessageEx(avSessionCls, @selector(setCategory:mode:options:error:), (void *)hook_setCategory_mode_options_error, &orig_setCategory_mode_options_error);
}
