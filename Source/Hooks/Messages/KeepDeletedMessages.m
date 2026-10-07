#import "Include/ThetaHelper.h"
#import "Include/MessagesManager.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

static char kThetaOriginalBackgroundColorKey;
static char kThetaProcessedMessageIdKey;
static char kThetaOverlayViewKey;

#define THETA_DELETED_BADGE_TAG 77005

static NSMutableDictionary<NSString *, NSDate *> *thetaDeleteForYouKeys;

static void thetaPruneDeleteForYouKeys(void) {
	if (!thetaDeleteForYouKeys.count) return;
	NSDate *cutoff = [NSDate dateWithTimeIntervalSinceNow:-10.0];
	for (NSString *sid in [thetaDeleteForYouKeys.allKeys copy]) {
		if ([thetaDeleteForYouKeys[sid] compare:cutoff] == NSOrderedAscending) {
			[thetaDeleteForYouKeys removeObjectForKey:sid];
		}
	}
}

static UIView *thetaFindMessageBubble(UIView *root) {
	if (!root) return nil;
	Class bubbleClass = NSClassFromString(@"IGDirectMessageBubbleView");
	if (bubbleClass && [root isKindOfClass:bubbleClass]) return root;
	// Heuristic: look for any subview class name that contains "BubbleView"
	for (UIView *sub in root.subviews) {
		NSString *className = NSStringFromClass([sub class]);
		if ([className containsString:@"BubbleView"]) return sub;
	}
	for (UIView *sub in root.subviews) {
		UIView *found = thetaFindMessageBubble(sub);
		if (found) return found;
	}
	return nil;
}

static UIView *thetaFindFirstSubviewOfClass(UIView *root, Class cls) {
	if (!root || !cls) return nil;
	for (UIView *sub in root.subviews) {
		if ([sub isKindOfClass:cls]) return sub;
	}
	for (UIView *sub in root.subviews) {
		UIView *found = thetaFindFirstSubviewOfClass(sub, cls);
		if (found) return found;
	}
	return nil;
}

// Find: IGDirectMessageBubbleView (outer) -> IGDirectTextMessageBubbleView -> IGDirectMessageBubbleView (inner target)
static UIView *thetaFindInnerTextMessageBubble(UIView *root) {
	if (!root) return nil;
	Class outerBubble = NSClassFromString(@"IGDirectMessageBubbleView");
	Class textBubble = NSClassFromString(@"IGDirectTextMessageBubbleView");
	Class innerBubble = NSClassFromString(@"IGDirectMessageBubbleView");

	UIView *outer = thetaFindFirstSubviewOfClass(root, outerBubble) ?: root;
	UIView *text = thetaFindFirstSubviewOfClass(outer, textBubble);
	if (!text) {
		text = thetaFindFirstSubviewOfClass(root, textBubble);
	}
	if (!text) return nil;
	UIView *inner = thetaFindFirstSubviewOfClass(text, innerBubble);
	return inner ?: nil;
}

static NSString *thetaServerIdFromKey(id key) {
	if (!key) return nil;
	if ([key isKindOfClass:[NSString class]]) return (NSString *)key;

	static const char *names[] = {"_messageServerId", "_serverId"};
	for (int i = 0; i < 2; i++) {
		Ivar iv = class_getInstanceVariable([key class], names[i]);
		if (iv) {
			@try {
				id val = object_getIvar(key, iv);
				if ([val isKindOfClass:[NSString class]] && [(NSString *)val length] > 0) {
					return (NSString *)val;
				}
				if ([val isKindOfClass:[NSNumber class]]) {
					return [(NSNumber *)val stringValue];
				}
			} @catch (__unused id e) {}
		}
	}

	@try {
		id sid = [key valueForKey:@"serverId"];
		if ([sid isKindOfClass:[NSString class]] && [(NSString *)sid length] > 0) return (NSString *)sid;
		if ([sid isKindOfClass:[NSNumber class]]) return [(NSNumber *)sid stringValue];
	} @catch (__unused id e) {}

	@try {
		id sid = [key valueForKey:@"messageServerId"];
		if ([sid isKindOfClass:[NSString class]] && [(NSString *)sid length] > 0) return (NSString *)sid;
		if ([sid isKindOfClass:[NSNumber class]]) return [(NSNumber *)sid stringValue];
	} @catch (__unused id e) {}

	@try {
		id sid = [key valueForKey:@"_serverId"];
		if ([sid isKindOfClass:[NSString class]] && [(NSString *)sid length] > 0) return (NSString *)sid;
		if ([sid isKindOfClass:[NSNumber class]]) return [(NSNumber *)sid stringValue];
	} @catch (__unused id e) {}

	@try {
		id sid = [key valueForKey:@"_messageServerId"];
		if ([sid isKindOfClass:[NSString class]] && [(NSString *)sid length] > 0) return (NSString *)sid;
		if ([sid isKindOfClass:[NSNumber class]]) return [(NSNumber *)sid stringValue];
	} @catch (__unused id e) {}

	return nil;
}

