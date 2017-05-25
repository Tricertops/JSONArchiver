//
//  JSONKeyedArchiver.m
//  JSONArchiver
//
//  Created by Martin Kiss on 25 May 2017.
//  Copyright © 2017 Tricertops. All rights reserved.
//

#import "JSONArchiver.h"



#define var  __auto_type
#define let  __auto_type const





@interface JSONArchiver ()


//TODO: Nested state.
@property NSUInteger nextIndex;
@property NSMutableDictionary<NSString *, id> *currectDictionary;


@end





@implementation JSONArchiver





#pragma mark - Convenience


+ (NSData *)archivedDataWithRootObject:(NSObject<NSCoding> *)object pretty:(BOOL)isPretty {
    var archiver = [JSONArchiver new];
    archiver.shouldPrettyPrint = isPretty;
    [archiver encodeRootObject:object];
    return archiver.archivedData;
}


+ (BOOL)archiveRootObject:(NSObject<NSCoding> *)object toURL:(NSURL *)URL pretty:(BOOL)isPretty {
    var archiver = [JSONArchiver new];
    archiver.shouldPrettyPrint = isPretty;
    [archiver encodeRootObject:object];
    return [archiver writeArchiveToURL:URL];
}





#pragma mark - Basics


- (instancetype)init {
    self = [super init];
    NSAssert(self != nil, @"Failed to initialize %@ instance", JSONArchiver.class);
    
    self->_archive = @[];
    
    return self;
}


- (BOOL)allowsKeyedCoding {
    return YES;
}





#pragma mark - Encoding


- (void)encodeObject:(NSObject<NSCoding> *)object forKey:(NSString *)key {
    //! All public keyed encoding methods invoke this method, except conditional encoding.
    NSAssert(key.length > 0, @"Key is empty");
    NSAssert( ! [key hasPrefix:@"#"], @"Key must not begin with '#' symbol: %@", key);
    
    [self internalEncodeObject:object forKey:key conditional:NO];
}


- (void)encodeObject:(NSObject<NSCoding> *)object {
    //! All public indexed encoding methods invoke this method, except conditional encoding.
    [self internalEncodeObject:object forKey:nil conditional:NO];
}


- (void)encodeConditionalObject:(NSObject<NSCoding> *)object forKey:(NSString *)key {
    NSAssert(key.length > 0, @"Key is empty");
    NSAssert( ! [key hasPrefix:@"#"], @"Key must not begin with '#' symbol: %@", key);
    
    [self internalEncodeObject:object forKey:key conditional:YES];
}


- (void)encodeConditionalObject:(NSObject<NSCoding> *)object {
    [self internalEncodeObject:object forKey:nil conditional:YES];
}


