static BOOL videoPlayed = NO;

@class IGVideo;
static void downloadHDVideo(IGVideo *inputVideo);

static void (*orig_visualmsgghostbuttons)(IGDirectVisualMessageViewerController *self, SEL _cmd);
static void hook_visualmsgghostbuttons(IGDirectVisualMessageViewerController *self, SEL _cmd) {
    if (orig_visualmsgghostbuttons) orig_visualmsgghostbuttons(self, _cmd);

    UIView *containerView = [self valueForKey:@"view"];
    if (!containerView || ![containerView isKindOfClass:[UIView class]]) {
        NSLog(@"Failed to get valid container view");
        return;
    }
    
    UIColor *downloadColor = [UIColor whiteColor];
    @try {
        NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"Save Button Color_Color"];
        UIColor *color = [NSKeyedUnarchiver unarchivedObjectOfClass:[UIColor class] fromData:data error:nil];
        if (color) downloadColor = color;
    } @catch (__unused NSException *exception) {}

    UIButton *downloadButton = [ThetaFloatingMediaButton buttonWithSystemImage:@"arrow.down" tintColor:downloadColor];
    downloadButton.tag = 77001;

    UIColor *seenColor = [UIColor whiteColor];
    @try {
        NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"Seen Button Color_Color"];
        UIColor *color = [NSKeyedUnarchiver unarchivedObjectOfClass:[UIColor class] fromData:data error:nil];
        if (color) seenColor = color;
    } @catch (__unused NSException *exception) {}

    UIButton *seenButton = [ThetaFloatingMediaButton buttonWithSystemImage:@"eye" tintColor:seenColor];
    seenButton.tag = 77002;

    BOOL downloadVideos = ENABLED(@"Save Media");
    BOOL hideSeenState = ENABLED(@"Private Media Ghost");

    ThetaSetCaptureHiding(downloadButton);
    ThetaSetCaptureHiding(seenButton);

    UIView *oldDownload = [containerView viewWithTag:77001];
    if (oldDownload) [oldDownload removeFromSuperview];
    UIView *oldSeen = [containerView viewWithTag:77002];
    if (oldSeen) [oldSeen removeFromSuperview];

    @try {
        if (downloadVideos && !hideSeenState) {
            [containerView addSubview:downloadButton];
            [containerView bringSubviewToFront:downloadButton];
            [NSLayoutConstraint activateConstraints:@[
                [downloadButton.bottomAnchor constraintEqualToAnchor:containerView.safeAreaLayoutGuide.bottomAnchor constant:-116],
                [downloadButton.trailingAnchor constraintEqualToAnchor:containerView.safeAreaLayoutGuide.trailingAnchor constant:-14],
                [downloadButton.widthAnchor constraintEqualToConstant:38],
                [downloadButton.heightAnchor constraintEqualToConstant:38]
            ]];
        }

        if (!downloadVideos && hideSeenState) {
            [containerView addSubview:seenButton];
            [containerView bringSubviewToFront:seenButton];
            [NSLayoutConstraint activateConstraints:@[
                [seenButton.bottomAnchor constraintEqualToAnchor:containerView.safeAreaLayoutGuide.bottomAnchor constant:-116],
                [seenButton.trailingAnchor constraintEqualToAnchor:containerView.safeAreaLayoutGuide.trailingAnchor constant:-14],
                [seenButton.widthAnchor constraintEqualToConstant:38],
                [seenButton.heightAnchor constraintEqualToConstant:38]
            ]];
        }

        if (downloadVideos && hideSeenState) {
            [containerView addSubview:downloadButton];
            [containerView addSubview:seenButton];
            [containerView bringSubviewToFront:downloadButton];
            [containerView bringSubviewToFront:seenButton];
            [NSLayoutConstraint activateConstraints:@[
                [downloadButton.bottomAnchor constraintEqualToAnchor:containerView.safeAreaLayoutGuide.bottomAnchor constant:-116],
                [downloadButton.trailingAnchor constraintEqualToAnchor:containerView.safeAreaLayoutGuide.trailingAnchor constant:-14],
                [downloadButton.widthAnchor constraintEqualToConstant:38],
                [downloadButton.heightAnchor constraintEqualToConstant:38]
            ]];
            [NSLayoutConstraint activateConstraints:@[
                [seenButton.bottomAnchor constraintEqualToAnchor:downloadButton.topAnchor constant:-16],
                [seenButton.trailingAnchor constraintEqualToAnchor:containerView.safeAreaLayoutGuide.trailingAnchor constant:-14],
                [seenButton.widthAnchor constraintEqualToConstant:38],
                [seenButton.heightAnchor constraintEqualToConstant:38]
            ]];
        }

        if (hideSeenState) {
            __weak typeof(self) weakSelf = self;
            [seenButton addAction:[UIAction actionWithHandler:^(UIAction *action) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                UIView *containView = [strongSelf valueForKey:@"_viewerContainerView"];
                UIView *medView = [containView valueForKey:@"mediaView"];
                if ([medView isKindOfClass:NSClassFromString(@"IGStoryModernVideoView")]) {
                    if ([strongSelf respondsToSelector:@selector(storyPlayerMediaViewDidPlay:)]) {
                        @try { [strongSelf performSelector:@selector(storyPlayerMediaViewDidPlay:) withObject:medView]; } @catch (__unused NSException *e) {}
                    }
                    videoPlayed = YES;
                }

                if ([medView isKindOfClass:NSClassFromString(@"IGStoryPhotoView")]) {
                    SEL didLoadSel = @selector(storyPlayerMediaViewDidLoad:loadSource:networkRequestSummary:);
                    if ([strongSelf respondsToSelector:didLoadSel]) {
                        @try {
                            ((void (*)(id, SEL, id, NSInteger, NSInteger))objc_msgSend)(strongSelf, didLoadSel, medView, 0, 0);
                        } @catch (__unused NSException *e) {}
                    }
                    videoPlayed = YES;
                }

                if (ENABLED(@"Show Banners")) {
                    [ThetaHelper showToastWithTitle:@"Marked as seen!" subtitle:@"They know we are here." icon:[ThetaHelper imageFromEmojiString:@"👀" width:60] autoHide:4 openURL:nil];
                }
            }] forControlEvents:UIControlEventTouchUpInside];
        }

        if (downloadVideos) {
            __weak typeof(self) weakSelf = self;
            [downloadButton addAction:[UIAction actionWithHandler:^(UIAction *action) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                id initialVisualMessage = nil;
                @try { initialVisualMessage = [strongSelf valueForKey:@"_initialVisualMessage"]; } @catch (__unused NSException *e) {}
                id visualMediaInfo = nil;
                @try { visualMediaInfo = [initialVisualMessage valueForKey:@"_visualMediaInfo"]; } @catch (__unused NSException *e) {}
                id media = nil;
                @try { media = [visualMediaInfo valueForKey:@"media"]; } @catch (__unused NSException *e) {}
                id video = nil;
                @try { video = [media valueForKey:@"_video_video"] ?: [media valueForKey:@"video"]; } @catch (__unused NSException *e) {}
                if (video) {
                    downloadHDVideo(video);
                }

                id photo = nil;
                @try { photo = [media valueForKey:@"_photo_photo"] ?: [media valueForKey:@"photo"]; } @catch (__unused NSException *e) {}
                if (photo) {
                    NSArray *originalImageVersions = nil;
                    @try { originalImageVersions = [photo valueForKey:@"_originalImageVersions"]; } @catch (__unused NSException *e) {}
                    if (![originalImageVersions isKindOfClass:[NSArray class]] || originalImageVersions.count == 0) {
                        @try { originalImageVersions = [photo valueForKey:@"imageVersions"]; } @catch (__unused NSException *e) {}
                    }
                    if (![originalImageVersions isKindOfClass:[NSArray class]] || originalImageVersions.count == 0) {
                        @try { originalImageVersions = [photo valueForKey:@"_imageVersions"]; } @catch (__unused NSException *e) {}
                    }
                    if ([originalImageVersions isKindOfClass:[NSArray class]] && originalImageVersions.count > 0) {
                        id bestCand = nil;
                        double maxPixels = -1.0;
                        for (id cand in originalImageVersions) {
                            double width = 0.0, height = 0.0;
                            if ([cand isKindOfClass:[NSDictionary class]]) {
                                NSDictionary *d = (NSDictionary *)cand;
                                if (d[@"width"]) width = [d[@"width"] doubleValue];
                                if (d[@"height"]) height = [d[@"height"] doubleValue];
                            } else {
                                @try {
                                    if ([cand respondsToSelector:@selector(width)]) width = [[cand valueForKey:@"width"] doubleValue];
                                    if ([cand respondsToSelector:@selector(height)]) height = [[cand valueForKey:@"height"] doubleValue];
                                } @catch (__unused NSException *e) {}
                            }
                            double pixels = width * height;
                            if (pixels > maxPixels) {
                                maxPixels = pixels;
                                bestCand = cand;
                            }
                        }
                        id photoURL = bestCand ?: [originalImageVersions lastObject];
                        NSURL *url = nil;
                        if ([photoURL isKindOfClass:[NSURL class]]) {
                            url = (NSURL *)photoURL;
                        } else if ([photoURL isKindOfClass:[NSString class]]) {
                            url = [NSURL URLWithString:(NSString *)photoURL];
                        } else if ([photoURL isKindOfClass:[NSDictionary class]]) {
                            id u = ((NSDictionary *)photoURL)[@"url"];
                            if ([u isKindOfClass:[NSURL class]]) url = (NSURL *)u;
                            else if ([u isKindOfClass:[NSString class]]) url = [NSURL URLWithString:(NSString *)u];
                        } else {
                            @try {
                                id u = [photoURL valueForKey:@"url"];
                                if ([u isKindOfClass:[NSURL class]]) url = (NSURL *)u;
                                else if ([u isKindOfClass:[NSString class]]) url = [NSURL URLWithString:(NSString *)u];
                            } @catch (__unused NSException *e) {}
                        }
                        if (url) {
                            MediaSelectionViewController *mediaSelectionViewController = [[MediaSelectionViewController alloc] init];
                            [mediaSelectionViewController downloadMediaToTemp:url completion:^(NSString *filePath, NSString *fileExtension){
                                if (ENABLED(@"Show Banners")) {
                                    NSInteger saveMethod = [[NSUserDefaults standardUserDefaults] integerForKey:@"Save Method_SegmentIndex"];
                                    if (saveMethod == 0) {
                                        [ThetaHelper showToastWithTitle:@"Saved to camera roll!" subtitle:@"Tap here to go to camera roll." icon:[UIImage systemImageNamed:@"checkmark.circle.fill"] autoHide:4 openURL:[NSURL URLWithString:@"photos-redirect://"]];
                                    } else {
                                        [ThetaHelper showToastWithTitle:@"Saved!" subtitle:@"Saved to local folder." icon:[UIImage systemImageNamed:@"checkmark.circle.fill"] autoHide:4 openURL:nil];
                                    }
                                }
                            }];
                        }
                    }
                }
            }] forControlEvents:UIControlEventTouchUpInside];
        }
    } @catch (NSException *exception) {
        NSLog(@"Error adding buttons: %@", exception);
    }
}

