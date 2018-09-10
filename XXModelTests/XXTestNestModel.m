//
//  XXTestNestModel.m
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


@interface XXTestNestUser : NSObject
@property uint64_t uid;
@property NSString *name;
@end
@implementation XXTestNestUser
@end

@interface XXTestNestRepo : NSObject
@property uint64_t repoID;
@property NSString *name;
@property XXTestNestUser *user;
@end
@implementation XXTestNestRepo
@end



@interface XXTestNestModel : XCTestCase

@end

@implementation XXTestNestModel

- (void)test {
    NSString *json = @"{\"repoID\":1234,\"name\":\"XXModel\",\"user\":{\"uid\":5678,\"name\":\"ibireme\"}}";
    XXTestNestRepo *repo = [XXTestNestRepo xx_modelWithJSON:json];
    XCTAssert(repo.repoID == 1234);
    XCTAssert([repo.name isEqualToString:@"XXModel"]);
    XCTAssert(repo.user.uid == 5678);
    XCTAssert([repo.user.name isEqualToString:@"ibireme"]);
    
    NSDictionary *jsonObject = [repo xx_modelToJSONObject];
    XCTAssert([((NSString *)jsonObject[@"name"]) isEqualToString:@"XXModel"]);
    XCTAssert([((NSString *)((NSDictionary *)jsonObject[@"user"])[@"name"]) isEqualToString:@"ibireme"]);
    
    [repo xx_modelSetWithJSON:@{@"name" : @"XXImage", @"user" : @{@"name": @"bot"}}];
    XCTAssert(repo.repoID == 1234);
    XCTAssert([repo.name isEqualToString:@"XXImage"]);
    XCTAssert(repo.user.uid == 5678);
    XCTAssert([repo.user.name isEqualToString:@"bot"]);
}

@end