- (void)internalEncodeObject:(NSObject<NSCoding> *)object forKey:(NSString *)key conditional:(BOOL)isConditional {
    BOOL isKeyed = (key.length > 0);
    if ( ! isKeyed) {
        key = [NSString stringWithFormat:@"#%tu", self.nextIndex];
        self.nextIndex ++;
    }
    NSAssert(self.currectDictionary[key] == nil, @"Existing duplicate key: %@", key);
    
    //! Nil values are encoded as JSON null.
    if (object == nil) {
        self.currectDictionary[key] = NSNull.null;
    }
    //! NSNull is encoded as special object.
    else if (object == NSNull.null) {
        self.currectDictionary[key] = [self specialObjectWithContent:@"NSNull"];
    }
    //! Numbers are direct.
    else if ([object isKindOfClass:NSNumber.class]) {
        
        //! NSNumber created using boolean literals or +numberWithBool: method.
        if (object == (id)kCFBooleanFalse || object == (id)kCFBooleanTrue) {
            self.currectDictionary[key] = object;
        }
        //! NaNs are not supported in JSON, so we use special placeholder.
        else if (object == (id)kCFNumberNaN) {
            self.currectDictionary[key] = [self specialObjectWithContent:@"NaN"];
        }
        //! Infinite values are not supported in JSON, so we use special placeholder.
        else if (object == (id)kCFNumberPositiveInfinity) {
            self.currectDictionary[key] = [self specialObjectWithContent:@"+Inf"];
        }
        //! Infinite values are not supported in JSON, so we use special placeholder.
        else if (object == (id)kCFNumberNegativeInfinity) {
            self.currectDictionary[key] = [self specialObjectWithContent:@"-Inf"];
        }
        //! This NSNumber should be valid for JSON.
        else {
            self.currectDictionary[key] = object;
        }
    }
    //! Strings are direct, but only plain immutable strings up to certain length.
    else if (object.classForKeyedArchiver == NSString.class && ((NSString *)object).length <= 1024) {
        self.currectDictionary[key] = object;
    }
    //! Arrays are direct, but only immutable ones up to certain size.
    else if (object.classForKeyedArchiver == NSArray.class && ((NSArray *)object).count <= 32) {
        self.currectDictionary[key] = object;
    }
    else {
        //TODO: Find how NSKeyedArchiver treats -isEqual: objects.
        
        //TODO: Store all top-level objects in NSMutableOrderedSet.
        //TODO: Find existing top-level object and use its reference.
        //TODO: Create special object for references that encodes as { "#ref": 4 }
        //TODO: Push state and invoke -encodeWithCoder: on the object.
        
        if (isConditional) {
            //TODO: Handle conditional objects.
            //TODO: Store conditional objects in the top-level list, but remember if they have any strong ref.
            //TODO: During finalization (we will need finalization?), replace them with null values.
            //TODO: Avoid finalization by producing finalized `archive` on demand and cache it until next root object.
        }
        
        BOOL isRoot = YES;
        
        if (isRoot) {
            //TODO: If the first root is keyed, create special #root dictionary at index 0 and the root at index 1.
            //TODO: In case of second root, add it to following index and add reference to #root dictionary.
            
            //TODO: If the first root is indexed, encode it at index 0.
            //TODO: In case of second root, add it to following index and add reference to #root dictionary.
        }
    }
}


- (NSDictionary<NSString *, NSString *> *)specialObjectWithContent:(NSString *)content {
    return @{ @"#special": content ?: @"" };
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
    let data = [NSData dataWithBytes:bytes length:length];
    [self encodeObject:data forKey:key];
}


// System methods for encoding structs are implemented using other encoding methods.





#pragma mark - Indexed Encoding Methods


- (void)encodeRootObject:(NSObject<NSCoding> *)object {
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
    let object = [self objectFromObjCType:type address:address];
    [self encodeObject:object];
}


- (NSValue *)objectFromObjCType:(const char *)type address:(const void *)address {
#define check_and_return(TYPE)   if (strcmp(type, @encode(TYPE)) == 0) return (address ? @(*(TYPE*)address) : @0)
    
    check_and_return(char);
    check_and_return(short);
    check_and_return(int);
    check_and_return(long);
    check_and_return(long long);
    
    check_and_return(unsigned char);
    check_and_return(unsigned short);
    check_and_return(unsigned int);
    check_and_return(unsigned long);
    check_and_return(unsigned long long);
    
    check_and_return(float);
    check_and_return(double);
    
    check_and_return(bool);
    
#undef check_and_return
    
    //TODO: Handle other C types.
    
    return [NSValue valueWithBytes:address objCType:type];
}


// System methods for encoding structs are implemented using other encoding methods.





#pragma mark - JSON Serialization


- (NSJSONWritingOptions)writingOptions {
    return (self.shouldPrettyPrint? NSJSONWritingPrettyPrinted : kNilOptions);
}


- (NSData *)archivedData {
    if (self.archive == nil) return nil;
    
    return [NSJSONSerialization dataWithJSONObject:self.archive options:self.writingOptions error:nil];
}


- (NSString *)archivedString {
    if (self.archive == nil) return nil;
    
    return [[NSString alloc] initWithData:self.archivedData encoding:NSUTF8StringEncoding];
}


- (BOOL)writeArchiveToURL:(NSURL *)URL {
    if (self.archive == nil) return NO;
    
    var stream = [NSOutputStream outputStreamWithURL:URL append:NO];
    [stream open];
    let ok = [self writeArchiveToStream:stream];
    [stream close];
    return ok;
}


- (BOOL)writeArchiveToStream:(NSOutputStream *)stream {
    if (self.archive == nil) return NO;
    
    let length = [NSJSONSerialization writeJSONObject:self.archive toStream:stream options:self.writingOptions error:nil];
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




