/*
 * Author: Landon Fuller <landonf@plausible.coop>
 *
 * Copyright (c) 2010-2013 Plausible Labs Cooperative, Inc.
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

#import <Foundation/Foundation.h>

#import "EXExecutableBinary.h"

@interface EXUniversalBinary : NSObject {
@private
    /** Path to binary */
    NSString *_path;

    /** All Mach-O executables found within the binary */
    NSArray *_executables;
}

+ (id) binaryWithPath: (NSString *) path error: (NSError **) outError;

- (id) initWithPath: (NSString *) path error: (NSError **) outError;

- (EXExecutableBinary *) executableMatchingCurrentArchitecture;

/** All valid Mach-O executables found within the binary, as an ordered array of EXExecutableBinary instances. The array
 * will be ordered to match the in-file ordering. */
@property(nonatomic, readonly) NSArray *executables;

- (BOOL) loadLibraryWithRPaths: (NSArray *) rpaths error: (NSError **) outError;


@end
