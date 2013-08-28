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
#import "EXViewAnalyzerOutlineView.h"

#import "EXUniversalBinary.h"

#import "eXcodePlugin.h"
#import <FScript/FScript.h>

#import <objc/runtime.h>

/** Notification sent when a new vew is targeted by the EXViewAnalyzer. The targeted view will be available via -[NSNotification object]. */
static NSString *EXViewAnalyzerTargetedViewNotification = @"EXViewAnalyzerTargetedViewNotification";

@interface EXViewAnalyzerWindowController (NSOutlineViewDataSource) <EXViewAnalyzerOutlineViewDataSource> @end

@interface EXViewAnalyzerWindowController () <NSWindowDelegate> @end

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
    
    /** All interpreter windows */
    NSMutableArray *_interpreterWindows;
}

/**
 * Initialize a new window controller instance.
 */
- (id) init {
    if ((self = [super initWithWindowNibName: [self className] owner: self]) == nil)
        return nil;
    
    _subnodes = [NSMutableArray array];
    _interpreterWindows = [NSMutableArray array];

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
        [_outlineView setDataSource: nil];
        [_outlineView removeFromSuperview];

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

// from NSWindowDelegate protocol
- (void) windowWillClose: (NSNotification *) notification {
    [_interpreterWindows removeObject: [notification object]];
}

- (void) openInFScriptConsole: (NSMenuItem *) item {
    EXViewAnalyzerNode *node = [item representedObject];

    /* Interpeter window */
    NSWindow *fscriptWindow  = [[NSWindow alloc] initWithContentRect: NSMakeRect(100, 100, 500, 400)
                                                        styleMask: NSClosableWindowMask | NSTitledWindowMask
                                                          backing: NSBackingStoreBuffered
                                                            defer: NO];
    FSInterpreterView *fscriptView = [[FSInterpreterView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    [fscriptWindow setContentView: fscriptView];
    
    /* Add this instance to the interpreter */
    [[fscriptView interpreter] setObject: node.address forIdentifier: @"target"];

    /* Configure ourself as a delegate, and ensure the window survives */
    [fscriptWindow setDelegate: self];
    [_interpreterWindows addObject: fscriptWindow];
    
    [[fscriptView interpreter] browse: node];
    
    /* Pop the console */
    [fscriptWindow orderFront: nil];
}

- (void) openWithHopper: (NSMenuItem *) item {
    EXViewAnalyzerNode *node = [item representedObject];
    [[NSWorkspace sharedWorkspace] openFile: node.codePath withApplication: @"Hopper Disassembler" andDeactivate: YES];
}

- (void) openWithIDA32: (NSMenuItem *) item {
    EXViewAnalyzerNode *node = [item representedObject];
    [[NSWorkspace sharedWorkspace] openFile: node.codePath withApplication: @"idaq" andDeactivate: YES];
}

- (void) openWithIDA64: (NSMenuItem *) item {
    EXViewAnalyzerNode *node = [item representedObject];
    [[NSWorkspace sharedWorkspace] openFile: node.codePath withApplication: @"idaq64" andDeactivate: YES];
}

@end

@implementation EXViewAnalyzerWindowController (NSOutlineViewDataSource)

- (NSMenu *) ex_outlineView: (EXViewAnalyzerOutlineView *) outlineView menuForRow: (NSInteger) row {
    EXViewAnalyzerNode *node = [_outlineView itemAtRow: row];
    if (node == nil)
        return nil;
    
    NSMenu *rowMenu = [[NSMenu alloc] initWithTitle:@"View Analzyer"];
    
    [[rowMenu addItemWithTitle: @"Examine with F-Script" action: @selector(openInFScriptConsole:) keyEquivalent: @""] setRepresentedObject: node];
    
    NSMenuItem *decompileItem = [rowMenu addItemWithTitle: @"Open with ..." action: @selector(submenuAction:) keyEquivalent: @""];
    NSMenu *decompileMenu = [[NSMenu alloc] init];
    [decompileItem setSubmenu: decompileMenu];

    [[decompileMenu addItemWithTitle: @"Hopper" action: @selector(openWithHopper:) keyEquivalent: @""] setRepresentedObject: node];

    /* Determine the available binaries; we only offer IDA 32/64 depending on availability */
    NSError *error;
    EXUniversalBinary *universal = [EXUniversalBinary binaryWithPath: node.codePath error: &error];
    if (universal == nil) {
        NSLog(@"Failed to load binary: %@", universal);
        return rowMenu;
    }

    BOOL has64 = NO;
    BOOL has32 = NO;
    for (EXExecutableBinary *binary in universal.executables) {
        if (binary.cpu_type & CPU_ARCH_ABI64) {
            has64 = YES;
        } else {
            has32 = YES;
        }
    }
    
    if (has32)
        [[decompileMenu addItemWithTitle: @"IDA Pro (32-bit)" action: @selector(openWithIDA32:) keyEquivalent: @""] setRepresentedObject: node];
    
    if (has64)
        [[decompileMenu addItemWithTitle: @"IDA Pro (64-bit)" action: @selector(openWithIDA64:) keyEquivalent: @""] setRepresentedObject: node];
    
    return rowMenu;
}

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
