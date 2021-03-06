//
//  MFSideMenu.m
//  MFSideMenuDemo
//
//  Created by Michael Frederick on 10/22/12.
//  Copyright (c) 2012 University of Wisconsin - Madison. All rights reserved.
//

#import "MFSideMenu.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#ifdef COCOAPODS_POD_AVAILABLE__CocoaLumberjack
#import "DDLog.h" // LUMBERJACK
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif 
#ifdef COCOAPODS_POD_AVAILABLE__StaticLumberjack
#import "DDLog.h" // LUMBERJACK
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif 

MFSideMenu *_activeSideMenu = nil;

@interface MFSideMenu() {
    CGPoint panGestureOrigin;
    BOOL _shouldBeRemoved;
}

@property (nonatomic, assign, readwrite) MFSideMenuNavigationController *navigationController;
@property (nonatomic, strong, readwrite) UIViewController<MFSideMenuDelegate>* sideMenuController;

@property (nonatomic, assign) MFSideMenuLocation menuSide;
@property (nonatomic, assign) MFSideMenuOptions options;

// layout constraints for the sideMenuController
@property (nonatomic, strong) NSLayoutConstraint *topConstraint;
@property (nonatomic, strong) NSLayoutConstraint *rightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *bottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *leftConstraint;
@property (nonatomic, assign) CGFloat panGestureVelocity;

@end


@implementation MFSideMenu

@synthesize menuState = _menuState;


#pragma mark -
#pragma mark - Menu Creation

+ (MFSideMenu *) menuWithNavigationController:(MFSideMenuNavigationController *)navigationController
                        sideMenuController:(UIViewController<MFSideMenuDelegate>*)menuController {
    MFSideMenuOptions options = MFSideMenuOptionMenuButtonEnabled|MFSideMenuOptionBackButtonEnabled|MFSideMenuOptionShadowEnabled;
    
    return [MFSideMenu menuWithNavigationController:navigationController
                          sideMenuController:menuController
                                    location:MFSideMenuLocationLeft
                                     options:options];
}

+ (MFSideMenu *) menuWithNavigationController:(MFSideMenuNavigationController *)navigationController
                        sideMenuController:(UIViewController<MFSideMenuDelegate>*)menuController
                                  location:(MFSideMenuLocation)side
                                   options:(MFSideMenuOptions)options {
    MFSideMenuPanMode panMode = MFSideMenuPanModeNavigationBar|MFSideMenuPanModeNavigationController;
    
    return [MFSideMenu menuWithNavigationController:navigationController
                          sideMenuController:menuController
                                    location:MFSideMenuLocationLeft
                                     options:options
                                     panMode:panMode];
}

+ (MFSideMenu *) menuWithNavigationController:(MFSideMenuNavigationController *)navigationController
                   sideMenuController:(UIViewController<MFSideMenuDelegate>*)menuController
                             location:(MFSideMenuLocation)side
                              options:(MFSideMenuOptions)options
                              panMode:(MFSideMenuPanMode)panMode {
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 6.0) {
        return nil;
    }
    
    
    MFSideMenu *menu = [[MFSideMenu alloc] init];
    menu.navigationController = navigationController;
    menu.sideMenuController = menuController;
    menu.menuSide = side;
    menu.options = options;
    menu.panMode = panMode;
    menu.considerStatusBar = YES;
    navigationController.sideMenu = menu;
    menuController.sideMenu = menu;
    
    
    
    UIPanGestureRecognizer *recognizer = [[UIPanGestureRecognizer alloc]
                                          initWithTarget:menu action:@selector(navigationBarPanned:)];
	[recognizer setMaximumNumberOfTouches:1];
    [recognizer setDelegate:menu];
    [recognizer setCancelsTouchesInView:NO];
    [navigationController.navigationBar addGestureRecognizer:recognizer];
    menu.barGestureRecognizer = recognizer;
    
    recognizer = [[UIScreenEdgePanGestureRecognizer alloc]
                  initWithTarget:menu action:@selector(navigationControllerPanned:)];
    UIScreenEdgePanGestureRecognizer * edgeRecognizer = (UIScreenEdgePanGestureRecognizer *)recognizer;
    edgeRecognizer.edges = UIRectEdgeLeft;
    [recognizer setDelegate:menu];
    [recognizer setCancelsTouchesInView:NO];
    [navigationController.view addGestureRecognizer:recognizer];
    menu.panGestureRecognizer = recognizer;
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc]
                                             initWithTarget:menu action:@selector(navigationControllerTapped:)];
    [tapRecognizer setDelegate:menu];
    [tapRecognizer setCancelsTouchesInView:NO];
    [navigationController.view addGestureRecognizer:tapRecognizer];
    menu.tapGestureRecognizer = tapRecognizer;
    
    [[NSNotificationCenter defaultCenter] addObserver:menu
                                             selector:@selector(statusBarOrientationDidChange:)
                                                 name:UIApplicationDidChangeStatusBarOrientationNotification
                                               object:nil];
    
    if (navigationController.hadDidAppear) {
        [menu navigationControllerWillAppear];
        [menu navigationControllerDidAppear];
    }
    
    _activeSideMenu = menu;
    return menu;
}

