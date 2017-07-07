//
//  YYClassInfo.m
//  YYModel <https://github.com/ibireme/YYModel>
//
//  Created by ibireme on 15/5/9.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "YYClassInfo.h"
#import <objc/runtime.h>
#import <pthread.h>

YYEncodingType YYEncodingGetType(const char *typeEncoding) {
    char *type = (char *)typeEncoding;
    if (!type) return YYEncodingTypeUnknown;
    size_t len = strlen(type);
    if (len == 0) return YYEncodingTypeUnknown;
    
    YYEncodingType qualifier = 0;
    bool prefix = true;
    while (prefix) {
        switch (*type) {
            case 'r': {
                qualifier |= YYEncodingTypeQualifierConst;
                type++;
            } break;
            case 'n': {
                qualifier |= YYEncodingTypeQualifierIn;
                type++;
            } break;
            case 'N': {
                qualifier |= YYEncodingTypeQualifierInout;
                type++;
            } break;
            case 'o': {
                qualifier |= YYEncodingTypeQualifierOut;
                type++;
            } break;
            case 'O': {
                qualifier |= YYEncodingTypeQualifierBycopy;
                type++;
            } break;
            case 'R': {
                qualifier |= YYEncodingTypeQualifierByref;
                type++;
            } break;
            case 'V': {
                qualifier |= YYEncodingTypeQualifierOneway;
                type++;
            } break;
            default: { prefix = false; } break;
        }
    }
    
    len = strlen(type);
    if (len == 0) return YYEncodingTypeUnknown | qualifier;
    
    switch (*type) {
        case 'v': return YYEncodingTypeVoid | qualifier;
        case 'B': return YYEncodingTypeBool | qualifier;
        case 'c': return YYEncodingTypeInt8 | qualifier;
        case 'C': return YYEncodingTypeUInt8 | qualifier;
        case 's': return YYEncodingTypeInt16 | qualifier;
        case 'S': return YYEncodingTypeUInt16 | qualifier;
        case 'i': return YYEncodingTypeInt32 | qualifier;
        case 'I': return YYEncodingTypeUInt32 | qualifier;
        case 'l': return YYEncodingTypeInt32 | qualifier;
        case 'L': return YYEncodingTypeUInt32 | qualifier;
        case 'q': return YYEncodingTypeInt64 | qualifier;
        case 'Q': return YYEncodingTypeUInt64 | qualifier;
        case 'f': return YYEncodingTypeFloat | qualifier;
        case 'd': return YYEncodingTypeDouble | qualifier;
        case 'D': return YYEncodingTypeLongDouble | qualifier;
        case '#': return YYEncodingTypeClass | qualifier;
        case ':': return YYEncodingTypeSEL | qualifier;
        case '*': return YYEncodingTypeCString | qualifier;
        case '^': return YYEncodingTypePointer | qualifier;
        case '[': return YYEncodingTypeCArray | qualifier;
        case '(': return YYEncodingTypeUnion | qualifier;
        case '{': return YYEncodingTypeStruct | qualifier;
        case '@': {
            if (len == 2 && *(type + 1) == '?')
                return YYEncodingTypeBlock | qualifier;
            else
                return YYEncodingTypeObject | qualifier;
        }
        default: return YYEncodingTypeUnknown | qualifier;
    }
}

@implementation YYClassIvarInfo

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
        _type = YYEncodingGetType(typeEncoding);
    }
    return self;
}

@end

@implementation YYClassMethodInfo

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

@implementation YYClassPropertyInfo

- (instancetype)initWithProperty:(objc_property_t)property {
    if (!property) return nil;
    self = [super init];
    _property = property;
    const char *name = property_getName(property);
    if (name) {
        _name = [NSString stringWithUTF8String:name];
    }
    
    YYEncodingType type = YYEncodingTypeUnknown;
    unsigned int attrCount;
    objc_property_attribute_t *attrs = property_copyAttributeList(property, &attrCount);
    for (unsigned int i = 0; i < attrCount; i++) {
        switch (attrs[i].name[0]) {
            case 'T': { // Type encoding
                if (attrs[i].value) {
                    _typeEncoding = [NSString stringWithUTF8String:attrs[i].value];
                    type = YYEncodingGetType(attrs[i].value);
                    if ((type & YYEncodingTypeMask) == YYEncodingTypeObject && _typeEncoding.length > 0) {
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
                type |= YYEncodingTypePropertyReadonly;
            } break;
            case 'C': {
                type |= YYEncodingTypePropertyCopy;
            } break;
            case '&': {
                type |= YYEncodingTypePropertyRetain;
            } break;
            case 'N': {
                type |= YYEncodingTypePropertyNonatomic;
            } break;
            case 'D': {
                type |= YYEncodingTypePropertyDynamic;
            } break;
            case 'W': {
                type |= YYEncodingTypePropertyWeak;
            } break;
            case 'G': {
                type |= YYEncodingTypePropertyCustomGetter;
                if (attrs[i].value) {
                    _getter = NSSelectorFromString([NSString stringWithUTF8String:attrs[i].value]);
                }
            } break;
            case 'S': {
                type |= YYEncodingTypePropertyCustomSetter;
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

@implementation YYClassInfo {
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
            YYClassMethodInfo *info = [[YYClassMethodInfo alloc] initWithMethod:methods[i]];
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
            YYClassPropertyInfo *info = [[YYClassPropertyInfo alloc] initWithProperty:properties[i]];
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
            YYClassIvarInfo *info = [[YYClassIvarInfo alloc] initWithIvar:ivars[i]];
            if (info.name) ivarInfos[info.name] = info;
        }
        free(ivars);
    }
    
    if (!_ivarInfos) _ivarInfos = @{};
    if (!_methodInfos) _methodInfos = @{};
    if (!_propertyInfos) _propertyInfos = @{};
    
    _needsUpdate = NO;
}

static CFMutableDictionaryRef yymodel_classCache;
static CFMutableDictionaryRef yymodel_metaCache;
static pthread_rwlock_t yymodel_rwlock;

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        yymodel_classCache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        yymodel_metaCache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        YYMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_init(&yymodel_rwlock, NULL));
    });
}

