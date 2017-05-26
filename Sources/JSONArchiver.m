//
//  JSONKeyedArchiver.m
//  JSONArchiver
//
//  Created by Martin Kiss on 25 May 2017.
//  Copyright © 2017 Tricertops. All rights reserved.
//

@import ObjectiveC.runtime;
#import "JSONArchiver.h"



#define var  __auto_type
#define let  __auto_type const





@interface JSONArchiverContainer : NSObject


@property NSMutableDictionary<NSString *, id> *dictionary;
- (BOOL)containsKey:(NSString *)key;
- (void)storeJSONObject:(id)object forKey:(NSString *)key;

@property NSUInteger nextIndex;
- (NSString *)nextIndexedKey;


@end





@interface JSONArchiverSelector : NSObject

@property SEL selector;

@end


@implementation JSONArchiverSelector

@end





@implementation JSONArchiverContainer


- (instancetype)init {
    self = [super init];
    
    self->_nextIndex = 0;
    self->_dictionary = [NSMutableDictionary new];
    
    return self;
}


- (BOOL)containsKey:(NSString *)key {
    return (self.dictionary[key] != nil);
}


- (NSString *)nextIndexedKey {
    let key = [NSString stringWithFormat:@"#%tu", self.nextIndex];
    self.nextIndex ++;
    return key;
}


- (void)storeJSONObject:(id)object forKey:(NSString *)key {
    NSAssert( ! [self containsKey:key], @"Duplicate key: %@", key);
    self.dictionary[key] = object;
}


@end





@interface JSONArchiver ()


//! Array where all top-level objects are stored before finalization.
@property (readonly) NSMutableArray<id> *topJSONObjects;
//! Indexes for objects in top-level object array that should be nullified during finalization.
@property (readonly) NSMutableIndexSet *conditionalTopIndexes;

//! Container that holds root objects. When needed, it is archived as top-level object.
@property (readonly) JSONArchiverContainer *rootContainer;
//! Flag that indicates whether the root container needs to be archived.
@property BOOL requiresRootInArchive;
//! Flag that indicates whether the receiver encodes root object. Alters some behavior.
@property (readonly) BOOL isRoot;

//! Stack of containers used for recursive encoding.
@property (readonly) NSMutableArray<JSONArchiverContainer *> *nestedContainers;
//! Returns last container from nested containers, if any. Otherwise returns root container.
@property (readonly) JSONArchiverContainer *currentContainer;

//! Holds finalized top-level objects. Created on demand and cleared on any mutation.
@property id cachedFinalizedArchive;


@end





@implementation JSONArchiver





#pragma mark - Convenience


+ (NSData *)archivedDataWithRootObject:(NSObject<NSCoding> *)object pretty:(BOOL)isPretty {
    var archiver = [JSONArchiver new];
    archiver.shouldPrettyPrint = isPretty;
    [archiver encodeRootObject:object];
    return archiver.JSONData;
}


+ (BOOL)archiveRootObject:(NSObject<NSCoding> *)object toURL:(NSURL *)URL pretty:(BOOL)isPretty {
    var archiver = [JSONArchiver new];
    archiver.shouldPrettyPrint = isPretty;
    [archiver encodeRootObject:object];
    return [archiver writeJSONToURL:URL];
}





#pragma mark - Basics


- (instancetype)init {
    self = [super init];
    NSAssert(self != nil, @"Failed to initialize %@ instance", JSONArchiver.class);
    
    self.shouldCompactRoot = YES;
    
    self->_topJSONObjects = [NSMutableArray new];
    self->_conditionalTopIndexes = [NSMutableIndexSet new];
    self->_rootContainer = [JSONArchiverContainer new];
    self->_nestedContainers = [NSMutableArray new];
    
    [self.rootContainer storeJSONObject:@"root" forKey:@"#special"];
    
    return self;
}


- (BOOL)allowsKeyedCoding {
    return YES;
}


- (BOOL)isRoot {
    return (self.nestedContainers.count == 0);
}


- (JSONArchiverContainer *)currentContainer {
    return self.nestedContainers.lastObject ?: self.rootContainer;
}





#pragma mark - Encoding


- (void)encodeObject:(NSObject<NSCoding> *)object forKey:(NSString *)key {
    [self internalEncodeObject:object forKey:[self validKey:key] conditional:NO];
}


- (void)encodeObject:(NSObject<NSCoding> *)object {
    [self internalEncodeObject:object forKey:nil conditional:NO];
}


