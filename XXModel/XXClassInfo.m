//
//  XXClassInfo.m
//  XXModel <https://github.com/ibireme/XXModel>
//
//  Created by ibireme on 15/5/9.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "XXClassInfo.h"
#import <objc/runtime.h>
#import <pthread.h>

XXEncodingType XXEncodingGetType(const char *typeEncoding) {
    char *type = (char *)typeEncoding;
    if (!type) return XXEncodingTypeUnknown;
    size_t len = strlen(type);
    if (len == 0) return XXEncodingTypeUnknown;
    
    XXEncodingType qualifier = 0;
    bool prefix = true;
    while (prefix) {
        switch (*type) {
            case 'r': {
                qualifier |= XXEncodingTypeQualifierConst;
                type++;
            } break;
            case 'n': {
                qualifier |= XXEncodingTypeQualifierIn;
                type++;
            } break;
            case 'N': {
                qualifier |= XXEncodingTypeQualifierInout;
                type++;
            } break;
            case 'o': {
                qualifier |= XXEncodingTypeQualifierOut;
                type++;
            } break;
            case 'O': {
                qualifier |= XXEncodingTypeQualifierBycopy;
                type++;
            } break;
            case 'R': {
                qualifier |= XXEncodingTypeQualifierByref;
                type++;
            } break;
            case 'V': {
                qualifier |= XXEncodingTypeQualifierOneway;
                type++;
            } break;
            default: { prefix = false; } break;
        }
    }
    
    len = strlen(type);
    if (len == 0) return XXEncodingTypeUnknown | qualifier;
    
    switch (*type) {
        case 'v': return XXEncodingTypeVoid | qualifier;
        case 'B': return XXEncodingTypeBool | qualifier;
        case 'c': return XXEncodingTypeInt8 | qualifier;
        case 'C': return XXEncodingTypeUInt8 | qualifier;
        case 's': return XXEncodingTypeInt16 | qualifier;
        case 'S': return XXEncodingTypeUInt16 | qualifier;
        case 'i': return XXEncodingTypeInt32 | qualifier;
        case 'I': return XXEncodingTypeUInt32 | qualifier;
        case 'l': return XXEncodingTypeInt32 | qualifier;
        case 'L': return XXEncodingTypeUInt32 | qualifier;
        case 'q': return XXEncodingTypeInt64 | qualifier;
        case 'Q': return XXEncodingTypeUInt64 | qualifier;
        case 'f': return XXEncodingTypeFloat | qualifier;
        case 'd': return XXEncodingTypeDouble | qualifier;
        case 'D': return XXEncodingTypeLongDouble | qualifier;
        case '#': return XXEncodingTypeClass | qualifier;
        case ':': return XXEncodingTypeSEL | qualifier;
        case '*': return XXEncodingTypeCString | qualifier;
        case '^': return XXEncodingTypePointer | qualifier;
        case '[': return XXEncodingTypeCArray | qualifier;
        case '(': return XXEncodingTypeUnion | qualifier;
        case '{': return XXEncodingTypeStruct | qualifier;
        case '@': {
            if (len == 2 && *(type + 1) == '?')
                return XXEncodingTypeBlock | qualifier;
            else
                return XXEncodingTypeObject | qualifier;
        }
        default: return XXEncodingTypeUnknown | qualifier;
    }
}

@implementation XXClassIvarInfo

- (instancetype)initWithIvar:(Ivar)ivar {
    if (!ivar) return nil;
    self = [super init];
    _ivar = ivar;
    const char *name = ivar_getName(ivar);
    if (name) {
        _name = [NSString stringWithUTF8String:name];
    }
    _offset = ivar_getOffset(ivar);
    const char *typeEncoding = ivar_getTypeEncoding(ivar);
    if (typeEncoding) {
        _typeEncoding = [NSString stringWithUTF8String:typeEncoding];
        _type = XXEncodingGetType(typeEncoding);
    }
    return self;
}

@end

@implementation XXClassMethodInfo

