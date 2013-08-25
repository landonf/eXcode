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

#import "DevToolsCore/header-stamp.h" // Xcode dependency hack
#import "DevToolsCore/XCPluginManager.h"

@implementation eXcodePlugin

static void updated_plugin_callback (ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[]) {
    NSBundle *bundle = (__bridge NSBundle *) clientCallBackInfo;
    
    /* TODO: Dispatch a synchronous "STOP EVERYTHING" notification */

    /* Our code will no longer exist once the bundle is unloaded; we can't simply unload the bundle here, as the process will crash once it returns */
    NSLog(@"Plugin was updated, reloading");
    FSEventStreamStop((FSEventStreamRef) streamRef);

    [bundle performSelector: @selector(unload) withObject: nil afterDelay: 0.0];
    [[XCPluginManager sharedPluginManager] performSelector: @selector(loadPluginBundle:) withObject: bundle afterDelay: 1.0f];
}

+ (void) pluginDidLoad: (NSBundle *) plugin {
    NSLog(@"Plugin is active");
    
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

@end
