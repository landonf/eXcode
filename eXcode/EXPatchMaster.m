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

#import "EXPatchMaster.h"
#import "EXLog.h"

#import <objc/runtime.h>

/**
 * Runtime method patching support for NSObject. These are implemented via EXPatchMaster.
 */
@implementation NSObject (EXPatchMaster)

/**
 * Patch the receiver's @a selector class method. The previously registered IMP may be fetched via EXPatchMaster::originalIMP:.
 *
 * @param selector The selector to patch.
 * @param originalIMP[out] If non-NULL, the previous method IMP will be provided.
 * @param replacementBlock The new implementation for @a selector.
 *
 * @return Returns YES on success, or NO if @a selector is not a defined @a cls method.
 */
+ (BOOL) ex_patchSelector: (SEL) selector originalIMP: (IMP *) originalIMP withReplacementBlock: (id) replacementBlock {
    return [[EXPatchMaster master] patchClass: [self class] selector: selector originalIMP: originalIMP  replacementBlock: replacementBlock];

}

/**
 * Patch the receiver's @a selector instance method. The previously registered IMP may be fetched via EXPatchMaster::originalIMP:.
 *
 * @param selector The selector to patch.
 * @param originalIMP[out] If non-NULL, the previous method IMP will be provided.
 * @param replacementBlock The new implementation for @a selector.
 *
 * @return Returns YES on success, or NO if @a selector is not a defined @a cls instance method.
 */
+ (BOOL) ex_patchInstanceSelector: (SEL) selector originalIMP: (IMP *) originalIMP withReplacementBlock: (id) replacementBlock {
    return [[EXPatchMaster master] patchInstancesWithClass: [self class] selector: selector originalIMP: originalIMP replacementBlock: replacementBlock];
}

@end

/**
 * Manages application (and removal) of runtime patches. This class is thread-safe, and may be accessed from any thread.
 */
@implementation EXPatchMaster {
    /** Lock that must be held when mutating or accessing internal state */
    OSSpinLock _lock;

    /** Maps class -> set -> selector names. Used to keep track of patches that have already been made,
     * and thus do not require a _restoreBlock to be registered */
    NSMutableDictionary *_classPatches;

    /** Maps class -> set -> selector names. Used to keep track of patches that have already been made,
     * and thus do not require a _restoreBlock to be registered */
    NSMutableDictionary *_instancePatches;
    
    /* An array of zero-arg blocks that, when executed, will reverse
     * all previously patched methods. */
    NSMutableArray *_restoreBlocks;
}

/**
 * Return the default patch master.
 */
+ (instancetype) master {
    static EXPatchMaster *m = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        m = [[EXPatchMaster alloc] init];;
    });
    
    return m;
}

- (instancetype) init {
    if ((self = [super init]) == nil)
        return nil;
    
    /* Default state */
    _classPatches = [NSMutableDictionary dictionary];
    _instancePatches = [NSMutableDictionary dictionary];
    _restoreBlocks = [NSMutableArray array];
    _lock = OS_SPINLOCK_INIT;

    /* Handle unload */
    [[NSNotificationCenter defaultCenter] addObserverForName: EXPluginUnloadNotification object: nil queue: [NSOperationQueue mainQueue] usingBlock: ^(NSNotification *note) {
        /* We only care about our own bundle */
        if (![[note object] isEqual: [NSBundle bundleForClass: [self class]]])
            return;
        
        EXLog(@"Unloading all patches!");
        
        /* Unpatch everything. */
        for (void (^b)(void) in _restoreBlocks)
            b();
    }];

    return self;
}

/**
 * Patch the class method @a selector of @a cls.
 *
 * @param cls The class to patch.
 * @param selector The selector to patch.
 * @param originalIMP[out] If non-NULL, the previous method IMP will be provided.
 * @param replacementBlock The new implementation for @a selector.
 *
 * @return Returns YES on success, or NO if @a selector is not a defined @a cls method.
 */
- (BOOL) patchClass: (Class) cls selector: (SEL) selector originalIMP: (IMP *) originalIMP replacementBlock: (id) replacementBlock {
    Method m = class_getClassMethod(cls, selector);
    if (m == NULL)
        return NO;

    /* Provide the old implementation; this needs to occur *before* the newIMP could possibly be called */
    IMP oldIMP = method_getImplementation(m);
    if (originalIMP != NULL)
        *originalIMP = oldIMP;
    
    /* Insert the new implementation */
    IMP newIMP = imp_implementationWithBlock(replacementBlock);
    method_setImplementation(m, newIMP);

    /* If the method has already been patched once, we don't need to add another restore block */
    OSSpinLockLock(&_lock); {
        /* If the method has already been patched once, we won't need to restore the IMP */
        BOOL restoreIMP = YES;
        if (_classPatches[cls][NSStringFromSelector(selector)] != nil)
            restoreIMP = NO;
        
        /* Otherwise, record the patch and save a restore block */
        if (_classPatches[cls] == nil)
            _classPatches[(id)cls] = [NSMutableSet setWithObject: NSStringFromSelector(selector)];
        else
            [_classPatches[(id)cls] addObject: NSStringFromSelector(selector)];

        [_restoreBlocks addObject: [^{
            if (restoreIMP) {
                Method m = class_getClassMethod(cls, selector);
                method_setImplementation(m, oldIMP);
            }
            imp_removeBlock(newIMP);
        } copy]];
    } OSSpinLockUnlock(&_lock);

    return YES;
}

/**
 * Patch the instance method @a selector of @a cls.
 *
 * @param cls The class to patch.
 * @param selector The selector to patch.
 * @param originalIMP[out] If non-NULL, the previous method IMP will be provided.
 * @param replacementBlock The new implementation for @a selector.
 *
 * @return Returns YES on success, or NO if @a selector is not a defined @a cls instance method.
 */
- (BOOL) patchInstancesWithClass: (Class) cls selector: (SEL) selector originalIMP: (IMP *) originalIMP replacementBlock: (id) replacementBlock {
    @autoreleasepool {
        Method m = class_getInstanceMethod(cls, selector);
        if (m == NULL)
            return NO;

        /* Provide the old implementation; this needs to occur *before* the newIMP could possibly be called */
        IMP oldIMP = method_getImplementation(m);
        if (originalIMP != NULL)
            *originalIMP = oldIMP;

        /* Insert the new implementation */
        IMP newIMP = imp_implementationWithBlock(replacementBlock);
        method_setImplementation(m, newIMP);

        OSSpinLockLock(&_lock); {
            /* If the method has already been patched once, we won't need to restore the IMP */
            BOOL restoreIMP = YES;
            if (_instancePatches[cls][NSStringFromSelector(selector)] != nil)
                restoreIMP = NO;
            
            /* Otherwise, record the patch and save a restore block */
            if (_instancePatches[cls] == nil)
                _instancePatches[(id)cls] = [NSMutableSet setWithObject: NSStringFromSelector(selector)];
            else
                [_instancePatches[(id)cls] addObject: NSStringFromSelector(selector)];
            
            [_restoreBlocks addObject: [^{
                if (restoreIMP) {
                    Method m = class_getInstanceMethod(cls, selector);
                    method_setImplementation(m, oldIMP);
                }
                imp_removeBlock(newIMP);
            } copy]];
        } OSSpinLockUnlock(&_lock);
    }

    return YES;
}

@end