- (instancetype)initWithMethod:(Method)method {
    if (!method) return nil;
    self = [super init];
    _method = method;
    _sel = method_getName(method);
    _imp = method_getImplementation(method);
    const char *name = sel_getName(_sel);
    if (name) {
        _name = [NSString stringWithUTF8String:name];
    }
    const char *typeEncoding = method_getTypeEncoding(method);
    if (typeEncoding) {
        _typeEncoding = [NSString stringWithUTF8String:typeEncoding];
    }
    char *returnType = method_copyReturnType(method);
    if (returnType) {
        _returnTypeEncoding = [NSString stringWithUTF8String:returnType];
        free(returnType);
    }
    unsigned int argumentCount = method_getNumberOfArguments(method);
    if (argumentCount > 0) {
        NSMutableArray *argumentTypes = [NSMutableArray new];
        for (unsigned int i = 0; i < argumentCount; i++) {
            char *argumentType = method_copyArgumentType(method, i);
            NSString *type = argumentType ? [NSString stringWithUTF8String:argumentType] : nil;
            [argumentTypes addObject:type ? type : @""];
            if (argumentType) free(argumentType);
        }
        _argumentTypeEncodings = argumentTypes;
    }
    return self;
}

@end

@implementation XXClassPropertyInfo

- (instancetype)initWithProperty:(objc_property_t)property {
    if (!property) return nil;
    self = [super init];
    _property = property;
    const char *name = property_getName(property);
    if (name) {
        _name = [NSString stringWithUTF8String:name];
    }
    
    XXEncodingType type = XXEncodingTypeUnknown;
    unsigned int attrCount;
    objc_property_attribute_t *attrs = property_copyAttributeList(property, &attrCount);
    for (unsigned int i = 0; i < attrCount; i++) {
        switch (attrs[i].name[0]) {
            case 'T': { // Type encoding
                if (attrs[i].value) {
                    _typeEncoding = [NSString stringWithUTF8String:attrs[i].value];
                    type = XXEncodingGetType(attrs[i].value);
                    if ((type & XXEncodingTypeMask) == XXEncodingTypeObject && _typeEncoding.length > 0) {
                        size_t len = strlen(attrs[i].value);
                        if (len > 3) {
                            len = len - 3 + 1;
                            char clsName[len];
                            clsName[len - 1] = '\0';
                            memcpy(clsName, attrs[i].value + 2, len - 1);
                            
                            //It has protocols if the final char is >.
                            //if multi protocols, the clsName maybe is NSMutableArray<Pig><Dog><Cat>
                            if (clsName[len - 2] == '>') {
                                clsName[len - 2] = '\0';
                                char *p = strchr(clsName, '<');
                                if (p != NULL) {
                                    p[0] = '\0';
                                    _cls = objc_getClass(clsName);
                                    
                                    p++;
                                    //p maybe contain multi protocol names. maybe is Pig><Dog><Cat
                                    //and if one protocol is not adopted(or used), objc_getProtocol(p) would return nil
                                    //see http://stackoverflow.com/questions/10212119/objc-getprotocol-returns-null-for-nsapplicationdelegate
                                    //so we just record the protocol names
                                    NSString *pNames = [NSString stringWithUTF8String:p];
                                    _protocolNames = [pNames componentsSeparatedByString:@"><"];
                                    
                                    //pseudo generic class
                                    for (NSString *protocol in _protocolNames) {
                                        Class cls = objc_getClass(protocol.UTF8String);
                                        if (cls) {
                                            _pseudoGenericCls = cls;
                                            break;
                                        }
                                    }
                                }
                            }else{
                                _cls = objc_getClass(clsName);
                            }
                            
                            NSAssert((_cls!=nil&&strlen(clsName)>0)||(_cls==nil&&strlen(clsName)<=0), @"Error: Class %s maybe has not a implementation",clsName);
                        }
                    }
                }
            } break;
            case 'V': { // Instance variable
                if (attrs[i].value) {
                    _ivarName = [NSString stringWithUTF8String:attrs[i].value];
                }
            } break;
            case 'R': {
                type |= XXEncodingTypePropertyReadonly;
            } break;
            case 'C': {
                type |= XXEncodingTypePropertyCopy;
            } break;
            case '&': {
                type |= XXEncodingTypePropertyRetain;
            } break;
            case 'N': {
                type |= XXEncodingTypePropertyNonatomic;
            } break;
            case 'D': {
                type |= XXEncodingTypePropertyDynamic;
            } break;
            case 'W': {
                type |= XXEncodingTypePropertyWeak;
            } break;
            case 'G': {
                type |= XXEncodingTypePropertyCustomGetter;
                if (attrs[i].value) {
                    _getter = NSSelectorFromString([NSString stringWithUTF8String:attrs[i].value]);
                }
            } break;
            case 'S': {
                type |= XXEncodingTypePropertyCustomSetter;
                if (attrs[i].value) {
                    _setter = NSSelectorFromString([NSString stringWithUTF8String:attrs[i].value]);
                }
            } // break; commented for code coverage in next line
            default: break;
        }
    }
    if (attrs) {
        free(attrs);
        attrs = NULL;
    }
    
    _type = type;
    if (_name.length) {
        if (!_getter) {
            _getter = NSSelectorFromString(_name);
        }
        if (!_setter) {
            _setter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:", [_name substringToIndex:1].uppercaseString, [_name substringFromIndex:1]]);
        }
    }
    return self;
}

