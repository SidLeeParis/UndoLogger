//
//  AppDelegate.h
//  UndoLogger
//
//  Created by David Bismut on 18/11/2014.
//  Copyright (c) 2014 David Bismut. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (assign) BOOL accessStatus;
@property (assign) BOOL connectionStatus;

@property (strong, nonatomic) IBOutlet NSMenu *statusMenu;
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (weak) IBOutlet NSMenuItem *statusActivate;

- (void)noteNewAccessStatus:(NSNumber *)oldAccessStatus;
- (IBAction)grantAccess:(id) sender;
- (IBAction)goToWebsite:(id)sender;

@end