static void (*orig_visualmsgghostvideo)(id self, SEL _cmd, id arg1);
static void hook_visualmsgghostvideo(id self, SEL _cmd, id arg1) {
    if (!ENABLED(@"Private Media Ghost")) {
        if (orig_visualmsgghostvideo) orig_visualmsgghostvideo(self, _cmd, arg1);
        return;
    }

    if (videoPlayed) {
        if (orig_visualmsgghostvideo) orig_visualmsgghostvideo(self, _cmd, arg1);
        videoPlayed = NO;
    }
}

static void (*orig_visualmsgghostphoto)(id self, SEL _cmd, id arg1, id arg2, id arg3, id arg4);
static void hook_visualmsgghostphoto(id self, SEL _cmd, id arg1, id arg2, id arg3, id arg4) {
    if (!ENABLED(@"Private Media Ghost")) {
        if (orig_visualmsgghostphoto) orig_visualmsgghostphoto(self, _cmd, arg1, arg2, arg3, arg4);
        return;
    }

    if (videoPlayed) {
        if (orig_visualmsgghostphoto) orig_visualmsgghostphoto(self, _cmd, arg1, arg2, arg3, arg4);
        videoPlayed = NO;
    }
}

static void (*orig_visualmsgghost_layoutSubviews)(IGDirectVisualMessageViewerController *self, SEL _cmd);
static void hook_visualmsgghost_layoutSubviews(IGDirectVisualMessageViewerController *self, SEL _cmd) {
    if (orig_visualmsgghost_layoutSubviews) {
        orig_visualmsgghost_layoutSubviews(self, _cmd);
    }
    @try {
        UIView *containerView = [self valueForKey:@"view"];
        if (containerView) {
            UIView *b1 = [containerView viewWithTag:77001];
            if (b1) [containerView bringSubviewToFront:b1];
            UIView *b2 = [containerView viewWithTag:77002];
            if (b2) [containerView bringSubviewToFront:b2];
        }
    } @catch (__unused NSException *e) {}
}

