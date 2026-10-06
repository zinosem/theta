#import "Include/ThetaHelper.h"
#import "Include/SettingsViewController.h"
#import "Include/InstagramHeaders.h"
#import "Include/CustomToastView.h"
#import <AudioToolbox/AudioToolbox.h>

#define ENABLED(setting) [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"%@_Enabled", setting]]

@implementation ThetaHelper

static volatile BOOL sGlobalDownloadInProgress = NO;

#pragma mark - Constants

+ (UIColor *)iotaPinkColor {
    return [UIColor colorWithRed:1.0 green:0.412 blue:0.706 alpha:1.0];
}

+ (NSTimeInterval)cooldownPeriod {
    return 30.0;
}

+(NSString *)hexFromColour:(UIColor *)colour {
	CGFloat red, green, blue, alpha;
	[colour getRed:&red green:&green blue:&blue alpha:&alpha];
	return [NSString stringWithFormat:@"%02lX%02lX%02lX", lroundf(red * 255), lroundf(green * 255), lroundf(blue * 255)];
}

+(UIColor *)colourFromHex:(NSString *)hexString {
	if (hexString && hexString.length > 0) {
		unsigned rgbValue = 0;
		NSScanner *scanner = [NSScanner scannerWithString:hexString];
		[scanner scanHexInt:&rgbValue];
		return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0x00FF00) >> 8)/255.0 blue:(rgbValue & 0x0000FF)/255.0 alpha:1.0];
	}
	return [UIColor labelColor];
}

#pragma mark - Alert Management

+ (void)showCustomAlertWithActions:(NSString *)title description:(NSString *)description actions:(NSArray<NSDictionary *> *)actions {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            Class actionCls = NSClassFromString(@"IGCustomAlertAction");
            Class alertCls = NSClassFromString(@"IGDSAlertDialogView");
            if (!actionCls || !alertCls) {
                // Fallback so story mentions / long-press menus still work if IG DS alert classes move.
                UIAlertController *ac = [UIAlertController alertControllerWithTitle:title message:description preferredStyle:UIAlertControllerStyleAlert];
                for (NSDictionary *actionDict in actions) {
                    NSString *titleText = actionDict[@"title"] ?: @"OK";
                    UIAlertActionStyle style = UIAlertActionStyleDefault;
                    if ([titleText isEqualToString:@"Cancel"] || [titleText isEqualToString:@"No, cancel."] ||
                        [titleText isEqualToString:@"No, I'm good."] || [titleText isEqualToString:@"No"]) {
                        style = UIAlertActionStyleCancel;
                    }
                    void (^handler)(id) = actionDict[@"handler"];
                    [ac addAction:[UIAlertAction actionWithTitle:titleText style:style handler:^(UIAlertAction *a) {
                        if (handler) {
                            @try { handler(a); } @catch (__unused NSException *e) {}
                        }
                    }]];
                }
                UIViewController *top = [self topViewController];
                if (top) [top presentViewController:ac animated:YES completion:nil];
                return;
            }

            NSMutableArray *buttons = [NSMutableArray array];
            for (NSDictionary *actionDict in actions) {
                id action = [[actionCls alloc] init];
                @try { [action setValue:actionDict[@"handler"] forKey:@"handler"]; } @catch (__unused NSException *e) {}
                @try { [action setValue:actionDict[@"title"] forKey:@"title"]; } @catch (__unused NSException *e) {}
                
                NSString *titleText = actionDict[@"title"];
                if ([titleText isEqualToString:@"No, cancel."] || 
                    [titleText isEqualToString:@"Cancel"] || 
                    [titleText isEqualToString:@"No, I'm good."] || 
                    [titleText isEqualToString:@"No"]) {
                    @try { [action setValue:@4 forKey:@"style"]; } @catch (__unused NSException *e) {}
                }
                if (action) [buttons addObject:action];
            }
            
            id alert = [[alertCls alloc] initWithStyle:@1 titleText:title descriptionText:description actions:buttons showHorizontalButtons:NO];
            NSArray *buttonsArray = nil;
            @try { buttonsArray = [alert valueForKey:@"buttons"]; } @catch (__unused NSException *e) {}
            if ([alert respondsToSelector:@selector(show)]) {
                [alert show];
            }
            
            if ([buttonsArray isKindOfClass:[NSArray class]]) {
                for (id button in buttonsArray) {
                    UILabel *label = nil;
                    @try { label = [button valueForKey:@"titleLabel"]; } @catch (__unused NSException *e) {}
                    if (![label isKindOfClass:[UILabel class]]) continue;
                    if ([label.text isEqualToString:@"Let's Go!"]) {
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                            label.textColor = [self iotaPinkColor];
                        });
                    }
                }
            }
        } @catch (NSException *exception) {
            NSLog(@"Error showing custom alert: %@", exception);
        }
    });
}