@end

@implementation XXClassInfo {
    BOOL _needsUpdate;
}

- (instancetype)initWithClass:(Class)cls {
    if (!cls) return nil;
    self = [super init];
    _cls = cls;
    _superCls = class_getSuperclass(cls);
    _isMeta = class_isMetaClass(cls);
    if (!_isMeta) {
        _metaCls = objc_getMetaClass(class_getName(cls));
    }
    _name = NSStringFromClass(cls);
    [self _update];
    
    _superClassInfo = [self.class classInfoWithClass:_superCls];
    return self;
}

- (void)_update {
    _ivarInfos = nil;
    _methodInfos = nil;
    _propertyInfos = nil;
    
    Class cls = self.cls;
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    if (methods) {
        NSMutableDictionary *methodInfos = [NSMutableDictionary new];
        _methodInfos = methodInfos;
        for (unsigned int i = 0; i < methodCount; i++) {
            XXClassMethodInfo *info = [[XXClassMethodInfo alloc] initWithMethod:methods[i]];
            if (info.name) methodInfos[info.name] = info;
        }
        free(methods);
    }
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
    if (properties) {
        NSMutableDictionary *propertyInfos = [NSMutableDictionary new];
        _propertyInfos = propertyInfos;
        for (unsigned int i = 0; i < propertyCount; i++) {
            XXClassPropertyInfo *info = [[XXClassPropertyInfo alloc] initWithProperty:properties[i]];
            if (info.name) propertyInfos[info.name] = info;
        }
        free(properties);
    }
    
    unsigned int ivarCount = 0;
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);
    if (ivars) {
        NSMutableDictionary *ivarInfos = [NSMutableDictionary new];
        _ivarInfos = ivarInfos;
        for (unsigned int i = 0; i < ivarCount; i++) {
            XXClassIvarInfo *info = [[XXClassIvarInfo alloc] initWithIvar:ivars[i]];
            if (info.name) ivarInfos[info.name] = info;
        }
        free(ivars);
    }
    
    if (!_ivarInfos) _ivarInfos = @{};
    if (!_methodInfos) _methodInfos = @{};
    if (!_propertyInfos) _propertyInfos = @{};
    
    _needsUpdate = NO;
}

static CFMutableDictionaryRef xxmodel_classCache;
static CFMutableDictionaryRef xxmodel_metaCache;
static pthread_rwlock_t xxmodel_rwlock;

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        xxmodel_classCache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        xxmodel_metaCache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        XXMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_init(&xxmodel_rwlock, NULL));
    });
}

- (void)setNeedsUpdate {
    XXMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_wrlock(&xxmodel_rwlock));
    _needsUpdate = YES;
    XXMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_unlock(&xxmodel_rwlock));
}

- (BOOL)needsUpdate {
    XXMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_rdlock(&xxmodel_rwlock));
    BOOL needsUpdate = _needsUpdate;
    XXMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_unlock(&xxmodel_rwlock));
    return needsUpdate;
}

