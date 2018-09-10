//
//  XXTestHelper.h
//  XXModel <https://github.com/ibireme/XXModel>
//
//  Created by ibireme on 15/11/28.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

@interface XXTestHelper : NSObject
+ (NSString *)jsonStringFromData:(NSData *)data;
+ (NSString *)jsonStringFromObject:(id)object;
+ (id)jsonObjectFromData:(NSData *)data;
+ (id)jsonObjectFromString:(NSString *)string;
+ (NSData *)jsonDataFromString:(NSString *)string;
+ (NSData *)jsonDataFromObject:(id)object;
@end
