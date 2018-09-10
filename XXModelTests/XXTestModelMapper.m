//
//  XXTestModelMapper.m
//  XXModel <https://github.com/ibireme/XXModel>
//
//  Created by ibireme on 15/11/27.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <XCTest/XCTest.h>
#import "XXModel.h"

@protocol XXTestPropertyMapperModelAuto
@end
@interface XXTestPropertyMapperModelAuto : NSObject
@property (nonatomic, assign) NSString *name;
@property (nonatomic, assign) NSNumber *count;

@property (nonatomic, copy) NSString *GodIsAGirl;

@end

@implementation XXTestPropertyMapperModelAuto
@end

@interface XXTestPropertyMapperModelCustom : NSObject
@property (nonatomic, assign) NSString *name;
@property (nonatomic, assign) NSNumber *count;
@property (nonatomic, assign) NSString *desc1;
@property (nonatomic, assign) NSString *desc2;
@property (nonatomic, assign) NSString *desc3;
@property (nonatomic, assign) NSString *desc4;
@property (nonatomic, assign) NSString *desc5;
@property (nonatomic, assign) NSString *modelID;
@end

@implementation XXTestPropertyMapperModelCustom
+ (NSDictionary *)modelCustomPropertyMapper {
    return @{ @"name" : @"n",
              @"count" : @"ext.c",
              @"desc1" : @"ext.d", // mapped to same key path
              @"desc2" : @"ext.d", // mapped to same key path
              @"desc3" : @"ext.d.e",
              @"desc4" : @".ext",
              @"desc5" : @[@"ext..a"],
              @"modelID" : @[@"ID", @"Id", @"id", @"ext.id"]};
}
@end

@interface XXTestPropertyMapperModelWarn : NSObject {
    NSString *_description;
}
@property (nonatomic, strong) NSString *description;
@property (nonatomic, strong) NSNumber *id;
@end

@implementation XXTestPropertyMapperModelWarn
@synthesize description = _description;
@end






@protocol XXTestPropertyMapperModelAuto <NSObject>
@end

@protocol XXTestPropertyMapperModelCustom <NSObject>
@end

@protocol XXSimpleProtocol <NSObject>
@end


@interface XXTestPropertyMapperModelContainer : NSObject
@property (nonatomic, strong) NSArray *array;
@property (nonatomic, strong) NSMutableArray *mArray;
@property (nonatomic, strong) NSDictionary *dict;
@property (nonatomic, strong) NSMutableDictionary *mDict;
@property (nonatomic, strong) NSSet *set;
@property (nonatomic, strong) NSMutableSet *mSet;

@property (nonatomic, strong) NSArray<XXTestPropertyMapperModelAuto> *pArray1;
@property (nonatomic, strong) NSArray<XXSimpleProtocol,XXTestPropertyMapperModelAuto> *pArray2;
@property (nonatomic, strong) NSArray<XXSimpleProtocol,XXTestPropertyMapperModelCustom> *pArray3;
@end

@implementation XXTestPropertyMapperModelContainer
@end

@interface XXTestPropertyMapperModelContainerGeneric : XXTestPropertyMapperModelContainer
@end

@implementation XXTestPropertyMapperModelContainerGeneric
+ (NSDictionary *)modelCustomPropertyMapper {
    return @{ @"mArray" : @"array",
              @"mDict" : @"dict",
              @"mSet" : @"set",
              @"pArray1" : @"array",
              @"pArray2" : @"array",
              @"pArray3" : @"array"};
}
+ (NSDictionary *)modelContainerPropertyGenericClass {
    return @{@"array" : XXTestPropertyMapperModelAuto.class,
             @"mArray" : XXTestPropertyMapperModelAuto.class,
             @"dict" : XXTestPropertyMapperModelAuto.class,
             @"mDict" : XXTestPropertyMapperModelAuto.class,
             @"set" : @"XXTestPropertyMapperModelAuto",
             @"mSet" : @"XXTestPropertyMapperModelAuto",
             @"pArray3" : @"XXTestPropertyMapperModelAuto"};
}
@end

@interface XXTestPseudoGenericPropertyMapperModelContainer : NSObject

@property (nonatomic, strong) NSArray<XXTestPropertyMapperModelAuto *><XXTestPropertyMapperModelAuto> *array;

@end

@implementation XXTestPseudoGenericPropertyMapperModelContainer
@end

@interface XXTestTransformProtocol : XXModelTransformProtocol

@end

@implementation XXTestTransformProtocol

+ (nullable NSDictionary<NSString *, id> *)modelCustomPropertyMapperForClass:(Class)cls {
    return @{
             @"GodIsAGirl":@"god-is-a-girl",
             };
}