static NSString *thetaGetCellServerId(id cell) {
	if (!cell) return nil;
	@try {
		id vm = nil;
		Ivar vmIvar = class_getInstanceVariable([cell class], "_viewModel");
		if (vmIvar) vm = object_getIvar(cell, vmIvar);
		if (!vm && [cell respondsToSelector:@selector(viewModel)]) {
			vm = [cell valueForKey:@"viewModel"];
		}
		if (!vm) return nil;

		id meta = nil;
		if ([vm respondsToSelector:@selector(messageMetadata)]) {
			#pragma clang diagnostic push
			#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
			meta = [vm performSelector:@selector(messageMetadata)];
			#pragma clang diagnostic pop
		} else {
			@try { meta = [vm valueForKey:@"messageMetadata"]; } @catch (__unused id e) {}
		}
		if (!meta) return nil;

		// 1. Check meta directly
		static const char *metaNames[] = {"_serverId", "_messageServerId"};
		for (int i = 0; i < 2; i++) {
			Ivar iv = class_getInstanceVariable([meta class], metaNames[i]);
			if (iv) {
				id sid = object_getIvar(meta, iv);
				if ([sid isKindOfClass:[NSString class]] && [(NSString *)sid length] > 0) return (NSString *)sid;
				if ([sid isKindOfClass:[NSNumber class]]) return [(NSNumber *)sid stringValue];
			}
		}

		@try {
			id sid = [meta valueForKey:@"serverId"] ?: [meta valueForKey:@"messageServerId"];
			if ([sid isKindOfClass:[NSString class]] && [(NSString *)sid length] > 0) return (NSString *)sid;
			if ([sid isKindOfClass:[NSNumber class]]) return [(NSNumber *)sid stringValue];
		} @catch (__unused id e) {}

		// 2. Check meta._key
		id keyObj = nil;
		Ivar keyIvar = class_getInstanceVariable([meta class], "_key");
		if (keyIvar) keyObj = object_getIvar(meta, keyIvar);
		if (!keyObj) {
			@try { keyObj = [meta valueForKey:@"key"]; } @catch (__unused id e) {}
		}
		if (keyObj) {
			NSString *sid = thetaServerIdFromKey(keyObj);
			if (sid.length > 0) return sid;
		}
	} @catch (__unused id e) {}
	return nil;
}

