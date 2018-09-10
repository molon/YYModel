//
//  NSObject+XXModel.m
//  XXModel <https://github.com/ibireme/XXModel>
//
//  Created by ibireme on 15/5/10.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "NSObject+XXModel.h"
#import "XXClassInfo.h"
#import <objc/message.h>
#import <pthread.h>

#define force_inline __inline__ __attribute__((always_inline))

/// Returns the cached model class meta
static CFMutableDictionaryRef yymodel_cache;
static pthread_rwlock_t yymodel_rwlock;

/// Foundation Class Type
typedef NS_ENUM (NSUInteger, XXEncodingNSType) {
    XXEncodingTypeNSUnknown = 0,
    XXEncodingTypeNSString,
    XXEncodingTypeNSMutableString,
    XXEncodingTypeNSValue,
    XXEncodingTypeNSNumber,
    XXEncodingTypeNSDecimalNumber,
    XXEncodingTypeNSData,
    XXEncodingTypeNSMutableData,
    XXEncodingTypeNSDate,
    XXEncodingTypeNSURL,
    XXEncodingTypeNSArray,
    XXEncodingTypeNSMutableArray,
    XXEncodingTypeNSDictionary,
    XXEncodingTypeNSMutableDictionary,
    XXEncodingTypeNSSet,
    XXEncodingTypeNSMutableSet,
};

/// Get the Foundation class type from property info.
static force_inline XXEncodingNSType XXClassGetNSType(Class cls) {
    if (!cls) return XXEncodingTypeNSUnknown;
    if ([cls isSubclassOfClass:[NSMutableString class]]) return XXEncodingTypeNSMutableString;
    if ([cls isSubclassOfClass:[NSString class]]) return XXEncodingTypeNSString;
    if ([cls isSubclassOfClass:[NSDecimalNumber class]]) return XXEncodingTypeNSDecimalNumber;
    if ([cls isSubclassOfClass:[NSNumber class]]) return XXEncodingTypeNSNumber;
    if ([cls isSubclassOfClass:[NSValue class]]) return XXEncodingTypeNSValue;
    if ([cls isSubclassOfClass:[NSMutableData class]]) return XXEncodingTypeNSMutableData;
    if ([cls isSubclassOfClass:[NSData class]]) return XXEncodingTypeNSData;
    if ([cls isSubclassOfClass:[NSDate class]]) return XXEncodingTypeNSDate;
    if ([cls isSubclassOfClass:[NSURL class]]) return XXEncodingTypeNSURL;
    if ([cls isSubclassOfClass:[NSMutableArray class]]) return XXEncodingTypeNSMutableArray;
    if ([cls isSubclassOfClass:[NSArray class]]) return XXEncodingTypeNSArray;
    if ([cls isSubclassOfClass:[NSMutableDictionary class]]) return XXEncodingTypeNSMutableDictionary;
    if ([cls isSubclassOfClass:[NSDictionary class]]) return XXEncodingTypeNSDictionary;
    if ([cls isSubclassOfClass:[NSMutableSet class]]) return XXEncodingTypeNSMutableSet;
    if ([cls isSubclassOfClass:[NSSet class]]) return XXEncodingTypeNSSet;
    return XXEncodingTypeNSUnknown;
}

/// Whether the type is c number.
static force_inline BOOL XXEncodingTypeIsCNumber(XXEncodingType type) {
    switch (type & XXEncodingTypeMask) {
        case XXEncodingTypeBool:
        case XXEncodingTypeInt8:
        case XXEncodingTypeUInt8:
        case XXEncodingTypeInt16:
        case XXEncodingTypeUInt16:
        case XXEncodingTypeInt32:
        case XXEncodingTypeUInt32:
        case XXEncodingTypeInt64:
        case XXEncodingTypeUInt64:
        case XXEncodingTypeFloat:
        case XXEncodingTypeDouble:
        case XXEncodingTypeLongDouble: return YES;
        default: return NO;
    }
}

/// Parse a number value from 'id'.
static force_inline NSNumber *XXNSNumberCreateFromID(__unsafe_unretained id value) {
    static NSCharacterSet *dot;
    static NSDictionary *dic;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dot = [NSCharacterSet characterSetWithRange:NSMakeRange('.', 1)];
        dic = @{@"TRUE" :   @(YES),
                @"True" :   @(YES),
                @"true" :   @(YES),
                @"FALSE" :  @(NO),
                @"False" :  @(NO),
                @"false" :  @(NO),
                @"YES" :    @(YES),
                @"Yes" :    @(YES),
                @"yes" :    @(YES),
                @"NO" :     @(NO),
                @"No" :     @(NO),
                @"no" :     @(NO),
                @"NIL" :    (id)kCFNull,
                @"Nil" :    (id)kCFNull,
                @"nil" :    (id)kCFNull,
                @"NULL" :   (id)kCFNull,
                @"Null" :   (id)kCFNull,
                @"null" :   (id)kCFNull,
                @"(NULL)" : (id)kCFNull,
                @"(Null)" : (id)kCFNull,
                @"(null)" : (id)kCFNull,
                @"<NULL>" : (id)kCFNull,
                @"<Null>" : (id)kCFNull,
                @"<null>" : (id)kCFNull};
    });
    
    if (!value || value == (id)kCFNull) return nil;
    if ([value isKindOfClass:[NSNumber class]]) return value;
    if ([value isKindOfClass:[NSString class]]) {
        NSNumber *num = dic[value];
        if (num) {
            if (num == (id)kCFNull) return nil;
            return num;
        }
        if ([(NSString *)value rangeOfCharacterFromSet:dot].location != NSNotFound) {
            const char *cstring = ((NSString *)value).UTF8String;
            if (!cstring) return nil;
            double num = atof(cstring);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        } else {
            const char *cstring = ((NSString *)value).UTF8String;
            if (!cstring) return nil;
            return @(strtoull(cstring, NULL, 0));
        }
    }
    return nil;
}

/// Parse string to date.
static force_inline NSDate *XXNSDateFromString(__unsafe_unretained NSString *string) {
    typedef NSDate* (^XXNSDateParseBlock)(NSString *string);
    #define kParserNum 34
    static XXNSDateParseBlock blocks[kParserNum + 1] = {0};
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        {
            /*
             2014-01-20  // Google
             */
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter.dateFormat = @"yyyy-MM-dd";
            blocks[10] = ^(NSString *string) { return [formatter dateFromString:string]; };
        }
        
        {
            /*
             2014-01-20 12:24:48
             2014-01-20T12:24:48   // Google
             2014-01-20 12:24:48.000
             2014-01-20T12:24:48.000
             */
            NSDateFormatter *formatter1 = [[NSDateFormatter alloc] init];
            formatter1.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter1.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter1.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
            
            NSDateFormatter *formatter2 = [[NSDateFormatter alloc] init];
            formatter2.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter2.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter2.dateFormat = @"yyyy-MM-dd HH:mm:ss";

            NSDateFormatter *formatter3 = [[NSDateFormatter alloc] init];
            formatter3.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter3.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter3.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS";

            NSDateFormatter *formatter4 = [[NSDateFormatter alloc] init];
            formatter4.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter4.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter4.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
            
            blocks[19] = ^(NSString *string) {
                if ([string characterAtIndex:10] == 'T') {
                    return [formatter1 dateFromString:string];
                } else {
                    return [formatter2 dateFromString:string];
                }
            };

            blocks[23] = ^(NSString *string) {
                if ([string characterAtIndex:10] == 'T') {
                    return [formatter3 dateFromString:string];
                } else {
                    return [formatter4 dateFromString:string];
                }
            };
        }
        
        {
            /*
             2014-01-20T12:24:48Z        // Github, Apple
             2014-01-20T12:24:48+0800    // Facebook
             2014-01-20T12:24:48+12:00   // Google
             2014-01-20T12:24:48.000Z
             2014-01-20T12:24:48.000+0800
             2014-01-20T12:24:48.000+12:00
             */
            NSDateFormatter *formatter = [NSDateFormatter new];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";

            NSDateFormatter *formatter2 = [NSDateFormatter new];
            formatter2.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter2.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZ";

            blocks[20] = ^(NSString *string) { return [formatter dateFromString:string]; };
            blocks[24] = ^(NSString *string) { return [formatter dateFromString:string]?: [formatter2 dateFromString:string]; };
            blocks[25] = ^(NSString *string) { return [formatter dateFromString:string]; };
            blocks[28] = ^(NSString *string) { return [formatter2 dateFromString:string]; };
            blocks[29] = ^(NSString *string) { return [formatter2 dateFromString:string]; };
        }
        
        {
            /*
             Fri Sep 04 00:12:21 +0800 2015 // Weibo, Twitter
             Fri Sep 04 00:12:21.000 +0800 2015
             */
            NSDateFormatter *formatter = [NSDateFormatter new];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.dateFormat = @"EEE MMM dd HH:mm:ss Z yyyy";

            NSDateFormatter *formatter2 = [NSDateFormatter new];
            formatter2.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter2.dateFormat = @"EEE MMM dd HH:mm:ss.SSS Z yyyy";

            blocks[30] = ^(NSString *string) { return [formatter dateFromString:string]; };
            blocks[34] = ^(NSString *string) { return [formatter2 dateFromString:string]; };
        }
    });
    if (!string) return nil;
    if (string.length > kParserNum) return nil;
    XXNSDateParseBlock parser = blocks[string.length];
    if (!parser) return nil;
    return parser(string);
    #undef kParserNum
}


/// Get the 'NSBlock' class.
static force_inline Class XXNSBlockClass() {
    static Class cls;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void (^block)(void) = ^{};
        cls = ((NSObject *)block).class;
        while (class_getSuperclass(cls) != [NSObject class]) {
            cls = class_getSuperclass(cls);
        }
    });
    return cls; // current is "NSBlock"
}



