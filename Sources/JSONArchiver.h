//
//  JSONArchiver.h
//  JSONArchiver
//
//  Created by Martin Kiss on 25 May 2017.
//  Copyright © 2017 Tricertops. All rights reserved.
//

@import Foundation;



FOUNDATION_EXPORT double JSONArchiverVersionNumber;
FOUNDATION_EXPORT const unsigned char JSONArchiverVersionString[];



//! NSCoder that writes arbitrary object graph into archive in JSON format. Preserves classes and cyclic references.
//! This archiver is intended as drop-in replacement for NSKeyedArchiver, so it supports all non-legacy features of archivation.
@interface JSONArchiver : NSCoder

//! Value is YES, this class supports both indexed and keyed encoding. Keyed coding is recommended except in case of single root.
@property (readonly) BOOL allowsKeyedCoding;

//! Convenience method to create JSON archive data from given root object, optionally pretty-printed.
+ (NSData *)archivedDataWithRootObject:(id<NSCoding>)rootObject pretty:(BOOL)prettyPrinted;
//! Convenience method to write JSON archive data of given root object to provided URL, optionally pretty-printed.
+ (BOOL)archiveRootObject:(id<NSCoding>)rootObject toURL:(NSURL *)fileURL pretty:(BOOL)prettyPrinted;

//! Default value is NO. Set this property to YES to produce JSON with newlines and space indentation. Also affects base64 wrapping.
@property BOOL shouldPrettyPrint;
//! Defaults value is YES, so the archiver will compact root elements of JSON for nicer output in some cases.
@property BOOL shouldCompactRoot;
//! Defaults value is NO. If set to YES, extra keys will be added to root objects for easier human inspection.
@property BOOL shouldIncludeDebuggingInfo;
//! Defaults value is NO, so encoding nil object produces JSON null. If set to YES, unnecesary keys are not produced. This doesn’t affect NSNull.
@property BOOL shouldOmitNulls;

//! Contains valid JSON object after encoding any number of root objects.
@property (readonly) id JSON;
//! JSON data in UTF-8 encoding created from JSON property, optionally pretty-printed.
@property (readonly) NSData *JSONData;
//! JSON string in UTF-8 encoding created from JSON property, optionally pretty-printed.
@property (readonly) NSString *JSONString;
//! Writes JSON data in UTF-8 encoding created from JSON property into file at given URL. Return success.
- (BOOL)writeJSONToURL:(NSURL *)fileURL;
//! Writes JSON data in UTF-8 encoding created from JSON property into given opened stream. Return success.
- (BOOL)writeJSONToStream:(NSOutputStream *)openedStream;

//! This archiver supports all methods that begin with “encode”, but the following are recommended.

//! The main encoding method for everything. All other “encode” method invoke this one.
//! – NSNumbers created from BOOL produce JSON true/false values.
//! – NSNumbers with value of NaN or infinity are handled in JSON-compatible manner.
//! – Other NSNumbers are encoded as standard JSON number values.
//! – Passing nil object produces JSON null value.
//! – Encoding NSNull produces special nested JSON value, not null.
//! – Short immutable NSStrings and NSArrays are nested directly without cross-referenced.
//! – NSArray, NSSet, NSDictionary and similar Foundation collections have improved encoded structure that uses JSON array.
//! – NSData, NSURL, NSDate and similar small objects are encoded more effectively.
//! – Other objects are encoded using NSCoding method into JSON object values.
- (void)encodeObject:(id<NSCoding>)object forKey:(NSString *)key;

//! Recommended way to encode single root object. Multiple root objects should be encoded using -encodeObject:forKey: method.
- (void)encodeRootObject:(id<NSCoding>)rootObject;
//! Encodes object only if it’s also encoded unconditionally by another object in the object graph. Cannot be used to encode root.
- (void)encodeConditionalObject:(id<NSCoding>)object forKey:(NSString *)key;
//! Convenience method that wraps given value in NSNumber and invokes -encodeObject:forKey: method.
- (void)encodeBool:(BOOL)boolean forKey:(NSString *)key;
//! Convenience method that wraps given value in NSNumber and invokes -encodeObject:forKey: method.
- (void)encodeInteger:(NSInteger)integer forKey:(NSString *)key;
//! Convenience method that wraps given value in NSNumber and invokes -encodeObject:forKey: method.
- (void)encodeDouble:(double)number forKey:(NSString *)key;

//! Methods that begin with “decode” are not supported. Also, -containsValueForKey:, .decodingFailurePolicy and -failWithError: are not supported.


@end