- (void)encodeConditionalObject:(NSObject<NSCoding> *)object forKey:(NSString *)key {
    [self internalEncodeObject:object forKey:[self validKey:key] conditional:YES];
}


- (void)encodeConditionalObject:(NSObject<NSCoding> *)object {
    [self internalEncodeObject:object forKey:nil conditional:YES];
}


- (NSString *)validKey:(NSString *)key {
    NSAssert(key.length > 0, @"Key is empty");
    
    //! Keys with prefix # are used for internal structure.
    if ([key hasPrefix:@"#"]) {
        //! We simply prefix the key with another # symbol. So during decoding ## prefix needs to be shortened to #.
        return [@"#" stringByAppendingString:key];
    }
    //! All other keys are allowed.
    return key;
}


- (void)internalEncodeObject:(NSObject<NSCoding> *)object forKey:(NSString *)key conditional:(BOOL)isConditional {
    //! In case we cached the archive, clear it.
    self.cachedFinalizedArchive = nil;
    
    //! This allows providing different object for encoding.
    object = [object replacementObjectForCoder:self] ?: object;
    //! This allows substitued classes and simplifies class clusters.
    let class = object.classForCoder ?: object.class;
    //! If we have a replacement, we will store it directly in current container.
    id replacement = [self replacementJSONForObject:object class:class];
    
    //! If first root is keyed, we store list of roots as first top-level object.
    if (self.isRoot) {
        BOOL hasMultipleRoots = (self.rootContainer.dictionary.count > 1); //! One is the special key.
        BOOL isKeyed = (key.length > 0);
        BOOL isEmpty = (self.topJSONObjects.count == 0);
        
        //! In some simple (but typical) cases, we don’t even need to archive list of root objects.
        if (isKeyed || hasMultipleRoots || replacement) {
            self.requiresRootInArchive = YES;
        }
        //! If the root need to be archived and archive is empty yet, store the root as first. Otherwise it will be appended last.
        if (self.requiresRootInArchive && isEmpty) {
            [self.topJSONObjects addObject:self.rootContainer.dictionary];
        }
        //! Root objects cannot be conditional.
        isConditional = NO;
    }
    //! For indexed encoding, we need to generate the keys sequentially.
    if (key.length == 0) {
        key = [self.currentContainer nextIndexedKey];
    }
    
    //! If we have replacement, simply store it and we are done.
    if (replacement) {
        [self.currentContainer storeJSONObject:replacement forKey:key];
        return;
    }
    
    //TODO: Find existing top-level object and use its reference.
    //TODO: Find how NSKeyedArchiver treats -isEqual: objects.
    //TODO: If object is referenced, remove it from conditional objects (replace with null).
    
    //! We to create new top-level object.
    var container = [JSONArchiverContainer new];
    let index = self.topJSONObjects.count;
    [self.topJSONObjects addObject:container.dictionary];
    
    //! Include some debugging info for humans.
    if (self.shouldIncludeDebuggingInfo) {
        if (self.isRoot) {
            [container storeJSONObject:key forKey:@"#root"];
        }
        [container storeJSONObject:@(index) forKey:@"#index"];
    }
    
    //! We keep indexes of conditional objects for later finalization.
    if (isConditional) {
        [self.conditionalTopIndexes addIndex:index];
    }
    //! Store special JSON reference in the current container.
    [self.currentContainer storeJSONObject:[self referenceJSONForIndex:index] forKey:key];
    
    //! Now we push new container, invoke encoding recursively and then pop that container.
    [self.nestedContainers addObject:container];
    [container storeJSONObject:NSStringFromClass(class) forKey:@"#class"];
    [object encodeWithCoder:self]; // Anything could happen here.
    NSAssert(self.nestedContainers.lastObject == container, @"Inconsistent nestign of containers.");
    [self.nestedContainers removeLastObject];
}


