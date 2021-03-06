//
//  XXClassInfo.h
//  XXModel <https://github.com/ibireme/XXModel>
//
//  Created by ibireme on 15/5/9.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

#define XXMODEL_THREAD_ASSERT_ON_ERROR(x_) do { \
_Pragma("clang diagnostic push"); \
_Pragma("clang diagnostic ignored \"-Wunused-variable\""); \
volatile int res = (x_); \
assert(res == 0); \
_Pragma("clang diagnostic pop"); \
} while (0)

/**
 Type encoding's type.
 */
typedef NS_OPTIONS(NSUInteger, XXEncodingType) {
    XXEncodingTypeMask       = 0xFF, ///< mask of type value
    XXEncodingTypeUnknown    = 0, ///< unknown
    XXEncodingTypeVoid       = 1, ///< void
    XXEncodingTypeBool       = 2, ///< bool
    XXEncodingTypeInt8       = 3, ///< char / BOOL
    XXEncodingTypeUInt8      = 4, ///< unsigned char
    XXEncodingTypeInt16      = 5, ///< short
    XXEncodingTypeUInt16     = 6, ///< unsigned short
    XXEncodingTypeInt32      = 7, ///< int
    XXEncodingTypeUInt32     = 8, ///< unsigned int
    XXEncodingTypeInt64      = 9, ///< long long
    XXEncodingTypeUInt64     = 10, ///< unsigned long long
    XXEncodingTypeFloat      = 11, ///< float
    XXEncodingTypeDouble     = 12, ///< double
    XXEncodingTypeLongDouble = 13, ///< long double
    XXEncodingTypeObject     = 14, ///< id
    XXEncodingTypeClass      = 15, ///< Class
    XXEncodingTypeSEL        = 16, ///< SEL
    XXEncodingTypeBlock      = 17, ///< block
    XXEncodingTypePointer    = 18, ///< void*
    XXEncodingTypeStruct     = 19, ///< struct
    XXEncodingTypeUnion      = 20, ///< union
    XXEncodingTypeCString    = 21, ///< char*
    XXEncodingTypeCArray     = 22, ///< char[10] (for example)
    
    XXEncodingTypeQualifierMask   = 0xFF00,   ///< mask of qualifier
    XXEncodingTypeQualifierConst  = 1 << 8,  ///< const
    XXEncodingTypeQualifierIn     = 1 << 9,  ///< in
    XXEncodingTypeQualifierInout  = 1 << 10, ///< inout
    XXEncodingTypeQualifierOut    = 1 << 11, ///< out
    XXEncodingTypeQualifierBycopy = 1 << 12, ///< bycopy
    XXEncodingTypeQualifierByref  = 1 << 13, ///< byref
    XXEncodingTypeQualifierOneway = 1 << 14, ///< oneway
    
    XXEncodingTypePropertyMask         = 0xFF0000, ///< mask of property
    XXEncodingTypePropertyReadonly     = 1 << 16, ///< readonly
    XXEncodingTypePropertyCopy         = 1 << 17, ///< copy
    XXEncodingTypePropertyRetain       = 1 << 18, ///< retain
    XXEncodingTypePropertyNonatomic    = 1 << 19, ///< nonatomic
    XXEncodingTypePropertyWeak         = 1 << 20, ///< weak
    XXEncodingTypePropertyCustomGetter = 1 << 21, ///< getter=
    XXEncodingTypePropertyCustomSetter = 1 << 22, ///< setter=
    XXEncodingTypePropertyDynamic      = 1 << 23, ///< @dynamic
};

/**
 Get the type from a Type-Encoding string.
 
 @discussion See also:
 https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
 https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html
 
 @param typeEncoding  A Type-Encoding string.
 @return The encoding type.
 */
XXEncodingType XXEncodingGetType(const char *typeEncoding);


/**
 Instance variable information.
 */
@interface XXClassIvarInfo : NSObject
@property (nonatomic, assign, readonly) Ivar ivar;              ///< ivar opaque struct
@property (nonatomic, strong, readonly) NSString *name;         ///< Ivar's name
@property (nonatomic, assign, readonly) ptrdiff_t offset;       ///< Ivar's offset
@property (nonatomic, strong, readonly) NSString *typeEncoding; ///< Ivar's type encoding
@property (nonatomic, assign, readonly) XXEncodingType type;    ///< Ivar's type

/**
 Creates and returns an ivar info object.
 
 @param ivar ivar opaque struct
 @return A new object, or nil if an error occurs.
 */
- (instancetype)initWithIvar:(Ivar)ivar;
@end


/**
 Method information.
 */
@interface XXClassMethodInfo : NSObject
@property (nonatomic, assign, readonly) Method method;                  ///< method opaque struct
@property (nonatomic, strong, readonly) NSString *name;                 ///< method name
@property (nonatomic, assign, readonly) SEL sel;                        ///< method's selector
@property (nonatomic, assign, readonly) IMP imp;                        ///< method's implementation
@property (nonatomic, strong, readonly) NSString *typeEncoding;         ///< method's parameter and return types
@property (nonatomic, strong, readonly) NSString *returnTypeEncoding;   ///< return value's type
@property (nullable, nonatomic, strong, readonly) NSArray<NSString *> *argumentTypeEncodings; ///< array of arguments' type

/**
 Creates and returns a method info object.
 
 @param method method opaque struct
 @return A new object, or nil if an error occurs.
 */
- (instancetype)initWithMethod:(Method)method;
@end


/**
 Property information.
 */