#pragma mark - Toast Management

+ (void)showToastWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon autoHide:(int)seconds openURL:(NSURL *)openURL {
    if (ENABLED(@"Show Banners")) {
        dispatch_async(dispatch_get_main_queue(), ^{
            CustomToastView *toast = [[CustomToastView alloc] initWithTitle:title subtitle:subtitle icon:icon autoHide:seconds openURL:openURL];
            [toast presentToast];
        });
        [self performHapticFeedbackIfEnabled];
    }
}

+ (void)showLoadToast:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon autoHide:(int)seconds openURL:(NSURL *)openURL {
    dispatch_async(dispatch_get_main_queue(), ^{
        CustomToastView *toast = [[CustomToastView alloc] initWithTitle:title subtitle:subtitle icon:icon autoHide:seconds openURL:openURL];
        [toast presentToast];
    });
    [self performHapticFeedbackIfEnabled];
}

#pragma mark - Haptic Feedback

+ (void)performHapticFeedbackIfEnabled {
    if (ENABLED(@"Haptic Feedback")) {
        AudioServicesPlaySystemSound(1519);
    }
}

#pragma mark - Image Utilities

+ (UIImage *)imageFromEmojiString:(NSString *)emojiString width:(CGFloat)width {
	if (!emojiString.length || width <= 0) return nil;
	NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
	paragraphStyle.alignment = NSTextAlignmentCenter;

	CGFloat fontSize = width * 0.8;

	NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:emojiString attributes:@{
		NSFontAttributeName: [UIFont systemFontOfSize:fontSize],
		NSParagraphStyleAttributeName: paragraphStyle
	}];

	UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, width), NO, 0);
	CGRect rect = CGRectMake(0, (width - fontSize) / 2.0, width, fontSize * 1.2);
	[attributedString drawInRect:rect];
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	return image;
}

#pragma mark - File Management

