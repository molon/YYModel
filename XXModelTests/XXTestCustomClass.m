//
//  XXTestCustomClass.m
//  XXModel <https://github.com/ibireme/XXModel>
//
//  Created by ibireme on 15/11/29.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <XCTest/XCTest.h>
#import "XXModel.h"

@interface XXBaseUser : NSObject
@property uint64_t uid;
@property NSString *name;
@end


@interface XXLocalUser : XXBaseUser
@property NSString *localName;
@end
@implementation XXLocalUser
@end

@interface XXRemoteUser : XXBaseUser
@property NSString *remoteName;
@end
@implementation XXRemoteUser
@end


@implementation XXBaseUser
+ (Class)modelCustomClassForDictionary:(NSDictionary*)dictionary {
    if (dictionary[@"localName"]) {
        return [XXLocalUser class];
    } else if (dictionary[@"remoteName"]) {
        return [XXRemoteUser class];
    }
    return [XXBaseUser class];
}
@end

@interface XXTestCustomClassModel : NSObject
@property (nonatomic, strong) NSArray *users;
@property (nonatomic, strong) NSDictionary *userDict;
@property (nonatomic, strong) NSSet *userSet;
@property (nonatomic, strong) XXBaseUser *user;
@end

@implementation XXTestCustomClassModel

+ (NSDictionary *)modelContainerPropertyGenericClass {
    return @{@"users" : XXBaseUser.class,
             @"userDict" : XXBaseUser.class,
             @"userSet" : XXBaseUser.class};
}
+ (Class)modelCustomClassForDictionary:(NSDictionary*)dictionary {
    if (dictionary[@"localName"]) {
        return [XXLocalUser class];
    } else if (dictionary[@"remoteName"]) {
        return [XXRemoteUser class];
    }
    return nil;
}
@end


@interface XXTestCustomClass : XCTestCase

@end

@implementation XXTestCustomClass

- (void)test {
    XXTestCustomClassModel *model;
    XXBaseUser *user;
    
    NSDictionary *jsonUserBase = @{@"uid" : @123, @"name" : @"Harry"};
    NSDictionary *jsonUserLocal = @{@"uid" : @123, @"name" : @"Harry", @"localName" : @"HarryLocal"};
    NSDictionary *jsonUserRemote = @{@"uid" : @123, @"name" : @"Harry", @"remoteName" : @"HarryRemote"};
    
    user = [XXBaseUser xx_modelWithDictionary:jsonUserBase];
    XCTAssert([user isMemberOfClass:[XXBaseUser class]]);
    
    user = [XXBaseUser xx_modelWithDictionary:jsonUserLocal];
    XCTAssert([user isMemberOfClass:[XXLocalUser class]]);
    
    user = [XXBaseUser xx_modelWithDictionary:jsonUserRemote];
    XCTAssert([user isMemberOfClass:[XXRemoteUser class]]);
    
    
    model = [XXTestCustomClassModel xx_modelWithJSON:@{@"user" : jsonUserLocal}];
    XCTAssert([model.user isMemberOfClass:[XXLocalUser class]]);
    
    model = [XXTestCustomClassModel xx_modelWithJSON:@{@"users" : @[jsonUserBase, jsonUserLocal, jsonUserRemote]}];
    XCTAssert([model.users[0] isMemberOfClass:[XXBaseUser class]]);
    XCTAssert([model.users[1] isMemberOfClass:[XXLocalUser class]]);
    XCTAssert([model.users[2] isMemberOfClass:[XXRemoteUser class]]);
    
    model = [XXTestCustomClassModel xx_modelWithJSON:@{@"userDict" : @{@"a" : jsonUserBase, @"b" : jsonUserLocal, @"c" : jsonUserRemote}}];
    XCTAssert([model.userDict[@"a"] isKindOfClass:[XXBaseUser class]]);
    XCTAssert([model.userDict[@"b"] isKindOfClass:[XXLocalUser class]]);
    XCTAssert([model.userDict[@"c"] isKindOfClass:[XXRemoteUser class]]);
    
    model = [XXTestCustomClassModel xx_modelWithJSON:@{@"userSet" : @[jsonUserBase, jsonUserLocal, jsonUserRemote]}];
    XCTAssert([model.userSet.anyObject isKindOfClass:[XXBaseUser class]]);
}

@end