@interface XXClassPropertyInfo : NSObject
@property (nonatomic, assign, readonly) objc_property_t property; ///< property's opaque struct
@property (nonatomic, strong, readonly) NSString *name;           ///< property's name
@property (nonatomic, assign, readonly) XXEncodingType type;      ///< property's type
@property (nonatomic, strong, readonly) NSString *typeEncoding;   ///< property's encoding value
@property (nonatomic, strong, readonly) NSString *ivarName;       ///< property's ivar name
@property (nullable, nonatomic, assign, readonly) Class cls;      ///< may be nil
@property (nullable, nonatomic, strong, readonly) NSArray<NSString*> *protocolNames; ///< may be nil
@property (nullable, nonatomic, assign, readonly) Class pseudoGenericCls; ///< may be nil
@property (nonatomic, assign, readonly) SEL getter;               ///< getter (nonnull)
@property (nonatomic, assign, readonly) SEL setter;               ///< setter (nonnull)

/**
 Creates and returns a property info object.
 
 @param property property opaque struct
 @return A new object, or nil if an error occurs.
 */
- (instancetype)initWithProperty:(objc_property_t)property;
@end


/**
 Class information for a class.
 */
@interface XXClassInfo : NSObject
@property (nonatomic, assign, readonly) Class cls; ///< class object
@property (nullable, nonatomic, assign, readonly) Class superCls; ///< super class object
@property (nullable, nonatomic, assign, readonly) Class metaCls;  ///< class's meta class object
@property (nonatomic, readonly) BOOL isMeta; ///< whether this class is meta class
@property (nonatomic, strong, readonly) NSString *name; ///< class name
@property (nullable, nonatomic, strong, readonly) XXClassInfo *superClassInfo; ///< super class's class info
@property (nullable, nonatomic, strong, readonly) NSDictionary<NSString *, XXClassIvarInfo *> *ivarInfos; ///< ivars
@property (nullable, nonatomic, strong, readonly) NSDictionary<NSString *, XXClassMethodInfo *> *methodInfos; ///< methods
@property (nullable, nonatomic, strong, readonly) NSDictionary<NSString *, XXClassPropertyInfo *> *propertyInfos; ///< properties

/**
 If the class is changed (for example: you add a method to this class with
 'class_addMethod()'), you should call this method to refresh the class info cache.
 
 After called this method, `needsUpdate` will returns `YES`, and you should call 
 'classInfoWithClass' or 'classInfoWithClassName' to get the updated class info.
 */
- (void)setNeedsUpdate;

/**
 If this method returns `YES`, you should stop using this instance and call
 `classInfoWithClass` or `classInfoWithClassName` to get the updated class info.
 
 @return Whether this class info need update.
 */
- (BOOL)needsUpdate;

/**
 Get the class info of a specified Class.
 
 @discussion This method will cache the class info and super-class info
 at the first access to the Class. This method is thread-safe.
 
 @param cls A class.
 @return A class info, or nil if an error occurs.
 */
+ (nullable instancetype)classInfoWithClass:(Class)cls;

/**
 Get the class info of a specified Class.
 
 @discussion This method will cache the class info and super-class info
 at the first access to the Class. This method is thread-safe.
 
 @param className A class name.
 @return A class info, or nil if an error occurs.
 */
+ (nullable instancetype)classInfoWithClassName:(NSString *)className;

@end

/**
 Provide some method to tell all property infos or whether a given property key is present in the class(or its superclass)
 */
@interface NSObject (XXClassInfo)

/**
 Returns a Boolean value that indicates whether a given property key is present in the class(or its superclass). The method will ignore the properties of [NSObject class].
 
 @param propertyKey a property key maybe exist
 
 @return YES if property key is present in the class, otherwise NO.
 */
+ (BOOL)xx_containsPropertyKey:(NSString*)propertyKey;

/**
 Returns a Boolean value that indicates whether a given property key is present in the class(or its superclass). The method will not ignore the properties of untilCls.
 
 @param propertyKey a property key maybe exist
 @param untilCls the last superclass which will be not ignored
 
 @return YES if property key is present in the class, otherwise NO.
 */
+ (BOOL)xx_containsPropertyKey:(NSString*)propertyKey untilClass:(Class)untilCls;

/**
 Returns a Boolean value that indicates whether a given property key is present in the class(or its superclass).
 
 @param propertyKey a property key maybe exist
 @param untilCls the last superclass which will be ignored or not
 @param ignoreUntilCls indicates whether the untilCls will be ignored
 
 @return YES if property key is present in the class, otherwise NO.
 */
+ (BOOL)xx_containsPropertyKey:(NSString*)propertyKey untilClass:(Class)untilCls ignoreUntilClass:(BOOL)ignoreUntilCls;

/**
 Returns all property infos in the class(or its superclass). The method will ignore the properties of [NSObject class].
 
 @return all property infos
 */
+ (nullable NSDictionary<NSString *, XXClassPropertyInfo *> *)xx_propertyInfos;

/**
 Returns all property infos in the class(or its superclass). The method will not ignore the properties of untilCls.
 
 @param untilCls the last superclass which will be not ignored
 
 @return all property infos
 */
+ (nullable NSDictionary<NSString *, XXClassPropertyInfo *> *)xx_propertyInfosUntilClass:(Class)untilCls;

/**
 Returns all property infos in the class(or its superclass).
 
 @param untilCls the last superclass which will be ignored or not
 @param ignoreUntilCls indicates whether the untilCls will be ignored
 
 @return all property infos
 */
+ (nullable NSDictionary<NSString *, XXClassPropertyInfo *> *)xx_propertyInfosUntilClass:(Class)untilCls ignoreUntilClass:(BOOL)ignoreUntilCls;

@end

NS_ASSUME_NONNULL_END