static void thetaUpdateCellAppearance(id cell) {
	if (!cell || ![cell isKindOfClass:[UIView class]]) return;
	if (!ENABLED(@"Keep Deleted Messages")) return;

	NSString *serverId = thetaGetCellServerId(cell);
	if (serverId.length == 0) return;

	BOOL isDeleted = [[MessagesManager sharedManager] messageExistsWithID:serverId];

	UIView *container = nil;
	Ivar mccvIvar = class_getInstanceVariable([cell class], "_messageContentContainerView");
	if (mccvIvar) {
		container = object_getIvar(cell, mccvIvar);
	}
	if (!container && [cell respondsToSelector:@selector(contentViewForVisualMessageViewerPresentation)]) {
		#pragma clang diagnostic push
		#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
		container = [cell performSelector:@selector(contentViewForVisualMessageViewerPresentation)];
		#pragma clang diagnostic pop
	}
	if (!container && [cell respondsToSelector:@selector(contentView)]) {
		@try { container = [cell valueForKey:@"contentView"]; } @catch (__unused id e) {}
	}
	if (!container) {
		container = (UIView *)cell;
	}

	UIView *bubble = thetaFindInnerTextMessageBubble(container);
	if (!bubble) bubble = thetaFindMessageBubble(container);
	if (!bubble) bubble = container;

	UIColor *originalBackgroundColor = objc_getAssociatedObject(bubble, &kThetaOriginalBackgroundColorKey);
	if (!originalBackgroundColor) {
		@try {
			originalBackgroundColor = [bubble valueForKey:@"backgroundColor"];
			if (originalBackgroundColor) {
				objc_setAssociatedObject(bubble, &kThetaOriginalBackgroundColorKey, originalBackgroundColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			}
		} @catch (__unused NSException *e) {}
	}

	UIColor *targetColor = nil;
	if (isDeleted) {
		@try {
			NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"Deleted Message Color_Color"];
			if (data) {
				targetColor = [NSKeyedUnarchiver unarchivedObjectOfClass:[UIColor class] fromData:data error:nil];
			}
		} @catch (__unused NSException *e) {}
		if (!targetColor) targetColor = [UIColor systemRedColor];
	} else if (originalBackgroundColor) {
		targetColor = originalBackgroundColor;
	}

	if (targetColor) {
		@try {
			// 1) Direct background set
			[bubble setValue:targetColor forKey:@"backgroundColor"];
			if ([bubble layer]) {
				bubble.layer.backgroundColor = targetColor.CGColor;
			}
			// 2) Shape layers tinting
			for (CALayer *sublayer in bubble.layer.sublayers ?: @[]) {
				if ([sublayer isKindOfClass:[CAShapeLayer class]]) {
					((CAShapeLayer *)sublayer).fillColor = targetColor.CGColor;
					((CAShapeLayer *)sublayer).backgroundColor = targetColor.CGColor;
				}
			}
			// 3) Overlay view for consistent styling
			UIView *overlay = objc_getAssociatedObject(bubble, &kThetaOverlayViewKey);
			if (isDeleted) {
				if (!overlay) {
					overlay = [[UIView alloc] initWithFrame:bubble.bounds];
					overlay.userInteractionEnabled = NO;
					overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
					overlay.layer.cornerRadius = bubble.layer.cornerRadius;
					overlay.layer.masksToBounds = YES;
					objc_setAssociatedObject(bubble, &kThetaOverlayViewKey, overlay, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
					[bubble insertSubview:overlay atIndex:0];
				}
				overlay.backgroundColor = targetColor;
				overlay.hidden = NO;
			} else {
				if (overlay) overlay.hidden = YES;
			}

			// 4) Visual badge indicator (Supprimé)
			UILabel *badge = [bubble viewWithTag:THETA_DELETED_BADGE_TAG];
			if (isDeleted) {
				if (!badge) {
					badge = [[UILabel alloc] init];
					badge.tag = THETA_DELETED_BADGE_TAG;
					badge.text = @" Supprimé ";
					badge.font = [UIFont boldSystemFontOfSize:9];
					badge.textColor = [UIColor whiteColor];
					badge.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];
					badge.layer.cornerRadius = 4;
					badge.layer.masksToBounds = YES;
					badge.translatesAutoresizingMaskIntoConstraints = NO;
					[bubble addSubview:badge];
					[NSLayoutConstraint activateConstraints:@[
						[badge.trailingAnchor constraintEqualToAnchor:bubble.trailingAnchor constant:-4],
						[badge.topAnchor constraintEqualToAnchor:bubble.topAnchor constant:2]
					]];
				}
				badge.hidden = NO;
				[bubble bringSubviewToFront:badge];
			} else {
				if (badge) badge.hidden = YES;
			}
		} @catch (__unused NSException *e) {}
	}
}