- (id)replacementJSONForObject:(NSObject<NSCoding> *)object class:(Class)class {
    //! If this method return nil, the object need to be encoded using NSCoding protocol as another top-level object.
    
    //! Nil values are encoded as JSON null.
    if (object == nil) {
        return NSNull.null;
    }
    //! NSNull is rare, so it’s encoded as special object.
    if (object == NSNull.null) {
        return [self specialJSON:@"NSNull"];
    }
    //! All numbers are handled, some need special JSON compatibility values.
    if (class == NSNumber.class) {
        
        //! NSNumbers created using BOOL literals or +numberWithBool: method.
        if (object == (id)kCFBooleanFalse || object == (id)kCFBooleanTrue) {
            return object;
        }
        //! NaNs and Infinity are not supported in JSON, so we use special placeholders.
        if (object == (id)kCFNumberNaN) {
            return [self specialJSON:@"NaN"];
        }
        if (object == (id)kCFNumberPositiveInfinity) {
            return [self specialJSON:@"+Inf"];
        }
        if (object == (id)kCFNumberNegativeInfinity) {
            return [self specialJSON:@"-Inf"];
        }
        //! All other NSNumbers are supported directly.
        return object;
        //! NSDecimalNumber will fallback to NSCoding.
    }
    //! NSStrings are directly encoded, but only plain immutable up to certain length.
    if (class == NSString.class) {
        let string = (NSString *)object;
        return (string.length > 512? nil : string);
    }
    //! NSArrays are direct, but only immutable up to certain size.
    if (class == NSArray.class) {
        let array = (NSArray *)object;
        return (array.count > 16? nil : array);
    }
    //! NSData needs special JSON object that holds base64 encoded data.
    if (class == NSData.class) {
        return [self base64JSON:(NSData *)object];
    }
    //! Classes are encoded using special object.
    if (object_isClass(object)) {
        return [self classJSON:(Class)object];
    }
    //! Selectors are encoded using special object.
    if (class == JSONArchiverSelector.class) {
        return [self selectorJSON:((JSONArchiverSelector *)object).selector];
    }
    //! All others will need to use NSCoding via -encodeWithCoder: method.
    return nil;
}


- (NSDictionary<NSString *, NSString *> *)specialJSON:(NSString *)name {
    return @{ @"#special": name ?: @"" };
}


- (NSDictionary<NSString *, NSString *> *)classJSON:(Class)class {
    return @{ @"#meta": NSStringFromClass(class) };
}


- (NSDictionary<NSString *, NSString *> *)selectorJSON:(SEL)selector {
    return @{ @"#selector": NSStringFromSelector(selector) };
}


- (NSDictionary<NSString *, NSString *> *)base64JSON:(NSData *)data {
    let prettyOptions = (NSDataBase64Encoding76CharacterLineLength | NSDataBase64EncodingEndLineWithLineFeed);
    let options = (self.shouldPrettyPrint? prettyOptions : kNilOptions);
    let base64 = [data base64EncodedStringWithOptions:options];
    return @{ @"#base64": base64 ?: @"" };
}


- (NSDictionary<NSString *, NSNumber *> *)referenceJSONForIndex:(NSUInteger)index {
    return @{ @"#ref": @(index) };
}


- (id)finalizedArchive {
    //! We will finalize archive, so it’s not mutated, it contains root list (if needed), and conditional objects are gone.
    NSMutableArray<id> *topObjects = [self.topJSONObjects mutableCopy];
    
    //! If we only have one top-level object, other finalizations are not necessary.
    if (self.shouldCompactRoot && topObjects.count == 1) {
        
        //! The that single object is root list, remove special mark and return it.
        if (topObjects.firstObject == self.rootContainer.dictionary) {
            var rootList = (NSMutableDictionary *)[topObjects.firstObject mutableCopy];
            [rootList removeObjectForKey:@"#special"];
            return rootList;
        }
        //! Other top-lever object should be fine.
        return topObjects.firstObject;
    }
    
    //! We don’t always archive list of root objects.
    if (self.requiresRootInArchive) {
        let rootList = self.rootContainer.dictionary;
        BOOL isRootAsFirst = (self.topJSONObjects.firstObject == rootList);
        //! Root may only be first or last.
        if (isRootAsFirst) {
            //! Root list is mutable and could be mutated later, so we need to copy it.
            topObjects[0] = [topObjects[0] copy];
        }
        else {
            //! If it’s not first, we need to append it now. This only happens in case of multiple indexed roots.
            return [self.topJSONObjects arrayByAddingObject:[rootList copy]];
        }
    }
    
    //! Replace conditional objects with JSON nulls, so references to them are preserved.
    [self.conditionalTopIndexes enumerateIndexesUsingBlock:^(NSUInteger index, __unused BOOL *stop) {
        topObjects[index] = NSNull.null;
    }];
    
    return topObjects;
}





#pragma mark - Keyed Encoding Methods


- (void)encodeBool:(BOOL)boolean forKey:(NSString *)key {
    [self encodeObject:[NSNumber numberWithBool:boolean] forKey:key];
}


- (void)encodeInt:(int)integer forKey:(NSString *)key {
    [self encodeObject:@(integer) forKey:key];
}


- (void)encodeInteger:(NSInteger)integer forKey:(NSString *)key {
    [self encodeObject:@(integer) forKey:key];
}


