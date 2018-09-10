//
//  XXTestClassInfo.m
//  XXModel <https://github.com/ibireme/XXModel>
//
//  Created by ibireme on 15/11/27.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <XCTest/XCTest.h>
#import <CoreFoundation/CoreFoundation.h>
#import "XXModel.h"

typedef union xx_union{ char a; int b;} xx_union;

@interface XXTestPropertyModel : NSObject
@property bool boolValue;
@property BOOL BOOLValue;
@property char charValue;
@property unsigned char unsignedCharValue;
@property short shortValue;
@property unsigned short unsignedShortValue;
@property int intValue;
@property unsigned int unsignedIntValue;
@property long longValue;
@property unsigned long unsignedLongValue;
@property long long longLongValue;
@property unsigned long long unsignedLongLongValue;
@property float floatValue;
@property double doubleValue;
@property long double longDoubleValue;
@property (strong) NSObject *objectValue;
@property (strong) NSArray *arrayValue;
@property (strong) Class classValue;
@property SEL selectorValue;
@property (copy) void (^blockValue)();
@property void *pointerValue;
@property CFArrayEqualCallBack functionPointerValue;
@property CGRect structValue;
@property xx_union unionValue;
@property char *cStringValue;

@property (nonatomic) NSObject *nonatomicValue;
@property (copy) NSObject *aCopyValue;
@property (assign) NSObject *assignValue;
@property (strong) NSObject *strongValue;
@property (retain) NSObject *retainValue;
@property (weak) NSObject *weakValue;
@property (readonly) NSObject *readonlyValue;
@property (nonatomic) NSObject *dynamicValue;
@property (unsafe_unretained) NSObject *unsafeValue;
@property (nonatomic, getter=getValue) NSObject *getterValue;
@property (nonatomic, setter=setValue:) NSObject *setterValue;
@end

@implementation XXTestPropertyModel {
    const NSObject *_constValue;
}

@dynamic dynamicValue;

- (NSObject *)getValue {
    return _getterValue;
}

- (void)setValue:(NSObject *)value {
    _setterValue = value;
}

- (void)testConst:(const NSObject *)value {}
- (void)testIn:(in NSObject *)value {}
- (void)testOut:(out NSObject *)value {}
- (void)testInout:(inout NSObject *)value {}
- (void)testBycopy:(bycopy NSObject *)value {}
- (void)testByref:(byref NSObject *)value {}
- (void)testOneway:(oneway NSObject *)value {}
@end


@protocol Pig
@end
@protocol Egg
@end
@protocol Dog
@end

@interface XXTestPropertySubModel : XXTestPropertyModel

@property (nonatomic, strong) NSString<Pig,Egg,Dog> *randomValue;

@end

@implementation XXTestPropertySubModel
@end


@interface XXTestClassInfo : XCTestCase
@end

@implementation XXTestClassInfo

- (void)testClassInfoCache {
    XXClassInfo *info1 = [XXClassInfo classInfoWithClass:[XXTestPropertyModel class]];
    [info1 setNeedsUpdate];
    XXClassInfo *info2 = [XXClassInfo classInfoWithClassName:@"XXTestPropertyModel"];
    XCTAssertNotNil(info1);
    XCTAssertNotNil(info2);
    XCTAssertEqual(info1, info2);
}

- (void)testClassMeta {
    XXClassInfo *classInfo = [XXClassInfo classInfoWithClass:[XXTestPropertyModel class]];
    XCTAssertNotNil(classInfo);
    XCTAssertEqual(classInfo.cls, [XXTestPropertyModel class]);
    XCTAssertEqual(classInfo.superCls, [NSObject class]);
    XCTAssertEqual(classInfo.metaCls, objc_getMetaClass("XXTestPropertyModel"));
    XCTAssertEqual(classInfo.isMeta, NO);
    
    Class meta = object_getClass([XXTestPropertyModel class]);
    XXClassInfo *metaClassInfo = [XXClassInfo classInfoWithClass:meta];
    XCTAssertNotNil(metaClassInfo);
    XCTAssertEqual(metaClassInfo.cls, meta);
    XCTAssertEqual(metaClassInfo.superCls, object_getClass([NSObject class]));
    XCTAssertEqual(metaClassInfo.metaCls, nil);
    XCTAssertEqual(metaClassInfo.isMeta, YES);
}

