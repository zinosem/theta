#import <objc/runtime.h>
#import "Include/ThetaDashManifest.h"

// UIView category for finding nearest view controller
@interface UIView (FindNearestViewController)
- (UIViewController *)findNearestViewController;
@end

@implementation UIView (FindNearestViewController)
- (UIViewController *)findNearestViewController {
    // Find the nearest view controller by traversing up the responder chain
    UIResponder *responder = self;
    while (responder && ![responder isKindOfClass:[UIViewController class]]) {
        responder = [responder nextResponder];
    }
    return (UIViewController *)responder;
}
@end

// Download delegate for progress tracking
@interface AudioDownloadDelegate : NSObject <NSURLSessionDownloadDelegate>
@property (nonatomic, weak) CustomToastView *progressToast;
@property (nonatomic, strong) NSString *audioURL;
@end

@implementation AudioDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (totalBytesExpectedToWrite > 0 && self.progressToast) {
            double progress = (double)totalBytesWritten / (double)totalBytesExpectedToWrite;
            int percentage = (int)(progress * 100);
            
            [self.progressToast updateProgressWithTitle:@"Downloading Audio" 
                                               subtitle:[NSString stringWithFormat:@"%d%%", percentage]];
        }
    });
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    // This method is called automatically, completion handler in the download task will handle the file processing
}

@end