- (void)encodeInt32:(int32_t)integer forKey:(NSString *)key {
    [self encodeObject:@(integer) forKey:key];
}


- (void)encodeInt64:(int64_t)integer forKey:(NSString *)key {
    [self encodeObject:@(integer) forKey:key];
}


- (void)encodeDouble:(double)number forKey:(NSString *)key {
    [self encodeObject:@(number) forKey:key];
}


- (void)encodeFloat:(float)number forKey:(NSString *)key {
    [self encodeObject:@(number) forKey:key];
}


- (void)encodeBytes:(const uint8_t *)bytes length:(NSUInteger)length forKey:(NSString *)key {
    //! Sending NSData to encode method will trigger special base64 behavior.
    let data = [NSData dataWithBytes:bytes length:length];
    [self encodeObject:data forKey:key];
}


//! System methods for encoding structs (CGPoint etc.) are implemented using other encoding methods.





#pragma mark - Indexed Encoding Methods


- (void)encodeRootObject:(NSObject<NSCoding> *)object {
    NSAssert(self.isRoot, @"Cannot encode root object while encoding.");
    
    [self encodeObject:object];
}


- (void)encodeBool:(BOOL)boolean {
    [self encodeObject:@(boolean)];
}


- (void)encodeInt:(int)integer {
    [self encodeObject:@(integer)];
}


- (void)encodeInteger:(NSInteger)integer {
    [self encodeObject:@(integer)];
}


- (void)encodeInt32:(int32_t)integer {
    [self encodeObject:@(integer)];
}


- (void)encodeInt64:(int64_t)integer {
    [self encodeObject:@(integer)];
}


- (void)encodeDouble:(double)number {
    [self encodeObject:@(number)];
}


- (void)encodeFloat:(float)number {
    [self encodeObject:@(number)];
}


- (void)encodeBytes:(const void *)bytes length:(NSUInteger)length {
    let data = [NSData dataWithBytes:bytes length:length];
    [self encodeObject:data];
}


- (void)encodeDataObject:(NSData *)data {
    [self encodeObject:data];
}


- (void)encodeValueOfObjCType:(const char *)type at:(const void *)address {
    id object = [self objectFromObjCType:type address:address];
    [self encodeObject:object];
}


- (id)objectFromObjCType:(const char *)type address:(const void *)address {
    
    //! Signed numeric types.
    if (strcmp(type, @encode(signed char)) == 0) {
        return (address ? @(*(signed char *)address) : @0);
    }
    if (strcmp(type, @encode(signed short)) == 0) {
        return (address ? @(*(signed short *)address) : @0);
    }
    if (strcmp(type, @encode(signed int)) == 0) {
        return (address ? @(*(signed int *)address) : @0);
    }
    if (strcmp(type, @encode(signed long)) == 0) {
        return (address ? @(*(signed long *)address) : @0);
    }
    if (strcmp(type, @encode(signed long long)) == 0) {
        return (address ? @(*(signed long long *)address) : @0);
    }
    
    //! Unsigned numeric types.
    if (strcmp(type, @encode(unsigned char)) == 0) {
        return (address ? @(*(unsigned char *)address) : @0);
    }
    if (strcmp(type, @encode(unsigned short)) == 0) {
        return (address ? @(*(unsigned short *)address) : @0);
    }
    if (strcmp(type, @encode(unsigned int)) == 0) {
        return (address ? @(*(unsigned int *)address) : @0);
    }
    if (strcmp(type, @encode(unsigned long)) == 0) {
        return (address ? @(*(unsigned long *)address) : @0);
    }
    if (strcmp(type, @encode(unsigned long long)) == 0) {
        return (address ? @(*(unsigned long long *)address) : @0);
    }
    
    //! Floating-point numeric types.
    if (strcmp(type, @encode(float)) == 0) {
        return (address ? @(*(float *)address) : @0);
    }
    if (strcmp(type, @encode(double)) == 0) {
        return (address ? @(*(double *)address) : @0);
    }
    if (strcmp(type, @encode(long double)) == 0) {
        // Not supported by NSNumber literal.
        return (address ? @((double)(*(long double *)address)) : @0);
    }
    
    //! Other C types.
    if (strcmp(type, @encode(_Bool)) == 0) {
        return (address ? @(*(_Bool *)address) : @0);
    }
    if (strcmp(type, @encode(void)) == 0) {
        return nil; // wtf?
    }
    if (strcmp(type, @encode(char *)) == 0) {
        return (address ? @(*(char **)address) : @"");
    }
    if (   type[0] == @encode(char[])[0]
        || type[0] == @encode(struct {})[0]
        || type[0] == @encode(union {})[0]) {
        return [NSValue valueWithBytes:address objCType:type];
    }
    
    //! Objective-C types.
    if (strcmp(type, @encode(id)) == 0) {
        return *(id __autoreleasing *)address;
    }
    if (strcmp(type, @encode(Class)) == 0) {
        return *(Class *)address;
    }
    if (strcmp(type, @encode(SEL)) == 0) {
        var wrapper = [JSONArchiverSelector new];
        wrapper.selector = *(SEL *)address;
        return wrapper;
    }
    
    //! Unknown type, pointers, bitfields.
    return nil;
}


