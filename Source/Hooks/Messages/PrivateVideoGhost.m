static BOOL videoPlayed = NO;

@class IGVideo;
static void downloadHDVideo(IGVideo *inputVideo);

static void (*orig_visualmsgghostbuttons)(IGDirectVisualMessageViewerController *self, SEL _cmd);
static void hook_visualmsgghostbuttons(IGDirectVisualMessageViewerController *self, SEL _cmd) {
    orig_visualmsgghostbuttons(self, _cmd);

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
        return orig_visualmsgghostvideo(self, _cmd, arg1);
    }

    if (videoPlayed) {
        orig_visualmsgghostvideo(self, _cmd, arg1);
        videoPlayed = NO;
    }
}

static void (*orig_visualmsgghostphoto)(id self, SEL _cmd, id arg1, id arg2, id arg3, id arg4);
static void hook_visualmsgghostphoto(id self, SEL _cmd, id arg1, id arg2, id arg3, id arg4) {
    if (!ENABLED(@"Private Media Ghost")) {
        return orig_visualmsgghostphoto(self, _cmd, arg1, arg2, arg3, arg4);
    }

    if (videoPlayed) {
        orig_visualmsgghostphoto(self, _cmd, arg1, arg2, arg3, arg4);
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

void THRegisterPrivateVideoGhostHooks(void) {
    NullHookMessageEx(objc_getClass("IGDirectVisualMessageViewerController"), @selector(viewDidLoad), (void *)hook_visualmsgghostbuttons, &orig_visualmsgghostbuttons);
    NullHookMessageEx(objc_getClass("IGDirectVisualMessageViewerController"), @selector(viewDidLayoutSubviews), (void *)hook_visualmsgghost_layoutSubviews, &orig_visualmsgghost_layoutSubviews);
    NullHookMessageEx(objc_getClass("IGDirectVisualMessageViewerController"), @selector(storyPlayerMediaViewDidPlay:), (void *)hook_visualmsgghostvideo, &orig_visualmsgghostvideo);
    NullHookMessageEx(objc_getClass("IGStoryPhotoView"), @selector(progressImageView:didLoadImage:loadSource:networkRequestSummary:), (void *)hook_visualmsgghostphoto, &orig_visualmsgghostphoto);
}