static void thetaRefreshVisibleCellIndicators(void) {
	Class cellClass = ThetaFirstClass(@[
		@"_TtC19IGDirectMessageCell19IGDirectMessageCell",
		@"IGDirectMessageCell"
	]);
	if (!cellClass) return;

	UIWindow *window = nil;
	for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
		if ([scene isKindOfClass:[UIWindowScene class]]) {
			for (UIWindow *w in ((UIWindowScene *)scene).windows) {
				if (w.isKeyWindow) { window = w; break; }
			}
		}
		if (window) break;
	}
	if (!window) {
		for (UIWindow *w in [UIApplication sharedApplication].windows) {
			if (w.isKeyWindow) { window = w; break; }
		}
	}
	if (!window) window = [UIApplication sharedApplication].windows.firstObject;
	if (!window) return;

	NSMutableArray *stack = [NSMutableArray arrayWithObject:window];
	while (stack.count > 0) {
		UIView *v = stack.lastObject;
		[stack removeLastObject];
		if ([v isKindOfClass:cellClass]) {
			thetaUpdateCellAppearance(v);
			continue;
		}
		for (UIView *sub in v.subviews) {
			[stack addObject:sub];
		}
	}
}

static NSArray *theta_threadUpdatesFromCacheUpdate(id cacheUpdate) {
	if (!cacheUpdate) return nil;

	// 1. Check method / KVC threadUpdates
	@try {
		id updates = [cacheUpdate valueForKey:@"threadUpdates"];
		if ([updates isKindOfClass:[NSArray class]] && [(NSArray *)updates count] > 0) {
			return (NSArray *)updates;
		}
	} @catch (__unused id e) {}

	// 2. Check ivar _threadUpdates (array)
	Ivar uiv = class_getInstanceVariable([cacheUpdate class], "_threadUpdates");
	if (uiv) {
		@try {
			id arr = object_getIvar(cacheUpdate, uiv);
			if ([arr isKindOfClass:[NSArray class]] && [(NSArray *)arr count] > 0) {
				return (NSArray *)arr;
			}
		} @catch (__unused id e) {}
	}

	// 3. Check ivar _threadUpdate (single object in modern Instagram 448+)
	Ivar siv = class_getInstanceVariable([cacheUpdate class], "_threadUpdate");
	if (siv) {
		@try {
			id single = object_getIvar(cacheUpdate, siv);
			if (single) return @[ single ];
		} @catch (__unused id e) {}
	}

	// 4. Try KVC threadUpdate (single)
	@try {
		id single = [cacheUpdate valueForKey:@"threadUpdate"];
		if (single) return @[ single ];
	} @catch (__unused id e) {}

	// 5. Fallback: if cacheUpdate itself has _messageUpdate, treat it as a threadUpdate
	Ivar miv = class_getInstanceVariable([cacheUpdate class], "_messageUpdate");
	if (miv) {
		return @[ cacheUpdate ];
	}

	return nil;
}

static id theta_messageUpdateFromThreadUpdate(id threadUpdate) {
	if (!threadUpdate) return nil;

	// 1. Check ivar _messageUpdate
	Ivar miv = class_getInstanceVariable([threadUpdate class], "_messageUpdate");
	if (miv) {
		@try {
			id msg = object_getIvar(threadUpdate, miv);
			if (msg) return msg;
		} @catch (__unused id e) {}
	}

	// 2. Check KVC messageUpdate
	@try {
		id msg = [threadUpdate valueForKey:@"messageUpdate"];
		if (msg) return msg;
	} @catch (__unused id e) {}

	// 3. Check KVC _messageUpdate
	@try {
		id msg = [threadUpdate valueForKey:@"_messageUpdate"];
		if (msg) return msg;
	} @catch (__unused id e) {}

	// 4. If threadUpdate itself has _removeMessages_messageKeys, it is already a messageUpdate
	Ivar rmIvar = class_getInstanceVariable([threadUpdate class], "_removeMessages_messageKeys");
	if (rmIvar) {
		return threadUpdate;
	}

	return nil;
}

