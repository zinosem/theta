#import "Include/ThetaHelper.h"
#import "Include/MessagesManager.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char kThetaOriginalBackgroundColorKey;
static char kThetaProcessedMessageIdKey;
static char kThetaOverlayViewKey;

#define THETA_DELETED_BADGE_TAG 77005

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

static NSString *thetaGetCellServerId(id cell) {
	if (!cell) return nil;
	@try {
		Ivar vmIvar = class_getInstanceVariable([cell class], "_viewModel");
		id vm = vmIvar ? object_getIvar(cell, vmIvar) : nil;
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

		id keyObj = nil;
		Ivar keyIvar = class_getInstanceVariable([meta class], "_key");
		if (keyIvar) keyObj = object_getIvar(meta, keyIvar);
		if (!keyObj) {
			@try { keyObj = [meta valueForKey:@"key"]; } @catch (__unused id e) {}
		}
		if (!keyObj) return nil;

		NSString *serverId = nil;
		Ivar sidIvar = class_getInstanceVariable([keyObj class], "_serverId");
		if (sidIvar) serverId = object_getIvar(keyObj, sidIvar);
		if (!serverId) {
			@try { serverId = [keyObj valueForKey:@"serverId"] ?: [keyObj valueForKey:@"_serverId"]; } @catch (__unused id e) {}
		}
		return [serverId isKindOfClass:[NSString class]] ? serverId : nil;
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
	if ([cell respondsToSelector:@selector(contentViewForVisualMessageViewerPresentation)]) {
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
	for (UIWindow *w in [UIApplication sharedApplication].windows) {
		if (w.isKeyWindow) { window = w; break; }
	}
	if (!window) window = [UIApplication sharedApplication].windows.firstObject;
	if (!window) {
		#pragma clang diagnostic push
		#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		window = [UIApplication sharedApplication].keyWindow;
		#pragma clang diagnostic pop
	}
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

static void processThreadUpdatesAndNeuterRemovals(id updates) {
	if (!updates) return;
	NSArray *updateList = nil;
	if ([updates isKindOfClass:[NSArray class]]) {
		updateList = (NSArray *)updates;
	} else {
		updateList = @[updates];
	}

	BOOL preservedAny = NO;

	for (id cacheThreadUpdate in updateList) {
		NSArray *threadUpdates = nil;
		@try {
			if ([cacheThreadUpdate respondsToSelector:@selector(threadUpdates)]) {
				#pragma clang diagnostic push
				#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
				threadUpdates = [cacheThreadUpdate performSelector:@selector(threadUpdates)];
				#pragma clang diagnostic pop
			} else if ([cacheThreadUpdate respondsToSelector:@selector(valueForKey:)]) {
				threadUpdates = [cacheThreadUpdate valueForKey:@"threadUpdates"];
			}
		} @catch (__unused NSException *e) {}

		if (![threadUpdates isKindOfClass:[NSArray class]]) {
			if (cacheThreadUpdate) {
				threadUpdates = @[cacheThreadUpdate];
			}
		}

		for (id threadUpdateObj in threadUpdates) {
			id messageUpdate = nil;
			@try {
				if ([threadUpdateObj respondsToSelector:@selector(messageUpdate)]) {
					#pragma clang diagnostic push
					#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
					messageUpdate = [threadUpdateObj performSelector:@selector(messageUpdate)];
					#pragma clang diagnostic pop
				} else if ([threadUpdateObj respondsToSelector:@selector(valueForKey:)]) {
					messageUpdate = [threadUpdateObj valueForKey:@"_messageUpdate"] ?: [threadUpdateObj valueForKey:@"messageUpdate"];
				}
			} @catch (__unused NSException *e) {}

			if (!messageUpdate) {
				messageUpdate = threadUpdateObj;
			}

			if (messageUpdate) {
				NSArray *removeKeys = nil;
				@try {
					if ([messageUpdate respondsToSelector:@selector(removeMessages_messageKeys)]) {
						#pragma clang diagnostic push
						#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
						removeKeys = [messageUpdate performSelector:@selector(removeMessages_messageKeys)];
						#pragma clang diagnostic pop
					} else if ([messageUpdate respondsToSelector:@selector(valueForKey:)]) {
						removeKeys = [messageUpdate valueForKey:@"_removeMessages_messageKeys"] ?: [messageUpdate valueForKey:@"removeMessages_messageKeys"];
					}
				} @catch (__unused NSException *e) {}

				if (![removeKeys isKindOfClass:[NSArray class]] || removeKeys.count == 0) {
					Ivar removeIvar = class_getInstanceVariable([messageUpdate class], "_removeMessages_messageKeys");
					if (removeIvar) {
						removeKeys = object_getIvar(messageUpdate, removeIvar);
					}
				}

				if ([removeKeys isKindOfClass:[NSArray class]] && removeKeys.count > 0) {
					for (id messageKey in removeKeys) {
						NSString *serverId = nil;
						@try {
							serverId = [messageKey valueForKey:@"_messageServerId"];
							if (!serverId) serverId = [messageKey valueForKey:@"serverId"];
							if (!serverId) serverId = [messageKey valueForKey:@"_serverId"];
						} @catch (__unused NSException *e) {}

						if (!serverId) {
							Ivar sidIvar = class_getInstanceVariable([messageKey class], "_messageServerId");
							if (sidIvar) serverId = object_getIvar(messageKey, sidIvar);
						}

						if (serverId && [serverId isKindOfClass:[NSString class]] && serverId.length > 0) {
							[[MessagesManager sharedManager] saveDeletedMessageWithID:serverId];
							preservedAny = YES;
						}
					}

					// NEUTER THE REMOVAL: Clear _removeMessages_messageKeys on messageUpdate so Instagram's applicator deletes nothing!
					Ivar removeIvar = class_getInstanceVariable([messageUpdate class], "_removeMessages_messageKeys");
					if (removeIvar) {
						object_setIvar(messageUpdate, removeIvar, nil);
					}
					@try {
						[messageUpdate setValue:nil forKey:@"_removeMessages_messageKeys"];
					} @catch (__unused NSException *e) {}
					@try {
						[messageUpdate setValue:@[] forKey:@"_removeMessages_messageKeys"];
					} @catch (__unused NSException *e) {}
				}
			}
		}
	}

	if (preservedAny) {
		dispatch_async(dispatch_get_main_queue(), ^{
			thetaRefreshVisibleCellIndicators();
		});
	}
}

static void (*orig_directMessageCell_configure)(id self, SEL _cmd, id viewModel, id specFactory, id launcher);
static void hook_directMessageCell_configure(id self, SEL _cmd, id viewModel, id specFactory, id launcher) {
	if (orig_directMessageCell_configure) orig_directMessageCell_configure(self, _cmd, viewModel, specFactory, launcher);
	if (!ENABLED(@"Keep Deleted Messages")) return;
	thetaUpdateCellAppearance(self);
}

static void (*orig_directMessageCell_layoutSubviews)(id self, SEL _cmd);
static void hook_directMessageCell_layoutSubviews(id self, SEL _cmd) {
	if (orig_directMessageCell_layoutSubviews) orig_directMessageCell_layoutSubviews(self, _cmd);
	if (!ENABLED(@"Keep Deleted Messages")) return;
	thetaUpdateCellAppearance(self);
}

static void (*orig_directCache_removeMessages)(id self, SEL _cmd, id messageKeys);
static void hook_directCache_removeMessages(id self, SEL _cmd, id messageKeys) {
	if (ENABLED(@"Keep Deleted Messages")) {
		if ([messageKeys isKindOfClass:[NSArray class]]) {
			for (id key in messageKeys) {
				NSString *sid = nil;
				@try { sid = [key valueForKey:@"serverId"] ?: [key valueForKey:@"_serverId"]; } @catch (__unused id e) {}
				if (sid.length > 0) {
					[[MessagesManager sharedManager] saveDeletedMessageWithID:sid];
				}
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
		NSString *sid = nil;
		@try { sid = [messageKey valueForKey:@"serverId"] ?: [messageKey valueForKey:@"_serverId"]; } @catch (__unused id e) {}
		if (sid.length > 0) {
			[[MessagesManager sharedManager] saveDeletedMessageWithID:sid];
			dispatch_async(dispatch_get_main_queue(), ^{ thetaRefreshVisibleCellIndicators(); });
		}
		return;
	}
	if (orig_directCache_removeMessage) orig_directCache_removeMessage(self, _cmd, messageKey);
}

static void (*orig_messageCache3)(id self, SEL _cmd, id updates, id completion, id userAccess);
static void hook_messageCache3(id self, SEL _cmd, id updates, id completion, id userAccess) {
	if (!ENABLED(@"Keep Deleted Messages")) {
		if (orig_messageCache3) orig_messageCache3(self, _cmd, updates, completion, userAccess);
		return;
	}

	@try {
		processThreadUpdatesAndNeuterRemovals(updates);
	} @catch (NSException *e) {
		NSLog(@"[Theta] Error neutering thread updates (3-arg): %@", e);
	}

	if (orig_messageCache3) orig_messageCache3(self, _cmd, updates, completion, userAccess);
}

static void (*orig_messageCache2)(id self, SEL _cmd, id updates, id completion);
static void hook_messageCache2(id self, SEL _cmd, id updates, id completion) {
	if (!ENABLED(@"Keep Deleted Messages")) {
		if (orig_messageCache2) orig_messageCache2(self, _cmd, updates, completion);
		return;
	}

	@try {
		processThreadUpdatesAndNeuterRemovals(updates);
	} @catch (NSException *e) {
		NSLog(@"[Theta] Error neutering thread updates (2-arg): %@", e);
	}

	if (orig_messageCache2) orig_messageCache2(self, _cmd, updates, completion);
}

void THRegisterKeepDeletedMessagesHooks(void) {
	Class applicator = ThetaFirstClass(@[
		@"_TtC26IGDirectCacheUpdatesApplicator26IGDirectCacheUpdatesApplicator",
		@"IGDirectCacheUpdatesApplicator"
	]);
	if (applicator) {
		NullHookMessageIfPresent(applicator, @selector(_applyThreadUpdates:completion:userAccess:), (void *)hook_messageCache3, &orig_messageCache3);
		NullHookMessageIfPresent(applicator, @selector(_applyThreadUpdates:completion:), (void *)hook_messageCache2, &orig_messageCache2);
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
		NullHookMessageIfPresent(messageCell,
			@selector(configureWithViewModel:ringViewSpecFactory:launcherSet:),
			(void *)hook_directMessageCell_configure,
			&orig_directMessageCell_configure);
		NullHookMessageIfPresent(messageCell,
			@selector(layoutSubviews),
			(void *)hook_directMessageCell_layoutSubviews,
			&orig_directMessageCell_layoutSubviews);
	}
}