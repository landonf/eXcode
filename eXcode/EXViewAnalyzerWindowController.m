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
#import "EXViewAnalyzerNode.h"

#import "eXcodePlugin.h"

/** Notification sent when a new vew is targeted by the EXViewAnalyzer. The targeted view will be available via -[NSNotification object]. */
static NSString *EXViewAnalyzerTargetedViewNotification = @"EXViewAnalyzerTargetedViewNotification";

@interface EXViewAnalyzerWindowController (NSOutlineViewDataSource) <NSOutlineViewDataSource> @end

/**
 * Manages the View Analyzer window.
 */
@implementation EXViewAnalyzerWindowController {
    /** Managed outline view */
    IBOutlet __weak NSOutlineView *_outlineView;
    
    /** Top-level node, or nil if none. */
    EXViewAnalyzerNode *_head;

    /** All instantiated subnodes */
    NSMutableArray *_subnodes;
}

/**
 * Initialize a new window controller instance.
 */
- (id) init {
    if ((self = [super initWithWindowNibName: [self className] owner: self]) == nil)
        return nil;
    
    _subnodes = [NSMutableArray array];

    /* Handle unload */
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(handleUnloadNotification:) name: EXPluginUnloadNotification object: [NSBundle bundleForClass: [self class]]];

    /* View changed notification */
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(handleViewChangedNotification:) name: EXViewAnalyzerTargetedViewNotification object: nil];
    
    /* Enable the NSEvent-based notification hook.  */
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [NSWindow ex_patchInstanceSelector: @selector(sendEvent:) withReplacementBlock: ^(EXPatchIMP *patch, NSEvent *event) {
            NSWindow *window = (__bridge NSWindow *) patch->self;
            if (window != self.window && [event type] == NSLeftMouseUp && [window isKeyWindow]) {
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

// EXViewAnalyzerTargetedViewNotification notification
- (void) handleViewChangedNotification: (NSNotification *) notification {
    _head = [[EXViewAnalyzerNode alloc] initWithView: [notification object]];
    [_subnodes removeAllObjects];
    [_outlineView reloadData];
}

// EXPluginUnloadNotification notification
- (void) handleUnloadNotification: (NSNotification *) notification {
    @autoreleasepool {
        [self close];
    }
}

- (void) dealloc {
    _outlineView.dataSource = nil;
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void) windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

@end

@implementation EXViewAnalyzerWindowController (NSOutlineViewDataSource)

- (NSInteger) outlineView: (NSOutlineView *) outlineView numberOfChildrenOfItem: (id) item {
    EXViewAnalyzerNode *node = item;

    if (_head == nil)
        return 0;
    
    if (item == nil)
        return 1;

    return [[node subviews] count];
}

- (id) outlineView: (NSOutlineView *) outlineView child: (NSInteger) index ofItem: (id) item {
    EXViewAnalyzerNode *node = item;

    if (item == nil)
        return _head;
    
    EXViewAnalyzerNode *new = [[EXViewAnalyzerNode alloc] initWithView: [[node subviews] objectAtIndex: index]];
    [_subnodes addObject: new];
    return new;
}

- (id) outlineView: (NSOutlineView *) outlineView objectValueForTableColumn: (NSTableColumn *) tableColumn byItem: (id) item {
    EXViewAnalyzerNode *node = item;

    NSString *identifier = [tableColumn identifier];
    if ([identifier isEqual: @"name"]) {
        return node.className;
    } else if ([identifier isEqual: @"address"]) {
        return [NSString stringWithFormat: @"%p", (void *)node.address];
    } else if ([identifier isEqual: @"path"]) {
        if (node.codePath != nil)
            return node.codePath;
        else
            return @"<unknown>";
    }

    // Unreachable
    abort();
}

- (BOOL) outlineView: (NSOutlineView *) outlineView isItemExpandable: (id) item {
    EXViewAnalyzerNode *node = item;
    
    if ([node.subviews count] > 0)
        return YES;
    
    return NO;
}

@end