- (void)setNeedsUpdate {
    YYMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_wrlock(&yymodel_rwlock));
    _needsUpdate = YES;
    YYMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_unlock(&yymodel_rwlock));
}

- (BOOL)needsUpdate {
    YYMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_rdlock(&yymodel_rwlock));
    BOOL needsUpdate = _needsUpdate;
    YYMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_unlock(&yymodel_rwlock));
    return needsUpdate;
}

+ (instancetype)classInfoWithClass:(Class)cls {
    if (!cls) return nil;
    
    YYMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_rdlock(&yymodel_rwlock));
    YYClassInfo *info = CFDictionaryGetValue(class_isMetaClass(cls) ? yymodel_metaCache : yymodel_classCache, (__bridge const void *)(cls));
    BOOL needsUpdate = info && info->_needsUpdate;
    YYMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_unlock(&yymodel_rwlock));
    
    if (needsUpdate) {
        YYMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_wrlock(&yymodel_rwlock));
        if (info->_needsUpdate) {
            [info _update];
        }
        YYMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_unlock(&yymodel_rwlock));
    }else if (!info) {
        info = [[YYClassInfo alloc] initWithClass:cls];
        YYMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_wrlock(&yymodel_rwlock));
        YYClassInfo *infoInCache = CFDictionaryGetValue(class_isMetaClass(cls) ? yymodel_metaCache : yymodel_classCache, (__bridge const void *)(cls));
        if (!infoInCache) {
            if (info) {
                CFDictionarySetValue(info.isMeta ? yymodel_metaCache : yymodel_classCache, (__bridge const void *)(cls), (__bridge const void *)(info));
            }
        }else{
            info = infoInCache;
        }
        YYMODEL_THREAD_ASSERT_ON_ERROR(pthread_rwlock_unlock(&yymodel_rwlock));
    }
    return info;
}

+ (instancetype)classInfoWithClassName:(NSString *)className {
    Class cls = NSClassFromString(className);
    return [self classInfoWithClass:cls];
}

@end

@implementation NSObject (YYClassInfo)

+ (BOOL)yy_containsPropertyKey:(NSString*)propertyKey {
    return [self yy_containsPropertyKey:propertyKey untilClass:[NSObject class] ignoreUntilClass:YES];
}

+ (BOOL)yy_containsPropertyKey:(NSString*)propertyKey untilClass:(Class)untilCls {
    return [self yy_containsPropertyKey:propertyKey untilClass:untilCls ignoreUntilClass:NO];
}

+ (BOOL)yy_containsPropertyKey:(NSString*)propertyKey untilClass:(Class)untilCls ignoreUntilClass:(BOOL)ignoreUntilCls {
    NSDictionary<NSString *, YYClassPropertyInfo *> *propertyInfos = [self yy_propertyInfosUntilClass:untilCls ignoreUntilClass:ignoreUntilCls];
    return (propertyInfos[propertyKey]!=nil);
}

+ (NSDictionary<NSString *, YYClassPropertyInfo *> *)yy_propertyInfos {
    return [self yy_propertyInfosUntilClass:[NSObject class] ignoreUntilClass:YES];
}

+ (NSDictionary<NSString *, YYClassPropertyInfo *> *)yy_propertyInfosUntilClass:(Class)untilCls {
    return [self yy_propertyInfosUntilClass:untilCls ignoreUntilClass:NO];
}

+ (NSDictionary<NSString *, YYClassPropertyInfo *> *)yy_propertyInfosUntilClass:(Class)untilCls ignoreUntilClass:(BOOL)ignoreUntilCls {
    NSAssert(untilCls, @"The `cls` param of yy_propertyInfosUntilClass:ignoreUntilClass: cant be nil!");
    NSAssert([[self class] isSubclassOfClass:untilCls], @"%@ is not the subclass of %@",NSStringFromClass([self class]),NSStringFromClass(untilCls));
    
    YYClassInfo *classInfo = [YYClassInfo classInfoWithClass:[self class]];
    if (!classInfo) return nil;
    
    NSMutableDictionary<NSString *, YYClassPropertyInfo *> *allPropertyInfos = [NSMutableDictionary<NSString *, YYClassPropertyInfo *> dictionary];
    Class ignoreClass = ignoreUntilCls?untilCls:[untilCls superclass];//if cls is [NSObject class],its superclass is nil
    
    YYClassInfo *curClassInfo = classInfo;
    while (curClassInfo && curClassInfo.cls != ignoreClass) {
        for (YYClassPropertyInfo *propertyInfo in curClassInfo.propertyInfos.allValues) {
            if (!propertyInfo.name || allPropertyInfos[propertyInfo.name]) continue; //If contains the same key, subclass is preferred.
            allPropertyInfos[propertyInfo.name] = propertyInfo;
        }
        curClassInfo = curClassInfo.superClassInfo;
    }
    
    return allPropertyInfos.count>0?allPropertyInfos:nil;
}

@end