- (void)removeSideMenu {
    [self setMenuState:MFSideMenuStateHidden];
    _shouldBeRemoved = YES;
}
- (void)removeSideMenuOnceHidden {
#ifdef COCOAPODS_POD_AVAILABLE__CocoaLumberjack
    DDLogVerbose(@"removeSideMenuOnceHidden");
#endif
#ifdef COCOAPODS_POD_AVAILABLE__StaticLumberjack
    DDLogVerbose(@"removeSideMenuOnceHidden");
#endif
    [self.navigationController.navigationBar removeGestureRecognizer:self.barGestureRecognizer];
    self.barGestureRecognizer = nil;
    [self.navigationController.view removeGestureRecognizer:self.panGestureRecognizer];
    self.panGestureRecognizer = nil;
    [self.navigationController.view removeGestureRecognizer:self.tapGestureRecognizer];
    self.tapGestureRecognizer = nil;
    
    self.sideMenuController.sideMenu = nil;
    self.sideMenuController = nil;
    
    self.navigationController = nil;
    self.navigationController.sideMenu = nil;
    
    if ([_activeSideMenu isEqual:self]) {
        _activeSideMenu = nil;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -
#pragma mark - Navigation Controller View Lifecycle

- (void) navigationControllerWillAppear {
    [self setMenuState:MFSideMenuStateHidden];
    
    if(self.navigationController.viewControllers && self.navigationController.viewControllers.count) {
        // we need to do this b/c the options to show the barButtonItem
        // weren't set yet when viewDidLoad of the topViewController was called
        [self setupSideMenuBarButtonItem];
    }
}

- (void) navigationControllerDidAppear {
    UIView *menuView = self.sideMenuController.view;
    if(menuView.superview) return;
    
    UIView *windowRootView = self.rootViewController.view;
    UIView *containerView = windowRootView.superview;
    
    [containerView insertSubview:menuView belowSubview:windowRootView];
    
    [menuView setTranslatesAutoresizingMaskIntoConstraints:NO];
    self.topConstraint = [[self class] edgeConstraint:NSLayoutAttributeTop subview:menuView];
    self.rightConstraint = [[self class] edgeConstraint:NSLayoutAttributeRight subview:menuView];
    self.bottomConstraint = [[self class] edgeConstraint:NSLayoutAttributeBottom subview:menuView];
    self.leftConstraint = [[self class] edgeConstraint:NSLayoutAttributeLeft subview:menuView];
    
    [containerView addConstraint:self.topConstraint];
    [containerView addConstraint:self.rightConstraint];
    [containerView addConstraint:self.bottomConstraint];
    [containerView addConstraint:self.leftConstraint];
    
    // we need to reorient from the status bar here incase the initial orientation is landscape
    [self orientSideMenuFromStatusBar];
    
    if([self shadowEnabled]) {
        // we have to redraw the shadow when the device flips
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(drawRootControllerShadowPath)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
        
        [self drawRootControllerShadowPath];
        self.rootViewController.view.layer.shadowOpacity = 0.75f;
        self.rootViewController.view.layer.shadowRadius = kMFSideMenuShadowWidth;
        self.rootViewController.view.layer.shadowColor = [UIColor blackColor].CGColor;
    }
}

- (void) navigationControllerDidDisappear {
    // we don't want the menu to be visible if the navigation controller is gone
    if(self.sideMenuController.view && self.sideMenuController.view.superview) {
        [self.sideMenuController.view removeFromSuperview];
    }
    
    NSArray *constraints = [NSArray arrayWithObjects:self.topConstraint, self.bottomConstraint,
                            self.leftConstraint, self.rightConstraint, nil];
    [self.rootViewController.view.superview removeConstraints:constraints];
}

+ (NSLayoutConstraint *)edgeConstraint:(NSLayoutAttribute)edge subview:(UIView *)subview {
    return [NSLayoutConstraint constraintWithItem:subview
                                        attribute:edge
                                        relatedBy:NSLayoutRelationEqual
                                           toItem:subview.superview
                                        attribute:edge
                                       multiplier:1
                                         constant:0];
}


#pragma mark -
#pragma mark - MFSideMenuOptions

- (BOOL) menuButtonEnabled {
    return ((self.options & MFSideMenuOptionMenuButtonEnabled) == MFSideMenuOptionMenuButtonEnabled);
}

- (BOOL) backButtonEnabled {
    return ((self.options & MFSideMenuOptionBackButtonEnabled) == MFSideMenuOptionBackButtonEnabled);
}

- (BOOL) shadowEnabled {
    return ((self.options & MFSideMenuOptionShadowEnabled) == MFSideMenuOptionShadowEnabled);
}


#pragma mark -
#pragma mark - MFSideMenuPanMode

- (BOOL) navigationControllerPanEnabled {
    return ((self.panMode & MFSideMenuPanModeNavigationController) == MFSideMenuPanModeNavigationController);
}

- (BOOL) navigationBarPanEnabled {
    return ((self.panMode & MFSideMenuPanModeNavigationBar) == MFSideMenuPanModeNavigationBar);
}


#pragma mark -
#pragma mark - UIBarButtonItems & Callbacks

UIBarButtonItem *_menuBarButtonItem = nil;
UIBarButtonItem *_backBarButtonItem = nil;

- (UIBarButtonItem *)menuBarButtonItem {
    if (!_menuBarButtonItem) {
        _menuBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"menu-icon.png"]
                                            style:UIBarButtonItemStyleBordered
                                           target:self
                                           action:@selector(toggleSideMenuPressed:)];
    }
    return _menuBarButtonItem;
}

