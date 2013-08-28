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

#import "EXMachO.h"

/**
 * Generic Plausible Simulator Exception
 * @ingroup exceptions
 */
NSString *EXMachOException = @"EXMachOException";

/** Plausible Simulator NSError Domain
 * @ingroup globals */
NSString *EXMachOErrorDomain = @"EXMachOErrorDomain";

/**
 * @internal
 
 * Return a new NSError instance using the provided information.
 *
 * @param code The error code corresponding to this error.
 * @param description A localized error description.
 * @param cause The underlying cause, if any. May be nil.
 */
NSError *exmacho_nserror (EXMachOError code, NSString *description, NSError *cause) {
    NSMutableDictionary *userInfo;
    
    /* Create the userInfo dictionary */
    userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                description, NSLocalizedDescriptionKey,
                nil
                ];
    
    if (cause != nil)
        [userInfo setObject: cause forKey: NSUnderlyingErrorKey];
    
    return [NSError errorWithDomain: EXMachOErrorDomain code: code userInfo: userInfo];
}

/**
 * @internal
 
 * Populate an NSError instance with the provided information.
 *
 * @param error Error instance to populate. If NULL, this method returns
 * and nothing is modified.
 * @param code The error code corresponding to this error.
 * @param description A localized error description.
 * @param cause The underlying cause, if any. May be nil.
 */
void exmacho_populate_nserror (NSError **error, EXMachOError code, NSString *description, NSError *cause) {
    if (error == NULL)
        return;
    
    *error = exmacho_nserror(code, description, cause);
}

/* Verify that the given range is within bounds. */
const void *ex_macho_read (macho_input_t *input, const void *address, size_t length) {
    if ((((uint8_t *) address) - ((uint8_t *) input->data)) + length > input->length) {
        return NULL;
    }
    
    return address;
}

/* Verify that address + offset + length is within bounds. */
const void *ex_macho_offset (macho_input_t *input, const void *address, size_t offset, size_t length) {
    void *result = ((uint8_t *) address) + offset;
    return ex_macho_read(input, result, length);
}