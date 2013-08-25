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

#import "EXViewAnalyzerWindowController.h"
#import "EXLog.h"

#import "EXPatchMaster.h"

#import "eXcodePlugin.h"

/** Notification sent when a new vew is targeted by the EXViewAnalyzer. The targeted view will be available via -[NSNotification object]. */
static NSString *EXViewAnalyzerTargetedViewNotification = @"EXViewAnalyzerTargetedViewNotification";

@interface EXViewAnalyzerWindowController ()

@end

/**
 * Manages the View Analyzer window.
 */
@implementation EXViewAnalyzerWindowController {
    id _observerToken;
}

- (void) handleUnloadNotification: (NSNotification *) notification {
    [self close];
}



/**
 * Initialize a new window controller instance.
 */
- (id) init {
    if ((self = [super initWithWindowNibName: [self className] owner: self]) == nil)
        return nil;

    /* Handle unload */
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(handleUnloadNotification:) name: EXPluginUnloadNotification object: [NSBundle bundleForClass: [self class]]];

    /* Stub out the notification */
    _observerToken = [[NSNotificationCenter defaultCenter] addObserverForName: EXViewAnalyzerTargetedViewNotification object: nil queue: [NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        NSLog(@"VIEW: %@", [note object]);
    }];
    
    /* Enable the NSEvent-based notification hook.  */
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [NSWindow ex_patchInstanceSelector: @selector(sendEvent:) withReplacementBlock: ^(EXPatchIMP *patch, NSEvent *event) {
            NSWindow *window = (__bridge NSWindow *) patch->self;
            if ([window isKeyWindow]) {
                /* The last view seen */
                static NSView *lastView = nil;
                                
                NSPoint point = [window.contentView convertPoint: [event locationInWindow] fromView: nil];
                NSView *hitView = [window.contentView hitTest: point];

                /* Only send a notification when the view changes */
                if (hitView != nil && hitView != lastView) {
                    lastView = hitView;
                    [[NSNotificationCenter defaultCenter] postNotificationName: EXViewAnalyzerTargetedViewNotification object: hitView];
                }
            }
            
            EXPatchIMPFoward(patch, void (*)(id, SEL, NSEvent *), event);
        }];
    });


    return self;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [[NSNotificationCenter defaultCenter] removeObserver: _observerToken];
}

- (void) windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

@end