+ (void)createDirectoryIfNotExists:(NSURL *)URL {
    if (![URL checkResourceIsReachableAndReturnError:nil]) {
        [[NSFileManager defaultManager] createDirectoryAtURL:URL withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

+ (void)cleanupTemporaryMediaFiles {
    NSURL *documentsURL = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] isDirectory:YES];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *files = [fm contentsOfDirectoryAtPath:documentsURL.path error:nil];
    
    for (NSString *file in files) {
        if ([file hasSuffix:@".mp4"] || [file hasSuffix:@".aac"] || [file hasSuffix:@".m4a"]) {
            if ([file hasPrefix:@"Video-"]) continue;
            NSURL *fileURL = [documentsURL URLByAppendingPathComponent:file];
            [fm removeItemAtURL:fileURL error:nil];
        }
    }
    NSString *caches = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    for (NSString *root in @[documentsURL.path, caches ?: @"", NSTemporaryDirectory()]) {
        if (!root.length) continue;
        NSArray *items = [fm contentsOfDirectoryAtPath:root error:nil];
        for (NSString *item in items) {
            if ([item hasPrefix:@"theta_save_"] || [item hasPrefix:@"theta-save"] || [item hasPrefix:@"theta_bulk_"] ||
                [item isEqualToString:@"video.mp4"] || [item isEqualToString:@"audio.m4a"] || [item isEqualToString:@"audio.aac"] ||
                [item isEqualToString:@"audio_lc.m4a"] || [item isEqualToString:@"output.mp4"] || [item isEqualToString:@"output_h264.mp4"]) {
                [fm removeItemAtPath:[root stringByAppendingPathComponent:item] error:nil];
            }
        }
    }
}

#pragma mark - Download Management

+ (BOOL)tryBeginGlobalDownloadOrNotify {
    @synchronized(self) {
        if (sGlobalDownloadInProgress) {
            UIImage *hourglass = [UIImage systemImageNamed:@"hourglass"];
            hourglass = [hourglass imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            CustomToastView *toast = [[CustomToastView alloc] initWithTitle:@"Download in progress" subtitle:@"Please wait for download to finish." icon:hourglass autoHide:2 openURL:nil];
            if (toast.progressIconView) {
                toast.progressIconView.tintColor = [UIColor labelColor];
            }
            toast.isProgressType = NO;
            [toast presentToast];
            return NO;
        }
        sGlobalDownloadInProgress = YES;
        return YES;
    }
}

+ (void)endGlobalDownload {
    @synchronized(self) {
        sGlobalDownloadInProgress = NO;
    }
}

+ (BOOL)isGlobalDownloadInProgress {
    @synchronized(self) {
        return sGlobalDownloadInProgress;
    }
}

#pragma mark - Utility Functions

+ (UIViewController *)nearestViewController:(UIView *)view {
    UIResponder *nextResponder = [view nextResponder];
    
    if ([nextResponder isKindOfClass:[UIViewController class]]) {
        return (UIViewController *)nextResponder;
    }
    
    return [self nearestViewController:[view superview]];
}

+ (UIWindow *)activeKeyWindow {
    UIApplication *app = [UIApplication sharedApplication];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in app.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive) continue;
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                if (w.isKeyWindow) return w;
            }
            UIWindow *first = ((UIWindowScene *)scene).windows.firstObject;
            if (first) return first;
        }
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindow *first = ((UIWindowScene *)scene).windows.firstObject;
            if (first) return first;
        }
    }
    for (UIWindow *w in app.windows) {
        if (w.isKeyWindow) return w;
    }
    if (app.windows.count) {
        return app.windows.firstObject;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return app.keyWindow;
#pragma clang diagnostic pop
}

+ (UIViewController *)topViewController {
    UIWindow *window = [self activeKeyWindow];
    UIViewController *vc = window.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

+ (void)presentSettings {
    dispatch_async(dispatch_get_main_queue(), ^{
        static NSTimeInterval lastPresentTime = 0;
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        if (now - lastPresentTime < 0.75) {
            return;
        }

        UIWindow *window = [self activeKeyWindow];
        if (!window) return;

        // Ensure SettingsViewController is not already presented anywhere in the presentation chain
        UIViewController *curr = window.rootViewController;
        while (curr) {
            if ([curr isKindOfClass:NSClassFromString(@"SettingsViewController")]) {
                return;
            }
            if ([curr isKindOfClass:[UINavigationController class]]) {
                UINavigationController *nav = (UINavigationController *)curr;
                for (UIViewController *child in nav.viewControllers) {
                    if ([child isKindOfClass:NSClassFromString(@"SettingsViewController")]) {
                        return;
                    }
                }
            }
            curr = curr.presentedViewController;
        }

        UIViewController *topVC = [self topViewController];
        if (!topVC) return;
        if ([topVC isKindOfClass:NSClassFromString(@"SettingsViewController")]) {
            return;
        }
        if ([topVC isKindOfClass:[UINavigationController class]]) {
            UINavigationController *nav = (UINavigationController *)topVC;
            if ([nav.topViewController isKindOfClass:NSClassFromString(@"SettingsViewController")]) {
                return;
            }
        }

        lastPresentTime = now;

        SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:settingsVC];
        navController.modalPresentationStyle = UIModalPresentationPageSheet;
        [topVC presentViewController:navController animated:YES completion:nil];
    });
}

+ (void)storeSegmentIndex:(NSInteger)index forSettingTitle:(NSString *)title {
    if (title.length == 0) return;
    NSString *key = [NSString stringWithFormat:@"%@_SegmentIndex", title];
    [[NSUserDefaults standardUserDefaults] setInteger:index forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

@implementation ThetaFloatingMediaButton

+ (instancetype)buttonWithSystemImage:(NSString *)systemImageName tintColor:(UIColor *)tintColor {
    UIImage *img = nil;
    if (systemImageName.length) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];
        img = [UIImage systemImageNamed:systemImageName withConfiguration:config];
    }
    return [self buttonWithImage:img tintColor:tintColor];
}