static void processThreadUpdatesAndNeuterRemovals(id updates) {
	if (!updates) return;

	NSArray *updateList = nil;
	if ([updates isKindOfClass:[NSArray class]]) {
		updateList = (NSArray *)updates;
	} else {
		updateList = @[ updates ];
	}

	if (!thetaDeleteForYouKeys) {
		thetaDeleteForYouKeys = [[NSMutableDictionary alloc] init];
	}
	thetaPruneDeleteForYouKeys();

	BOOL preservedAny = NO;

	for (id cacheUpdate in updateList) {
		NSArray *threadUpdates = theta_threadUpdatesFromCacheUpdate(cacheUpdate);
		if (!threadUpdates) continue;

		for (id tu in threadUpdates) {
			id msgUpdate = theta_messageUpdateFromThreadUpdate(tu);
			if (!msgUpdate) continue;

			// Extract remove keys
			NSArray *keys = nil;
			Ivar rmIvar = class_getInstanceVariable([msgUpdate class], "_removeMessages_messageKeys");
			if (rmIvar) {
				@try {
					keys = object_getIvar(msgUpdate, rmIvar);
				} @catch (__unused id e) {}
			}
			if (![keys isKindOfClass:[NSArray class]] || keys.count == 0) {
				@try {
					id val = [msgUpdate valueForKey:@"removeMessages_messageKeys"] ?: [msgUpdate valueForKey:@"_removeMessages_messageKeys"];
					if ([val isKindOfClass:[NSArray class]]) keys = val;
				} @catch (__unused id e) {}
			}

			if (![keys isKindOfClass:[NSArray class]] || keys.count == 0) {
				continue;
			}

			// Check reason (0 = unsend by sender, 2 = delete for me)
			long long reason = -1;
			Ivar rIvar = class_getInstanceVariable([msgUpdate class], "_removeMessages_reason");
			if (rIvar) {
				@try {
					ptrdiff_t off = ivar_getOffset(rIvar);
					reason = *(long long *)((char *)(__bridge void *)msgUpdate + off);
				} @catch (__unused id e) {}
			}

			// reason == 2 is "Delete for me" (local user deletion)
			if (reason == 2) {
				for (id key in keys) {
					NSString *sid = thetaServerIdFromKey(key);
					if (sid.length > 0) {
						thetaDeleteForYouKeys[sid] = [NSDate date];
					}
				}
				continue;
			}

			// If reason is not 0 (unsend) and not -1 (unspecified), skip neutering
			if (reason != 0 && reason != -1) {
				continue;
			}

			// Check if any key was marked for delete-for-me
			BOOL isDeleteForMe = NO;
			for (id key in keys) {
				NSString *sid = thetaServerIdFromKey(key);
				if (sid.length > 0 && thetaDeleteForYouKeys[sid]) {
					isDeleteForMe = YES;
					[thetaDeleteForYouKeys removeObjectForKey:sid];
				}
			}
			if (isDeleteForMe) {
				continue;
			}

			// This is an unsend by the sender! Preserve the messages!
			for (id key in keys) {
				NSString *sid = thetaServerIdFromKey(key);
				if (sid.length > 0) {
					[[MessagesManager sharedManager] saveDeletedMessageWithID:sid];
					preservedAny = YES;
				}
			}

			// NEUTER the unsend removal in Instagram's cache updates!
			if (rmIvar) {
				@try {
					object_setIvar(msgUpdate, rmIvar, nil);
				} @catch (__unused id e) {}
			}
			@try {
				[msgUpdate setValue:nil forKey:@"_removeMessages_messageKeys"];
			} @catch (__unused id e) {}
			@try {
				[msgUpdate setValue:@[] forKey:@"_removeMessages_messageKeys"];
			} @catch (__unused id e) {}
		}
	}

	if (preservedAny) {
		dispatch_async(dispatch_get_main_queue(), ^{
			thetaRefreshVisibleCellIndicators();
		});
	}
}

static void (*orig_directMessageCell_configure_mobileConfig)(id self, SEL _cmd, id viewModel, id specFactory, id mobileConfig);
static void hook_directMessageCell_configure_mobileConfig(id self, SEL _cmd, id viewModel, id specFactory, id mobileConfig) {
	if (orig_directMessageCell_configure_mobileConfig) {
		orig_directMessageCell_configure_mobileConfig(self, _cmd, viewModel, specFactory, mobileConfig);
	}
	if (!ENABLED(@"Keep Deleted Messages")) return;
	thetaUpdateCellAppearance(self);
}

