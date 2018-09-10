//
//  XXTestCustomTransform.m
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

@interface XXTestCustomTransformModel : NSObject
@property uint64_t id;
@property NSString *content;
@property NSDate *time;
@end

@implementation XXTestCustomTransformModel


-(NSDictionary *)modelCustomWillTransformFromDictionary:(NSDictionary *)dic{
    if (dic) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:dic];
        if (dict[@"date"]) {
            dict[@"time"] = dict[@"date"];
        }
        return dict;
    }
    return dic;
}

- (BOOL)modelCustomTransformFromDictionary:(NSDictionary *)dic {
    NSNumber *time = dic[@"time"];
    if ([time isKindOfClass:[NSNumber class]] && time.unsignedLongLongValue != 0) {
        _time = [NSDate dateWithTimeIntervalSince1970:time.unsignedLongLongValue / 1000.0];
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)modelCustomTransformToDictionary:(NSMutableDictionary *)dic {
    if (_time) {
        dic[@"time"] = @((uint64_t)(_time.timeIntervalSince1970 * 1000));
        return YES;
    } else {
        return NO;
    }
}

@end



@interface XXTestCustomTransform : XCTestCase

@end

@implementation XXTestCustomTransform


- (void)test {
    NSString *json;
    XXTestCustomTransformModel *model;
    NSDictionary *jsonObject;
    
    json = @"{\"id\":5472746497,\"content\":\"Hello\",\"time\":1401234567000}";
    model = [XXTestCustomTransformModel xx_modelWithJSON:json];
    XCTAssert(model.time != nil);
    
    json = @"{\"id\":5472746497,\"content\":\"Hello\"}";
    model = [XXTestCustomTransformModel xx_modelWithJSON:json];
    XCTAssert(model == nil);
    
    model = [XXTestCustomTransformModel xx_modelWithDictionary:@{@"id":@5472746497,@"content":@"Hello"}];
    XCTAssert(model == nil);
    
    json = @"{\"id\":5472746497,\"content\":\"Hello\",\"time\":1401234567000}";
    model = [XXTestCustomTransformModel xx_modelWithJSON:json];
    jsonObject = [model xx_modelToJSONObject];
    XCTAssert([jsonObject[@"time"] isKindOfClass:[NSNumber class]]);
    
    model.time = nil;
    jsonObject = [model xx_modelToJSONObject];
    XCTAssert(jsonObject == nil);
    
    json = @"{\"id\":5472746497,\"content\":\"Hello\",\"date\":1401234567000}";
    model = [XXTestCustomTransformModel xx_modelWithJSON:json];
    XCTAssert(model.time != nil);
    
}

@end