/**
 Get the ISO date formatter.
 
 ISO8601 format example:
 2010-07-09T16:13:30+12:00
 2011-01-11T11:11:11+0000
 2011-01-26T19:06:43Z
 
 length: 20/24/25
 */
static force_inline NSDateFormatter *XXISODateFormatter() {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
    });
    return formatter;
}

/// Get the value with key paths from dictionary
/// The dic should be NSDictionary, and the keyPath should not be nil.
static force_inline id XXValueForKeyPath(__unsafe_unretained NSDictionary *dic, __unsafe_unretained NSArray *keyPaths) {
    id value = nil;
    for (NSUInteger i = 0, max = keyPaths.count; i < max; i++) {
        value = dic[keyPaths[i]];
        if (i + 1 < max) {
            if ([value isKindOfClass:[NSDictionary class]]) {
                dic = value;
            } else {
                return nil;
            }
        }
    }
    return value;
}

/// Get the value with multi key (or key path) from dictionary
/// The dic should be NSDictionary
static force_inline id XXValueForMultiKeys(__unsafe_unretained NSDictionary *dic, __unsafe_unretained NSArray *multiKeys) {
    id value = nil;
    for (NSString *key in multiKeys) {
        if ([key isKindOfClass:[NSString class]]) {
            value = dic[key];
            if (value) break;
        } else {
            value = XXValueForKeyPath(dic, (NSArray *)key);
            if (value) break;
        }
    }
    return value;
}

@implementation XXModelTransformProtocol {
    @package
    Class _protocolClass;
}

+ (instancetype)center {
    static XXModelTransformProtocol *_center = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _center = [[XXModelTransformProtocol alloc]init];
        _center->_protocolClass = [XXModelTransformProtocol class];
    });
    return _center;
}

+ (void)registerClass:(Class)cls {
    [[self center]registerClass:cls];
}

+ (void)unregisterClass {
    [[self center]unregisterClass];
}

- (void)registerClass:(Class)cls {
    NSAssert([cls isSubclassOfClass:[XXModelTransformProtocol class]], @"Register transform class must be subclass of \'XXModelTransformProtocol\'");
    
    //We must clean the cached model class meta,
    //Because maybe the cache is all not correct after new protocol class set.
    XXMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_wrlock(&yymodel_rwlock));
    
    _protocolClass = cls;
    
    //release original
    if (yymodel_cache) {
        CFRelease(yymodel_cache);
    }
    //Just recreate
    yymodel_cache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    
    XXMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_unlock(&yymodel_rwlock));
}

- (void)unregisterClass {
    //We must clean the cached model class meta,
    //Because maybe the cache is all not correct after new protocol class set.
    XXMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_wrlock(&yymodel_rwlock));
    
    _protocolClass = [XXModelTransformProtocol class];
    
    //release original
    if (yymodel_cache) {
        CFRelease(yymodel_cache);
    }
    //Just recreate
    yymodel_cache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    
    XXMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_unlock(&yymodel_rwlock));
}

+ (nullable NSDictionary<NSString *, id> *)modelCustomPropertyMapperForClass:(Class)cls {
    return nil;
}

+ (id)newValueBeforeTransformFromValue:(id)value modelClass:(Class)cls modelKey:(NSString*)modelKey {
    return nil;
}

+ (id)newModelBeforeTransformFromModel:(id)model modelKey:(NSString*)modelKey {
    return nil;
}

@end

/// A property info in object model.
@interface _XXModelPropertyMeta : NSObject {
    @package
    NSString *_name;             ///< property's name
    XXEncodingType _type;        ///< property's type
    XXEncodingNSType _nsType;    ///< property's Foundation type
    BOOL _isCNumber;             ///< is c number type
    BOOL _isContainer;           ///< is container(NSArray,NSMutableArray,NSDictionary,NSMutableDictionary,NSSet,NSMutableSet)
    Class _cls;                  ///< property's class, or nil
    Class _genericCls;           ///< container's generic class, or nil if threr's no generic class
    SEL _getter;                 ///< getter, or nil if the instances cannot respond
    SEL _setter;                 ///< setter, or nil if the instances cannot respond
    BOOL _isKVCCompatible;       ///< YES if it can access with key-value coding
    BOOL _isStructAvailableForKeyedArchiver; ///< YES if the struct can encoded with keyed archiver/unarchiver
    BOOL _hasCustomClassFromDictionary; ///< class/generic class implements +modelCustomClassForDictionary:
    
    id _defaultValue;
    
    /*
     property->key:       _mappedToKey:key     _mappedToKeyPath:nil            _mappedToKeyArray:nil
     property->keyPath:   _mappedToKey:keyPath _mappedToKeyPath:keyPath(array) _mappedToKeyArray:nil
     property->keys:      _mappedToKey:keys[0] _mappedToKeyPath:nil/keyPath    _mappedToKeyArray:keys(array)
     */
    NSString *_mappedToKey;      ///< the key mapped to
    NSArray *_mappedToKeyPath;   ///< the key path mapped to (nil if the name is not key path)
    NSArray *_mappedToKeyArray;  ///< the key(NSString) or keyPath(NSArray) array (nil if not mapped to multiple keys)
    XXClassPropertyInfo *_info;  ///< property's info
    _XXModelPropertyMeta *_next; ///< next meta if there are multiple properties mapped to the same key.
}
@end

@implementation _XXModelPropertyMeta
+ (instancetype)metaWithClassInfo:(XXClassInfo *)classInfo propertyInfo:(XXClassPropertyInfo *)propertyInfo defaultValue:(id)defaultValue generic:(Class)generic {
    _XXModelPropertyMeta *meta = [self new];
    
    meta->_name = propertyInfo.name;
    meta->_type = propertyInfo.type;
    meta->_info = propertyInfo;
    meta->_defaultValue = defaultValue;
    
    if ((meta->_type & XXEncodingTypeMask) == XXEncodingTypeObject) {
        meta->_nsType = XXClassGetNSType(propertyInfo.cls);
        meta->_isContainer =
            meta->_nsType == XXEncodingTypeNSArray||
            meta->_nsType == XXEncodingTypeNSMutableArray||
            meta->_nsType == XXEncodingTypeNSDictionary||
            meta->_nsType == XXEncodingTypeNSMutableDictionary||
            meta->_nsType == XXEncodingTypeNSSet||
            meta->_nsType == XXEncodingTypeNSMutableSet;
        if (meta->_isContainer && !generic && propertyInfo.protocolNames.count > 0) {
            //support pseudo generic class only for container class
            generic = propertyInfo.pseudoGenericCls;
        }
    } else {
        meta->_isCNumber = XXEncodingTypeIsCNumber(meta->_type);
    }
    
    meta->_genericCls = generic;
    
    if ((meta->_type & XXEncodingTypeMask) == XXEncodingTypeStruct) {
        /*
         It seems that NSKeyedUnarchiver cannot decode NSValue except these structs:
         */
        static NSSet *types = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSMutableSet *set = [NSMutableSet new];
            // 32 bit
            [set addObject:@"{CGSize=ff}"];
            [set addObject:@"{CGPoint=ff}"];
            [set addObject:@"{CGRect={CGPoint=ff}{CGSize=ff}}"];
            [set addObject:@"{CGAffineTransform=ffffff}"];
            [set addObject:@"{UIEdgeInsets=ffff}"];
            [set addObject:@"{UIOffset=ff}"];
            // 64 bit
            [set addObject:@"{CGSize=dd}"];
            [set addObject:@"{CGPoint=dd}"];
            [set addObject:@"{CGRect={CGPoint=dd}{CGSize=dd}}"];
            [set addObject:@"{CGAffineTransform=dddddd}"];
            [set addObject:@"{UIEdgeInsets=dddd}"];
            [set addObject:@"{UIOffset=dd}"];
            types = set;
        });
        if ([types containsObject:propertyInfo.typeEncoding]) {
            meta->_isStructAvailableForKeyedArchiver = YES;
        }
    }
    meta->_cls = propertyInfo.cls;
    
    if (generic) {
        meta->_hasCustomClassFromDictionary = [generic respondsToSelector:@selector(modelCustomClassForDictionary:)];
    } else if (meta->_cls && meta->_nsType == XXEncodingTypeNSUnknown) {
        meta->_hasCustomClassFromDictionary = [meta->_cls respondsToSelector:@selector(modelCustomClassForDictionary:)];
    }
    
    if (propertyInfo.getter) {
        if ([classInfo.cls instancesRespondToSelector:propertyInfo.getter]) {
            meta->_getter = propertyInfo.getter;
        }
    }
    if (propertyInfo.setter) {
        if ([classInfo.cls instancesRespondToSelector:propertyInfo.setter]) {
            meta->_setter = propertyInfo.setter;
        }
    }
    
    if (meta->_getter && meta->_setter) {
        /*
         KVC invalid type:
         long double
         pointer (such as SEL/CoreFoundation object)
         */
        switch (meta->_type & XXEncodingTypeMask) {
            case XXEncodingTypeBool:
            case XXEncodingTypeInt8:
            case XXEncodingTypeUInt8:
            case XXEncodingTypeInt16:
            case XXEncodingTypeUInt16:
            case XXEncodingTypeInt32:
            case XXEncodingTypeUInt32:
            case XXEncodingTypeInt64:
            case XXEncodingTypeUInt64:
            case XXEncodingTypeFloat:
            case XXEncodingTypeDouble:
            case XXEncodingTypeObject:
            case XXEncodingTypeClass:
            case XXEncodingTypeBlock:
            case XXEncodingTypeStruct:
            case XXEncodingTypeUnion: {
                meta->_isKVCCompatible = YES;
            } break;
            default: break;
        }
    }
    
    return meta;
}
@end