static void (*orig_directMessageCell_configure_launcherSet)(id self, SEL _cmd, id viewModel, id specFactory, id launcher);
static void hook_directMessageCell_configure_launcherSet(id self, SEL _cmd, id viewModel, id specFactory, id launcher) {
	if (orig_directMessageCell_configure_launcherSet) {
		orig_directMessageCell_configure_launcherSet(self, _cmd, viewModel, specFactory, launcher);
	}
	if (!ENABLED(@"Keep Deleted Messages")) return;
	thetaUpdateCellAppearance(self);
}

static void (*orig_directMessageCell_layoutSubviews)(id self, SEL _cmd);
static void hook_directMessageCell_layoutSubviews(id self, SEL _cmd) {
	if (orig_directMessageCell_layoutSubviews) orig_directMessageCell_layoutSubviews(self, _cmd);
	if (!ENABLED(@"Keep Deleted Messages")) return;
	thetaUpdateCellAppearance(self);
}

static void (*orig_removeMutationExecute)(id self, SEL _cmd, id handler, id pkg);
static void hook_removeMutationExecute(id self, SEL _cmd, id handler, id pkg) {
	Ivar keysIvar = class_getInstanceVariable([self class], "_messageKeys");
	NSArray *keys = keysIvar ? object_getIvar(self, keysIvar) : nil;
	long long reason = -1;
	Ivar rIvar = class_getInstanceVariable([self class], "_reason");
	if (rIvar) {
		@try {
			ptrdiff_t off = ivar_getOffset(rIvar);
			reason = *(long long *)((char *)(__bridge void *)self + off);
		} @catch (__unused id e) {}
	}
	if ([keys isKindOfClass:[NSArray class]]) {
		if (!thetaDeleteForYouKeys) thetaDeleteForYouKeys = [[NSMutableDictionary alloc] init];
		if (reason == 2) {
			for (id key in keys) {
				NSString *sid = thetaServerIdFromKey(key);
				if (sid.length > 0) thetaDeleteForYouKeys[sid] = [NSDate date];
			}
		}
	}
	if (orig_removeMutationExecute) orig_removeMutationExecute(self, _cmd, handler, pkg);
}

static void (*orig_directCache_removeMessages)(id self, SEL _cmd, id messageKeys);
static void hook_directCache_removeMessages(id self, SEL _cmd, id messageKeys) {
	if (ENABLED(@"Keep Deleted Messages")) {
		if ([messageKeys isKindOfClass:[NSArray class]]) {
			BOOL anyDeleteForMe = NO;
			for (id key in messageKeys) {
				NSString *sid = thetaServerIdFromKey(key);
				if (sid.length > 0) {
					if (thetaDeleteForYouKeys && thetaDeleteForYouKeys[sid]) {
						anyDeleteForMe = YES;
					} else {
						[[MessagesManager sharedManager] saveDeletedMessageWithID:sid];
					}
				}
			}
			if (anyDeleteForMe) {
				if (orig_directCache_removeMessages) orig_directCache_removeMessages(self, _cmd, messageKeys);
				return;
			}
			dispatch_async(dispatch_get_main_queue(), ^{ thetaRefreshVisibleCellIndicators(); });
		}
		return;
	}
	if (orig_directCache_removeMessages) orig_directCache_removeMessages(self, _cmd, messageKeys);
}

static void (*orig_directCache_removeMessage)(id self, SEL _cmd, id messageKey);
static void hook_directCache_removeMessage(id self, SEL _cmd, id messageKey) {
	if (ENABLED(@"Keep Deleted Messages")) {
		NSString *sid = thetaServerIdFromKey(messageKey);
		if (sid.length > 0) {
			if (thetaDeleteForYouKeys && thetaDeleteForYouKeys[sid]) {
				if (orig_directCache_removeMessage) orig_directCache_removeMessage(self, _cmd, messageKey);
				return;
			}
			[[MessagesManager sharedManager] saveDeletedMessageWithID:sid];
			dispatch_async(dispatch_get_main_queue(), ^{ thetaRefreshVisibleCellIndicators(); });
		}
		return;
	}
	if (orig_directCache_removeMessage) orig_directCache_removeMessage(self, _cmd, messageKey);
}