- (void)testClassInfo {
    XXClassInfo *info = [XXClassInfo classInfoWithClass:[XXTestPropertyModel class]];
    XCTAssertEqual([self getType:info name:@"boolValue"] & XXEncodingTypeMask, XXEncodingTypeBool);
#ifdef OBJC_BOOL_IS_BOOL
    XCTAssertEqual([self getType:info name:@"BOOLValue"] & XXEncodingTypeMask, XXEncodingTypeBool);
#else
    XCTAssertEqual([self getType:info name:@"BOOLValue"] & XXEncodingTypeMask, XXEncodingTypeInt8);
#endif
    XCTAssertEqual([self getType:info name:@"charValue"] & XXEncodingTypeMask, XXEncodingTypeInt8);
    XCTAssertEqual([self getType:info name:@"unsignedCharValue"] & XXEncodingTypeMask, XXEncodingTypeUInt8);
    XCTAssertEqual([self getType:info name:@"shortValue"] & XXEncodingTypeMask, XXEncodingTypeInt16);
    XCTAssertEqual([self getType:info name:@"unsignedShortValue"] & XXEncodingTypeMask, XXEncodingTypeUInt16);
    XCTAssertEqual([self getType:info name:@"intValue"] & XXEncodingTypeMask, XXEncodingTypeInt32);
    XCTAssertEqual([self getType:info name:@"unsignedIntValue"] & XXEncodingTypeMask, XXEncodingTypeUInt32);
#ifdef __LP64__
    XCTAssertEqual([self getType:info name:@"longValue"] & XXEncodingTypeMask, XXEncodingTypeInt64);
    XCTAssertEqual([self getType:info name:@"unsignedLongValue"] & XXEncodingTypeMask, XXEncodingTypeUInt64);
    XCTAssertEqual(XXEncodingGetType("l") & XXEncodingTypeMask, XXEncodingTypeInt32); // long in 32 bit system
    XCTAssertEqual(XXEncodingGetType("L") & XXEncodingTypeMask, XXEncodingTypeUInt32); // unsingle long in 32 bit system
#else
    XCTAssertEqual([self getType:info name:@"longValue"] & XXEncodingTypeMask, XXEncodingTypeInt32);
    XCTAssertEqual([self getType:info name:@"unsignedLongValue"] & XXEncodingTypeMask, XXEncodingTypeUInt32);
#endif
    XCTAssertEqual([self getType:info name:@"longLongValue"] & XXEncodingTypeMask, XXEncodingTypeInt64);
    XCTAssertEqual([self getType:info name:@"unsignedLongLongValue"] & XXEncodingTypeMask, XXEncodingTypeUInt64);
    XCTAssertEqual([self getType:info name:@"floatValue"] & XXEncodingTypeMask, XXEncodingTypeFloat);
    XCTAssertEqual([self getType:info name:@"doubleValue"] & XXEncodingTypeMask, XXEncodingTypeDouble);
    XCTAssertEqual([self getType:info name:@"longDoubleValue"] & XXEncodingTypeMask, XXEncodingTypeLongDouble);
    
    XCTAssertEqual([self getType:info name:@"objectValue"] & XXEncodingTypeMask, XXEncodingTypeObject);
    XCTAssertEqual([self getType:info name:@"arrayValue"] & XXEncodingTypeMask, XXEncodingTypeObject);
    XCTAssertEqual([self getType:info name:@"classValue"] & XXEncodingTypeMask, XXEncodingTypeClass);
    XCTAssertEqual([self getType:info name:@"selectorValue"] & XXEncodingTypeMask, XXEncodingTypeSEL);
    XCTAssertEqual([self getType:info name:@"blockValue"] & XXEncodingTypeMask, XXEncodingTypeBlock);
    XCTAssertEqual([self getType:info name:@"pointerValue"] & XXEncodingTypeMask, XXEncodingTypePointer);
    XCTAssertEqual([self getType:info name:@"functionPointerValue"] & XXEncodingTypeMask, XXEncodingTypePointer);
    XCTAssertEqual([self getType:info name:@"structValue"] & XXEncodingTypeMask, XXEncodingTypeStruct);
    XCTAssertEqual([self getType:info name:@"unionValue"] & XXEncodingTypeMask, XXEncodingTypeUnion);
    XCTAssertEqual([self getType:info name:@"cStringValue"] & XXEncodingTypeMask, XXEncodingTypeCString);
    
    XCTAssertEqual(XXEncodingGetType(@encode(void)) & XXEncodingTypeMask, XXEncodingTypeVoid);
    XCTAssertEqual(XXEncodingGetType(@encode(int[10])) & XXEncodingTypeMask, XXEncodingTypeCArray);
    XCTAssertEqual(XXEncodingGetType("") & XXEncodingTypeMask, XXEncodingTypeUnknown);
    XCTAssertEqual(XXEncodingGetType(".") & XXEncodingTypeMask, XXEncodingTypeUnknown);
    XCTAssertEqual(XXEncodingGetType("ri") & XXEncodingTypeQualifierMask, XXEncodingTypeQualifierConst);
    XCTAssertEqual([self getMethodTypeWithName:@"testIn:"] & XXEncodingTypeQualifierMask, XXEncodingTypeQualifierIn);
    XCTAssertEqual([self getMethodTypeWithName:@"testOut:"] & XXEncodingTypeQualifierMask, XXEncodingTypeQualifierOut);
    XCTAssertEqual([self getMethodTypeWithName:@"testInout:"] & XXEncodingTypeQualifierMask, XXEncodingTypeQualifierInout);
    XCTAssertEqual([self getMethodTypeWithName:@"testBycopy:"] & XXEncodingTypeQualifierMask, XXEncodingTypeQualifierBycopy);
    XCTAssertEqual([self getMethodTypeWithName:@"testByref:"] & XXEncodingTypeQualifierMask, XXEncodingTypeQualifierByref);
    XCTAssertEqual([self getMethodTypeWithName:@"testOneway:"] & XXEncodingTypeQualifierMask, XXEncodingTypeQualifierOneway);
    
    XCTAssert([self getType:info name:@"nonatomicValue"] & XXEncodingTypePropertyMask &XXEncodingTypePropertyNonatomic);
    XCTAssert([self getType:info name:@"aCopyValue"] & XXEncodingTypePropertyMask & XXEncodingTypePropertyCopy);
    XCTAssert([self getType:info name:@"strongValue"] & XXEncodingTypePropertyMask & XXEncodingTypePropertyRetain);
    XCTAssert([self getType:info name:@"retainValue"] & XXEncodingTypePropertyMask & XXEncodingTypePropertyRetain);
    XCTAssert([self getType:info name:@"weakValue"] & XXEncodingTypePropertyMask & XXEncodingTypePropertyWeak);
    XCTAssert([self getType:info name:@"readonlyValue"] & XXEncodingTypePropertyMask & XXEncodingTypePropertyReadonly);
    XCTAssert([self getType:info name:@"dynamicValue"] & XXEncodingTypePropertyMask & XXEncodingTypePropertyDynamic);
    XCTAssert([self getType:info name:@"getterValue"] & XXEncodingTypePropertyMask &XXEncodingTypePropertyCustomGetter);
    XCTAssert([self getType:info name:@"setterValue"] & XXEncodingTypePropertyMask & XXEncodingTypePropertyCustomSetter);
}