@end

@interface XXTestModelPropertyMapper : XCTestCase

@end

@implementation XXTestModelPropertyMapper

- (void)testAuto {
    NSString *json;
    XXTestPropertyMapperModelAuto *model;
    
    json = @"{\"name\":\"Apple\",\"count\":12}";
    model = [XXTestPropertyMapperModelAuto xx_modelWithJSON:json];
    XCTAssertTrue([model.name isEqualToString:@"Apple"]);
    XCTAssertTrue([model.count isEqual:@12]);
    
    json = @"{\"n\":\"Apple\",\"count\":12, \"description\":\"hehe\"}";
    model = [XXTestPropertyMapperModelAuto xx_modelWithJSON:json];
    XCTAssertTrue(model.name == nil);
    XCTAssertTrue([model.count isEqual:@12]);
}

- (void)testCustom {
    NSString *json;
    NSDictionary *jsonObject;
    XXTestPropertyMapperModelCustom *model;
    
    json = @"{\"n\":\"Apple\",\"ext\":{\"c\":12}}";
    model = [XXTestPropertyMapperModelCustom xx_modelWithJSON:json];
    XCTAssertTrue([model.name isEqualToString:@"Apple"]);
    XCTAssertTrue([model.count isEqual:@12]);
    
    json = @"{\"n\":\"Apple\",\"count\":12}";
    model = [XXTestPropertyMapperModelCustom xx_modelWithJSON:json];
    XCTAssertTrue(model.count == nil);
    
    json = @"{\"n\":\"Apple\",\"ext\":12}";
    model = [XXTestPropertyMapperModelCustom xx_modelWithJSON:json];
    XCTAssertTrue(model.count == nil);
    
    json = @"{\"n\":\"Apple\",\"ext\":@{}}";
    model = [XXTestPropertyMapperModelCustom xx_modelWithJSON:json];
    XCTAssertTrue(model.count == nil);
    
    json = @"{\"ext\":{\"d\":\"Apple\"}}";
    model = [XXTestPropertyMapperModelCustom xx_modelWithJSON:json];
    XCTAssertTrue([model.desc1 isEqualToString:@"Apple"]);
    XCTAssertTrue([model.desc2 isEqualToString:@"Apple"]);
    
    jsonObject = [model xx_modelToJSONObject];
    XCTAssertTrue([((NSDictionary *)jsonObject[@"ext"])[@"d"] isEqualToString:@"Apple"]);
    
    json = @"{\"ext\":{\"d\":{ \"e\" : \"Apple\"}}}";
    model = [XXTestPropertyMapperModelCustom xx_modelWithJSON:json];
    XCTAssertTrue([model.desc3 isEqualToString:@"Apple"]);
    
    json = @"{\".ext\":\"Apple\"}";
    model = [XXTestPropertyMapperModelCustom xx_modelWithJSON:json];
    XCTAssertTrue([model.desc4 isEqualToString:@"Apple"]);
    
    json = @"{\".ext\":\"Apple\", \"name\":\"Apple\", \"count\":\"10\", \"desc1\":\"Apple\", \"desc2\":\"Apple\", \"desc3\":\"Apple\", \"desc4\":\"Apple\", \"modelID\":\"Apple\"}";
    model = [XXTestPropertyMapperModelCustom xx_modelWithJSON:json];
    XCTAssertTrue([model.desc4 isEqualToString:@"Apple"]);
    
    json = @"{\"ext..a\":\"AppleDesc5\", \"name\":\"Apple\", \"count\":\"10\", \"desc1\":\"Apple\", \"desc2\":\"Apple\", \"desc3\":\"Apple\", \"desc4\":\"Apple\", \"modelID\":\"Apple\"}";
    model = [XXTestPropertyMapperModelCustom xx_modelWithJSON:json];
    XCTAssertTrue([model.desc5 isEqualToString:@"AppleDesc5"]);

    json = @"{\"id\":\"abcd\"}";
    model = [XXTestPropertyMapperModelCustom xx_modelWithJSON:json];
    XCTAssertTrue([model.modelID isEqualToString:@"abcd"]);
    
    json = @"{\"ext\":{\"id\":\"abcd\"}}";
    model = [XXTestPropertyMapperModelCustom xx_modelWithJSON:json];
    XCTAssertTrue([model.modelID isEqualToString:@"abcd"]);
    
    json = @"{\"id\":\"abcd\",\"ID\":\"ABCD\",\"Id\":\"Abcd\"}";
    model = [XXTestPropertyMapperModelCustom xx_modelWithJSON:json];
    XCTAssertTrue([model.modelID isEqualToString:@"ABCD"]);
    
    jsonObject = [model xx_modelToJSONObject];
    XCTAssertTrue(jsonObject[@"id"] == nil);
    XCTAssertTrue([jsonObject[@"ID"] isEqualToString:@"ABCD"]);
}

