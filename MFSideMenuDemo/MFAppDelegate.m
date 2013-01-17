//
//  MFAppDelegate.m
//  MFSideMenuDemo
//
//  Created by Michael Frederick on 3/19/12.

#import "MFAppDelegate.h"
#import "MFSideMenu.h"
#import "DemoViewController.h"
#import "SideMenuViewController.h"

@implementation MFAppDelegate

@synthesize window = _window;

- (DemoViewController *)demoController {
    return [[DemoViewController alloc] initWithNibName:@"DemoViewController" bundle:nil];
}

- (MFSideMenuNavigationController *)navigationController {
    return [[MFSideMenuNavigationController alloc]
            initWithRootViewController:[self demoController]];
}

- (MFSideMenu *)sideMenu {
    SideMenuViewController *sideMenuController = [[SideMenuViewController alloc] init];
    MFSideMenuNavigationController *navigationController = [self navigationController];
    
    MFSideMenuOptions options = MFSideMenuOptionMenuButtonEnabled|MFSideMenuOptionBackButtonEnabled
                                                                 |MFSideMenuOptionShadowEnabled;
    MFSideMenuPanMode panMode = MFSideMenuPanModeNavigationBar|MFSideMenuPanModeNavigationController;
    
    MFSideMenu *sideMenu = [MFSideMenu menuWithNavigationController:navigationController
                                                 sideMenuController:sideMenuController
                                                           location:MFSideMenuLocationLeft
                                                            options:options
                                                            panMode:panMode];
    
    sideMenuController.sideMenu = sideMenu;
    
    return sideMenu;
}

- (void) setupNavigationControllerApp {
    self.window.rootViewController = [self sideMenu].navigationController;
    [self.window makeKeyAndVisible];
}

- (void) setupTabBarControllerApp {
    NSMutableArray *controllers = [NSMutableArray new];
    [controllers addObject:[self sideMenu].navigationController];
    [controllers addObject:[self sideMenu].navigationController];
    [controllers addObject:[self sideMenu].navigationController];
    [controllers addObject:[self sideMenu].navigationController];
    
    UITabBarController *tabBarController = [[UITabBarController alloc] init];
    [tabBarController setViewControllers:controllers];
    
    self.window.rootViewController = tabBarController;
    [self.window makeKeyAndVisible];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    [self setupNavigationControllerApp];
    //[self setupTabBarControllerApp];
    
    return YES;
}
     
    

@end
