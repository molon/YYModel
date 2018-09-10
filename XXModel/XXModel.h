//
//  XXModel.h
//  XXModel <https://github.com/ibireme/XXModel>
//
//  Created by ibireme on 15/5/10.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

#if __has_include(<XXModel/XXModel.h>)
FOUNDATION_EXPORT double XXModelVersionNumber;
FOUNDATION_EXPORT const unsigned char XXModelVersionString[];
#import <XXModel/NSObject+XXModel.h>
#import <XXModel/XXClassInfo.h>
#else
#import "NSObject+XXModel.h"
#import "XXClassInfo.h"
#endif
