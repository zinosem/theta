#import "Include/MessagesManager.h"
#import "Include/CustomToastView.h"
#import "Include/ThetaHelper.h"
#import <os/lock.h>

#define ENABLED(setting) [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"%@_Enabled", setting]]

@interface MessagesManager () {
    NSMutableDictionary *_memoryCache;
    os_unfair_lock _lock;
}
@end

@implementation MessagesManager

NSString *const plistFileName = @"deleted_messages.plist";

+ (instancetype)sharedManager {
    static MessagesManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _lock = OS_UNFAIR_LOCK_INIT;
        _memoryCache = [self loadPlistData];
    }
    return self;
}

- (NSString *)plistPath {
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    return [documentsDirectory stringByAppendingPathComponent:plistFileName];
}

- (NSMutableDictionary *)loadPlistData {
    NSString *path = [self plistPath];
    NSMutableDictionary *data = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    if (!data) {
        data = [NSMutableDictionary dictionary];
    }
    return data;
}

- (void)savePlistData:(NSDictionary *)data {
    NSString *path = [self plistPath];
    [data writeToFile:path atomically:YES];
}

- (void)saveDeletedMessageWithID:(NSString *)messageID {
    if (messageID.length == 0) {
        NSLog(@"Message ID cannot be empty.");
        return;
    }
    
    NSString *currentDate = [[NSDate date] description];
    NSDictionary *snapshotToSave = nil;
    os_unfair_lock_lock(&_lock);
    _memoryCache[messageID] = currentDate;
    snapshotToSave = [_memoryCache copy];
    os_unfair_lock_unlock(&_lock);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self savePlistData:snapshotToSave];
    });

    if (ENABLED(@"Show Banners")) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [ThetaHelper showToastWithTitle:@"Someone deleted a message." subtitle:nil icon:[ThetaHelper imageFromEmojiString:@"🗑️" width:60] autoHide:4 openURL:nil];
        });
    }
}

- (BOOL)messageExistsWithID:(NSString *)messageID {
    if (messageID.length == 0) {
        return NO;
    }
    
    os_unfair_lock_lock(&_lock);
    BOOL exists = (_memoryCache[messageID] != nil);
    os_unfair_lock_unlock(&_lock);
    return exists;
}

- (NSString *)dateForDeletedMessageWithID:(NSString *)messageID {
    if (messageID.length == 0) {
        return nil;
    }
    
    os_unfair_lock_lock(&_lock);
    NSString *date = _memoryCache[messageID];
    os_unfair_lock_unlock(&_lock);
    return date;
}
@end