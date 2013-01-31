//
//  MFSideMenu.h
//
//  Created by Michael Frederick on 3/17/12.
//

#import "MFSideMenuNavigationController.h"

static const CGFloat kMFSideMenuSidebarWidth = 270.0f;
static const CGFloat kMFSideMenuShadowWidth = 10.0f;
static const CGFloat kMFSideMenuAnimationDuration = 0.2f;
static const CGFloat kMFSideMenuAnimationMaxDuration = 0.4f;

typedef enum {
    MFSideMenuLocationLeft, // show the menu on the left hand side
    MFSideMenuLocationRight // show the menu on the right hand side
} MFSideMenuLocation;

typedef enum {
    MFSideMenuOptionMenuButtonEnabled = 1 << 0, // enable the 'menu' UIBarButtonItem
    MFSideMenuOptionBackButtonEnabled = 1 << 1, // enable the 'back' UIBarButtonItem
    MFSideMenuOptionShadowEnabled = 1 << 2, // enable the shadow between the navigation controller & side menu
} MFSideMenuOptions;

typedef enum {
    MFSideMenuPanModeNavigationBar = 1 << 0, // enable panning on the navigation bar
    MFSideMenuPanModeNavigationController = 1 << 1 // enable panning on the body of the navigation controller
} MFSideMenuPanMode;

typedef enum {
    MFSideMenuStateHidden, // the menu is hidden
    MFSideMenuStateVisible // the menu is shown
} MFSideMenuState;

typedef enum {
    MFSideMenuStateEventMenuWillOpen, // the menu is going to open
    MFSideMenuStateEventMenuDidOpen, // the menu finished opening
    MFSideMenuStateEventMenuWillClose, // the menu is going to close
    MFSideMenuStateEventMenuDidClose // the menu finished closing
} MFSideMenuStateEvent;

typedef void (^MFSideMenuStateEventBlock)(MFSideMenuStateEvent);

@protocol MFSideMenuDelegate <NSObject>
- (MFSideMenu *)sideMenu;
- (void)setSideMenu:(MFSideMenu *)sideMenu;
@end

@interface MFSideMenu : NSObject<UIGestureRecognizerDelegate>

@property (nonatomic, readonly) MFSideMenuNavigationController *navigationController;
@property (nonatomic, strong, readonly) UIViewController<MFSideMenuDelegate>* sideMenuController;
@property (nonatomic, assign) MFSideMenuState menuState;
@property (nonatomic, assign) MFSideMenuPanMode panMode;
@property (nonatomic, strong) UIGestureRecognizer *barGestureRecognizer;
@property (nonatomic, strong) UIGestureRecognizer *panGestureRecognizer;
@property (nonatomic, strong) UIGestureRecognizer *tapGestureRecognizer;
@property (nonatomic, assign) BOOL considerStatusBar;

// this can be used to observe all MFSideMenuStateEvents
@property (copy) MFSideMenuStateEventBlock menuStateEventBlock;

+ (MFSideMenu *) menuWithNavigationController:(MFSideMenuNavigationController *)navigationController
                        sideMenuController:(UIViewController<MFSideMenuDelegate>*)menuController;

+ (MFSideMenu *) menuWithNavigationController:(MFSideMenuNavigationController *)navigationController
                        sideMenuController:(UIViewController<MFSideMenuDelegate>*)menuController
                                  location:(MFSideMenuLocation)side
                                   options:(MFSideMenuOptions)options;

+ (MFSideMenu *) menuWithNavigationController:(MFSideMenuNavigationController *)navigationController
                   sideMenuController:(UIViewController<MFSideMenuDelegate>*)menuController
                             location:(MFSideMenuLocation)side
                              options:(MFSideMenuOptions)options
                              panMode:(MFSideMenuPanMode)panMode;

- (void) removeSideMenu;

- (UIBarButtonItem *) menuBarButtonItem;
- (UIBarButtonItem *) backBarButtonItem;
- (void) setupSideMenuBarButtonItem;


@end