- (UIBarButtonItem *)backBarButtonItem {
    if (!_backBarButtonItem) {
        _backBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"back-arrow"]
                                            style:UIBarButtonItemStyleBordered
                                           target:self
                                           action:@selector(backButtonPressed:)];
    }
    return _backBarButtonItem;
}

NSArray *GetBarButtonItems(NSArray *barButtonItems, UIBarButtonItem *menuButton) {
    if (barButtonItems.count < 1) {
        barButtonItems = @[ menuButton ];
    }
    else {
        if (![barButtonItems containsObject:menuButton]) {
            NSMutableArray *newBarButtonItems = [NSMutableArray arrayWithArray:barButtonItems];
            [newBarButtonItems insertObject:menuButton atIndex:0];
            barButtonItems = [NSArray arrayWithArray:newBarButtonItems];
        }
    }
    return barButtonItems;
}

- (void)setupSideMenuBarButtonItem {
    UINavigationItem *navigationItem = self.navigationController.topViewController.navigationItem;
    if([self menuButtonEnabled]) {
        if(self.menuSide == MFSideMenuLocationRight && !navigationItem.rightBarButtonItem) {
            NSArray *barButtonItems = GetBarButtonItems(navigationItem.rightBarButtonItems, [self menuBarButtonItem]);
            navigationItem.rightBarButtonItems = barButtonItems;
        }
        else if(self.menuSide == MFSideMenuLocationLeft &&
                  (self.menuState == MFSideMenuStateVisible || self.navigationController.viewControllers.count == 1)) {
            // show the menu button on the root view controller or if the menu is open
            NSArray *barButtonItems = GetBarButtonItems(navigationItem.leftBarButtonItems, [self menuBarButtonItem]);
            navigationItem.leftBarButtonItems = barButtonItems;
        }
    }
    
    if([self backButtonEnabled] && self.navigationController.viewControllers.count > 1
       && self.menuState == MFSideMenuStateHidden) {
        navigationItem.leftBarButtonItem = [self backBarButtonItem];
    }
}

- (void)toggleSideMenuPressed:(id)sender {
    if(self.menuState == MFSideMenuStateVisible) {
        [self setMenuState:MFSideMenuStateHidden];
    } else {
        [self setMenuState:MFSideMenuStateVisible];
    }
}

- (void)backButtonPressed:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}


