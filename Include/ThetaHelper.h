#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ThetaHelper : NSObject

+ (NSString *)hexFromColour:(UIColor *)colour;
+ (UIColor *)colourFromHex:(NSString *)hexString;

#pragma mark - Alert Management
+ (void)showCustomAlertWithActions:(NSString *)title description:(NSString *)description actions:(NSArray<NSDictionary *> *)actions;

#pragma mark - Toast Management
+ (void)showToastWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon autoHide:(int)seconds openURL:(NSURL *)openURL;
+ (void)showLoadToast:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon autoHide:(int)seconds openURL:(NSURL *)openURL;
/// Presents Instagram's native confirmation toast with custom title, subtitle, and optional image. Pass nil for subtitle or image as needed.
FOUNDATION_EXPORT void ThetaShowNativeToast(NSString *title, NSString * _Nullable subtitle, UIImage * _Nullable image);
/// Same as ThetaShowNativeToast but uses an emoji as the thumbnail (via ThetaHelper imageFromEmojiString). Pass nil for emojiString for text-only.
FOUNDATION_EXPORT void ThetaShowNativeToastWithEmoji(NSString *title, NSString * _Nullable subtitle, NSString * _Nullable emojiString, CGFloat width);

#pragma mark - Haptic Feedback
+ (void)performHapticFeedbackIfEnabled;

#pragma mark - Image Utilities
+ (UIImage *)imageFromEmojiString:(NSString *)emojiString width:(CGFloat)width;

#pragma mark - File Management
+ (void)createDirectoryIfNotExists:(NSURL *)URL;
+ (void)cleanupTemporaryMediaFiles;

#pragma mark - Download Management
+ (BOOL)tryBeginGlobalDownloadOrNotify;
+ (void)endGlobalDownload;
+ (BOOL)isGlobalDownloadInProgress;

#pragma mark - Utility Functions
+ (UIWindow *)activeKeyWindow;
+ (UIViewController *)nearestViewController:(UIView *)view;
+ (UIViewController *)topViewController;

#pragma mark - Settings Helpers
// Stores selected index for a segment setting with given title
+ (void)storeSegmentIndex:(NSInteger)index forSettingTitle:(NSString *)title;

#pragma mark - Constants
+ (UIColor *)iotaPinkColor;
+ (NSTimeInterval)cooldownPeriod;

@end

FOUNDATION_EXPORT NSURL *theta_bestVideoURLFromVideo(id video);

@interface ThetaFloatingMediaButton : UIButton
+ (instancetype)buttonWithSystemImage:(NSString *)systemImageName tintColor:(UIColor *)tintColor;
+ (instancetype)buttonWithImage:(UIImage *)image tintColor:(UIColor *)tintColor;
- (void)configureWithImage:(UIImage *)image tintColor:(UIColor *)tintColor;
@end 