+ (instancetype)buttonWithImage:(UIImage *)image tintColor:(UIColor *)tintColor {
    ThetaFloatingMediaButton *btn = [self buttonWithType:UIButtonTypeCustom];
    [btn configureWithImage:image tintColor:tintColor];
    return btn;
}

- (void)configureWithImage:(UIImage *)image tintColor:(UIColor *)tintColor {
    self.translatesAutoresizingMaskIntoConstraints = NO;

    // Default to bright white so it is never invisible on dark or black media
    UIColor *effectiveTint = [UIColor whiteColor];
    if (tintColor) {
        CGFloat r = 0, g = 0, b = 0, a = 0;
        if ([tintColor getRed:&r green:&g blue:&b alpha:&a]) {
            if (r > 0.15 || g > 0.15 || b > 0.15) {
                effectiveTint = tintColor;
            }
        } else {
            effectiveTint = tintColor;
        }
    }
    self.tintColor = effectiveTint;

    if (image) {
        UIImage *templateImg = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [self setImage:templateImg forState:UIControlStateNormal];
    }

    // Frosted glass dark circular background with subtle light border
    self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55];
    self.layer.cornerRadius = 19.0;
    self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.35].CGColor;
    self.layer.borderWidth = 1.0;
    self.layer.masksToBounds = NO;

    // Drop shadow for high contrast on bright media
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.55;
    self.layer.shadowOffset = CGSizeMake(0, 2);
    self.layer.shadowRadius = 4.0;
}

// Expands touch hit area by at least 15pt all around (minimum 68x68 pt hit target)
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    CGRect hitArea = CGRectInset(self.bounds, -15.0, -15.0);
    return CGRectContainsPoint(hitArea, point);
}

// Visual and tactile feedback when pressed
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:0.12 animations:^{
        self.transform = highlighted ? CGAffineTransformMakeScale(0.90, 0.90) : CGAffineTransformIdentity;
        self.alpha = highlighted ? 0.75 : 1.0;
    }];
    if (highlighted) {
        UIImpactFeedbackGenerator *impact = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [impact impactOccurred];
    }
}

@end

static NSURL *theta_helperURLFromCandidate(id cand) {
    if (!cand) return nil;
    if ([cand isKindOfClass:[NSURL class]]) return ((NSURL *)cand).scheme.length ? (NSURL *)cand : nil;
    if ([cand isKindOfClass:[NSString class]]) {
        NSURL *u = [NSURL URLWithString:(NSString *)cand];
        return u.scheme.length ? u : nil;
    }
    for (NSString *key in @[ @"url", @"URL", @"videoURL", @"videoUrl", @"uri", @"src" ]) {
        @try {
            id url = [cand valueForKey:key];
            if ([url isKindOfClass:[NSURL class]] && [(NSURL *)url scheme].length) return url;
            if ([url isKindOfClass:[NSString class]]) {
                NSURL *u = [NSURL URLWithString:(NSString *)url];
                if (u.scheme.length) return u;
            }
        } @catch (__unused NSException *e) {}
    }
    return nil;
}

NSURL *theta_bestVideoURLFromVideo(id video) {
    if (!video) return nil;
    if ([video respondsToSelector:@selector(allVideoURLs)]) {
        id set = nil;
        @try { set = [video performSelector:@selector(allVideoURLs)]; } @catch (__unused NSException *e) {}
        if ([set isKindOfClass:[NSSet class]]) {
            for (id cand in (NSSet *)set) {
                NSURL *u = theta_helperURLFromCandidate(cand);
                if (u) return u;
            }
        } else if ([set isKindOfClass:[NSArray class]]) {
            for (id cand in [(NSArray *)set reverseObjectEnumerator]) {
                NSURL *u = theta_helperURLFromCandidate(cand);
                if (u) return u;
            }
        }
    }
    for (NSString *key in @[ @"videoUrl", @"videoURL", @"url", @"_url" ]) {
        @try {
            id val = [video valueForKey:key];
            NSURL *u = theta_helperURLFromCandidate(val);
            if (u) return u;
        } @catch (__unused NSException *e) {}
    }
    return nil;
}