#pragma mark - 
#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isKindOfClass:[UIControl class]]) return NO;
    
    if([gestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) return YES;
    
    if([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]] &&
       self.menuState != MFSideMenuStateHidden) return YES;
    
    if([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        // we don't want to override UITableViewCell swipes
        if ([touch.view isKindOfClass:[UITableViewCell class]] ||
            [touch.view.superview isKindOfClass:[UITableViewCell class]]) return NO;
        
        if([gestureRecognizer.view isEqual:self.navigationController.view] &&
           ([self navigationControllerPanEnabled] || self.menuState == MFSideMenuStateVisible)) return YES;
        
        if([gestureRecognizer.view isEqual:self.navigationController.navigationBar] &&
           self.menuState == MFSideMenuStateHidden &&
           [self navigationBarPanEnabled]) return YES;
    }
    
    return NO;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
        shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
	return NO;
}


#pragma mark -
#pragma mark - UIGestureRecognizer Callbacks

// this method handles the navigation bar pan event
// and sets the navigation controller's frame as needed
- (void) handleNavigationBarPan:(UIPanGestureRecognizer *)recognizer {
    UIView *view = self.rootViewController.view;
    
	if(recognizer.state == UIGestureRecognizerStateBegan) {
        // remember where the pan started
        panGestureOrigin = view.frame.origin;
	}
    
    CGPoint translatedPoint = [recognizer translationInView:view];
    CGPoint adjustedOrigin = [self pointAdjustedForInterfaceOrientation:panGestureOrigin];
    translatedPoint = CGPointMake(adjustedOrigin.x + translatedPoint.x,
                                  adjustedOrigin.y + translatedPoint.y);
    
    if(self.menuSide == MFSideMenuLocationLeft) {
        translatedPoint.x = MIN(translatedPoint.x, kMFSideMenuSidebarWidth);
        translatedPoint.x = MAX(translatedPoint.x, 0);
    } else {
        translatedPoint.x = MAX(translatedPoint.x, -1*kMFSideMenuSidebarWidth);
        translatedPoint.x = MIN(translatedPoint.x, 0);
    }
    
    [self setRootControllerOffset:translatedPoint.x];
    
	if(recognizer.state == UIGestureRecognizerStateEnded) {
        CGPoint velocity = [recognizer velocityInView:view];
        CGFloat finalX = translatedPoint.x + (.35*velocity.x);
        CGFloat viewWidth = [self widthAdjustedForInterfaceOrientation:view];
        
        if(self.menuState == MFSideMenuStateHidden) {
            BOOL showMenu = (self.menuSide == MFSideMenuLocationLeft) ? (finalX > kMFSideMenuSidebarWidth) : (finalX < -1*kMFSideMenuSidebarWidth);
            if(showMenu) {
                self.panGestureVelocity = velocity.x;
                [self setMenuState:MFSideMenuStateVisible];
            } else {
                self.panGestureVelocity = 0;
                [UIView beginAnimations:nil context:NULL];
                [self setRootControllerOffset:0];
                [UIView commitAnimations];
            }
        } else if(self.menuState == MFSideMenuStateVisible) {
            BOOL hideMenu = (self.menuSide == MFSideMenuLocationLeft) ? (finalX < adjustedOrigin.x) : (finalX > adjustedOrigin.x);
            if(hideMenu) {
                self.panGestureVelocity = velocity.x;
                [self setMenuState:MFSideMenuStateHidden];
            } else {
                self.panGestureVelocity = 0;
                [UIView beginAnimations:nil context:NULL];
                [self setRootControllerOffset:adjustedOrigin.x];
                [UIView commitAnimations];
            }
        }
	}
}

- (void) navigationControllerTapped:(id)sender {
    if(self.menuState != MFSideMenuStateHidden) {
        [self setMenuState:MFSideMenuStateHidden];
    }
}

- (void) navigationControllerPanned:(id)sender {
    // if(self.menuState == MFSideMenuStateHidden) return;
    
    [self handleNavigationBarPan:sender];
}

- (void) navigationBarPanned:(id)sender {
    if(self.menuState != MFSideMenuStateHidden) return;
    
    [self handleNavigationBarPan:sender];
}


#pragma mark -
#pragma mark - UIGestureRecognizer Helpers

- (CGPoint) pointAdjustedForInterfaceOrientation:(CGPoint)point {
    //switch (self.rootViewController.interfaceOrientation)
    switch (UIInterfaceOrientationPortrait)
    {
        case UIInterfaceOrientationPortrait:
            return CGPointMake(point.x, point.y);
            break;
            
        case UIInterfaceOrientationPortraitUpsideDown:
            return CGPointMake(-1*point.x, -1*point.y);
            break;
            
        case UIInterfaceOrientationLandscapeLeft:
            return CGPointMake(-1*point.y, -1*point.x);
            break;
            
        case UIInterfaceOrientationLandscapeRight:
            return CGPointMake(point.y, point.x);
            break;
    }
}

