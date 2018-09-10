//
//  XXTestBlacklistWhitelist.m
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


@interface XXTestBlacklistModel : NSObject
@property (nonatomic, strong) NSString *a;
@property (nonatomic, strong) NSString *b;
@property (nonatomic, strong) NSString *c;
@end

@implementation XXTestBlacklistModel
+ (NSArray *)modelPropertyBlacklist {
    return @[@"a", @"d"];
}
@end

@interface XXTestWhitelistModel : NSObject
@property (nonatomic, strong) NSString *a;
@property (nonatomic, strong) NSString *b;
@property (nonatomic, strong) NSString *c;
@end

@implementation XXTestWhitelistModel
+ (NSArray *)modelPropertyWhitelist {
    return @[@"a", @"d"];
}
@end


@interface XXTestBlackWhitelistModel : NSObject
@property (nonatomic, strong) NSString *a;
@property (nonatomic, strong) NSString *b;
@property (nonatomic, strong) NSString *c;
@end

@implementation XXTestBlackWhitelistModel
+ (NSArray *)modelPropertyBlacklist {
    return @[@"a", @"d"];
}
+ (NSArray *)modelPropertyWhitelist {
    return @[@"a", @"b", @"d"];
}
@end




@interface XXTestBlacklistWhitelist : XCTestCase

@end

@implementation XXTestBlacklistWhitelist

- (void)testBlacklist {
    NSString *json = @"{\"a\":\"A\", \"b\":\"B\", \"c\":\"C\", \"d\":\"D\"}";
    XXTestBlacklistModel *model = [XXTestBlacklistModel xx_modelWithJSON:json];
    XCTAssert(model.a == nil);
    XCTAssert(model.b != nil);
    XCTAssert(model.c != nil);
    
    NSDictionary *dic = [model xx_modelToJSONObject];
    XCTAssert(dic[@"a"] == nil);
    XCTAssert(dic[@"b"] != nil);
    XCTAssert(dic[@"c"] != nil);
}

- (void)testWhitelist {
    NSString *json = @"{\"a\":\"A\", \"b\":\"B\", \"c\":\"C\", \"d\":\"D\"}";
    XXTestWhitelistModel *model = [XXTestWhitelistModel xx_modelWithJSON:json];
    XCTAssert(model.a != nil);
    XCTAssert(model.b == nil);
    XCTAssert(model.c == nil);
    
    NSDictionary *dic = [model xx_modelToJSONObject];
    XCTAssert(dic[@"a"] != nil);
    XCTAssert(dic[@"b"] == nil);
    XCTAssert(dic[@"c"] == nil);
}


- (void)testBlackWhitelist {
    NSString *json = @"{\"a\":\"A\", \"b\":\"B\", \"c\":\"C\", \"d\":\"D\"}";
    XXTestBlackWhitelistModel *model = [XXTestBlackWhitelistModel xx_modelWithJSON:json];
    XCTAssert(model.a == nil);
    XCTAssert(model.b != nil);
    XCTAssert(model.c == nil);
    
    NSDictionary *dic = [model xx_modelToJSONObject];
    XCTAssert(dic[@"a"] == nil);
    XCTAssert(dic[@"b"] != nil);
    XCTAssert(dic[@"c"] == nil);
}

@end
