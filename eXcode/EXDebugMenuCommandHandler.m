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

#import "EXDebugMenuCommandHandler.h"
#import "EXLog.h"

/**
 * Command handler for the Xcode internal debug menu (eXcode.CmdHandler.ExampleDebugMenuEntry).
 */
@implementation EXDebugMenuCommandHandler

// Returns the handler for a given action. This seemingly should already be available via
// the entries 'action' value; we need to spend some time reverse engineering the menu configuration
// options and how actions are mapped.
+ (id) handlerForAction: (SEL) action withSelectionSource: (id) src {
    return [[self alloc] init];
}

// eXcode.CmdHandler.ExampleDebugMenuEntry handler.
- (void) exampleDebugMenuEntry: (id) sender {
    EXLog(@"Action %@ called with sender: %@", NSStringFromSelector(_cmd), sender);
}

@end