- (CGFloat) widthAdjustedForInterfaceOrientation:(UIView *)view {
    //if(UIInterfaceOrientationIsPortrait(self.rootViewController.interfaceOrientation)) {
    if(UIInterfaceOrientationIsPortrait(UIInterfaceOrientationPortrait)) {
        return view.frame.size.width;
    } else {
        return view.frame.size.height;
    }
}


#pragma mark -
#pragma mark - Menu Rotation

- (void) orientSideMenuFromStatusBar {
    UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;//self.rootViewController.interfaceOrientation;//[[UIApplication sharedApplication] statusBarOrientation];
    CGSize statusBarSize = self.considerStatusBar ? [[UIApplication sharedApplication] statusBarFrame].size : CGSizeZero;
    CGSize windowSize = self.navigationController.view.window.bounds.size;
    CGFloat angle = 0.0;
    
    CGFloat portraitPadding = (windowSize.width - kMFSideMenuSidebarWidth);
    CGFloat portraitLeft, portraitRight;
    CGFloat landscapePadding = (windowSize.height - kMFSideMenuSidebarWidth);
    CGFloat landscapeTop, landscapeBottom;
    
    // we clear these here so that we don't create any unsatisfiable constraints below
    [self.topConstraint setConstant:0.0];
    [self.rightConstraint setConstant:0.0];
    [self.bottomConstraint setConstant:0.0];
    [self.leftConstraint setConstant:0.0];
    
    switch (orientation) {
        case UIInterfaceOrientationPortrait:
            angle = 0.0;
            
            portraitLeft = (self.menuSide == MFSideMenuLocationLeft) ? 0.0 : portraitPadding;
            portraitRight = (self.menuSide == MFSideMenuLocationLeft) ? -1*portraitPadding : 0.0;
            
            [self.topConstraint setConstant:statusBarSize.height];
            [self.rightConstraint setConstant:portraitRight];
            [self.leftConstraint setConstant:portraitLeft];
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            angle = M_PI;
            
            portraitLeft = (self.menuSide == MFSideMenuLocationLeft) ? portraitPadding : 0.0;
            portraitRight = (self.menuSide == MFSideMenuLocationLeft) ? 0.0 : -1*portraitPadding;
            
            [self.rightConstraint setConstant:portraitRight];
            [self.bottomConstraint setConstant:-1*statusBarSize.height];
            [self.leftConstraint setConstant:portraitLeft];
            break;
        case UIInterfaceOrientationLandscapeLeft:
            angle = - M_PI / 2.0f;
            
            landscapeTop = (self.menuSide == MFSideMenuLocationLeft) ? landscapePadding : 0.0;
            landscapeBottom = (self.menuSide == MFSideMenuLocationLeft) ? 0.0 : -1*landscapePadding;
            
            [self.topConstraint setConstant:landscapeTop];
            [self.bottomConstraint setConstant:landscapeBottom];
            [self.leftConstraint setConstant:statusBarSize.width];
            break;
        case UIInterfaceOrientationLandscapeRight:
            angle = M_PI / 2.0f;
            
            landscapeTop = (self.menuSide == MFSideMenuLocationLeft) ? 0.0 : landscapePadding;
            landscapeBottom = (self.menuSide == MFSideMenuLocationLeft) ? -1*landscapePadding : 0.0;
            
            [self.topConstraint setConstant:landscapeTop];
            [self.rightConstraint setConstant:-1*statusBarSize.width];
            [self.bottomConstraint setConstant:landscapeBottom];
            break;
    }
    
    CGAffineTransform transform = CGAffineTransformMakeRotation(angle);
    self.sideMenuController.view.transform = transform;
}

- (void)statusBarOrientationDidChange:(NSNotification *)notification {
    [self orientSideMenuFromStatusBar];
    
    if(self.menuState == MFSideMenuStateVisible) {
        [self setMenuState:MFSideMenuStateHidden];
    }
}


#pragma mark -
#pragma mark - Menu State & Open/Close Animation

- (void)setMenuState:(MFSideMenuState)menuState {
    MFSideMenuState currentState = _menuState;
    _menuState = menuState;
    
    switch (currentState) {
        case MFSideMenuStateHidden:
            if (menuState == MFSideMenuStateVisible) {
                [self toggleSideMenuHidden:NO];
            }
            break;
        case MFSideMenuStateVisible:
            if (menuState == MFSideMenuStateHidden) {
                [self toggleSideMenuHidden:YES];
            }
            break;
        default:
            break;
    }
}

