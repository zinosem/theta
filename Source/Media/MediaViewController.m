#import "Include/MediaViewController.h"



@implementation MediaViewController
- (instancetype)initWithMediaURL:(NSURL *)url {
    self = [super init];
    if (self) {
        _mediaURL = url;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    NSString *path = _mediaURL.path.lowercaseString;
    NSString *fileExtension = [_mediaURL pathExtension].lowercaseString;

    BOOL isVideo = ([fileExtension isEqualToString:@"mp4"] ||
                    [fileExtension isEqualToString:@"mov"] ||
                    [fileExtension isEqualToString:@"m4v"] ||
                    [path containsString:@".mp4"] ||
                    [path containsString:@".mov"]);

    if (isVideo) {
        [self displayVideo];
    } else {
        [self displayImage];
    }

    [self setupDismissButton];
}

- (void)setupDismissButton {
    UIButton *dismissButton = [UIButton buttonWithType:UIButtonTypeSystem];
    dismissButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightBold];
    [dismissButton setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:config] forState:UIControlStateNormal];
    [dismissButton setTintColor:[UIColor whiteColor]];
    dismissButton.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.6];
    dismissButton.layer.cornerRadius = 20;
    dismissButton.layer.borderWidth = 1.0;
    dismissButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.25].CGColor;
    dismissButton.clipsToBounds = YES;
    [dismissButton addTarget:self action:@selector(dismissViewController) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:dismissButton];

    [NSLayoutConstraint activateConstraints:@[
        [dismissButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [dismissButton.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [dismissButton.widthAnchor constraintEqualToConstant:40],
        [dismissButton.heightAnchor constraintEqualToConstant:40]
    ]];
}

- (void)displayImage {
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.delegate = self;
    self.scrollView.maximumZoomScale = 3.0;
    self.scrollView.minimumZoomScale = 1.0;
    [self.view addSubview:self.scrollView];

    self.imageView = [[UIImageView alloc] initWithFrame:self.scrollView.bounds];
    self.imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.imageView.userInteractionEnabled = YES;
    [self.scrollView addSubview:self.imageView];

    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spinner.color = [UIColor whiteColor];
    spinner.center = self.view.center;
    spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [spinner startAnimating];
    [self.view addSubview:spinner];

    NSURL *url = _mediaURL;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *imageData = nil;
        if ([url isFileURL]) {
            imageData = [NSData dataWithContentsOfURL:url];
        } else {
            NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
            config.timeoutIntervalForRequest = 15;
            NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
            dispatch_semaphore_t sem = dispatch_semaphore_create(0);
            __block NSData *downloaded = nil;
            [[session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (data && !error) downloaded = data;
                dispatch_semaphore_signal(sem);
            }] resume];
            dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC));
            imageData = downloaded;
        }
        UIImage *image = imageData ? [UIImage imageWithData:imageData] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [spinner stopAnimating];
            [spinner removeFromSuperview];
            if (image) {
                self.imageView.image = image;
            }
        });
    });
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.imageView;
}

- (void)displayVideo {
    @try {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayback error:nil];
        [session setActive:YES error:nil];
    } @catch (__unused NSException *e) {}

    AVPlayer *player = [AVPlayer playerWithURL:_mediaURL];
    self.playerViewController = [AVPlayerViewController new];
    self.playerViewController.player = player;
    self.playerViewController.showsPlaybackControls = YES;

    [self addChildViewController:self.playerViewController];
    [self.view addSubview:self.playerViewController.view];
    self.playerViewController.view.frame = self.view.bounds;
    self.playerViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.playerViewController didMoveToParentViewController:self];

    [player play];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if (self.imageView) {
        self.imageView.image = nil;
    }

    if (self.playerViewController) {
        [self.playerViewController.player pause];
        [self.playerViewController.view removeFromSuperview];
        [self.playerViewController removeFromParentViewController];
        self.playerViewController = nil;
    }
}

- (void)dismissViewController {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end