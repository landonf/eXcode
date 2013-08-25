/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
 *
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import "eXcodePlugin.h"
#import "EXLog.h"

#import "DevToolsCore/header-stamp.h" // Xcode dependency hack
#import "DevToolsCore/XCPluginManager.h"

#import "EXPatchMaster.h"
#import "EXViewAnalyzerWindowController.h"

/**
 * Notification sent synchronously when the eXcode plugin is to be unloaded. Listeners must immediately deregister
 * any dangling references that may be left after a plugin unload.
 *
 * The object associated with the notification will be the bundle to be unloaded. Listeners may use this to determine
 * whether their bundle is about to be unloaded.
 */
NSString *EXPluginUnloadNotification = @"EXPluginUnloadNotification";

static void updated_plugin_callback (ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[]);

@implementation eXcodePlugin {
    EXViewAnalyzerWindowController *_analyzerWindowController;
}

static eXcodePlugin *sharedPlugin = nil;

/**
 * Return the shared plugin instance.
 */
+ (instancetype) sharedPlugin {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPlugin = [[eXcodePlugin alloc] init];
    });
    
    return sharedPlugin;
}


// from Xcode XCPluginManager informal protocol
+ (void) pluginDidLoad: (NSBundle *) plugin {
    [self sharedPlugin];
}

- (id) init {
    if ((self = [super init]) == nil)
        return nil;
    
    EXLog(@"Plugin loaded; starting up ...");
    
    /* Enable clean-up handling */
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleUnloadNotification:)
                                                 name: EXPluginUnloadNotification
                                               object: [NSBundle bundleForClass: [self class]]];
    
#if EX_BUILD_DEBUG
    /* In debug builds, we automatically reload the plugin whenever it is updated. */
    [self enablePluginReloader];
#endif
    
    /* Fire up the analyzer window */
    _analyzerWindowController = [[EXViewAnalyzerWindowController alloc] init];
    [_analyzerWindowController showWindow: nil];

#if 1
    // Hacked in logger
    [NSWindow ex_patchInstanceSelector: @selector(sendEvent:) withReplacementBlock: ^(EXPatchIMP *patch, NSEvent *event) {
        NSWindow *window = (__bridge NSWindow *) patch->self;
        if ([window isKeyWindow]) {
            NSPoint point = [window.contentView convertPoint: [event locationInWindow] fromView: nil];
            NSView *hitView = [window.contentView hitTest: point];
            if (hitView != nil)
                NSLog(@"HIT: %@", hitView);
        }
        
        EXPatchIMPFoward(patch, void (*)(id, SEL, NSEvent *), event);
    }];
#endif

    return self;
}

- (void) dealloc {
    // watty wat
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

// EXPluginUnloadNotification notifications
- (void) handleUnloadNotification: (NSNotification *) notification {
    /* Trigger deallocation (assuming the refcount hits 0, which is really ought to) */
    sharedPlugin = nil;
}

#if EX_BUILD_DEBUG
/**
 * Enable the auto-reload machinery responsible for reloading the plugin.
 */
- (void) enablePluginReloader {
    NSBundle *bundle = [NSBundle bundleForClass: [self class]];
    
    /* Watch for plugin changes, automatically reload. */
    FSEventStreamRef eventStream;
    {
        NSArray *directories = @[[bundle bundlePath]];
        FSEventStreamContext ctx = {
            .version = 0,
            .info = (__bridge void *) bundle,
            .retain = CFRetain,
            .release = CFRelease,
            .copyDescription = CFCopyDescription
        };
        eventStream = FSEventStreamCreate(NULL, &updated_plugin_callback, &ctx, (__bridge CFArrayRef) directories, kFSEventStreamEventIdSinceNow, 0.0, kFSEventStreamCreateFlagUseCFTypes);
        FSEventStreamScheduleWithRunLoop(eventStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        FSEventStreamStart(eventStream);
    }
}
#endif /* EX_DEBUG_BUILD */

@end

#if EX_BUILD_DEBUG

static void updated_plugin_callback (ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[]) {
    NSBundle *bundle = (__bridge NSBundle *) clientCallBackInfo;
    
    /* Avoid any race conditions with the Xcode build process; we want (at least) the executable to be in place before we reload. If it's not there,
     * wait for the FSEvent notifying us of its addition. */
    if (![[NSFileManager defaultManager] fileExistsAtPath: [bundle executablePath]])
        return;
    
    EXLog(@"Plugin was updated, reloading");
    
    /* Dispatch plugin unload notification */
    [[NSNotificationCenter defaultCenter] postNotificationName: EXPluginUnloadNotification object: bundle];
    
    /* We'll re-register for events when the plugin reloads */
    FSEventStreamStop((FSEventStreamRef) streamRef);
    
    
    /*
     * Our code will no longer exist once the bundle is unloaded; we can't simply unload the bundle here, as the process will crash once it returns.
     * We use NSInvocationOperation operations to execute the unload,reload without relying on any code from our bundle, and use NSOperationQueue dependencies
     * to enforce the correct ordering of the operations.
     */
    NSInvocationOperation *unloadOp = [[NSInvocationOperation alloc] initWithTarget: bundle
                                                                           selector: @selector(unload)
                                                                             object: nil];
    
    NSInvocationOperation *reloadOp = [[NSInvocationOperation alloc] initWithTarget: [XCPluginManager sharedPluginManager]
                                                                           selector: @selector(loadPluginBundle:)
                                                                             object: bundle];
    [reloadOp addDependency: unloadOp];
    
    [[NSOperationQueue mainQueue] addOperations: @[unloadOp,reloadOp] waitUntilFinished: NO];
}

#endif /* EX_BUILD_DEBUG */
