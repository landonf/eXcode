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

#define PL_BLOCKIMP_PRIVATE 1 // Required for the unsupported trampoline API
#import <PLBlockIMP/trampoline_table.h>

#import "EXBlockLayout.h"

#import <objc/runtime.h>

#ifdef __x86_64__
#include "blockimp_x86_64.h"
#include "blockimp_x86_64_stret.h"
#else
#error Unsupported Architecture
#endif

/* Global lock for our mutable trampoline state. Must be held when accessing the trampoline tables. */
static pthread_mutex_t blockimp_lock = PTHREAD_MUTEX_INITIALIZER;

/* Trampoline tables for objc_msgSend_stret() dispatch. */
static pl_trampoline_table *blockimp_table_stret = NULL;

/* Trampoline tables for objc_msgSend() dispatch. */
static pl_trampoline_table *blockimp_table = NULL;

/**
 * Create a new EXPatchIMP block IMP trampoline.
 */
static IMP ex_imp_implementationWithBlock (id block, SEL selector, IMP origIMP) {
    /* Allocate the appropriate trampoline type. */
    pl_trampoline *tramp;
    struct Block_layout *bl = (__bridge struct Block_layout *) block;
    if (bl->flags & BLOCK_USE_STRET) {
        tramp = pl_trampoline_alloc(&ex_blockimp_patch_table_stret_page_config, &blockimp_lock, &blockimp_table_stret);
    } else {
        tramp = pl_trampoline_alloc(&ex_blockimp_patch_table_page_config, &blockimp_lock, &blockimp_table);
    }
    
    /* Configure the trampoline */
    void **config = pl_trampoline_data_ptr(tramp->trampoline);
    config[0] = Block_copy((__bridge void *)block);
    config[1] = tramp;
    config[2] = origIMP;
    config[3] = selector;

    /* Return the function pointer. */
    return (IMP) tramp->trampoline;
}

#if UNUSED

/**
 * Return the backing block for an IMP trampoline.
 */
static void *ex_imp_getBlock (IMP anImp) {
    /* Fetch the config data and return the block reference. */
    void **config = pl_trampoline_data_ptr(anImp);
    return config[0];
}

#endif

/**
 * Deallocate the IMP trampoline.
 */
static BOOL ex_imp_removeBlock (IMP anImp) {
    /* Fetch the config data */
    void **config = pl_trampoline_data_ptr(anImp);
    struct Block_layout *bl = config[0];
    pl_trampoline *tramp = config[1];
    
    /* Drop the trampoline allocation */
    if (bl->flags & BLOCK_USE_STRET) {
        pl_trampoline_free(&blockimp_lock, &blockimp_table_stret, tramp);
    } else {
        pl_trampoline_free(&blockimp_lock, &blockimp_table, tramp);
    }
    
    /* Release the block */
    Block_release(config[0]);
    
    // TODO - what does this return value mean?
    return YES;
}

/**
 * Runtime method patching support for NSObject. These are implemented via EXPatchMaster.
 */
@implementation NSObject (EXPatchMaster)

/**
 * Patch the receiver's @a selector class method. The previously registered IMP may be fetched via EXPatchMaster::originalIMP:.
 *
 * @param selector The selector to patch.
 * @param replacementBlock The new implementation for @a selector. The first parameter must be a pointer to EXPatchIMP; the
 * remainder of the parameters must match the original method.
 *
 * @return Returns YES on success, or NO if @a selector is not a defined @a cls method.
 */
+ (BOOL) ex_patchSelector: (SEL) selector withReplacementBlock: (id) replacementBlock {
    return [[EXPatchMaster master] patchClass: [self class] selector: selector replacementBlock: replacementBlock];

}

/**
 * Patch the receiver's @a selector instance method. The previously registered IMP may be fetched via EXPatchMaster::originalIMP:.
 *
 * @param selector The selector to patch.
 * @param replacementBlock The new implementation for @a selector. The first parameter must be a pointer to EXPatchIMP; the
 * remainder of the parameters must match the original method.
 *
 * @return Returns YES on success, or NO if @a selector is not a defined @a cls instance method.
 */
+ (BOOL) ex_patchInstanceSelector: (SEL) selector withReplacementBlock: (id) replacementBlock {
    return [[EXPatchMaster master] patchInstancesWithClass: [self class] selector: selector replacementBlock: replacementBlock];
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

/* Handle bundle unload */
- (void) handleUnloadNotification: (NSNotification *) notification {
    EXLog(@"Unloading all patches");
    
    /* Unpatch everything. */
    for (void (^b)(void) in _restoreBlocks)
        b();

    /* Remove ourself as an observer. */
    [[NSNotificationCenter defaultCenter] removeObserver: self];
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
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(handleUnloadNotification:) name: EXPluginUnloadNotification object: [NSBundle bundleForClass: [self class]]];

    return self;
}

/**
 * Patch the class method @a selector of @a cls.
 *
 * @param cls The class to patch.
 * @param selector The selector to patch.
 * @param replacementBlock The new implementation for @a selector. The first parameter must be a pointer to EXPatchIMP; the
 * remainder of the parameters must match the original method.
 *
 * @return Returns YES on success, or NO if @a selector is not a defined @a cls method.
 */
- (BOOL) patchClass: (Class) cls selector: (SEL) selector replacementBlock: (id) replacementBlock {
    Method m = class_getClassMethod(cls, selector);
    if (m == NULL)
        return NO;
    
    /* Insert the new implementation */
    IMP oldIMP = method_getImplementation(m);
    IMP newIMP = ex_imp_implementationWithBlock(replacementBlock, selector, oldIMP);

    if (!class_addMethod(object_getClass(cls), selector, newIMP, method_getTypeEncoding(m))) {
        /* Method already exists in subclass, we just need to swap the IMP */
        method_setImplementation(m, newIMP);
    }

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
            ex_imp_removeBlock(newIMP);
        } copy]];
    } OSSpinLockUnlock(&_lock);

    return YES;
}

/**
 * Patch the instance method @a selector of @a cls.
 *
 * @param cls The class to patch.
 * @param selector The selector to patch.
 * @param replacementBlock The new implementation for @a selector. The first parameter must be a pointer to EXPatchIMP; the
 * remainder of the parameters must match the original method.
 *
 * @return Returns YES on success, or NO if @a selector is not a defined @a cls instance method.
 */
- (BOOL) patchInstancesWithClass: (Class) cls selector: (SEL) selector replacementBlock: (id) replacementBlock {
    @autoreleasepool {
        Method m = class_getInstanceMethod(cls, selector);
        if (m == NULL)
            return NO;

        /* Insert the new implementation */
        IMP oldIMP = method_getImplementation(m);
        IMP newIMP = ex_imp_implementationWithBlock(replacementBlock, selector, oldIMP);
        
        if (!class_addMethod(cls, selector, newIMP, method_getTypeEncoding(m))) {
            /* Method already exists in subclass, we just need to swap the IMP */
            method_setImplementation(m, newIMP);
        }

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
                ex_imp_removeBlock(newIMP);
            } copy]];
        } OSSpinLockUnlock(&_lock);
    }

    return YES;
}

@end