/// A class info in object model.
@interface _XXModelMeta : NSObject {
    @package
    XXClassInfo *_classInfo;
    /// Key:mapped key and key path, Value:_XXModelPropertyMeta.
    NSDictionary *_mapper;
    /// Array<_XXModelPropertyMeta>, all property meta of this model.
    NSArray *_allPropertyMetas;
    /// Array<_XXModelPropertyMeta>, property meta which is mapped to a key path.
    NSArray *_keyPathPropertyMetas;
    /// Array<_XXModelPropertyMeta>, property meta which is mapped to multi keys.
    NSArray *_multiKeysPropertyMetas;
    /// The number of mapped key (and key path), same to _mapper.count.
    NSUInteger _keyMappedCount;
    /// Model class type.
    XXEncodingNSType _nsType;
    
    BOOL _hasCustomWillTransformFromDictionary;
    BOOL _hasCustomTransformFromDictionary;
    BOOL _hasCustomTransformToDictionary;
    BOOL _hasCustomClassFromDictionary;
}
@end

@implementation _XXModelMeta
- (instancetype)initWithClass:(Class)cls {
    XXClassInfo *classInfo = [XXClassInfo classInfoWithClass:cls];
    if (!classInfo) return nil;
    self = [super init];
    
    // Get black list
    NSSet *blacklist = nil;
    if ([cls respondsToSelector:@selector(modelPropertyBlacklist)]) {
        NSArray *properties = [(id<XXModel>)cls modelPropertyBlacklist];
        if (properties) {
            blacklist = [NSSet setWithArray:properties];
        }
    }
    
    // Get white list
    NSSet *whitelist = nil;
    if ([cls respondsToSelector:@selector(modelPropertyWhitelist)]) {
        NSArray *properties = [(id<XXModel>)cls modelPropertyWhitelist];
        if (properties) {
            whitelist = [NSSet setWithArray:properties];
        }
    }
    
    // Get container property's generic class
    NSDictionary *genericMapper = nil;
    if ([cls respondsToSelector:@selector(modelContainerPropertyGenericClass)]) {
        genericMapper = [(id<XXModel>)cls modelContainerPropertyGenericClass];
        if (genericMapper) {
            NSMutableDictionary *tmp = [NSMutableDictionary new];
            [genericMapper enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if (![key isKindOfClass:[NSString class]]) return;
                Class meta = object_getClass(obj);
                if (!meta) return;
                if (class_isMetaClass(meta)) {
                    tmp[key] = obj;
                } else if ([obj isKindOfClass:[NSString class]]) {
                    Class cls = NSClassFromString(obj);
                    if (cls) {
                        tmp[key] = cls;
                    }
                }
            }];
            genericMapper = tmp;
        }
    }
    
    NSDictionary *specialDefaultValueMapper = nil;
    // Get special default value mapper
    if ([cls respondsToSelector:@selector(modelCustomPropertyDefaultValueMapper)]) {
        specialDefaultValueMapper = [(id<XXModel>)cls modelCustomPropertyDefaultValueMapper];
    }
    
    // Create all property metas.
    NSMutableDictionary *allPropertyMetas = [NSMutableDictionary new];
    XXClassInfo *curClassInfo = classInfo;
    while (curClassInfo && curClassInfo.superCls != nil) { // recursive parse super class, but ignore root class (NSObject/NSProxy)
        for (XXClassPropertyInfo *propertyInfo in curClassInfo.propertyInfos.allValues) {
            if (!propertyInfo.name) continue;
            if (blacklist && [blacklist containsObject:propertyInfo.name]) continue;
            if (whitelist && ![whitelist containsObject:propertyInfo.name]) continue;
            _XXModelPropertyMeta *meta = [_XXModelPropertyMeta metaWithClassInfo:classInfo
                                                                    propertyInfo:propertyInfo
                                                                    defaultValue:specialDefaultValueMapper[propertyInfo.name] generic:genericMapper[propertyInfo.name]];
            if (!meta || !meta->_name) continue;
            if (!meta->_getter || !meta->_setter) continue;
            if (allPropertyMetas[meta->_name]) continue;
            allPropertyMetas[meta->_name] = meta;
        }
        curClassInfo = curClassInfo.superClassInfo;
    }
    if (allPropertyMetas.count>0) _allPropertyMetas = allPropertyMetas.allValues.copy;
    
    // create mapper
    NSMutableDictionary *mapper = [NSMutableDictionary new];
    NSMutableArray *keyPathPropertyMetas = [NSMutableArray new];
    NSMutableArray *multiKeysPropertyMetas = [NSMutableArray new];
    
    // get center mapper
    NSDictionary *allCustomMapper = [[XXModelTransformProtocol center]->_protocolClass modelCustomPropertyMapperForClass:cls];
    if ([cls respondsToSelector:@selector(modelCustomPropertyMapper)]) {
        NSDictionary *selfCustomMapper = [(id <XXModel>)cls modelCustomPropertyMapper];
        if (selfCustomMapper && !allCustomMapper) {
            //just use customMapper
            allCustomMapper = selfCustomMapper;
        }else if (selfCustomMapper.count > 0) {
            allCustomMapper = [allCustomMapper isKindOfClass:[NSMutableDictionary class]]?allCustomMapper:[allCustomMapper mutableCopy];
            //replace the same key with selfCustomMapper and add nonexistent
            [allCustomMapper setValuesForKeysWithDictionary:selfCustomMapper];
        }
    }
    [allCustomMapper enumerateKeysAndObjectsUsingBlock:^(NSString *propertyName, NSString *mappedToKey, BOOL *stop) {
        _XXModelPropertyMeta *propertyMeta = allPropertyMetas[propertyName];
        if (!propertyMeta) return;
        [allPropertyMetas removeObjectForKey:propertyName];
        
        if ([mappedToKey isKindOfClass:[NSString class]]) {
            if (mappedToKey.length == 0) return;
            
            propertyMeta->_mappedToKey = mappedToKey;
            NSArray *keyPath = [mappedToKey componentsSeparatedByString:@"."];
            if (keyPath.count > 1 && ![keyPath containsObject:@""]) {
                propertyMeta->_mappedToKeyPath = keyPath;
                [keyPathPropertyMetas addObject:propertyMeta];
            }

            propertyMeta->_next = mapper[mappedToKey] ?: nil;
            mapper[mappedToKey] = propertyMeta;
            
        } else if ([mappedToKey isKindOfClass:[NSArray class]]) {
            
            NSMutableArray *mappedToKeyArray = [NSMutableArray new];
            for (NSString *oneKey in ((NSArray *)mappedToKey)) {
                if (![oneKey isKindOfClass:[NSString class]]) continue;
                if (oneKey.length == 0) continue;
                
                NSArray *keyPath = [oneKey componentsSeparatedByString:@"."];
                if (keyPath.count > 1 && ![keyPath containsObject:@""]) {
                    [mappedToKeyArray addObject:keyPath];
                } else {
                    [mappedToKeyArray addObject:oneKey];
                }
                
                if (!propertyMeta->_mappedToKey) {
                    propertyMeta->_mappedToKey = oneKey;
                    propertyMeta->_mappedToKeyPath = (keyPath.count > 1 && ![keyPath containsObject:@""]) ? keyPath : nil;
                }
            }
            if (!propertyMeta->_mappedToKey) return;
            
            propertyMeta->_mappedToKeyArray = mappedToKeyArray;
            [multiKeysPropertyMetas addObject:propertyMeta];
            
            propertyMeta->_next = mapper[mappedToKey] ?: nil;
            mapper[mappedToKey] = propertyMeta;
        }
    }];
    
    [allPropertyMetas enumerateKeysAndObjectsUsingBlock:^(NSString *name, _XXModelPropertyMeta *propertyMeta, BOOL *stop) {
        propertyMeta->_mappedToKey = name;
        propertyMeta->_next = mapper[name] ?: nil;
        mapper[name] = propertyMeta;
    }];
    
    if (mapper.count>0) _mapper = mapper;
    if (keyPathPropertyMetas.count>0) _keyPathPropertyMetas = keyPathPropertyMetas;
    if (multiKeysPropertyMetas.count>0) _multiKeysPropertyMetas = multiKeysPropertyMetas;
    
    _classInfo = classInfo;
    _keyMappedCount = _allPropertyMetas.count;
    _nsType = XXClassGetNSType(cls);
    _hasCustomWillTransformFromDictionary = ([cls instancesRespondToSelector:@selector(modelCustomWillTransformFromDictionary:)]);
    _hasCustomTransformFromDictionary = ([cls instancesRespondToSelector:@selector(modelCustomTransformFromDictionary:)]);
    _hasCustomTransformToDictionary = ([cls instancesRespondToSelector:@selector(modelCustomTransformToDictionary:)]);
    _hasCustomClassFromDictionary = ([cls respondsToSelector:@selector(modelCustomClassForDictionary:)]);
    
    return self;
}

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        yymodel_cache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        XXMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_init(&yymodel_rwlock, NULL));
    });
}

+ (instancetype)metaWithClass:(Class)cls {
    if (!cls) return nil;
    XXMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_rdlock(&yymodel_rwlock));
    _XXModelMeta *meta = CFDictionaryGetValue(yymodel_cache, (__bridge const void *)(cls));
    XXMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_unlock(&yymodel_rwlock));
    if (!meta || meta->_classInfo.needsUpdate) {
        XXMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_wrlock(&yymodel_rwlock));
        meta = CFDictionaryGetValue(yymodel_cache, (__bridge const void *)(cls));
        if (!meta || meta->_classInfo.needsUpdate) {
            meta = [[_XXModelMeta alloc] initWithClass:cls];
            if (meta) {
                CFDictionarySetValue(yymodel_cache, (__bridge const void *)(cls), (__bridge const void *)(meta));
            }
        }
        XXMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_unlock(&yymodel_rwlock));
    }
    return meta;
}