static void theta_attachAudioNoteGestureRecognizer(UIView *self) {
    if (ENABLED(@"Save Audio Notes")) {
        // Check if gesture recognizer already exists to avoid adding multiple
        BOOL hasLongPressGesture = NO;
        for (UIGestureRecognizer *recognizer in [self gestureRecognizers]) {
            if ([recognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
                hasLongPressGesture = YES;
                break;
            }
        }
        
        if (!hasLongPressGesture) {
            // Ensure the view can receive touch events
            UIView *view = (UIView *)self;
            view.userInteractionEnabled = YES;
            
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] init];
            longPress.minimumPressDuration = 0.5;
            longPress.numberOfTouchesRequired = 1;
            longPress.cancelsTouchesInView = NO; // Allow other gestures to work
            
            // Use block-based approach
            [longPress addActionBlock:^(UIGestureRecognizer *recognizer) {
                if (((UILongPressGestureRecognizer *)recognizer).state == UIGestureRecognizerStateBegan) {
                    UIView *pressedView = recognizer.view;
                    
                    // Get music info and extract audio URL
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                        @try {
                            Ivar musicInfo = class_getInstanceVariable([pressedView class], "_musicInfo");
            if (musicInfo) {
                                id musicInfoValue = object_getIvar(pressedView, musicInfo);
                                if (musicInfoValue) {
                                    id musicAssets = nil;
                                    if ([musicInfoValue respondsToSelector:@selector(musicAssetInfo)]) {
                                        musicAssets = [musicInfoValue performSelector:@selector(musicAssetInfo)];
                                    }
                                    if (musicAssets) {
                                        NSString *xml = nil;
                                        if ([musicAssets respondsToSelector:@selector(dashManifest)]) {
                                            xml = [musicAssets performSelector:@selector(dashManifest)];
                                        }
                                        if (xml && xml.length > 0) {
                        NSString *audioURL = IGDashManifestBestAudioURL(xml);
                                            if (audioURL && audioURL.length > 0) {
                                                // Show confirmation dialog
                                                NSArray *actions = @[
                                                    @{ @"title": @"Yes, Save Audio", @"handler": ^{ 
                                                        // Show progress toast
                                                        CustomToastView *progressToast = [CustomToastView showProgressToastWithTitle:@"Downloading Audio" 
                                                                                                                            subtitle:@"0%"];
                                                        
                                                        // Create delegate for progress tracking
                                                        AudioDownloadDelegate *delegate = [[AudioDownloadDelegate alloc] init];
                                                        delegate.progressToast = progressToast;
                                                        delegate.audioURL = audioURL;
                                                        
                                                        // Download audio with progress tracking
                                                        NSURL *url = [NSURL URLWithString:audioURL];
                                                        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
                                                        NSURLSession *session = [NSURLSession sessionWithConfiguration:config 
                                                                                                            delegate:delegate 
                                                                                                        delegateQueue:[NSOperationQueue mainQueue]];
                                                        
                                                        NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithURL:url 
                                                                                                            completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
                                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                                if (error) {
                                                                    NSLog(@"Download failed: %@", error.localizedDescription);
                                                                    [progressToast completeProgressWithTitle:@"Download Failed" 
                                                                                                    subtitle:error.localizedDescription 
                                                                                                        icon:[UIImage systemImageNamed:@"xmark.circle.fill"] 
                                                                                                        url:nil];
                                                                    [progressToast hideAfter:3.0];
                                                                    return;
                                                                }
                                                                
                                                                if (!location) {
                                                                    NSLog(@"No download location provided");
                                                                    [progressToast completeProgressWithTitle:@"Download Failed" 
                                                                                                    subtitle:@"No data received" 
                                                                                                        icon:[UIImage systemImageNamed:@"xmark.circle.fill"] 
                                                                                                        url:nil];
                                                                    [progressToast hideAfter:3.0];
                                                                    return;
                                                                }
                                                                
                                                                // Read downloaded data
                                                                NSData *data = [NSData dataWithContentsOfURL:location];
                                                                if (!data) {
                                                                    NSLog(@"Failed to read downloaded data");
                                                                    [progressToast completeProgressWithTitle:@"Download Failed" 
                                                                                                    subtitle:@"Failed to read downloaded data" 
                                                                                                        icon:[UIImage systemImageNamed:@"xmark.circle.fill"] 
                                                                                                        url:nil];
                                                                    [progressToast hideAfter:3.0];
                                                                    return;
                                                                }
                                                                
                                                                // Determine file extension based on URL or audio format
                                                                NSString *extension = @"m4a"; // Default to M4A for ISO-BMFF / AAC audio
                                                                NSString *urlString = audioURL.lowercaseString;
                                                                
                                                                BOOL isMP4 = NO;
                                                                BOOL isADTS = NO;
                                                                BOOL isMP3 = NO;

                                                                // Inspect data headers
                                                                if (data.length >= 8) {
                                                                    const unsigned char *bytes = (const unsigned char *)[data bytes];
                                                                    isMP4 = (bytes[4] == 'f' && bytes[5] == 't' && bytes[6] == 'y' && bytes[7] == 'p') ||
                                                                            (bytes[4] == 's' && bytes[5] == 't' && bytes[6] == 'y' && bytes[7] == 'p') ||
                                                                            (bytes[4] == 'm' && bytes[5] == 'o' && bytes[6] == 'o' && (bytes[7] == 'v' || bytes[7] == 'f'));
                                                                    isADTS = (bytes[0] == 0xFF && (bytes[1] & 0xF0) == 0xF0);
                                                                    isMP3 = ((bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0) ||
                                                                             (bytes[0] == 'I' && bytes[1] == 'D' && bytes[2] == '3'));
                                                                } else if (data.length >= 4) {
                                                                    const unsigned char *bytes = (const unsigned char *)[data bytes];
                                                                    isMP3 = ((bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0) ||
                                                                             (bytes[0] == 'I' && bytes[1] == 'D' && bytes[2] == '3'));
                                                                }

                                                                if (isMP4) {
                                                                    extension = @"m4a";
                                                                } else if (isMP3) {
                                                                    extension = @"mp3";
                                                                } else if (isADTS) {
                                                                    extension = @"aac";
                                                                } else if ([urlString containsString:@"mp3"] || [urlString containsString:@"mpeg"]) {
                                                                    extension = @"mp3";
                                                                } else if ([urlString containsString:@"mp4a"] || [urlString containsString:@"m4a"]) {
                                                                    extension = @"m4a";
                                                                } else if ([urlString containsString:@"aac"]) {
                                                                    extension = @"aac";
                                                                } else {
                                                                    extension = @"m4a";
                                                                }
                                                                
                                                                // Generate filename with timestamp
                                                                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                                                                [formatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
                                                                NSString *timestamp = [formatter stringFromDate:[NSDate date]];
                                                                NSString *filename = [NSString stringWithFormat:@"AudioNote_%@.%@", timestamp, extension];
                                                                
                                                                // Get user name for folder organization
                                                                NSString *userFolderName = @"Unknown User";
                                                                UIViewController *nearestVC = [pressedView findNearestViewController];
                                                                if (nearestVC) {
                                                                    @try {
                                                                        Ivar replyToUserIvar = class_getInstanceVariable([nearestVC class], "_replyToUser");
                                                                        if (replyToUserIvar) {
                                                                            id replyToUser = object_getIvar(nearestVC, replyToUserIvar);
                                                                            if (replyToUser) {
                                                                                NSString *userName = nil;
                                                                                if ([replyToUser respondsToSelector:@selector(name)]) {
                                                                                    userName = [replyToUser performSelector:@selector(name)];
                                                                                } else if ([replyToUser respondsToSelector:@selector(username)]) {
                                                                                    userName = [replyToUser performSelector:@selector(username)];
                                                                                } else {
                                                                                    userName = ThetaValueForKey(replyToUser, @"username") ?: ThetaValueForKey(replyToUser, @"name");
                                                                                }
                                                                                if (userName && [userName isKindOfClass:[NSString class]] && userName.length > 0) {
                                                                                    userFolderName = userName;
                                                                                }
                                                                            }
                                                                        }
                                                                    } @catch (NSException *exception) {
                                                                        NSLog(@"Exception getting user name: %@", exception.reason);
                                                                        // Keep default "Unknown User" folder name
                                                                    }
                                                                }
                                                                
                                                                // Create AudioNotes directory if it doesn't exist
                                                                NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
                                                                NSString *audioNotesDir = [documentsPath stringByAppendingPathComponent:@"AudioNotes"];
                                                                
                                                                // Create user-specific subfolder
                                                                NSString *userFolderPath = [audioNotesDir stringByAppendingPathComponent:userFolderName];
                                                                
                                                                NSFileManager *fileManager = [NSFileManager defaultManager];
                                                                BOOL isDirectory;
                                                                BOOL dirExists = [fileManager fileExistsAtPath:audioNotesDir isDirectory:&isDirectory];
                                                                
                                                                if (!dirExists || !isDirectory) {
                                                                    NSError *createDirError = nil;
                                                                    BOOL dirCreated = [fileManager createDirectoryAtPath:audioNotesDir 
                                                                                            withIntermediateDirectories:YES 
                                                                                                            attributes:nil 
                                                                                                                    error:&createDirError];
                                                                    if (!dirCreated) {
                                                                        NSLog(@"Failed to create AudioNotes directory: %@", createDirError.localizedDescription);
                                                                        [progressToast completeProgressWithTitle:@"Save Failed" 
                                                                                                        subtitle:@"Failed to create AudioNotes folder" 
                                                                                                            icon:[UIImage systemImageNamed:@"xmark.circle.fill"] 
                                                                                                            url:nil];
                                                                        [progressToast hideAfter:3.0];
                                                                        return;
                                                                    }
                                                                    NSLog(@"Created AudioNotes directory at: %@", audioNotesDir);
                                                                }
                                                                
                                                                // Create user subfolder if it doesn't exist
                                                                BOOL userDirExists = [fileManager fileExistsAtPath:userFolderPath isDirectory:&isDirectory];
                                                                if (!userDirExists || !isDirectory) {
                                                                    NSError *createUserDirError = nil;
                                                                    BOOL userDirCreated = [fileManager createDirectoryAtPath:userFolderPath 
                                                                                            withIntermediateDirectories:YES 
                                                                                                            attributes:nil 
                                                                                                                    error:&createUserDirError];
                                                                    if (!userDirCreated) {
                                                                        NSLog(@"Failed to create user directory: %@", createUserDirError.localizedDescription);
                                                                        [progressToast completeProgressWithTitle:@"Save Failed" 
                                                                                                        subtitle:@"Failed to create user folder" 
                                                                                                            icon:[UIImage systemImageNamed:@"xmark.circle.fill"] 
                                                                                                            url:nil];
                                                                        [progressToast hideAfter:3.0];
                                                                        return;
                                                                    }
                                                                    NSLog(@"Created user directory at: %@", userFolderPath);
                                                                }
                                                                
                                                                NSString *filePath = [userFolderPath stringByAppendingPathComponent:filename];
                                                                
                                                                // Save the file
                                                                BOOL success = [data writeToFile:filePath atomically:YES];
                                                                
                                                                if (success) {
                                                                    // Show success completion
                                                                    [progressToast completeProgressWithTitle:@"Audio Downloaded!" 
                                                                                                    subtitle:[NSString stringWithFormat:@"Audio saved to your device."] 
                                                                                                        icon:[UIImage systemImageNamed:@"checkmark.circle.fill"] 
                                                                                                        url:nil];
                                                                    [progressToast hideAfter:3.0];
                                                                } else {
                                                                    NSLog(@"Failed to save audio file to: %@", filePath);
                                                                    [progressToast completeProgressWithTitle:@"Save Failed" 
                                                                                                    subtitle:@"Failed to save audio file" 
                                                                                                        icon:[UIImage systemImageNamed:@"xmark.circle.fill"] 
                                                                                                        url:nil];
                                                                    [progressToast hideAfter:3.0];
                                                                }
                                                            });
                                                        }];
                                                        
                                                        [downloadTask resume];
                                                    }},
                                                    @{ @"title": @"Cancel", @"handler": ^{ /* do nothing */ }}
                                                ];
                                                [ThetaHelper showCustomAlertWithActions:@"Save Audio Note" 
                                                                            description:@"Would you like to save this audio note to your device?"
                                                                                actions:actions];
                                            } else {
                                                NSLog(@"No audio URL found in manifest");
                                                NSArray *actions = @[@{ @"title": @"OK", @"handler": ^{ /* do nothing */ }}];
                                                [ThetaHelper showCustomAlertWithActions:@"Audio Note" 
                                                                            description:@"No audio URL found in manifest"
                                                                                actions:actions];
                                            }
                                        } else {
                                            NSLog(@"No dash manifest found");
                                            NSArray *actions = @[@{ @"title": @"OK", @"handler": ^{ /* do nothing */ }}];
                                            [ThetaHelper showCustomAlertWithActions:@"Audio Note" 
                                                                        description:@"No dash manifest found"
                                                                            actions:actions];
                                        }
                                    } else {
                                        NSLog(@"No music assets found");
                                        NSArray *actions = @[@{ @"title": @"OK", @"handler": ^{ /* do nothing */ }}];
                                        [ThetaHelper showCustomAlertWithActions:@"Audio Note" 
                                                                    description:@"No music assets found"
                                                                        actions:actions];
                                    }
                                } else {
                                    NSLog(@"No music info value found");
                                    NSArray *actions = @[@{ @"title": @"OK", @"handler": ^{ /* do nothing */ }}];
                                    [ThetaHelper showCustomAlertWithActions:@"Audio Note" 
                                                                description:@"No music info value found"
                                                                    actions:actions];
                                }
                            } else {
                                NSLog(@"No music info ivar found");
                                NSArray *actions = @[@{ @"title": @"OK", @"handler": ^{ /* do nothing */ }}];
                                [ThetaHelper showCustomAlertWithActions:@"Audio Note" 
                                                            description:@"No music info ivar found"
                                                                actions:actions];
                            }
                        } @catch (NSException *exception) {
                            NSLog(@"Exception in long press handler: %@", exception.reason);
                            NSArray *actions = @[@{ @"title": @"OK", @"handler": ^{ /* do nothing */ }}];
                            [ThetaHelper showCustomAlertWithActions:@"Audio Note Error" 
                                                        description:[NSString stringWithFormat:@"Exception: %@", exception.reason]
                                                            actions:actions];
                        }
                    });
                }
            }];
            
            [self addGestureRecognizer:longPress];
        }
    }
}

