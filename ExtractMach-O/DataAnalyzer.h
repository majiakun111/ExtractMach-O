//
//  DataAnalyzer.h
//  ExtractMach-O
//
//  Created by Ansel on 2019/6/21.
//  Copyright © 2019年 Ansel. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ClassWrapper : NSObject

@property(nonatomic, copy) NSString *className;
@property(nonatomic, assign) BOOL isEmpty; //没IvarLayout BaseMethods BaseProtocols WeakIvarLayout baseProperties
@property(nonatomic, assign) BOOL isUsed;
@property(nonatomic, strong) NSMutableArray<ClassWrapper *> *childClassWrappers;

@end

@interface ClassInfoDataStruct : NSObject

@property(nonatomic, copy) NSArray<NSString *> *classNames;
@property(nonatomic, copy) NSDictionary<NSString*, ClassWrapper *> *classWrapperMap; //key是classname

@end

@interface MethodWrapper : NSObject

@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *detailName; //[Student hello]

@end

@interface UnusedDataStruct : NSObject

@property(nonatomic, strong) NSArray<ClassWrapper *> *unusedClasses;
@property(nonatomic, strong) NSArray<NSString *> *unusedMethods;

@end

@interface DataAnalyzer : NSObject

- (instancetype)initWithDataSegmentPath:(NSString *)dataSegmentPath methodRefsPath:(NSString *)methodRefsPath NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)getUnusedDataStructCallback:(void(^)(UnusedDataStruct *unusedDataStruct))callback;

@end

NS_ASSUME_NONNULL_END