@end


/**
 Get number from property.
 @discussion Caller should hold strong reference to the parameters before this function returns.
 @param model Should not be nil.
 @param meta  Should not be nil, meta.isCNumber should be YES, meta.getter should not be nil.
 @return A number object, or nil if failed.
 */
static force_inline NSNumber *ModelCreateNumberFromProperty(__unsafe_unretained id model,
                                                            __unsafe_unretained _XXModelPropertyMeta *meta) {
    switch (meta->_type & XXEncodingTypeMask) {
        case XXEncodingTypeBool: {
            return @(((bool (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case XXEncodingTypeInt8: {
            return @(((int8_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case XXEncodingTypeUInt8: {
            return @(((uint8_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case XXEncodingTypeInt16: {
            return @(((int16_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case XXEncodingTypeUInt16: {
            return @(((uint16_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case XXEncodingTypeInt32: {
            return @(((int32_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case XXEncodingTypeUInt32: {
            return @(((uint32_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case XXEncodingTypeInt64: {
            return @(((int64_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case XXEncodingTypeUInt64: {
            return @(((uint64_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case XXEncodingTypeFloat: {
            float num = ((float (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        case XXEncodingTypeDouble: {
            double num = ((double (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        case XXEncodingTypeLongDouble: {
            double num = ((long double (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        default: return nil;
    }
}

/**
 Set number to property.
 @discussion Caller should hold strong reference to the parameters before this function returns.
 @param model Should not be nil.
 @param num   Can be nil.
 @param meta  Should not be nil, meta.isCNumber should be YES, meta.setter should not be nil.
 */
static force_inline void ModelSetNumberToProperty(__unsafe_unretained id model,
                                                  __unsafe_unretained NSNumber *num,
                                                  __unsafe_unretained _XXModelPropertyMeta *meta) {
    switch (meta->_type & XXEncodingTypeMask) {
        case XXEncodingTypeBool: {
            ((void (*)(id, SEL, bool))(void *) objc_msgSend)((id)model, meta->_setter, num.boolValue);
        } break;
        case XXEncodingTypeInt8: {
            ((void (*)(id, SEL, int8_t))(void *) objc_msgSend)((id)model, meta->_setter, (int8_t)num.charValue);
        } break;
        case XXEncodingTypeUInt8: {
            ((void (*)(id, SEL, uint8_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint8_t)num.unsignedCharValue);
        } break;
        case XXEncodingTypeInt16: {
            ((void (*)(id, SEL, int16_t))(void *) objc_msgSend)((id)model, meta->_setter, (int16_t)num.shortValue);
        } break;
        case XXEncodingTypeUInt16: {
            ((void (*)(id, SEL, uint16_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint16_t)num.unsignedShortValue);
        } break;
        case XXEncodingTypeInt32: {
            ((void (*)(id, SEL, int32_t))(void *) objc_msgSend)((id)model, meta->_setter, (int32_t)num.intValue);
        }
        case XXEncodingTypeUInt32: {
            ((void (*)(id, SEL, uint32_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint32_t)num.unsignedIntValue);
        } break;
        case XXEncodingTypeInt64: {
            if ([num isKindOfClass:[NSDecimalNumber class]]) {
                ((void (*)(id, SEL, int64_t))(void *) objc_msgSend)((id)model, meta->_setter, (int64_t)num.stringValue.longLongValue);
            } else {
                ((void (*)(id, SEL, uint64_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint64_t)num.longLongValue);
            }
        } break;
        case XXEncodingTypeUInt64: {
            if ([num isKindOfClass:[NSDecimalNumber class]]) {
                ((void (*)(id, SEL, int64_t))(void *) objc_msgSend)((id)model, meta->_setter, (int64_t)num.stringValue.longLongValue);
            } else {
                ((void (*)(id, SEL, uint64_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint64_t)num.unsignedLongLongValue);
            }
        } break;
        case XXEncodingTypeFloat: {
            float f = num.floatValue;
            if (isnan(f) || isinf(f)) f = 0;
            ((void (*)(id, SEL, float))(void *) objc_msgSend)((id)model, meta->_setter, f);
        } break;
        case XXEncodingTypeDouble: {
            double d = num.doubleValue;
            if (isnan(d) || isinf(d)) d = 0;
            ((void (*)(id, SEL, double))(void *) objc_msgSend)((id)model, meta->_setter, d);
        } break;
        case XXEncodingTypeLongDouble: {
            long double d = num.doubleValue;
            if (isnan(d) || isinf(d)) d = 0;
            ((void (*)(id, SEL, long double))(void *) objc_msgSend)((id)model, meta->_setter, (long double)d);
        } // break; commented for code coverage in next line
        default: break;
    }
}

/**
 Set value to model with a property meta.
 
 @discussion Caller should hold strong reference to the parameters before this function returns.
 
 @param model Should not be nil.
 @param originalValue Should not be nil, but can be NSNull.
 @param meta  Should not be nil, and meta->_setter should not be nil.
 */
static void ModelSetValueForProperty(__unsafe_unretained id model,
                                     __unsafe_unretained id originalValue,
                                     __unsafe_unretained _XXModelPropertyMeta *meta) {

    NS_VALID_UNTIL_END_OF_SCOPE id value = originalValue;
    
    if (meta->_isCNumber) {
        NSNumber *num = XXNSNumberCreateFromID(value);
        if (!num&&[meta->_defaultValue isKindOfClass:[NSNumber class]]) {
            num = meta->_defaultValue;
        }
        ModelSetNumberToProperty(model, num, meta);
        if (num) [num class]; // hold the number
    } else {
        if (value == (id)kCFNull && meta->_defaultValue) {
            value = meta->_defaultValue;
        }
        
        if (meta->_cls) {
            id newValue = [[XXModelTransformProtocol center]->_protocolClass newValueBeforeTransformFromValue:value modelClass:meta->_cls modelKey:meta->_name];
            if (newValue) {
                value = newValue;
            }
        }
        
        if (meta->_nsType) {
            if (value == (id)kCFNull) {
                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)nil);
            } else {
                switch (meta->_nsType) {
                    case XXEncodingTypeNSString:
                    case XXEncodingTypeNSMutableString: {
                        if ([value isKindOfClass:[NSString class]]) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                           meta->_setter,
                                                                           (meta->_nsType == XXEncodingTypeNSString)?
                                                                           value :
                                                                           ((NSString *)value).mutableCopy);
                        } else if ([value isKindOfClass:[NSNumber class]]) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                           meta->_setter,
                                                                           (meta->_nsType == XXEncodingTypeNSString) ?
                                                                           ((NSNumber *)value).stringValue :
                                                                           ((NSNumber *)value).stringValue.mutableCopy);
                        } else if ([value isKindOfClass:[NSData class]]) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                           meta->_setter,
                                                                           (meta->_nsType == XXEncodingTypeNSString)?
                                                                           [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding] :
                                                                           [[NSMutableString alloc] initWithData:value encoding:NSUTF8StringEncoding]);
                        } else if ([value isKindOfClass:[NSURL class]]) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                           meta->_setter,
                                                                           (meta->_nsType == XXEncodingTypeNSString) ?
                                                                           ((NSURL *)value).absoluteString :
                                                                           ((NSURL *)value).absoluteString.mutableCopy);
                        } else if ([value isKindOfClass:[NSAttributedString class]]) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                           meta->_setter,
                                                                           (meta->_nsType == XXEncodingTypeNSString) ?
                                                                           ((NSAttributedString *)value).string :
                                                                           ((NSAttributedString *)value).string.mutableCopy);
                        }
                    } break;
                        
                    case XXEncodingTypeNSValue:
                    case XXEncodingTypeNSNumber:
                    case XXEncodingTypeNSDecimalNumber: {
                        if (meta->_nsType == XXEncodingTypeNSNumber) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, XXNSNumberCreateFromID(value));
                        } else if (meta->_nsType == XXEncodingTypeNSDecimalNumber) {
                            if ([value isKindOfClass:[NSDecimalNumber class]]) {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                            } else if ([value isKindOfClass:[NSNumber class]]) {
                                NSDecimalNumber *decNum = [NSDecimalNumber decimalNumberWithDecimal:[((NSNumber *)value) decimalValue]];
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, decNum);
                            } else if ([value isKindOfClass:[NSString class]]) {
                                NSDecimalNumber *decNum = [NSDecimalNumber decimalNumberWithString:value];
                                NSDecimal dec = decNum.decimalValue;
                                if (dec._length == 0 && dec._isNegative) {
                                    decNum = nil; // NaN
                                }
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, decNum);
                            }
                        } else { // XXEncodingTypeNSValue
                            if ([value isKindOfClass:[NSValue class]]) {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                            }
                        }
                    } break;
                        
                    case XXEncodingTypeNSData:
                    case XXEncodingTypeNSMutableData: {
                        if ([value isKindOfClass:[NSData class]]) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                           meta->_setter,
                                                                           (meta->_nsType == XXEncodingTypeNSData) ?
                                                                           value :
                                                                           ((NSData *)value).mutableCopy);
                        } else if ([value isKindOfClass:[NSString class]]) {
                            NSData *data = [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                           meta->_setter,
                                                                           (meta->_nsType == XXEncodingTypeNSData) ?
                                                                           data :
                                                                           data.mutableCopy);
                        }
                    } break;
                        
                    case XXEncodingTypeNSDate: {
                        if ([value isKindOfClass:[NSDate class]]) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                        } else if ([value isKindOfClass:[NSString class]]) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, XXNSDateFromString(value));
                        }
                    } break;
                        
                    case XXEncodingTypeNSURL: {
                        if ([value isKindOfClass:[NSURL class]]) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                        } else if ([value isKindOfClass:[NSString class]]) {
                            NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                            NSString *str = [value stringByTrimmingCharactersInSet:set];
                            if (str.length == 0) {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, nil);
                            } else {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, [[NSURL alloc] initWithString:str]);
                            }
                        }
                    } break;
                        
                    case XXEncodingTypeNSArray:
                    case XXEncodingTypeNSMutableArray: {
                        NSArray *valueArr = nil;
                        if ([value isKindOfClass:[NSArray class]]) valueArr = value;
                        else if ([value isKindOfClass:[NSSet class]]) valueArr = ((NSSet *)value).allObjects;
                        if (valueArr) {
                            if (meta->_genericCls) {
                                NSMutableArray *objectArr = [NSMutableArray new];
                                for (id one in valueArr) {
                                    if ([one isKindOfClass:meta->_genericCls]) {
                                        [objectArr addObject:one];
                                    } else if ([one isKindOfClass:[NSDictionary class]]) {
                                        Class cls = meta->_genericCls;
                                        if (meta->_hasCustomClassFromDictionary) {
                                            cls = [cls modelCustomClassForDictionary:one];
                                            if (!cls) cls = meta->_genericCls; // for xcode code coverage
                                        }
                                        NSObject *newOne = [cls new];
                                        [newOne xx_modelSetWithDictionary:one];
                                        if (newOne) [objectArr addObject:newOne];
                                    }
                                }
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, objectArr);
                            } else {
                                if ([valueArr containsObject:(id)kCFNull]) {
                                    NSMutableArray *objectArr = valueArr.mutableCopy;
                                    [objectArr removeObject:(id)kCFNull];
                                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                                   meta->_setter,
                                                                                   objectArr);
                                }else{
                                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                                   meta->_setter,
                                                                                   (meta->_nsType == XXEncodingTypeNSArray) ?
                                                                                   valueArr :
                                                                                   valueArr.mutableCopy);
                                }
                            }
                        }
                    } break;
                        
                    case XXEncodingTypeNSDictionary:
                    case XXEncodingTypeNSMutableDictionary: {
                        if ([value isKindOfClass:[NSDictionary class]]) {
                            if (meta->_genericCls) {
                                NSMutableDictionary *dic = [NSMutableDictionary new];
                                [((NSDictionary *)value) enumerateKeysAndObjectsUsingBlock:^(NSString *oneKey, id oneValue, BOOL *stop) {
                                    if ([oneValue isKindOfClass:[NSDictionary class]]) {
                                        Class cls = meta->_genericCls;
                                        if (meta->_hasCustomClassFromDictionary) {
                                            cls = [cls modelCustomClassForDictionary:oneValue];
                                            if (!cls) cls = meta->_genericCls; // for xcode code coverage
                                        }
                                        NSObject *newOne = [cls new];
                                        [newOne xx_modelSetWithDictionary:(id)oneValue];
                                        if (newOne) dic[oneKey] = newOne;
                                    }
                                }];
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, dic);
                            } else {
                                NSMutableDictionary *dic = [NSMutableDictionary new];
                                [((NSDictionary *)value) enumerateKeysAndObjectsUsingBlock:^(NSString *oneKey, id oneValue, BOOL *stop) {
                                    if (oneValue != (id)kCFNull) {
                                        dic[oneKey] = oneValue;
                                    }
                                }];
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, dic);
                            }
                        }
                    } break;
                        
                    case XXEncodingTypeNSSet:
                    case XXEncodingTypeNSMutableSet: {
                        NSSet *valueSet = nil;
                        if ([value isKindOfClass:[NSArray class]]) valueSet = [NSMutableSet setWithArray:value];
                        else if ([value isKindOfClass:[NSSet class]]) valueSet = ((NSSet *)value);
                        
                        if (valueSet) {
                            if (meta->_genericCls) {
                                NSMutableSet *set = [NSMutableSet new];
                                for (id one in valueSet) {
                                    if ([one isKindOfClass:meta->_genericCls]) {
                                        [set addObject:one];
                                    } else if ([one isKindOfClass:[NSDictionary class]]) {
                                        Class cls = meta->_genericCls;
                                        if (meta->_hasCustomClassFromDictionary) {
                                            cls = [cls modelCustomClassForDictionary:one];
                                            if (!cls) cls = meta->_genericCls; // for xcode code coverage
                                        }
                                        NSObject *newOne = [cls new];
                                        [newOne xx_modelSetWithDictionary:one];
                                        if (newOne) [set addObject:newOne];
                                    }
                                }
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, set);
                            } else {
                                if ([valueSet containsObject:(id)kCFNull]) {
                                    NSMutableSet *objectSet = [valueSet isKindOfClass:[NSMutableSet class]]?valueSet:valueSet.mutableCopy;
                                    [objectSet removeObject:(id)kCFNull];
                                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                                   meta->_setter,
                                                                                   objectSet);
                                }else{
                                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                                   meta->_setter,
                                                                                   (meta->_nsType == XXEncodingTypeNSSet) ?
                                                                                   valueSet :
                                                                                   ([valueSet isKindOfClass:[NSMutableSet class]]?valueSet:valueSet.mutableCopy));
                                }
                            }
                        }
                    } // break; commented for code coverage in next line
                        
                    default: break;
                }
            }
        } else {
            BOOL isNull = (value == (id)kCFNull);
            switch (meta->_type & XXEncodingTypeMask) {
                case XXEncodingTypeObject: {
                    if (isNull) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)nil);
                    } else if ([value isKindOfClass:meta->_cls] || !meta->_cls) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)value);
                    } else if ([value isKindOfClass:[NSDictionary class]]) {
                        NSObject *one = nil;
                        if (meta->_getter) {
                            one = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
                        }
                        if (one) {
                            [one xx_modelSetWithDictionary:value];
                        } else {
                            Class cls = meta->_cls;
                            if (meta->_hasCustomClassFromDictionary) {
                                cls = [cls modelCustomClassForDictionary:value];
                                if (!cls) cls = meta->_cls; // for xcode code coverage
                            }
                            one = [cls new];
                            [one xx_modelSetWithDictionary:value];
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)one);
                        }
                    }
                } break;
                    
                case XXEncodingTypeClass: {
                    if (isNull) {
                        ((void (*)(id, SEL, Class))(void *) objc_msgSend)((id)model, meta->_setter, (Class)NULL);
                    } else {
                        Class cls = nil;
                        if ([value isKindOfClass:[NSString class]]) {
                            cls = NSClassFromString(value);
                            if (cls) {
                                ((void (*)(id, SEL, Class))(void *) objc_msgSend)((id)model, meta->_setter, (Class)cls);
                            }
                        } else {
                            cls = object_getClass(value);
                            if (cls) {
                                if (class_isMetaClass(cls)) {
                                    ((void (*)(id, SEL, Class))(void *) objc_msgSend)((id)model, meta->_setter, (Class)value);
                                }
                            }
                        }
                    }
                } break;
                    
                case  XXEncodingTypeSEL: {
                    if (isNull) {
                        ((void (*)(id, SEL, SEL))(void *) objc_msgSend)((id)model, meta->_setter, (SEL)NULL);
                    } else if ([value isKindOfClass:[NSString class]]) {
                        SEL sel = NSSelectorFromString(value);
                        if (sel) ((void (*)(id, SEL, SEL))(void *) objc_msgSend)((id)model, meta->_setter, (SEL)sel);
                    }
                } break;
                    
                case XXEncodingTypeBlock: {
                    if (isNull) {
                        ((void (*)(id, SEL, void (^)()))(void *) objc_msgSend)((id)model, meta->_setter, (void (^)())NULL);
                    } else if ([value isKindOfClass:XXNSBlockClass()]) {
                        ((void (*)(id, SEL, void (^)()))(void *) objc_msgSend)((id)model, meta->_setter, (void (^)())value);
                    }
                } break;
                    
                case XXEncodingTypeStruct:
                case XXEncodingTypeUnion:
                case XXEncodingTypeCArray: {
                    if ([value isKindOfClass:[NSValue class]]) {
                        const char *valueType = ((NSValue *)value).objCType;
                        const char *metaType = meta->_info.typeEncoding.UTF8String;
                        if (valueType && metaType && strcmp(valueType, metaType) == 0) {
                            [model setValue:value forKey:meta->_name];
                        }
                    }
                } break;
                    
                case XXEncodingTypePointer:
                case XXEncodingTypeCString: {
                    if (isNull) {
                        ((void (*)(id, SEL, void *))(void *) objc_msgSend)((id)model, meta->_setter, (void *)NULL);
                    } else if ([value isKindOfClass:[NSValue class]]) {
                        NSValue *nsValue = value;
                        if (nsValue.objCType && strcmp(nsValue.objCType, "^v") == 0) {
                            ((void (*)(id, SEL, void *))(void *) objc_msgSend)((id)model, meta->_setter, nsValue.pointerValue);
                        }
                    }
                } // break; commented for code coverage in next line
                    
                default: break;
            }
        }
    }
}


typedef struct {
    void *modelMeta;  ///< _XXModelMeta
    void *model;      ///< id (self)
    void *dictionary; ///< NSDictionary (json)
} ModelSetContext;

/**
 Apply function for dictionary, to set the key-value pair to model.
 
 @param _key     should not be nil, NSString.
 @param _value   should not be nil.
 @param _context _context.modelMeta and _context.model should not be nil.
 */
static void ModelSetWithDictionaryFunction(const void *_key, const void *_value, void *_context) {
    ModelSetContext *context = _context;
    __unsafe_unretained _XXModelMeta *meta = (__bridge _XXModelMeta *)(context->modelMeta);
    __unsafe_unretained _XXModelPropertyMeta *propertyMeta = [meta->_mapper objectForKey:(__bridge id)(_key)];
    __unsafe_unretained id model = (__bridge id)(context->model);
    while (propertyMeta) {
        if (propertyMeta->_setter) {
            ModelSetValueForProperty(model, (__bridge __unsafe_unretained id)_value, propertyMeta);
        }
        propertyMeta = propertyMeta->_next;
    };
}

/**
 Apply function for model property meta, to set dictionary to model.
 
 @param _propertyMeta should not be nil, _XXModelPropertyMeta.
 @param _context      _context.model and _context.dictionary should not be nil.
 */
static void ModelSetWithPropertyMetaArrayFunction(const void *_propertyMeta, void *_context) {
    ModelSetContext *context = _context;
    __unsafe_unretained NSDictionary *dictionary = (__bridge NSDictionary *)(context->dictionary);
    __unsafe_unretained _XXModelPropertyMeta *propertyMeta = (__bridge _XXModelPropertyMeta *)(_propertyMeta);
    if (!propertyMeta->_setter) return;
    id value = nil;
    
    if (propertyMeta->_mappedToKeyArray) {
        value = XXValueForMultiKeys(dictionary, propertyMeta->_mappedToKeyArray);
    } else if (propertyMeta->_mappedToKeyPath) {
        value = XXValueForKeyPath(dictionary, propertyMeta->_mappedToKeyPath);
    } else {
        value = [dictionary objectForKey:propertyMeta->_mappedToKey];
    }
    
    if (value) {
        __unsafe_unretained id model = (__bridge id)(context->model);
        ModelSetValueForProperty(model, value, propertyMeta);
    }
}

/**
 Returns a valid JSON object (NSArray/NSDictionary/NSString/NSNumber/NSNull), 
 or nil if an error occurs.
 
 @param model Model, can be nil.
 @param modelKey can be nil
 @return JSON object, nil if an error occurs.
 */
static id ModelToJSONObjectRecursive(NSObject *model,NSString *modelKey) {
    if (!model || model == (id)kCFNull) return model;
    
    id newModel = [[XXModelTransformProtocol center]->_protocolClass newModelBeforeTransformFromModel:model modelKey:modelKey];
    if (newModel) {
        model = newModel;
    }
    
    if ([model isKindOfClass:[NSString class]]) return model;
    if ([model isKindOfClass:[NSNumber class]]) return model;
    if ([model isKindOfClass:[NSDictionary class]]) {
        if ([NSJSONSerialization isValidJSONObject:model]) return model;
        NSMutableDictionary *newDic = [NSMutableDictionary new];
        [((NSDictionary *)model) enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
            NSString *stringKey = [key isKindOfClass:[NSString class]] ? key : key.description;
            if (!stringKey) return;
            id jsonObj = ModelToJSONObjectRecursive(obj,stringKey);
            if (!jsonObj) jsonObj = (id)kCFNull;
            newDic[stringKey] = jsonObj;
        }];
        return newDic;
    }
    if ([model isKindOfClass:[NSSet class]]) {
        NSArray *array = ((NSSet *)model).allObjects;
        if ([NSJSONSerialization isValidJSONObject:array]) return array;
        NSMutableArray *newArray = [NSMutableArray new];
        for (id obj in array) {
            if ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSNumber class]]) {
                [newArray addObject:obj];
            } else {
                id jsonObj = ModelToJSONObjectRecursive(obj,nil);
                if (jsonObj && jsonObj != (id)kCFNull) [newArray addObject:jsonObj];
            }
        }
        return newArray;
    }
    if ([model isKindOfClass:[NSArray class]]) {
        if ([NSJSONSerialization isValidJSONObject:model]) return model;
        NSMutableArray *newArray = [NSMutableArray new];
        for (id obj in (NSArray *)model) {
            if ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSNumber class]]) {
                [newArray addObject:obj];
            } else {
                id jsonObj = ModelToJSONObjectRecursive(obj,nil);
                if (jsonObj && jsonObj != (id)kCFNull) [newArray addObject:jsonObj];
            }
        }
        return newArray;
    }
    if ([model isKindOfClass:[NSURL class]]) return ((NSURL *)model).absoluteString;
    if ([model isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)model).string;
    if ([model isKindOfClass:[NSDate class]]) return [XXISODateFormatter() stringFromDate:(id)model];
    if ([model isKindOfClass:[NSData class]]) return nil;
    
    
    _XXModelMeta *modelMeta = [_XXModelMeta metaWithClass:[model class]];
    if (!modelMeta || modelMeta->_keyMappedCount == 0) return nil;
    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:64];
    __unsafe_unretained NSMutableDictionary *dic = result; // avoid retain and release in block
    [modelMeta->_mapper enumerateKeysAndObjectsUsingBlock:^(NSString *propertyMappedKey, _XXModelPropertyMeta *propertyMeta, BOOL *stop) {
        if (!propertyMeta->_getter) return;
        
        id value = nil;
        if (propertyMeta->_isCNumber) {
            value = ModelCreateNumberFromProperty(model, propertyMeta);
        } else if (propertyMeta->_nsType) {
            id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
            value = ModelToJSONObjectRecursive(v,propertyMeta->_name);
        } else {
            switch (propertyMeta->_type & XXEncodingTypeMask) {
                case XXEncodingTypeObject: {
                    id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = ModelToJSONObjectRecursive(v,propertyMeta->_name);
                    if (value == (id)kCFNull) value = nil;
                } break;
                case XXEncodingTypeClass: {
                    Class v = ((Class (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = v ? NSStringFromClass(v) : nil;
                } break;
                case XXEncodingTypeSEL: {
                    SEL v = ((SEL (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = v ? NSStringFromSelector(v) : nil;
                } break;
                default: break;
            }
        }
        if (!value) return;
        
        if (propertyMeta->_mappedToKeyPath) {
            NSMutableDictionary *superDic = dic;
            NSMutableDictionary *subDic = nil;
            for (NSUInteger i = 0, max = propertyMeta->_mappedToKeyPath.count; i < max; i++) {
                NSString *key = propertyMeta->_mappedToKeyPath[i];
                if (i + 1 == max) { // end
                    if (!superDic[key]) superDic[key] = value;
                    break;
                }
                
                subDic = superDic[key];
                if (subDic) {
                    if ([subDic isKindOfClass:[NSDictionary class]]) {
                        subDic = subDic.mutableCopy;
                        superDic[key] = subDic;
                    } else {
                        break;
                    }
                } else {
                    subDic = [NSMutableDictionary new];
                    superDic[key] = subDic;
                }
                superDic = subDic;
                subDic = nil;
            }
        } else {
            if (!dic[propertyMeta->_mappedToKey]) {
                dic[propertyMeta->_mappedToKey] = value;
            }
        }
    }];
    
    if (modelMeta->_hasCustomTransformToDictionary) {
        BOOL suc = [((id<XXModel>)model) modelCustomTransformToDictionary:dic];
        if (!suc) return nil;
    }
    return result;
}

/// Add indent to string (exclude first line)
static NSMutableString *ModelDescriptionAddIndent(NSMutableString *desc, NSUInteger indent) {
    for (NSUInteger i = 0, max = desc.length; i < max; i++) {
        unichar c = [desc characterAtIndex:i];
        if (c == '\n') {
            for (NSUInteger j = 0; j < indent; j++) {
                [desc insertString:@"    " atIndex:i + 1];
            }
            i += indent * 4;
            max += indent * 4;
        }
    }
    return desc;
}

/// Generaate a description string
static NSString *ModelDescription(NSObject *model) {
    static const int kDescMaxLength = 100;
    if (!model) return @"<nil>";
    if (model == (id)kCFNull) return @"<null>";
    if (![model isKindOfClass:[NSObject class]]) return [NSString stringWithFormat:@"%@",model];
    
    
    _XXModelMeta *modelMeta = [_XXModelMeta metaWithClass:model.class];
    switch (modelMeta->_nsType) {
        case XXEncodingTypeNSString: case XXEncodingTypeNSMutableString: {
            return [NSString stringWithFormat:@"\"%@\"",model];
        }
        
        case XXEncodingTypeNSValue:
        case XXEncodingTypeNSData: case XXEncodingTypeNSMutableData: {
            NSString *tmp = model.description;
            if (tmp.length > kDescMaxLength) {
                tmp = [tmp substringToIndex:kDescMaxLength];
                tmp = [tmp stringByAppendingString:@"..."];
            }
            return tmp;
        }
            
        case XXEncodingTypeNSNumber:
        case XXEncodingTypeNSDecimalNumber:
        case XXEncodingTypeNSDate:
        case XXEncodingTypeNSURL: {
            return [NSString stringWithFormat:@"%@",model];
        }
            
        case XXEncodingTypeNSSet: case XXEncodingTypeNSMutableSet: {
            model = ((NSSet *)model).allObjects;
        } // no break
            
        case XXEncodingTypeNSArray: case XXEncodingTypeNSMutableArray: {
            NSArray *array = (id)model;
            NSMutableString *desc = [NSMutableString new];
            if (array.count == 0) {
                return [desc stringByAppendingString:@"[]"];
            } else {
                [desc appendFormat:@"[\n"];
                for (NSUInteger i = 0, max = array.count; i < max; i++) {
                    NSObject *obj = array[i];
                    [desc appendString:@"    "];
                    [desc appendString:ModelDescriptionAddIndent(ModelDescription(obj).mutableCopy, 1)];
                    [desc appendString:(i + 1 == max) ? @"\n" : @";\n"];
                }
                [desc appendString:@"]"];
                return desc;
            }
        }
        case XXEncodingTypeNSDictionary: case XXEncodingTypeNSMutableDictionary: {
            NSDictionary *dic = (id)model;
            NSMutableString *desc = [NSMutableString new];
            if (dic.count == 0) {
                return [desc stringByAppendingString:@"{}"];
            } else {
                NSArray *keys = dic.allKeys;
                
                [desc appendFormat:@"{\n"];
                for (NSUInteger i = 0, max = keys.count; i < max; i++) {
                    NSString *key = keys[i];
                    NSObject *value = dic[key];
                    [desc appendString:@"    "];
                    [desc appendFormat:@"%@ = %@",key, ModelDescriptionAddIndent(ModelDescription(value).mutableCopy, 1)];
                    [desc appendString:(i + 1 == max) ? @"\n" : @";\n"];
                }
                [desc appendString:@"}"];
            }
            return desc;
        }
        
        default: {
            NSMutableString *desc = [NSMutableString new];
            [desc appendFormat:@"<%@: %p>", model.class, model];
            if (modelMeta->_allPropertyMetas.count == 0) return desc;
            
            // sort property names
            NSArray *properties = [modelMeta->_allPropertyMetas
                                   sortedArrayUsingComparator:^NSComparisonResult(_XXModelPropertyMeta *p1, _XXModelPropertyMeta *p2) {
                                       return [p1->_name compare:p2->_name];
                                   }];
            
            [desc appendFormat:@" {\n"];
            for (NSUInteger i = 0, max = properties.count; i < max; i++) {
                _XXModelPropertyMeta *property = properties[i];
                NSString *propertyDesc;
                if (property->_isCNumber) {
                    NSNumber *num = ModelCreateNumberFromProperty(model, property);
                    propertyDesc = num.stringValue;
                } else {
                    switch (property->_type & XXEncodingTypeMask) {
                        case XXEncodingTypeObject: {
                            id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, property->_getter);
                            propertyDesc = ModelDescription(v);
                            if (!propertyDesc) propertyDesc = @"<nil>";
                        } break;
                        case XXEncodingTypeClass: {
                            id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, property->_getter);
                            propertyDesc = ((NSObject *)v).description;
                            if (!propertyDesc) propertyDesc = @"<nil>";
                        } break;
                        case XXEncodingTypeSEL: {
                            SEL sel = ((SEL (*)(id, SEL))(void *) objc_msgSend)((id)model, property->_getter);
                            if (sel) propertyDesc = NSStringFromSelector(sel);
                            else propertyDesc = @"<NULL>";
                        } break;
                        case XXEncodingTypeBlock: {
                            id block = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, property->_getter);
                            propertyDesc = block ? ((NSObject *)block).description : @"<nil>";
                        } break;
                        case XXEncodingTypeCArray: case XXEncodingTypeCString: case XXEncodingTypePointer: {
                            void *pointer = ((void* (*)(id, SEL))(void *) objc_msgSend)((id)model, property->_getter);
                            propertyDesc = [NSString stringWithFormat:@"%p",pointer];
                        } break;
                        case XXEncodingTypeStruct: case XXEncodingTypeUnion: {
                            NSValue *value = [model valueForKey:property->_name];
                            propertyDesc = value ? value.description : @"{unknown}";
                        } break;
                        default: propertyDesc = @"<unknown>";
                    }
                }
                
                propertyDesc = ModelDescriptionAddIndent(propertyDesc.mutableCopy, 1);
                [desc appendFormat:@"    %@ = %@",property->_name, propertyDesc];
                [desc appendString:(i + 1 == max) ? @"\n" : @";\n"];
            }
            [desc appendFormat:@"}"];
            return desc;
        }
    }
}


@implementation NSObject (XXModel)

+ (NSDictionary *)_xx_dictionaryWithJSON:(id)json {
    if (!json || json == (id)kCFNull) return nil;
    NSDictionary *dic = nil;
    NSData *jsonData = nil;
    if ([json isKindOfClass:[NSDictionary class]]) {
        dic = json;
    } else if ([json isKindOfClass:[NSString class]]) {
        jsonData = [(NSString *)json dataUsingEncoding : NSUTF8StringEncoding];
    } else if ([json isKindOfClass:[NSData class]]) {
        jsonData = json;
    }
    if (jsonData) {
        dic = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if (![dic isKindOfClass:[NSDictionary class]]) dic = nil;
    }
    return dic;
}

+ (instancetype)xx_modelWithJSON:(id)json {
    NSDictionary *dic = [self _xx_dictionaryWithJSON:json];
    return [self xx_modelWithDictionary:dic];
}

+ (instancetype)xx_modelWithDictionary:(NSDictionary *)dictionary {
    if (!dictionary || dictionary == (id)kCFNull) return nil;
    if (![dictionary isKindOfClass:[NSDictionary class]]) return nil;
    
    Class cls = [self class];
    _XXModelMeta *modelMeta = [_XXModelMeta metaWithClass:cls];
    if (modelMeta->_hasCustomClassFromDictionary) {
        cls = [cls modelCustomClassForDictionary:dictionary] ?: cls;
    }
    
    NSObject *one = [cls new];
    if ([one xx_modelSetWithDictionary:dictionary]) return one;
    return nil;
}

- (BOOL)xx_modelSetWithJSON:(id)json {
    NSDictionary *dic = [NSObject _xx_dictionaryWithJSON:json];
    return [self xx_modelSetWithDictionary:dic];
}

- (BOOL)xx_modelSetWithDictionary:(NSDictionary *)dic {
    if (!dic || dic == (id)kCFNull) return NO;
    if (![dic isKindOfClass:[NSDictionary class]]) return NO;
    

    _XXModelMeta *modelMeta = [_XXModelMeta metaWithClass:object_getClass(self)];
    if (modelMeta->_keyMappedCount == 0) return NO;
    
    if (modelMeta->_hasCustomWillTransformFromDictionary) {
        dic = [((id<XXModel>)self) modelCustomWillTransformFromDictionary:dic];
        if (![dic isKindOfClass:[NSDictionary class]]) return NO;
    }
    
    ModelSetContext context = {0};
    context.modelMeta = (__bridge void *)(modelMeta);
    context.model = (__bridge void *)(self);
    context.dictionary = (__bridge void *)(dic);
    
    
    if (modelMeta->_keyMappedCount >= CFDictionaryGetCount((CFDictionaryRef)dic)) {
        CFDictionaryApplyFunction((CFDictionaryRef)dic, ModelSetWithDictionaryFunction, &context);
        if (modelMeta->_keyPathPropertyMetas) {
            CFArrayApplyFunction((CFArrayRef)modelMeta->_keyPathPropertyMetas,
                                 CFRangeMake(0, CFArrayGetCount((CFArrayRef)modelMeta->_keyPathPropertyMetas)),
                                 ModelSetWithPropertyMetaArrayFunction,
                                 &context);
        }
        if (modelMeta->_multiKeysPropertyMetas) {
            CFArrayApplyFunction((CFArrayRef)modelMeta->_multiKeysPropertyMetas,
                                 CFRangeMake(0, CFArrayGetCount((CFArrayRef)modelMeta->_multiKeysPropertyMetas)),
                                 ModelSetWithPropertyMetaArrayFunction,
                                 &context);
        }
    } else {
        CFArrayApplyFunction((CFArrayRef)modelMeta->_allPropertyMetas,
                             CFRangeMake(0, modelMeta->_keyMappedCount),
                             ModelSetWithPropertyMetaArrayFunction,
                             &context);
    }
    
    if (modelMeta->_hasCustomTransformFromDictionary) {
        return [((id<XXModel>)self) modelCustomTransformFromDictionary:dic];
    }
    return YES;
}

- (id)xx_modelToJSONObject {
    return [self xx_modelToJSONObjectOrRootSelf:NO];
}

- (id)xx_modelToJSONObjectOrRootSelf:(BOOL)rootSelf {
    /*
     Apple said:
     The top level object is an NSArray or NSDictionary.
     All objects are instances of NSString, NSNumber, NSArray, NSDictionary, or NSNull.
     All dictionary keys are instances of NSString.
     Numbers are not NaN or infinity.
     */
    id jsonObject = ModelToJSONObjectRecursive(self,nil);
    if ([jsonObject isKindOfClass:[NSArray class]]) return jsonObject;
    if ([jsonObject isKindOfClass:[NSDictionary class]]) return jsonObject;
    return rootSelf?jsonObject:nil;
}

- (NSData *)xx_modelToJSONData {
    id jsonObject = [self xx_modelToJSONObject];
    if (!jsonObject) return nil;
    return [NSJSONSerialization dataWithJSONObject:jsonObject options:0 error:NULL];
}

- (NSString *)xx_modelToJSONString {
    NSData *jsonData = [self xx_modelToJSONData];
    if (jsonData.length == 0) return nil;
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (id)xx_modelCopy{
    if (self == (id)kCFNull) return self;
    _XXModelMeta *modelMeta = [_XXModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return [self copy];
    
    NSObject *one = [self.class new];
    for (_XXModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_getter || !propertyMeta->_setter) continue;
        
        if (propertyMeta->_isCNumber) {
            switch (propertyMeta->_type & XXEncodingTypeMask) {
                case XXEncodingTypeBool: {
                    bool num = ((bool (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, bool))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case XXEncodingTypeInt8:
                case XXEncodingTypeUInt8: {
                    uint8_t num = ((bool (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint8_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case XXEncodingTypeInt16:
                case XXEncodingTypeUInt16: {
                    uint16_t num = ((uint16_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint16_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case XXEncodingTypeInt32:
                case XXEncodingTypeUInt32: {
                    uint32_t num = ((uint32_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint32_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case XXEncodingTypeInt64:
                case XXEncodingTypeUInt64: {
                    uint64_t num = ((uint64_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint64_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case XXEncodingTypeFloat: {
                    float num = ((float (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, float))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case XXEncodingTypeDouble: {
                    double num = ((double (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, double))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case XXEncodingTypeLongDouble: {
                    long double num = ((long double (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, long double))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } // break; commented for code coverage in next line
                default: break;
            }
        } else {
            switch (propertyMeta->_type & XXEncodingTypeMask) {
                case XXEncodingTypeObject:
                case XXEncodingTypeClass:
                case XXEncodingTypeBlock: {
                    id value = ((id (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)one, propertyMeta->_setter, value);
                } break;
                case XXEncodingTypeSEL:
                case XXEncodingTypePointer:
                case XXEncodingTypeCString: {
                    size_t value = ((size_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, size_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, value);
                } break;
                case XXEncodingTypeStruct:
                case XXEncodingTypeUnion: {
                    @try {
                        NSValue *value = [self valueForKey:NSStringFromSelector(propertyMeta->_getter)];
                        if (value) {
                            [one setValue:value forKey:propertyMeta->_name];
                        }
                    } @catch (NSException *exception) {}
                } // break; commented for code coverage in next line
                default: break;
            }
        }
    }
    return one;
}

- (void)xx_modelEncodeWithCoder:(NSCoder *)aCoder {
    if (!aCoder) return;
    if (self == (id)kCFNull) {
        [((id<NSCoding>)self)encodeWithCoder:aCoder];
        return;
    }
    
    _XXModelMeta *modelMeta = [_XXModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) {
        [((id<NSCoding>)self)encodeWithCoder:aCoder];
        return;
    }
    
    for (_XXModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_getter) return;
        
        if (propertyMeta->_isCNumber) {
            NSNumber *value = ModelCreateNumberFromProperty(self, propertyMeta);
            if (value) [aCoder encodeObject:value forKey:propertyMeta->_name];
        } else {
            switch (propertyMeta->_type & XXEncodingTypeMask) {
                case XXEncodingTypeObject: {
                    id value = ((id (*)(id, SEL))(void *)objc_msgSend)((id)self, propertyMeta->_getter);
                    if (value && (propertyMeta->_nsType || [value respondsToSelector:@selector(encodeWithCoder:)])) {
                        if ([value isKindOfClass:[NSValue class]]) {
                            if ([value isKindOfClass:[NSNumber class]]) {
                                [aCoder encodeObject:value forKey:propertyMeta->_name];
                            }
                        } else {
                            [aCoder encodeObject:value forKey:propertyMeta->_name];
                        }
                    }
                } break;
                case XXEncodingTypeSEL: {
                    SEL value = ((SEL (*)(id, SEL))(void *)objc_msgSend)((id)self, propertyMeta->_getter);
                    if (value) {
                        NSString *str = NSStringFromSelector(value);
                        [aCoder encodeObject:str forKey:propertyMeta->_name];
                    }
                } break;
                case XXEncodingTypeStruct:
                case XXEncodingTypeUnion: {
                    if (propertyMeta->_isKVCCompatible && propertyMeta->_isStructAvailableForKeyedArchiver) {
                        @try {
                            NSValue *value = [self valueForKey:NSStringFromSelector(propertyMeta->_getter)];
                            [aCoder encodeObject:value forKey:propertyMeta->_name];
                        } @catch (NSException *exception) {}
                    }
                } break;
                    
                default:
                    break;
            }
        }
    }
}

- (id)xx_modelInitWithCoder:(NSCoder *)aDecoder {
    if (!aDecoder) return self;
    if (self == (id)kCFNull) return self;    
    _XXModelMeta *modelMeta = [_XXModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return self;
    
    for (_XXModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_setter) continue;
        
        if (propertyMeta->_isCNumber) {
            NSNumber *value = [aDecoder decodeObjectForKey:propertyMeta->_name];
            if ([value isKindOfClass:[NSNumber class]]) {
                ModelSetNumberToProperty(self, value, propertyMeta);
                [value class];
            }
        } else {
            XXEncodingType type = propertyMeta->_type & XXEncodingTypeMask;
            switch (type) {
                case XXEncodingTypeObject: {
                    id value = [aDecoder decodeObjectForKey:propertyMeta->_name];
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)self, propertyMeta->_setter, value);
                } break;
                case XXEncodingTypeSEL: {
                    NSString *str = [aDecoder decodeObjectForKey:propertyMeta->_name];
                    if ([str isKindOfClass:[NSString class]]) {
                        SEL sel = NSSelectorFromString(str);
                        ((void (*)(id, SEL, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_setter, sel);
                    }
                } break;
                case XXEncodingTypeStruct:
                case XXEncodingTypeUnion: {
                    if (propertyMeta->_isKVCCompatible) {
                        @try {
                            NSValue *value = [aDecoder decodeObjectForKey:propertyMeta->_name];
                            if (value) [self setValue:value forKey:propertyMeta->_name];
                        } @catch (NSException *exception) {}
                    }
                } break;
                    
                default:
                    break;
            }
        }
    }
    return self;
}

- (NSUInteger)xx_modelHash {
    if (self == (id)kCFNull) return [self hash];
    _XXModelMeta *modelMeta = [_XXModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return [self hash];
    
    NSUInteger value = 0;
    NSUInteger count = 0;
    for (_XXModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_isKVCCompatible) continue;
        value ^= [[self valueForKey:NSStringFromSelector(propertyMeta->_getter)] hash];
        count++;
    }
    if (count == 0) value = (long)((__bridge void *)self);
    return value;
}

- (BOOL)xx_modelIsEqual:(id)model {
    if (self == model) return YES;
    if (![model isMemberOfClass:self.class]) return NO;
    _XXModelMeta *modelMeta = [_XXModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return [self isEqual:model];
    if ([self hash] != [model hash]) return NO;
    
    for (_XXModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_isKVCCompatible) continue;
        id this = [self valueForKey:NSStringFromSelector(propertyMeta->_getter)];
        id that = [model valueForKey:NSStringFromSelector(propertyMeta->_getter)];
        if (this == that) continue;
        if (this == nil || that == nil) return NO;
        if (![this isEqual:that]) return NO;
    }
    return YES;
}

- (NSString *)xx_modelDescription {
    return ModelDescription(self);
}


- (void)xx_resetPropertyValueForKey:(NSString*)key {
    if (key.length<=0) {
        return;
    }
    
    _XXModelMeta *modelMeta = [_XXModelMeta metaWithClass:self.class];
    for (_XXModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if ([key isEqualToString:propertyMeta->_name]) {
            [self xx_modelSetWithDictionary:@{propertyMeta->_name:propertyMeta->_defaultValue?:(id)kCFNull}];
            break;
        }
    }
}

- (void)xx_resetAllPropertyValues {
    NSMutableDictionary *defaultValueMapper = [NSMutableDictionary dictionary];
    
    _XXModelMeta *modelMeta = [_XXModelMeta metaWithClass:self.class];
    for (_XXModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        defaultValueMapper[propertyMeta->_name] = propertyMeta->_defaultValue?:(id)kCFNull;
    }
    [self xx_modelSetWithDictionary:defaultValueMapper];
}

@end



@implementation NSArray (XXModel)

+ (NSArray *)xx_modelArrayWithClass:(Class)cls json:(id)json {
    if (!json) return nil;
    NSArray *arr = nil;
    NSData *jsonData = nil;
    if ([json isKindOfClass:[NSArray class]]) {
        arr = json;
    } else if ([json isKindOfClass:[NSString class]]) {
        jsonData = [(NSString *)json dataUsingEncoding : NSUTF8StringEncoding];
    } else if ([json isKindOfClass:[NSData class]]) {
        jsonData = json;
    }
    if (jsonData) {
        arr = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if (![arr isKindOfClass:[NSArray class]]) arr = nil;
    }
    return [self xx_modelArrayWithClass:cls array:arr];
}

+ (NSArray *)xx_modelArrayWithClass:(Class)cls array:(NSArray *)arr {
    if (!cls || !arr) return nil;
    NSMutableArray *result = [NSMutableArray new];
    for (NSDictionary *dic in arr) {
        if (![dic isKindOfClass:[NSDictionary class]]) continue;
        NSObject *obj = [cls xx_modelWithDictionary:dic];
        if (obj) [result addObject:obj];
    }
    return result;
}

@end


@implementation NSDictionary (XXModel)

+ (NSDictionary *)xx_modelDictionaryWithClass:(Class)cls json:(id)json {
    if (!json) return nil;
    NSDictionary *dic = nil;
    NSData *jsonData = nil;
    if ([json isKindOfClass:[NSDictionary class]]) {
        dic = json;
    } else if ([json isKindOfClass:[NSString class]]) {
        jsonData = [(NSString *)json dataUsingEncoding : NSUTF8StringEncoding];
    } else if ([json isKindOfClass:[NSData class]]) {
        jsonData = json;
    }
    if (jsonData) {
        dic = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if (![dic isKindOfClass:[NSDictionary class]]) dic = nil;
    }
    return [self xx_modelDictionaryWithClass:cls dictionary:dic];
}

+ (NSDictionary *)xx_modelDictionaryWithClass:(Class)cls dictionary:(NSDictionary *)dic {
    if (!cls || !dic) return nil;
    NSMutableDictionary *result = [NSMutableDictionary new];
    for (NSString *key in dic.allKeys) {
        if (![key isKindOfClass:[NSString class]]) continue;
        NSObject *obj = [cls xx_modelWithDictionary:dic[key]];
        if (obj) result[key] = obj;
    }
    return result;
}

@end
