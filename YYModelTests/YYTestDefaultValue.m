//
//  YYTestDefaultValue.m
//  YYModel
//
//  Created by molon on 16/6/14.
//  Copyright © 2016年 ibireme. All rights reserved.
//
#import <XCTest/XCTest.h>
#import "YYModel.h"

@interface YYTestObject : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger age;
@property (nonatomic, assign) Class cls;
@property (nonatomic, assign) SEL sel;
@property (nonatomic, copy) void(^testBlock)(NSString *str);

@end

@implementation YYTestObject

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self yy_resetAllPropertyValues];
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
             @"cls":YYTestObject.class,
             @"sel":NSStringFromSelector(@selector(test)),
             };
}

@end

@interface YYTestDefaultValue : XCTestCase

@end

@implementation YYTestDefaultValue

- (void)testReadobly
{
    NSString *json1 = @"{\"name\":\"molon\"}";
    NSString *json2 = @"{\"name\":null}";
    
    YYTestObject *o = [YYTestObject yy_modelWithJSON:json1];
    XCTAssert([o.name isEqualToString:@"molon"]);
    
    [o yy_modelSetWithJSON:json2];
    XCTAssert([o.name isEqualToString:@"God"]);
    
    [o yy_modelSetWithJSON:json1];
    XCTAssert([o.name isEqualToString:@"molon"]);
    
    [o yy_resetAllPropertyValues];
    XCTAssert([o.name isEqualToString:@"God"]);
    
    [o yy_modelSetWithJSON:json1];
    XCTAssert([o.name isEqualToString:@"molon"]);
    
    [o yy_resetPropertyValueForKey:@"name"];
    XCTAssert([o.name isEqualToString:@"God"]);
}

@end