- (void)testOthers {
    //contain property key
    XCTAssert([XXTestPropertyModel xx_containsPropertyKey:@"boolValue"]);
    XCTAssert(![XXTestPropertyModel xx_containsPropertyKey:@"boolValue" untilClass:[XXTestPropertyModel class] ignoreUntilClass:YES]);
    XCTAssert(![XXTestPropertySubModel xx_containsPropertyKey:@"boolValue" untilClass:[XXTestPropertySubModel class]]);
    XCTAssert([XXTestPropertySubModel xx_containsPropertyKey:@"boolValue" untilClass:[XXTestPropertyModel class]]);
    XCTAssert(![XXTestPropertySubModel xx_containsPropertyKey:@"boolValue" untilClass:[XXTestPropertyModel class] ignoreUntilClass:YES]);
    
    //propertyInfos
    XCTAssert([XXTestPropertySubModel xx_propertyInfos][@"boolValue"]);
    XCTAssert([XXTestPropertySubModel xx_propertyInfosUntilClass:[XXTestPropertySubModel class]][@"randomValue"]);
    XCTAssert(![XXTestPropertySubModel xx_propertyInfosUntilClass:[XXTestPropertyModel class] ignoreUntilClass:YES][@"boolValue"]);
    
    //protocol names
    XXClassInfo *info = [XXClassInfo classInfoWithClass:[XXTestPropertySubModel class]];
    XXClassPropertyInfo *propertyInfo = info.propertyInfos[@"randomValue"];
    XCTAssert([propertyInfo.protocolNames containsObject:@"Pig"]);
    XCTAssert([propertyInfo.protocolNames containsObject:@"Egg"]);
    XCTAssert([propertyInfo.protocolNames containsObject:@"Dog"]);
}

- (XXEncodingType)getType:(XXClassInfo *)info name:(NSString *)name {
    return ((XXClassPropertyInfo *)info.propertyInfos[name]).type;
}

- (XXEncodingType)getMethodTypeWithName:(NSString *)name {
    XXTestPropertyModel *model = [XXTestPropertyModel new];
    NSMethodSignature *sig = [model methodSignatureForSelector:NSSelectorFromString(name)];
    const char *typeName = [sig getArgumentTypeAtIndex:2];
    return XXEncodingGetType(typeName);
}

@end
