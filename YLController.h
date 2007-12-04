//
//  YLController.h
//  MacBlueTelnet
//
//  Created by Yung-Luen Lan on 9/11/07.
//  Copyright 2007 yllan.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "YLView.h"
#import <PSMTabBarControl/PSMTabBarControl.h>
#import "YLSite.h"

@class YLTerminal;

@interface YLController : NSObject {
    IBOutlet NSPanel *_sitesWindow;
    IBOutlet NSWindow *_mainWindow;
	IBOutlet id _telnetView;
	IBOutlet id _addressBar;
    IBOutlet PSMTabBarControl *_tab;
    IBOutlet NSMenuItem *_closeWindowMenuItem;
    IBOutlet NSMenuItem *_closeTabMenuItem;
    NSMutableArray *_sites;
    IBOutlet NSArrayController *_sitesController;
    IBOutlet NSMenuItem *_sitesMenu;
    IBOutlet NSTableView *_sitesTableView;
    IBOutlet NSMenuItem *_showHiddenTextMenuItem;
}

- (IBAction) newTab: (id) sender ;
- (IBAction) connect: (id) sender;
- (IBAction) openLocation: (id) sender;
- (IBAction) selectNextTab: (id) sender;
- (IBAction) selectPrevTab: (id) sender;
- (void) selectTabNumber: (int) index ;
- (IBAction) closeTab: (id) sender;
- (IBAction) reconnect: (id) sender;
- (IBAction) openSites: (id) sender;
- (IBAction) editSites: (id) sender;
- (IBAction) closeSites: (id) sender;
- (IBAction) addSites: (id) sender;
- (IBAction) showHiddenText: (id) sender;

- (NSArray *)sites;
- (unsigned)countOfSites;
- (id)objectInSitesAtIndex:(unsigned)theIndex;
- (void)getSites:(id *)objsPtr range:(NSRange)range;
- (void)insertObject:(id)obj inSitesAtIndex:(unsigned)theIndex;
- (void)removeObjectFromSitesAtIndex:(unsigned)theIndex;
- (void)replaceObjectInSitesAtIndex:(unsigned)theIndex withObject:(id)obj;

- (void) refreshTabLabelNumber: (NSTabView *) tabView ;

@end
