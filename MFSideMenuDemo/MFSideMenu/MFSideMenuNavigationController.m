//
//  UINavigationController+MFSideMenu.m
//  MFSideMenuDemo
//
//  Created by Michael Frederick on 10/24/12.
//  Copyright (c) 2012 University of Wisconsin - Madison. All rights reserved.
//

#import "MFSideMenuNavigationController.h"
#import "MFSideMenu.h"
#import <objc/runtime.h>
#import "UIViewController+PAKOrientation.h"

@implementation MFSideMenuNavigationController

static char menuKey;

- (void)setSideMenu:(MFSideMenu *)sideMenu {
    objc_setAssociatedObject(self, &menuKey, sideMenu, OBJC_ASSOCIATION_RETAIN);
}

- (MFSideMenu *)sideMenu {
    return (MFSideMenu *)objc_getAssociatedObject(self, &menuKey);
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.sideMenu performSelector:@selector(navigationControllerWillAppear)];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.hadDidAppear = YES;
    [self.sideMenu performSelector:@selector(navigationControllerDidAppear)];
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    self.hadDidAppear = NO;
    [self.sideMenu performSelector:@selector(navigationControllerDidDisappear)];
}

@end
