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

#import "EXViewAnalyzerNode.h"
#import <dlfcn.h>

/**
 * A single data node in the EXViewAnalyzerWindowController
 */
@implementation EXViewAnalyzerNode

- (id) initWithView: (NSView *) view {
    if ((self = [super init]) == nil)
        return nil;
    
    _className = [view className];
    _address = (uintptr_t) view;
    _subviews = [[view subviews] copy];
    
    Dl_info dli;
    if (dladdr((__bridge void *) [view class], &dli) == 0 || dli.dli_fname == NULL) {
        _codePath = nil;
        return self;
    }
    
    _codePath = [NSString stringWithUTF8String: dli.dli_fname];


    return self;
}

@end
