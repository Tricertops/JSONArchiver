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


int main(__unused int argc, __unused const char * argv[]) {
    @autoreleasepool {
        
        var archiver = [JSONArchiver new];
        archiver.shouldPrettyPrint = YES;
        
        NSLog(@"@YES: %i", (id)@YES == (id)kCFBooleanTrue);
        NSLog(@"@(YES): %i", (id)@(YES) == (id)kCFBooleanTrue);
        NSLog(@"@1: %i", (id)@1 == (id)kCFBooleanTrue);
        NSLog(@"@(1): %i", (id)@((BOOL)1) == (id)kCFBooleanTrue);
        NSLog(@"bool: %i", (id)[NSNumber numberWithBool:1] == (id)kCFBooleanTrue);
        NSLog(@"@(1): %i", (id)[NSNumber numberWithInt:YES] == (id)kCFBooleanTrue);
        
        NSLog(@"JSON:\n%@", archiver.archivedString);
    }
    return 0;
}


