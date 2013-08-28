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

#import "EXViewAnalyzerOutlineView.h"

@implementation EXViewAnalyzerOutlineView

- (id) initWithFrame: (NSRect) frame {
    if ((self = [super initWithFrame: frame]) == nil)
        return nil;
    
    return self;
}

- (NSMenu *) menuForEvent: (NSEvent*) evt {
    NSPoint point = [self convertPoint: [evt locationInWindow] fromView: nil];
    NSInteger row = [self rowAtPoint: point];
    NSMenu *menu = nil;
    
    /* Retarget the row selection */
    NSIndexSet *selectedRowIndexes = [self selectedRowIndexes];
    if ([selectedRowIndexes containsIndex: row] == NO) {
        [self deselectAll: self];
        [self selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: NO];
    }

    id<EXViewAnalyzerOutlineViewDataSource> ds = (id<EXViewAnalyzerOutlineViewDataSource>) [self dataSource];
    if ([ds respondsToSelector: @selector(ex_outlineView:menuForRow:)])
        menu = [ds ex_outlineView: self menuForRow: row];
    
    if (menu == nil)
        return [super menuForEvent: evt];
    
    return menu;
}

@end
