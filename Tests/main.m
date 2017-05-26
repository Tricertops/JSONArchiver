//
//  main.m
//  JSONArchiver
//
//  Created by Martin Kiss on 25 May 2017.
//  Copyright © 2017 Tricertops. All rights reserved.
//

@import Foundation;
@import JSONArchiver;


#define var  __auto_type
#define let  __auto_type const


@interface TestObject : NSObject <NSCoding>

@property NSString *title;
@property TestObject *next;

@end


@implementation TestObject

- (instancetype)initWithCoder:(NSCoder *)decoder {
    return [self init];
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.title forKey:@"title"];
    [encoder encodeObject:self.next forKey:@"next"];
}

@end


int main(__unused int argc, __unused const char * argv[]) {
    @autoreleasepool {
        
        var testA = [TestObject new];
        testA.title = @"A";
        
        var testB = [TestObject new];
        testB.title = @"B";
        
        var testC = [TestObject new];
        testC.title = @"C";
        
        testA.next = testB;
        testB.next = testC;
        
        var archiver = [JSONArchiver new];
        archiver.shouldPrettyPrint = YES;
        archiver.shouldIncludeDebuggingInfo = YES;
        
        [archiver encodeObject:testA];
        
        NSLog(@"JSON:\n%@", archiver.JSONString);
    }
    return 0;
}












