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

#import <FScript/FScript.h>

#import "EXPatchMaster.h"
#import "EXViewAnalyzerWindowController.h"

/* See comment in F-Script initialization below */
@interface NSObject (private_IBUICanvasLayoutPersistence)
+ (NSPoint) ibExternalLastKnownCanvasFrameOrigin;
- (NSPoint) ibExternalLastKnownCanvasFrameOrigin;
@end

@implementation eXcodePlugin {
    EXViewAnalyzerWindowController *_analyzerWindowController;
    FScriptMenuItem *_fscriptMenu;
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
    
#if EX_BUILD_DEBUG
    /* Fire up the analyzer window */
    _analyzerWindowController = [[EXViewAnalyzerWindowController alloc] init];
    [_analyzerWindowController showWindow: nil];
#endif
    
    
    /* Inject F-Script menu
     *
     * Xcode's IDEInterfaceBuilderCocoaTouchIntegration includes an NSObject category that registers
     * an assortment of ib-related methods for abstract methods, and then triggers non-exception-based
     * abort() when they are called. This triggers a crash when F-Script introspects defined object
     * properties. This ugly hack works around the issue; we can re-evaluate this in favor for a more
     * surgical approach at later date.
     */
    [NSObject ex_patchSelector: @selector(ibExternalLastKnownCanvasFrameOrigin) withReplacementBlock: ^(EXPatchIMP *patch) { return NSZeroPoint; }];
    [NSObject ex_patchInstanceSelector: @selector(ibExternalLastKnownCanvasFrameOrigin) withReplacementBlock: ^(EXPatchIMP *patch) { return NSZeroPoint; }];

    _fscriptMenu = [[FScriptMenuItem alloc] init];
    [[NSApp mainMenu] addItem: _fscriptMenu];

    return self;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

@end
