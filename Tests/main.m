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


@interface Person : NSObject <NSCoding>

@property NSString *name;
@property NSInteger age;
@property Person *partner;
@property NSArray<Person *> *children;

@end


@implementation Person

- (instancetype)initWithCoder:(__unused NSCoder *)decoder {
    return [self init];
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.name forKey:@"name"];
    [encoder encodeInteger:self.age forKey:@"age"];
    [encoder encodeObject:self.partner forKey:@"partner"];
    [encoder encodeObject:self.children forKey:@"children"];
}

@end


int main(__unused int argc, __unused const char * argv[]) {
    @autoreleasepool {
        
        var mom = [Person new];
        mom.name = @"Mom";
        mom.age = 45;
        
        var dad = [Person new];
        dad.name = @"Dad";
        dad.age = 48;
        
        var alex = [Person new];
        alex.name = @"Alex";
        alex.age = 8;
        
        var chris = [Person new];
        chris.name = @"Chris";
        chris.age = 4;
        
        mom.partner = dad;
        dad.partner = mom;
        mom.children = @[alex, chris];
        dad.children = mom.children;
        
        
        var archiver = [JSONArchiver new];
        archiver.shouldPrettyPrint = YES; // Default is NO.
        //archiver.shouldCompactRoot = NO; // Default is YES.
        //archiver.shouldIncludeDebuggingInfo = YES; // Default is NO.
        //archiver.shouldOmitNulls = YES; // Default is NO.
        
        [archiver encodeRootObject:@[mom,dad]];
        
        NSLog(@"JSON:\n%@", archiver.JSONString);
    }
    return 0;
}












