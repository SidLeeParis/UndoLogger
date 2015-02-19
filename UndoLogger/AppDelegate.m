//
//  AppDelegate.m
//  UndoLogger
//
//  Created by David Bismut on 18/11/2014.
//  Copyright (c) 2014 David Bismut. All rights reserved.
//

#import "AppDelegate.h"
#import "Reachability.h"

NSString * const serverPath = @"http://youraddress";
NSString * const secret = @"yoursecret";

@interface AppDelegate ()

@end

@implementation AppDelegate {
    id _eventMonitor;
    NSString * _bundleVersion;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    _bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    [_statusItem setMenu:_statusMenu];
    NSImage *image = [NSImage imageNamed:@"undo_on"];
    [image setTemplate:YES];
    
    [_statusItem setImage:image];
    

    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(didToggleAccessStatus:) name:@"com.apple.accessibility.api" object:nil suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
    
    // Get current accessibility status of Accessibility Testbench, and log whether access is already allowed when Accessibility Testbench is launched.
    BOOL status = NO;
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_8) { // AXIsProcessTrustedWithOptions function was introduced in OS X 10.9 Mavericks
        status = [self isProcessTrustedWithoutAlert];
    }
    
    NSLog(@"At launch // process trusted: %@", (status) ? @"YES" : @"NO");
    
    [self setAccessStatus:status];
    [self grantAccess:self]; // present alerts if access is not enabled
    
    if (status) {
        [self registerUndos];
    }
    
    [self updateStatusItem];
    [self setLaunchAtLogin];
    
    Reachability* reach = [Reachability reachabilityWithHostname:@"www.google.com"];
    
    // Set the blocks
    reach.reachableBlock = ^(Reachability*reach)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            _connectionStatus = YES;
            NSLog(@"Network reachable");
            [self updateStatusItem];
        });
    };
    
    reach.unreachableBlock = ^(Reachability*reach)
    {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            _connectionStatus = NO;
            NSLog(@"Oh no, Network unreachable!!!");
            [self updateStatusItem];
        });
    };
    
    // Start the notifier, which will cause the reachability object to retain itself!
    [reach startNotifier];
}

- (IBAction)grantAccess:(id) sender {
    
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_8) {
        [self isProcessTrustedWithAlert];
    }
}

- (IBAction)goToWebsite:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: serverPath]];
}


- (void)didToggleAccessStatus:(NSNotification *)notification {
    [self performSelector:@selector(noteNewAccessStatus:) withObject:[NSNumber numberWithBool:[self accessStatus]] afterDelay:0.5]; // 0.5 seconds
}

- (BOOL)isProcessTrustedWithoutAlert {
    NSDictionary *withoutAlertOption = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:(__bridge NSString *)kAXTrustedCheckOptionPrompt];
    return [self isProcessTrustedWithOptions:withoutAlertOption];
}

- (BOOL)isProcessTrustedWithOptions:(NSDictionary *)options {
    return AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}

- (void)noteNewAccessStatus:(NSNumber *)oldAccessStatusNumber {
    
    BOOL status = NO;
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_8) {
        status = [self isProcessTrustedWithoutAlert];
    }
    

    NSLog(@"noteNewAccessStatus // process trusted: %@", (status) ? @"YES" : @"NO");
    
    
    BOOL oldAccessStatus = [oldAccessStatusNumber boolValue]; // "before" value
    BOOL newAccessStatus = status; // "after" value
    
    if (newAccessStatus != oldAccessStatus) {
        if (newAccessStatus == YES) {
            NSLog(@"Registering Undos");
            [self registerUndos];
        } else if (newAccessStatus == NO) {
            NSLog(@"Access was denied");
            [NSEvent removeMonitor:_eventMonitor];
        }
    }
    
    [self setAccessStatus:newAccessStatus];
    [self updateStatusItem];
}


- (BOOL)isProcessTrustedWithAlert {
    NSDictionary *withAlertOption = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:(__bridge NSString *)kAXTrustedCheckOptionPrompt];
    return [self isProcessTrustedWithOptions:withAlertOption];
}

- (void) updateStatusItem {
    NSImage *image = [NSImage imageNamed:_accessStatus && _connectionStatus ? @"undo_on" : @"undo_off"];
    [image setTemplate:YES];
    [_statusItem setImage:image];
    [_statusActivate setEnabled:!_accessStatus];
}

- (void)registerUndos {
    _eventMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSKeyDownMask handler:^(NSEvent *event) {
        if (_connectionStatus && ! event.isARepeat && event.modifierFlags == 1048840 && [event.charactersIgnoringModifiers  isEqual: @"z"]) {
            NSLog(@"POMME-Z ;), %@", _bundleVersion);
            
            NSString *appName = [NSWorkspace sharedWorkspace].frontmostApplication.localizedName;
            
            
            NSString *firstName = [[NSFullUserName() componentsSeparatedByString:@" "] objectAtIndex:0];
            
            NSDictionary *undoObject = [NSDictionary dictionaryWithObjectsAndKeys:
                                        firstName, @"username",
                                        appName, @"appname",
                                        secret,@"secret",
                                        _bundleVersion, @"version",
                                        nil];
            
            NSError *error;
            NSData *undoData = [NSJSONSerialization dataWithJSONObject:undoObject options:NSJSONWritingPrettyPrinted error:&error];

            NSString *url = [NSString stringWithFormat:@"%@/addUndo", serverPath];
            
            [self sendJSONRequestWithData:undoData andURL:url andCompletion:nil];
        }
        
    }];
}

- (void)sendJSONRequestWithData:(NSData *)jsonData andURL:(NSString*)url andCompletion:(void (^)(BOOL finished))completion {
   
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                       timeoutInterval:10];
    
    
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)jsonData.length] forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody: jsonData];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        if (connectionError) {
            NSLog(@"error: %@", connectionError.localizedDescription);
            if(completion) completion(false);
        }
        else if(completion) completion(true);
    }];
}

- (void)setLaunchAtLogin {
    NSString *fileName = @"AddLoginItem";
    NSString *filePath = [[NSBundle mainBundle] pathForResource:fileName ofType:@"scpt"];
    NSString *template = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:NULL];
    
    NSString *source;
    NSString *localizedName = [[NSRunningApplication currentApplication] localizedName];
    
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    source = [NSString stringWithFormat:template, bundlePath, localizedName];

    // Run script
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:source];
    
    NSDictionary *error = nil;
    [script executeAndReturnError:&error];
    
    if (error) {
        NSLog(@"Error: %@", error[NSAppleScriptErrorBriefMessage]);
    }
}

@end