static void (*orig_messageCache3)(id self, SEL _cmd, id updates, id completion, id userAccess);
static void hook_messageCache3(id self, SEL _cmd, id updates, id completion, id userAccess) {
	if (ENABLED(@"Keep Deleted Messages")) {
		@try {
			processThreadUpdatesAndNeuterRemovals(updates);
		} @catch (NSException *e) {
			NSLog(@"[Theta] Error neutering thread updates (3-arg): %@", e);
		}
	}
	if (orig_messageCache3) orig_messageCache3(self, _cmd, updates, completion, userAccess);
}

static void (*orig_messageCache2)(id self, SEL _cmd, id updates, id completion);
static void hook_messageCache2(id self, SEL _cmd, id updates, id completion) {
	if (ENABLED(@"Keep Deleted Messages")) {
		@try {
			processThreadUpdatesAndNeuterRemovals(updates);
		} @catch (NSException *e) {
			NSLog(@"[Theta] Error neutering thread updates (2-arg): %@", e);
		}
	}
	if (orig_messageCache2) orig_messageCache2(self, _cmd, updates, completion);
}

static void (*orig_messageCache1)(id self, SEL _cmd, id updates);
static void hook_messageCache1(id self, SEL _cmd, id updates) {
	if (ENABLED(@"Keep Deleted Messages")) {
		@try {
			processThreadUpdatesAndNeuterRemovals(updates);
		} @catch (NSException *e) {
			NSLog(@"[Theta] Error neutering thread updates (1-arg): %@", e);
		}
	}
	if (orig_messageCache1) orig_messageCache1(self, _cmd, updates);
}

void THRegisterKeepDeletedMessagesHooks(void) {
	Class applicator = ThetaFirstClass(@[
		@"_TtC26IGDirectCacheUpdatesApplicator26IGDirectCacheUpdatesApplicator",
		@"IGDirectCacheUpdatesApplicator"
	]);
	if (applicator) {
		NullHookMessageIfPresent(applicator, @selector(_applyThreadUpdates:completion:userAccess:), (void *)hook_messageCache3, &orig_messageCache3);
		NullHookMessageIfPresent(applicator, @selector(_applyThreadUpdates:completion:), (void *)hook_messageCache2, &orig_messageCache2);
		NullHookMessageIfPresent(applicator, @selector(_applyThreadUpdates:), (void *)hook_messageCache1, &orig_messageCache1);
	}

	Class removeCls = NSClassFromString(@"IGDirectMessageOutgoingUpdateRemoveMessagesMutationProcessor");
	if (removeCls) {
		NullHookMessageIfPresent(removeCls, NSSelectorFromString(@"executeWithResultHandler:accessoryPackage:"), (void *)hook_removeMutationExecute, &orig_removeMutationExecute);
	}

	Class cache = ThetaFirstClass(@[
		@"_TtC13IGDirectCache13IGDirectCache",
		@"IGDirectCache"
	]);
	if (cache) {
		NullHookMessageIfPresent(cache, @selector(removeMessagesWithMessageKeys:), (void *)hook_directCache_removeMessages, &orig_directCache_removeMessages);
		NullHookMessageIfPresent(cache, @selector(removeMessageWithKey:), (void *)hook_directCache_removeMessage, &orig_directCache_removeMessage);
	}

	Class messageCell = ThetaFirstClass(@[
		@"_TtC19IGDirectMessageCell19IGDirectMessageCell",
		@"IGDirectMessageCell"
	]);
	if (messageCell) {
		// Modern Instagram 448+ selector (renamed trailing launcherSet: to mobileConfig:)
		NullHookMessageIfPresent(messageCell,
			NSSelectorFromString(@"configureWithViewModel:ringViewSpecFactory:mobileConfig:"),
			(void *)hook_directMessageCell_configure_mobileConfig,
			&orig_directMessageCell_configure_mobileConfig);
		// Legacy Instagram selector (<448)
		NullHookMessageIfPresent(messageCell,
			NSSelectorFromString(@"configureWithViewModel:ringViewSpecFactory:launcherSet:"),
			(void *)hook_directMessageCell_configure_launcherSet,
			&orig_directMessageCell_configure_launcherSet);
		NullHookMessageIfPresent(messageCell,
			@selector(layoutSubviews),
			(void *)hook_directMessageCell_layoutSubviews,
			&orig_directMessageCell_layoutSubviews);
	}
}