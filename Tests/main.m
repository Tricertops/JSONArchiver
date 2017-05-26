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
        
        let title = @"Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";
        
        var testA = [TestObject new];
        var testB = [TestObject new];
        testA.title = [title mutableCopy];
        testB.title = [title mutableCopy];
        testA.next = testB;
        testB.next = testA;
        
        var archiver = [JSONArchiver new];
        archiver.shouldPrettyPrint = YES;
        //archiver.shouldCompactRoot = YES;;
        //archiver.shouldIncludeDebuggingInfo = YES;
        //archiver.shouldOmitNulls = YES;
        
        [archiver encodeRootObject:testA];
        
        NSLog(@"JSON:\n%@", archiver.JSONString);
    }
    return 0;
}