- (void)testWarn {
    NSString *json = @"{\"description\":\"Apple\",\"id\":12345}";
    XXTestPropertyMapperModelWarn *model = [XXTestPropertyMapperModelWarn xx_modelWithJSON:json];
    XCTAssertTrue([model.description isEqualToString:@"Apple"]);
    XCTAssertTrue([model.id isEqual:@12345]);
}

- (void)testContainer {
    NSString *json;
    NSDictionary *jsonObject = nil;
    XXTestPropertyMapperModelContainer *model;
    
    json = @"{\"array\":[\n  {\"name\":\"Apple\", \"count\":10},\n  {\"name\":\"Banana\", \"count\":11},\n  {\"name\":\"Pear\", \"count\":12},\n  null\n]}";
    
    model = [XXTestPropertyMapperModelContainer xx_modelWithJSON:json];
    XCTAssertTrue([model.array isKindOfClass:[NSArray class]]);
    XCTAssertTrue(model.array.count == 3);
    
    jsonObject = [model xx_modelToJSONObject];
    XCTAssertTrue([jsonObject[@"array"] isKindOfClass:[NSArray class]]);
    
    model = [XXTestPropertyMapperModelContainerGeneric xx_modelWithJSON:json];
    XCTAssertTrue([model.array isKindOfClass:[NSArray class]]);
    XCTAssertTrue(model.array.count == 3);
    XCTAssertTrue([((XXTestPropertyMapperModelAuto *)model.array[0]).name isEqualToString:@"Apple"]);
    XCTAssertTrue([((XXTestPropertyMapperModelAuto *)model.array[0]).count isEqual:@10]);
    XCTAssertTrue([((XXTestPropertyMapperModelAuto *)model.array[2]).name isEqualToString:@"Pear"]);
    XCTAssertTrue([((XXTestPropertyMapperModelAuto *)model.array[2]).count isEqual:@12]);
    XCTAssertTrue([model.mArray isKindOfClass:[NSMutableArray class]]);
    
    XCTAssertTrue(model.pArray1.count == 3);
    XCTAssertTrue([((XXTestPropertyMapperModelAuto *)model.pArray1[0]).name isEqualToString:@"Apple"]);
    XCTAssertTrue([((XXTestPropertyMapperModelAuto *)model.pArray1[0]).count isEqual:@10]);
    XCTAssertTrue(model.pArray2.count == 3);
    XCTAssertTrue([((XXTestPropertyMapperModelAuto *)model.pArray2[0]).name isEqualToString:@"Apple"]);
    XCTAssertTrue([((XXTestPropertyMapperModelAuto *)model.pArray2[0]).count isEqual:@10]);
    XCTAssertTrue(model.pArray3.count == 3);
    XCTAssertTrue([((XXTestPropertyMapperModelAuto *)model.pArray3[0]).name isEqualToString:@"Apple"]);
    XCTAssertTrue([((XXTestPropertyMapperModelAuto *)model.pArray3[0]).count isEqual:@10]);
    
    
    jsonObject = [model xx_modelToJSONObject];
    XCTAssertTrue([jsonObject[@"array"] isKindOfClass:[NSArray class]]);
    
    json = @"{\"dict\":{\n  \"A\":{\"name\":\"Apple\", \"count\":10},\n  \"B\":{\"name\":\"Banana\", \"count\":11},\n  \"P\":{\"name\":\"Pear\", \"count\":12},\n  \"N\":null\n}}";
    
    model = [XXTestPropertyMapperModelContainer xx_modelWithJSON:json];
    XCTAssertTrue([model.dict isKindOfClass:[NSDictionary class]]);
    XCTAssertTrue(model.dict.count == 3);
    
    jsonObject = [model xx_modelToJSONObject];
    XCTAssertTrue(jsonObject != nil);
    
    model = [XXTestPropertyMapperModelContainerGeneric xx_modelWithJSON:json];
    XCTAssertTrue([model.dict isKindOfClass:[NSDictionary class]]);
    XCTAssertTrue(model.dict.count == 3);
    XCTAssertTrue([((XXTestPropertyMapperModelAuto *)model.dict[@"A"]).name isEqualToString:@"Apple"]);
    XCTAssertTrue([((XXTestPropertyMapperModelAuto *)model.dict[@"A"]).count isEqual:@10]);
    XCTAssertTrue([((XXTestPropertyMapperModelAuto *)model.dict[@"P"]).name isEqualToString:@"Pear"]);
    XCTAssertTrue([((XXTestPropertyMapperModelAuto *)model.dict[@"P"]).count isEqual:@12]);
    XCTAssertTrue([model.mDict isKindOfClass:[NSMutableDictionary class]]);
    
    jsonObject = [model xx_modelToJSONObject];
    XCTAssertTrue(jsonObject != nil);
    
    json = @"{\"set\":[\n  {\"name\":\"Apple\", \"count\":10},\n  {\"name\":\"Banana\", \"count\":11},\n  {\"name\":\"Pear\", \"count\":12},\n  null\n]}";
    
    model = [XXTestPropertyMapperModelContainer xx_modelWithJSON:json];
    XCTAssertTrue([model.set isKindOfClass:[NSSet class]]);
    XCTAssertTrue(model.set.count == 3);
    
    jsonObject = [model xx_modelToJSONObject];
    XCTAssertTrue(jsonObject != nil);
    
    model = [XXTestPropertyMapperModelContainerGeneric xx_modelWithJSON:json];
    XCTAssertTrue([model.set isKindOfClass:[NSSet class]]);
    XCTAssertTrue(model.set.count == 3);
    XCTAssertTrue([((XXTestPropertyMapperModelAuto *)model.set.anyObject).name isKindOfClass:[NSString class]]);
    XCTAssertTrue([model.mSet isKindOfClass:[NSMutableSet class]]);
    
    jsonObject = [model xx_modelToJSONObject];
    XCTAssertTrue(jsonObject != nil);
    
    model = [XXTestPropertyMapperModelContainerGeneric xx_modelWithJSON:@{@"set" : @[[XXTestPropertyMapperModelAuto new]]}];
    XCTAssertTrue([model.set isKindOfClass:[NSSet class]]);
    XCTAssertTrue([[model.set anyObject] isKindOfClass:[XXTestPropertyMapperModelAuto class]]);
    
    model = [XXTestPropertyMapperModelContainerGeneric xx_modelWithJSON:@{@"array" : [NSSet setWithArray:@[[XXTestPropertyMapperModelAuto new]]]}];
    XCTAssertTrue([model.array isKindOfClass:[NSArray class]]);
    XCTAssertTrue([[model.array firstObject] isKindOfClass:[XXTestPropertyMapperModelAuto class]]);
    
    model = [XXTestPropertyMapperModelContainer xx_modelWithJSON:@{@"mArray" : @[[XXTestPropertyMapperModelAuto new]]}];
    XCTAssertTrue([model.mArray isKindOfClass:[NSMutableArray class]]);
    XCTAssertTrue([[model.mArray firstObject] isKindOfClass:[XXTestPropertyMapperModelAuto class]]);
    
    model = [XXTestPropertyMapperModelContainer xx_modelWithJSON:@{@"mArray" : [NSSet setWithArray:@[[XXTestPropertyMapperModelAuto new]]]}];
    XCTAssertTrue([model.mArray isKindOfClass:[NSMutableArray class]]);
    XCTAssertTrue([[model.mArray firstObject] isKindOfClass:[XXTestPropertyMapperModelAuto class]]);
    
    NSString *json2 = @"{\"array\":[\n  {\"name\":\"Apple\", \"count\":10},\n  {\"name\":\"Banana\", \"count\":11},\n  {\"name\":\"Pear\", \"count\":12},\n  null\n]}";
    XXTestPseudoGenericPropertyMapperModelContainer *model2 = [XXTestPseudoGenericPropertyMapperModelContainer xx_modelWithJSON:json2];
    XCTAssertTrue(model2.array.count == 3);
    for (id object in model2.array) {
        XCTAssertTrue([object isMemberOfClass:[XXTestPropertyMapperModelAuto class]]);
    }
}

- (void)testTansformProtocol
{
    [XXModelTransformProtocol registerClass:[XXTestTransformProtocol class]];
    
    NSString *json = @"{\"god-is-a-girl\":\"Hello World\"}";
    XXTestPropertyMapperModelAuto *model = [XXTestPropertyMapperModelAuto xx_modelWithJSON:json];
    XCTAssertTrue([model.GodIsAGirl isEqualToString:@"Hello World"]);
    
    [XXModelTransformProtocol unregisterClass];
    
    model = [XXTestPropertyMapperModelAuto xx_modelWithJSON:json];
    XCTAssertTrue(![model.GodIsAGirl isEqualToString:@"Hello World"]);
}

@end