#pragma mark - Unlimited Replay Disappearing Media (Infinite View-Once Replay)

// 1. IGDirectVisualMessage
static NSInteger (*orig_msg_viewMode)(id self, SEL _cmd);
static NSInteger hook_msg_viewMode(id self, SEL _cmd) {
    NSInteger mode = orig_msg_viewMode ? orig_msg_viewMode(self, _cmd) : 0;
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        if (mode == 0) return 1; // 0 = View Once -> 1 = Replayable
    }
    return mode;
}

static BOOL (*orig_msg_isViewOnce)(id self, SEL _cmd);
static BOOL hook_msg_isViewOnce(id self, SEL _cmd) {
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        return NO;
    }
    return orig_msg_isViewOnce ? orig_msg_isViewOnce(self, _cmd) : NO;
}

static BOOL (*orig_msg_isExpired)(id self, SEL _cmd);
static BOOL hook_msg_isExpired(id self, SEL _cmd) {
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        return NO;
    }
    return orig_msg_isExpired ? orig_msg_isExpired(self, _cmd) : NO;
}

static BOOL (*orig_msg_hasExpired)(id self, SEL _cmd);
static BOOL hook_msg_hasExpired(id self, SEL _cmd) {
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        return NO;
    }
    return orig_msg_hasExpired ? orig_msg_hasExpired(self, _cmd) : NO;
}