static void (*orig_saveNoteAudio_Indicator)(id self, SEL _cmd);
static void hook_saveNoteAudio_Indicator(id self, SEL _cmd) {
    if (orig_saveNoteAudio_Indicator) orig_saveNoteAudio_Indicator(self, _cmd);
    theta_attachAudioNoteGestureRecognizer((UIView *)self);
}

static void (*orig_saveNoteAudio_Vinyl)(id self, SEL _cmd);
static void hook_saveNoteAudio_Vinyl(id self, SEL _cmd) {
    if (orig_saveNoteAudio_Vinyl) orig_saveNoteAudio_Vinyl(self, _cmd);
    theta_attachAudioNoteGestureRecognizer((UIView *)self);
}

static void (*orig_saveNoteAudio_AlbumArt)(id self, SEL _cmd);
static void hook_saveNoteAudio_AlbumArt(id self, SEL _cmd) {
    if (orig_saveNoteAudio_AlbumArt) orig_saveNoteAudio_AlbumArt(self, _cmd);
    theta_attachAudioNoteGestureRecognizer((UIView *)self);
}

void THRegisterSaveAudioNotesHooks(void) {
    SEL layout = @selector(layoutSubviews);
    NullHookMessageIfPresent(NSClassFromString(@"IGMusicStickerAudioIndicatorView"), layout, (void *)hook_saveNoteAudio_Indicator, (void **)&orig_saveNoteAudio_Indicator);
    NullHookMessageIfPresent(NSClassFromString(@"IGVinylMusicSticker"), layout, (void *)hook_saveNoteAudio_Vinyl, (void **)&orig_saveNoteAudio_Vinyl);
    NullHookMessageIfPresent(NSClassFromString(@"IGSmallAlbumArtMusicSticker"), layout, (void *)hook_saveNoteAudio_AlbumArt, (void **)&orig_saveNoteAudio_AlbumArt);
}