//! System methods for encoding structs (CGPoint etc.) are implemented using other encoding methods.





#pragma mark - JSON Serialization


- (id)JSON {
    //! Any cached archive should be cleared after future encodes.
    if (self.cachedFinalizedArchive == nil) {
        self.cachedFinalizedArchive = [self finalizedArchive];
    }
    return self.cachedFinalizedArchive;
}


- (NSJSONWritingOptions)writingOptions {
    return (self.shouldPrettyPrint? NSJSONWritingPrettyPrinted : kNilOptions);
}


- (NSData *)JSONData {
    if (self.JSON == nil) return nil;
    
    return [NSJSONSerialization dataWithJSONObject:self.JSON options:self.writingOptions error:nil];
}


- (NSString *)JSONString {
    if (self.JSON == nil) return nil;
    
    return [[NSString alloc] initWithData:self.JSONData encoding:NSUTF8StringEncoding];
}


- (BOOL)writeJSONToURL:(NSURL *)URL {
    if (self.JSON == nil) return NO;
    
    var stream = [NSOutputStream outputStreamWithURL:URL append:NO];
    [stream open];
    let ok = [self writeJSONToStream:stream];
    [stream close];
    return ok;
}


- (BOOL)writeJSONToStream:(NSOutputStream *)stream {
    if (self.JSON == nil) return NO;
    
    let length = [NSJSONSerialization writeJSONObject:self.JSON toStream:stream options:self.writingOptions error:nil];
    return (length > 0);
}





#pragma mark - Unimplemented Decoding Methods


#define JSONArchiverIsNotUnarchiver \
    NSAssert(NO, @"This method is not implemented, since this is only encoder.")


- (BOOL)containsValueForKey:(__unused NSString *)key {
    JSONArchiverIsNotUnarchiver;
    return NO;
}


- (void)failWithError:(__unused NSError *)error {
    JSONArchiverIsNotUnarchiver;
}


- (NSDecodingFailurePolicy)decodingFailurePolicy {
    JSONArchiverIsNotUnarchiver;
    return NSDecodingFailurePolicySetErrorAndReturn;
}


- (BOOL)decodeBoolForKey:(__unused NSString *)key {
    JSONArchiverIsNotUnarchiver;
    return NO;
}


- (const uint8_t *)decodeBytesForKey:(__unused NSString *)key returnedLength:(__unused NSUInteger *)lengthRef {
    JSONArchiverIsNotUnarchiver;
    return NULL;
}


- (NSData *)decodeDataObject {
    JSONArchiverIsNotUnarchiver;
    return nil;
}


- (double)decodeDoubleForKey:(__unused NSString *)key {
    JSONArchiverIsNotUnarchiver;
    return NAN;
}


- (float)decodeFloatForKey:(__unused NSString *)key {
    JSONArchiverIsNotUnarchiver;
    return NAN;
}


- (int)decodeIntForKey:(__unused NSString *)key {
    JSONArchiverIsNotUnarchiver;
    return 0;
}


- (NSInteger)decodeIntegerForKey:(__unused NSString *)key {
    JSONArchiverIsNotUnarchiver;
    return 0;
}


- (int32_t)decodeInt32ForKey:(__unused NSString *)key {
    JSONArchiverIsNotUnarchiver;
    return 0;
}


- (int64_t)decodeInt64ForKey:(__unused NSString *)key {
    JSONArchiverIsNotUnarchiver;
    return 0;
}


- (NSObject<NSCoding> *)decodeObject {
    JSONArchiverIsNotUnarchiver;
    return nil;
}


- (NSObject<NSCoding> *)decodeObjectForKey:(__unused NSString *)key {
    JSONArchiverIsNotUnarchiver;
    return nil;
}


- (void)decodeValueOfObjCType:(__unused const char *)type at:(__unused void *)data {
    JSONArchiverIsNotUnarchiver;
}





@end