+ (instancetype)classInfoWithClass:(Class)cls {
    if (!cls) return nil;
    
    XXMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_rdlock(&xxmodel_rwlock));
    XXClassInfo *info = CFDictionaryGetValue(class_isMetaClass(cls) ? xxmodel_metaCache : xxmodel_classCache, (__bridge const void *)(cls));
    BOOL needsUpdate = info && info->_needsUpdate;
    XXMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_unlock(&xxmodel_rwlock));
    
    if (needsUpdate) {
        XXMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_wrlock(&xxmodel_rwlock));
        if (info->_needsUpdate) {
            [info _update];
        }
        XXMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_unlock(&xxmodel_rwlock));
    }else if (!info) {
        info = [[XXClassInfo alloc] initWithClass:cls];
        XXMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_wrlock(&xxmodel_rwlock));
        XXClassInfo *infoInCache = CFDictionaryGetValue(class_isMetaClass(cls) ? xxmodel_metaCache : xxmodel_classCache, (__bridge const void *)(cls));
        if (!infoInCache) {
            if (info) {
                CFDictionarySetValue(info.isMeta ? xxmodel_metaCache : xxmodel_classCache, (__bridge const void *)(cls), (__bridge const void *)(info));
            }
        }else{
            info = infoInCache;
        }
        XXMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_unlock(&xxmodel_rwlock));
    }
    return info;
}

+ (instancetype)classInfoWithClassName:(NSString *)className {
    Class cls = NSClassFromString(className);
    return [self classInfoWithClass:cls];
}

@end

@implementation NSObject (XXClassInfo)

+ (BOOL)xx_containsPropertyKey:(NSString*)propertyKey {
    return [self xx_containsPropertyKey:propertyKey untilClass:[NSObject class] ignoreUntilClass:YES];
}

+ (BOOL)xx_containsPropertyKey:(NSString*)propertyKey untilClass:(Class)untilCls {
    return [self xx_containsPropertyKey:propertyKey untilClass:untilCls ignoreUntilClass:NO];
}

+ (BOOL)xx_containsPropertyKey:(NSString*)propertyKey untilClass:(Class)untilCls ignoreUntilClass:(BOOL)ignoreUntilCls {
    NSDictionary<NSString *, XXClassPropertyInfo *> *propertyInfos = [self xx_propertyInfosUntilClass:untilCls ignoreUntilClass:ignoreUntilCls];
    return (propertyInfos[propertyKey]!=nil);
}

+ (NSDictionary<NSString *, XXClassPropertyInfo *> *)xx_propertyInfos {
    return [self xx_propertyInfosUntilClass:[NSObject class] ignoreUntilClass:YES];
}

+ (NSDictionary<NSString *, XXClassPropertyInfo *> *)xx_propertyInfosUntilClass:(Class)untilCls {
    return [self xx_propertyInfosUntilClass:untilCls ignoreUntilClass:NO];
}

+ (NSDictionary<NSString *, XXClassPropertyInfo *> *)xx_propertyInfosUntilClass:(Class)untilCls ignoreUntilClass:(BOOL)ignoreUntilCls {
    NSAssert(untilCls, @"The `cls` param of xx_propertyInfosUntilClass:ignoreUntilClass: cant be nil!");
    NSAssert([[self class] isSubclassOfClass:untilCls], @"%@ is not the subclass of %@",NSStringFromClass([self class]),NSStringFromClass(untilCls));
    
    XXClassInfo *classInfo = [XXClassInfo classInfoWithClass:[self class]];
    if (!classInfo) return nil;
    
    NSMutableDictionary<NSString *, XXClassPropertyInfo *> *allPropertyInfos = [NSMutableDictionary<NSString *, XXClassPropertyInfo *> dictionary];
    Class ignoreClass = ignoreUntilCls?untilCls:[untilCls superclass];//if cls is [NSObject class],its superclass is nil
    
    XXClassInfo *curClassInfo = classInfo;
    while (curClassInfo && curClassInfo.cls != ignoreClass) {
        for (XXClassPropertyInfo *propertyInfo in curClassInfo.propertyInfos.allValues) {
            if (!propertyInfo.name || allPropertyInfos[propertyInfo.name]) continue; //If contains the same key, subclass is preferred.
            allPropertyInfos[propertyInfo.name] = propertyInfo;
        }
        curClassInfo = curClassInfo.superClassInfo;
    }
    
    return allPropertyInfos.count>0?allPropertyInfos:nil;
}

@end
