//
//  XXTestDefaultValue.m
//  XXModel
//
//  Created by molon on 16/6/14.
//  Copyright © 2016年 ibireme. All rights reserved.
//
#import <XCTest/XCTest.h>
#import "XXModel.h"

@interface XXTestObject : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger age;
@property (nonatomic, assign) Class cls;
@property (nonatomic, assign) SEL sel;
@property (nonatomic, copy) void(^testBlock)(NSString *str);

@end

@implementation XXTestObject

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self xx_resetAllPropertyValues];
    }
    return self;
}

- (void)test
{
    NSLog(@"test called");
}

+ (nullable NSDictionary<NSString *,id> *)modelCustomPropertyDefaultValueMapper
{
    void (^loveBlock)(NSString*) = ^(NSString *str){
        NSLog(@"%@",str);
    };
    
    return @{
             @"name":@"God",
             @"age":@(-1),
             @"testBlock":loveBlock,
             @"cls":XXTestObject.class,
             @"sel":NSStringFromSelector(@selector(test)),
             };
}

@end

@interface XXTestDefaultValue : XCTestCase

@end

@implementation XXTestDefaultValue

- (void)testReadobly
{
    NSString *json1 = @"{\"name\":\"molon\"}";
    NSString *json2 = @"{\"name\":null}";
    
    XXTestObject *o = [XXTestObject xx_modelWithJSON:json1];
    XCTAssert([o.name isEqualToString:@"molon"]);
    
    [o xx_modelSetWithJSON:json2];
    XCTAssert([o.name isEqualToString:@"God"]);
    
    [o xx_modelSetWithJSON:json1];
    XCTAssert([o.name isEqualToString:@"molon"]);
    
    [o xx_resetAllPropertyValues];
    XCTAssert([o.name isEqualToString:@"God"]);
    
    [o xx_modelSetWithJSON:json1];
    XCTAssert([o.name isEqualToString:@"molon"]);
    
    [o xx_resetPropertyValueForKey:@"name"];
    XCTAssert([o.name isEqualToString:@"God"]);
}

@end