static BOOL (*orig_msg_canReplay)(id self, SEL _cmd);
static BOOL hook_msg_canReplay(id self, SEL _cmd) {
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        return YES;
    }
    return orig_msg_canReplay ? orig_msg_canReplay(self, _cmd) : NO;
}

static BOOL (*orig_msg_isReplayable)(id self, SEL _cmd);
static BOOL hook_msg_isReplayable(id self, SEL _cmd) {
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        return YES;
    }
    return orig_msg_isReplayable ? orig_msg_isReplayable(self, _cmd) : NO;
}

static long long (*orig_msg_seenCount)(id self, SEL _cmd);
static long long hook_msg_seenCount(id self, SEL _cmd) {
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        return 0;
    }
    return orig_msg_seenCount ? orig_msg_seenCount(self, _cmd) : 0;
}

// 2. IGDirectVisualMediaInfo
static NSInteger (*orig_mediaInfo_viewMode)(id self, SEL _cmd);
static NSInteger hook_mediaInfo_viewMode(id self, SEL _cmd) {
    NSInteger mode = orig_mediaInfo_viewMode ? orig_mediaInfo_viewMode(self, _cmd) : 0;
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        if (mode == 0) return 1;
    }
    return mode;
}

static BOOL (*orig_mediaInfo_isViewOnce)(id self, SEL _cmd);
static BOOL hook_mediaInfo_isViewOnce(id self, SEL _cmd) {
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        return NO;
    }
    return orig_mediaInfo_isViewOnce ? orig_mediaInfo_isViewOnce(self, _cmd) : NO;
}