- (void)setOptions:(MFSideMenuOptions)options {
    _options = options;
    if ([self menuButtonEnabled]) {
        [self setupSideMenuBarButtonItem];
    }
}

// menu open/close animation
- (void) toggleSideMenuHidden:(BOOL)hidden {
    // notify that the menu state event is starting
    [self sendMenuStateEventNotification:(hidden ? MFSideMenuStateEventMenuWillClose : MFSideMenuStateEventMenuWillOpen)];
    
    CGFloat x = ABS([self pointAdjustedForInterfaceOrientation:self.rootViewController.view.frame.origin].x);
    
    CGFloat navigationControllerXPosition = (self.menuSide == MFSideMenuLocationLeft) ? kMFSideMenuSidebarWidth : -1*kMFSideMenuSidebarWidth;
    CGFloat animationPositionDelta = (hidden) ? x : (navigationControllerXPosition  - x);
    
    CGFloat duration;
    
    if(ABS(self.panGestureVelocity) > 1.0) {
        // try to continue the animation at the speed the user was swiping
        duration = animationPositionDelta / ABS(self.panGestureVelocity);
    } else {
        // no swipe was used, user tapped the bar button item
        CGFloat animationDurationPerPixel = kMFSideMenuAnimationDuration / navigationControllerXPosition;
        duration = animationDurationPerPixel * animationPositionDelta;
    }
    
    if(duration > kMFSideMenuAnimationMaxDuration) duration = kMFSideMenuAnimationMaxDuration;
    
    [UIView animateWithDuration:duration animations:^{
        CGFloat xPosition = (hidden) ? 0 : navigationControllerXPosition;
        [self setRootControllerOffset:xPosition];
    } completion:^(BOOL finished) {
        [self setupSideMenuBarButtonItem];
        
        // disable user interaction on the current view controller if the menu is visible
        self.navigationController.topViewController.view.userInteractionEnabled = (self.menuState == MFSideMenuStateHidden);
        
        // notify that the menu state event is done
        [self sendMenuStateEventNotification:(hidden ? MFSideMenuStateEventMenuDidClose : MFSideMenuStateEventMenuDidOpen)];
    }];
}

- (void) sendMenuStateEventNotification:(MFSideMenuStateEvent)event {
    //[[NSNotificationCenter defaultCenter] postNotificationName:MFSideMenuStateEventDidOccurNotification
    //                                                    object:[NSNumber numberWithInt:event]];
    
    if (_shouldBeRemoved) {
        [self removeSideMenuOnceHidden];
        return;
    }
    if(self.menuStateEventBlock) self.menuStateEventBlock(event);
}

#pragma mark -
#pragma mark - Root Controller

- (UIViewController *) rootViewController {
    return self.navigationController.view.window.rootViewController;
}

- (void) setRootControllerOffset:(CGFloat)xOffset {
    UIViewController *rootController = self.rootViewController;
    CGRect frame = rootController.view.frame;
    frame.origin = CGPointZero;
    
    // need to account for the controller's transform
    //switch (rootController.interfaceOrientation)
    switch (UIInterfaceOrientationPortrait)
    {
        case UIInterfaceOrientationPortrait:
            frame.origin.x = xOffset;
            break;
            
        case UIInterfaceOrientationPortraitUpsideDown:
            frame.origin.x = -1*xOffset;
            break;
            
        case UIInterfaceOrientationLandscapeLeft:
            frame.origin.y = -1*xOffset;
            break;
            
        case UIInterfaceOrientationLandscapeRight:
            frame.origin.y = xOffset;
            break;
    }
    
    rootController.view.frame = frame;
}

// draw a shadow between the navigation controller and the menu
- (void) drawRootControllerShadowPath {
    CGRect pathRect = self.rootViewController.view.bounds;
    if(self.menuSide == MFSideMenuLocationRight) {
        // draw the shadow on the right hand side of the navigationController
        pathRect.origin.x = pathRect.size.width - kMFSideMenuShadowWidth;
    }
    pathRect.size.width = kMFSideMenuShadowWidth;
    
    self.rootViewController.view.layer.shadowPath = [UIBezierPath bezierPathWithRect:pathRect].CGPath;
}

+ (MFSideMenu *)activeSideMenu {
    return _activeSideMenu;
}

@end
