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

#import <mach-o/dyld.h>

/* See comment in F-Script initialization below */
@interface NSObject (private_IBUICanvasLayoutPersistence)
+ (NSPoint) ibExternalLastKnownCanvasFrameOrigin;
- (NSPoint) ibExternalLastKnownCanvasFrameOrigin;
@end

/* Inject F-Script menu
 *
 * Xcode's IDEInterfaceBuilderCocoaTouchIntegration includes an NSObject category that registers
 * an assortment of ib-related methods for abstract methods, and then triggers non-exception-based
 * abort() when they are called. This triggers a crash when F-Script introspects defined object
 * properties. This ugly hack works around the issue; we can re-evaluate this in favor for a more
 * surgical approach at later date.
 */
void fscript_patch_dyld_added_image (const struct mach_header* mh, intptr_t vmaddr_slide) {
    if ([NSObject instancesRespondToSelector: @selector(ibExternalLastKnownCanvasFrameOrigin)]) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [NSObject ex_patchSelector: @selector(ibExternalLastKnownCanvasFrameOrigin) withReplacementBlock: ^(EXPatchIMP *patch) { return NSZeroPoint; }];
            [NSObject ex_patchInstanceSelector: @selector(ibExternalLastKnownCanvasFrameOrigin) withReplacementBlock: ^(EXPatchIMP *patch) { return NSZeroPoint; }];
        });
    }
}

@implementation eXcodePlugin {
    EXViewAnalyzerWindowController *_analyzerWindowController;
    FScriptMenuItem *_fscriptMenu;
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

    /* To fix an F-Script compatibility issue, we need to patch NSObject the
     * IDEInterfaceBuilderCocoaTouchIntegration image is loaded */
    _dyld_register_func_for_add_image(fscript_patch_dyld_added_image);

    // XXX - Our menu is being dropped if we instantiate it immediately
    // We probably need to plug into the Xcode menu system correctly, but in the mean time, this drops F-Script
    // into place.
    double delayInSeconds = 5.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        _fscriptMenu = [[FScriptMenuItem alloc] init];
        [[NSApp mainMenu] addItem: _fscriptMenu];
    });

    return self;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

@end