static BOOL (*orig_mediaInfo_isExpired)(id self, SEL _cmd);
static BOOL hook_mediaInfo_isExpired(id self, SEL _cmd) {
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        return NO;
    }
    return orig_mediaInfo_isExpired ? orig_mediaInfo_isExpired(self, _cmd) : NO;
}

static BOOL (*orig_mediaInfo_canReplay)(id self, SEL _cmd);
static BOOL hook_mediaInfo_canReplay(id self, SEL _cmd) {
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        return YES;
    }
    return orig_mediaInfo_canReplay ? orig_mediaInfo_canReplay(self, _cmd) : NO;
}

static long long (*orig_mediaInfo_seenCount)(id self, SEL _cmd);
static long long hook_mediaInfo_seenCount(id self, SEL _cmd) {
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        return 0;
    }
    return orig_mediaInfo_seenCount ? orig_mediaInfo_seenCount(self, _cmd) : 0;
}

// 3. IGDirectVisualMessageViewModel
static NSInteger (*orig_vm_viewMode)(id self, SEL _cmd);
static NSInteger hook_vm_viewMode(id self, SEL _cmd) {
    NSInteger mode = orig_vm_viewMode ? orig_vm_viewMode(self, _cmd) : 0;
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        if (mode == 0) return 1;
    }
    return mode;
}

static BOOL (*orig_vm_isViewOnce)(id self, SEL _cmd);
static BOOL hook_vm_isViewOnce(id self, SEL _cmd) {
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        return NO;
    }
    return orig_vm_isViewOnce ? orig_vm_isViewOnce(self, _cmd) : NO;
}

static BOOL (*orig_vm_isExpired)(id self, SEL _cmd);
static BOOL hook_vm_isExpired(id self, SEL _cmd) {
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        return NO;
    }
    return orig_vm_isExpired ? orig_vm_isExpired(self, _cmd) : NO;
}

static BOOL (*orig_vm_canReplay)(id self, SEL _cmd);
static BOOL hook_vm_canReplay(id self, SEL _cmd) {
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        return YES;
    }
    return orig_vm_canReplay ? orig_vm_canReplay(self, _cmd) : NO;
}

static BOOL (*orig_vm_isReplayable)(id self, SEL _cmd);
static BOOL hook_vm_isReplayable(id self, SEL _cmd) {
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        return YES;
    }
    return orig_vm_isReplayable ? orig_vm_isReplayable(self, _cmd) : NO;
}

static long long (*orig_vm_seenCount)(id self, SEL _cmd);
static long long hook_vm_seenCount(id self, SEL _cmd) {
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        return 0;
    }
    return orig_vm_seenCount ? orig_vm_seenCount(self, _cmd) : 0;
}

// 4. IGDirectVisualMessageCellViewModel
static NSInteger (*orig_cellVM_viewMode)(id self, SEL _cmd);
static NSInteger hook_cellVM_viewMode(id self, SEL _cmd) {
    NSInteger mode = orig_cellVM_viewMode ? orig_cellVM_viewMode(self, _cmd) : 0;
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        if (mode == 0) return 1;
    }
    return mode;
}

static BOOL (*orig_cellVM_isExpired)(id self, SEL _cmd);
static BOOL hook_cellVM_isExpired(id self, SEL _cmd) {
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        return NO;
    }
    return orig_cellVM_isExpired ? orig_cellVM_isExpired(self, _cmd) : NO;
}

static BOOL (*orig_cellVM_canReplay)(id self, SEL _cmd);
static BOOL hook_cellVM_canReplay(id self, SEL _cmd) {
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        return YES;
    }
    return orig_cellVM_canReplay ? orig_cellVM_canReplay(self, _cmd) : NO;
}

static BOOL (*orig_cellVM_isReplayable)(id self, SEL _cmd);
static BOOL hook_cellVM_isReplayable(id self, SEL _cmd) {
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        return YES;
    }
    return orig_cellVM_isReplayable ? orig_cellVM_isReplayable(self, _cmd) : NO;
}

static long long (*orig_cellVM_seenCount)(id self, SEL _cmd);
static long long hook_cellVM_seenCount(id self, SEL _cmd) {
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        return 0;
    }
    return orig_cellVM_seenCount ? orig_cellVM_seenCount(self, _cmd) : 0;
}

// 5. IGDirectVisualMessageViewerController
static BOOL (*orig_viewer_canReplay)(id self, SEL _cmd);
static BOOL hook_viewer_canReplay(id self, SEL _cmd) {
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        return YES;
    }
    return orig_viewer_canReplay ? orig_viewer_canReplay(self, _cmd) : NO;
}

static BOOL (*orig_viewer_isReplayable)(id self, SEL _cmd);
static BOOL hook_viewer_isReplayable(id self, SEL _cmd) {
    if (ENABLED(@"Unlimited Replay Disappearing Media")) {
        return YES;
    }
    return orig_viewer_isReplayable ? orig_viewer_isReplayable(self, _cmd) : NO;
}

void THRegisterPrivateVideoGhostHooks(void) {
    Class viewerClass = ThetaFirstClass(@[
        @"_TtC32IGDirectVisualMessageViewerSwift35IGDirectVisualMessageViewerController",
        @"IGDirectVisualMessageViewerController"
    ]);
    if (viewerClass) {
        NullHookMessageIfPresent(viewerClass, @selector(viewDidLoad), (void *)hook_visualmsgghostbuttons, &orig_visualmsgghostbuttons);
        NullHookMessageIfPresent(viewerClass, @selector(viewDidLayoutSubviews), (void *)hook_visualmsgghost_layoutSubviews, &orig_visualmsgghost_layoutSubviews);
        NullHookMessageIfPresent(viewerClass, @selector(storyPlayerMediaViewDidPlay:), (void *)hook_visualmsgghostvideo, &orig_visualmsgghostvideo);
        NullHookMessageIfPresent(viewerClass, NSSelectorFromString(@"canReplay"), (void *)hook_viewer_canReplay, &orig_viewer_canReplay);
        NullHookMessageIfPresent(viewerClass, NSSelectorFromString(@"isReplayable"), (void *)hook_viewer_isReplayable, &orig_viewer_isReplayable);
    }

    Class photoViewClass = ThetaFirstClass(@[
        @"_TtC16IGStoryPhotoView16IGStoryPhotoView",
        @"IGStoryPhotoView"
    ]);
    if (photoViewClass) {
        NullHookMessageIfPresent(photoViewClass, @selector(progressImageView:didLoadImage:loadSource:networkRequestSummary:), (void *)hook_visualmsgghostphoto, &orig_visualmsgghostphoto);
    }

    // 1. IGDirectVisualMessage
    Class msgClass = ThetaFirstClass(@[
        @"IGDirectVisualMessage",
        @"_TtC16IGDirectEntities21IGDirectVisualMessage"
    ]);
    if (msgClass) {
        NullHookMessageIfPresent(msgClass, NSSelectorFromString(@"viewMode"), (void *)hook_msg_viewMode, &orig_msg_viewMode);
        NullHookMessageIfPresent(msgClass, NSSelectorFromString(@"isViewOnce"), (void *)hook_msg_isViewOnce, &orig_msg_isViewOnce);
        NullHookMessageIfPresent(msgClass, NSSelectorFromString(@"isExpired"), (void *)hook_msg_isExpired, &orig_msg_isExpired);
        NullHookMessageIfPresent(msgClass, NSSelectorFromString(@"hasExpired"), (void *)hook_msg_hasExpired, &orig_msg_hasExpired);
        NullHookMessageIfPresent(msgClass, NSSelectorFromString(@"canReplay"), (void *)hook_msg_canReplay, &orig_msg_canReplay);
        NullHookMessageIfPresent(msgClass, NSSelectorFromString(@"isReplayable"), (void *)hook_msg_isReplayable, &orig_msg_isReplayable);
        NullHookMessageIfPresent(msgClass, NSSelectorFromString(@"seenCount"), (void *)hook_msg_seenCount, &orig_msg_seenCount);
    }

    // 2. IGDirectVisualMediaInfo / IGDirectVisualMedia
    Class mediaInfoClass = ThetaFirstClass(@[
        @"IGDirectVisualMediaInfo",
        @"IGDirectVisualMedia"
    ]);
    if (mediaInfoClass) {
        NullHookMessageIfPresent(mediaInfoClass, NSSelectorFromString(@"viewMode"), (void *)hook_mediaInfo_viewMode, &orig_mediaInfo_viewMode);
        NullHookMessageIfPresent(mediaInfoClass, NSSelectorFromString(@"isViewOnce"), (void *)hook_mediaInfo_isViewOnce, &orig_mediaInfo_isViewOnce);
        NullHookMessageIfPresent(mediaInfoClass, NSSelectorFromString(@"isExpired"), (void *)hook_mediaInfo_isExpired, &orig_mediaInfo_isExpired);
        NullHookMessageIfPresent(mediaInfoClass, NSSelectorFromString(@"canReplay"), (void *)hook_mediaInfo_canReplay, &orig_mediaInfo_canReplay);
        NullHookMessageIfPresent(mediaInfoClass, NSSelectorFromString(@"seenCount"), (void *)hook_mediaInfo_seenCount, &orig_mediaInfo_seenCount);
    }

    // 3. IGDirectVisualMessageViewModel
    Class vmClass = ThetaFirstClass(@[
        @"IGDirectVisualMessageViewModel",
        @"_TtC25IGDirectVisualMessageUI31IGDirectVisualMessageViewModel"
    ]);
    if (vmClass) {
        NullHookMessageIfPresent(vmClass, NSSelectorFromString(@"viewMode"), (void *)hook_vm_viewMode, &orig_vm_viewMode);
        NullHookMessageIfPresent(vmClass, NSSelectorFromString(@"isViewOnce"), (void *)hook_vm_isViewOnce, &orig_vm_isViewOnce);
        NullHookMessageIfPresent(vmClass, NSSelectorFromString(@"isExpired"), (void *)hook_vm_isExpired, &orig_vm_isExpired);
        NullHookMessageIfPresent(vmClass, NSSelectorFromString(@"canReplay"), (void *)hook_vm_canReplay, &orig_vm_canReplay);
        NullHookMessageIfPresent(vmClass, NSSelectorFromString(@"isReplayable"), (void *)hook_vm_isReplayable, &orig_vm_isReplayable);
        NullHookMessageIfPresent(vmClass, NSSelectorFromString(@"seenCount"), (void *)hook_vm_seenCount, &orig_vm_seenCount);
    }

    // 4. IGDirectVisualMessageCellViewModel / bubble view model
    Class cellVMClass = ThetaFirstClass(@[
        @"IGDirectVisualMessageCellViewModel",
        @"IGDirectVisualMessageBubbleViewModel",
        @"IGDirectVisualMessageActivityViewModel"
    ]);
    if (cellVMClass) {
        NullHookMessageIfPresent(cellVMClass, NSSelectorFromString(@"viewMode"), (void *)hook_cellVM_viewMode, &orig_cellVM_viewMode);
        NullHookMessageIfPresent(cellVMClass, NSSelectorFromString(@"isExpired"), (void *)hook_cellVM_isExpired, &orig_cellVM_isExpired);
        NullHookMessageIfPresent(cellVMClass, NSSelectorFromString(@"canReplay"), (void *)hook_cellVM_canReplay, &orig_cellVM_canReplay);
        NullHookMessageIfPresent(cellVMClass, NSSelectorFromString(@"isReplayable"), (void *)hook_cellVM_isReplayable, &orig_cellVM_isReplayable);
        NullHookMessageIfPresent(cellVMClass, NSSelectorFromString(@"seenCount"), (void *)hook_cellVM_seenCount, &orig_cellVM_seenCount);
    }
}