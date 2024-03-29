//
//  DataAnalyzer.m
//  ExtractMach-O
//
//  Created by Ansel on 2019/6/21.
//  Copyright © 2019年 Ansel. All rights reserved.
//

#import "DataAnalyzer.h"

static NSString * const EmptyData = @"0x0";

@implementation ClassWrapper

- (NSString *)description {
    //return [NSString stringWithFormat:@"className:%@, isUsed:%@, isEmpty:%@", self.className, self.isUsed ? @"YES" : @"NO", self.isEmpty ? @"YES" : @"NO"];
    return [NSString stringWithFormat:@"%@", self.className];
}

@end

@implementation ClassInfoDataStruct

@end

@implementation MethodWrapper

@end

@implementation UnusedDataStruct

@end

@interface DataAnalyzer ()

@property(nonatomic, copy) NSString *dataSegmentPath;
@property(nonatomic, copy) NSString *methodRefsPath;

@end

@implementation DataAnalyzer

- (instancetype)initWithDataSegmentPath:(NSString *)dataSegmentPath methodRefsPath:(NSString *)methodRefsPath {
    self = [super init];
    if (self) {
        self.dataSegmentPath = dataSegmentPath;
        self.methodRefsPath = methodRefsPath;
    }
    
    return self;
}

- (void)getUnusedDataStructCallback:(void(^)(UnusedDataStruct *unusedDataStruct))callback {
    if (!callback) {
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *dataSegmentString = [NSString stringWithContentsOfFile:self.dataSegmentPath encoding:NSUTF8StringEncoding error:nil];
        ClassInfoDataStruct *classInfoDataStruct = [self getClassInfoDataStructWithString:dataSegmentString];
        
        NSArray<ClassWrapper *> *unusedClasses = [self getUnusedClassesWithDataSegmentString:dataSegmentString classInfoDataStruct:classInfoDataStruct];
        NSArray<NSString *> *unusedMethods =[self getUnusedMethodsWithDataSegmentString:dataSegmentString classInfoDataStruct:classInfoDataStruct];
        
        classInfoDataStruct = nil;
        
        UnusedDataStruct *unusedDataStruct = [[UnusedDataStruct alloc] init];
        unusedDataStruct.unusedClasses = unusedClasses;
        unusedDataStruct.unusedMethods = unusedMethods;
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(unusedDataStruct);
        });
    });
}

-  (NSArray<ClassWrapper *> *)getUnusedClassesWithDataSegmentString:(NSString *)dataSegmentString classInfoDataStruct:(ClassInfoDataStruct *)classInfoDataStruct {
    NSSet<NSString *> *classrefs = [self getClassrefsWithString:dataSegmentString];
    NSArray<ClassWrapper *> *unusedClasses = [self getUnusedClassesWithClassrefs:classrefs classInfoDataStruct:classInfoDataStruct];
    
    return unusedClasses;
}

-  (NSArray<NSString *> *)getUnusedMethodsWithDataSegmentString:(NSString *)dataSegmentString classInfoDataStruct:(ClassInfoDataStruct *)classInfoDataStruct {
    NSMutableArray<NSString *> *unusedMethods = @[].mutableCopy;
    NSSet<NSString *> *selrefs = [self getMethodRefs];
    NSArray<MethodWrapper *> *methodWrappers = [self getAllMethodsWithDataSegmentString:dataSegmentString];
    [methodWrappers enumerateObjectsUsingBlock:^(MethodWrapper * _Nonnull methodWrapper, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([selrefs containsObject:methodWrapper.methodName]) {
            return;
        }
        
        //set get方法
        ClassWrapper *classWrapper = [classInfoDataStruct.classWrapperMap objectForKey:methodWrapper.className];
        NSString *propertyName = methodWrapper.methodName;
        NSString *specialPropertyName = nil; //大写字母开头的属性
//        if ([methodWrapper.methodName hasPrefix:@"set"] && [methodWrapper.methodName hasSuffix:@":"]) {
//            propertyName = [propertyName stringByReplacingOccurrencesOfString:@"set" withString:@""];
//            propertyName = [propertyName stringByReplacingOccurrencesOfString:@":" withString:@""];
//            specialPropertyName = propertyName;
//            //处理小写字母开头的属性
//            if ([propertyName length] >= 1) {
//                NSString *firstName = [[propertyName substringToIndex:1] lowercaseString];
//                if ([propertyName length] < 2) {
//                    propertyName = firstName;
//                } else {
//                    propertyName = [NSString stringWithFormat:@"%@%@", firstName, [propertyName substringFromIndex:1]];
//                }
//            }
//        }
        
        BOOL isProperty = [classWrapper.propertyNames containsObject:propertyName] || [classWrapper.propertyNames containsObject:specialPropertyName];
        if (self.methodCategory == MethodCategoryExcludeSettrAndGetter && isProperty) {//过滤掉set get方法
            return;
        } else if (self.methodCategory == MethodCategorySettrAndGetter && !isProperty) {//只保留set get 方法
            return;
        }

        if (!self.filterBlock) {
            [unusedMethods addObject:methodWrapper.detailName];
            return;
        }
        
        if (self.filterBlock(methodWrapper.className)) {
            [unusedMethods addObject:methodWrapper.detailName];
        }
    }];
    
    return unusedMethods;
}

#pragma mark - PrivateMethod

-  (ClassInfoDataStruct *)getClassInfoDataStructWithString:(NSString *)string {
    NSRange range = [string rangeOfString:@"Contents of (__DATA,__objc_classlist) section" options:NSCaseInsensitiveSearch];
    if (range.location == NSNotFound) {
        return nil;
    }
    NSString *infosString = [string substringFromIndex:range.location + range.length];
    NSRange endRange = [infosString rangeOfString:@"Contents of" options:NSCaseInsensitiveSearch];
    infosString = [infosString substringToIndex:endRange.location];
    infosString = [infosString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray<NSString *> *lines = [infosString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    //只保存当前的class name不保存super的 保证同一个pod的class一块
    NSMutableArray<NSString *> *classNames = @[].mutableCopy;
    //及保存当前的class name也保存super的
    NSMutableDictionary<NSString *, ClassWrapper *> *classWrapperMap = @{}.mutableCopy;
    __block ClassWrapper *classWrapper = nil;
    __block ClassWrapper *superClassWrapper = nil;
    __block BOOL isEmpty = YES;
    __block BOOL analyzeBasePropertiesing = NO;
    [lines enumerateObjectsUsingBlock:^(NSString * _Nonnull line, NSUInteger idx, BOOL * _Nonnull stop) {
        line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([line containsString:@"_OBJC_CLASS_$_"]) { //
            NSString *className = [[[line componentsSeparatedByString:@" "] lastObject] stringByReplacingOccurrencesOfString:@"_OBJC_CLASS_$_" withString:@""];
            if (![line containsString:@"superclass"]) { //以包含_OBJC_CLASS_$_但不包含superclass 来划分class
                //处理上一个的 classWrapper
                classWrapper.isEmpty = isEmpty;
                isEmpty = YES;
                
                //当前的
                [classNames addObject:className];
                classWrapper = [classWrapperMap objectForKey:className];
                if (classWrapper) {
                    return;
                }
                
                classWrapper = [[ClassWrapper alloc] init];
                classWrapper.className = className;
                [classWrapperMap setObject:classWrapper forKey:className];
            } else {
                superClassWrapper = [classWrapperMap objectForKey:className];
                if (!superClassWrapper) {
                    superClassWrapper = [[ClassWrapper alloc] init];
                    superClassWrapper.className = className;
                    superClassWrapper.childClassWrappers = @[classWrapper].mutableCopy;
                    [classWrapperMap setObject:superClassWrapper forKey:className];
                } else {
                    if (!superClassWrapper.childClassWrappers) {
                        superClassWrapper.childClassWrappers = @[classWrapper].mutableCopy;
                    } else {
                        [superClassWrapper.childClassWrappers addObject:classWrapper];
                    }
                }
            }
        }
        
        //class 和 meta class 都有描述
        if (isEmpty && ([line containsString:@"ivarLayout"] ||
                        [line containsString:@"baseMethods"] ||
                        [line containsString:@"baseProtocols"] ||
                        [line containsString:@"weakIvarLayout"] ||
                        [line containsString:@"baseProperties"])) {
            //比如 baseMethods 0x0 (struct method_list_t *)
            isEmpty = [[[line componentsSeparatedByString:@" "] objectAtIndex:1] isEqualToString:EmptyData];
        }
        
        if ([line containsString:@"baseProperties"]) {
            analyzeBasePropertiesing = YES;
            classWrapper.propertyNames = @[].mutableCopy;
        }
        
        //处理baseProperties
        if ([line containsString:@"baseProperties"]) {
            
        }
        if ([line containsString:@"Meta Class"]) {
            analyzeBasePropertiesing = NO;
        }
        
        if (analyzeBasePropertiesing && [line containsString:@"name"]) {
            line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString *propertyName = [[line componentsSeparatedByString:@" "] lastObject];
            [classWrapper.propertyNames addObject:propertyName];
        }
    }];
    
    ClassInfoDataStruct *classInfoDataStruct = [[ClassInfoDataStruct alloc] init];
    classInfoDataStruct.classNames = classNames;
    classInfoDataStruct.classWrapperMap = classWrapperMap;
    
    return classInfoDataStruct;
}

-  (NSSet<NSString *> *)getClassrefsWithString:(NSString *)string {
    NSRange range = [string rangeOfString:@"Contents of (__DATA,__objc_classrefs) section" options:NSCaseInsensitiveSearch];
    if (range.location == NSNotFound) {
        return nil;
    }
    NSString *classrefsString = [string substringFromIndex:range.location + range.length];
    NSRange endRange = [classrefsString rangeOfString:@"Contents of" options:NSCaseInsensitiveSearch];
    classrefsString = [classrefsString substringToIndex:endRange.location];
    classrefsString = [classrefsString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    NSArray<NSString *> *lines = [classrefsString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableSet<NSString *> *classrefs  = @[].mutableCopy;
    [lines enumerateObjectsUsingBlock:^(NSString * _Nonnull line, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *classref = [[line componentsSeparatedByString:@" "] lastObject];
        classref = [classref stringByReplacingOccurrencesOfString:@"_OBJC_CLASS_$_" withString:@""];
        [classrefs addObject:classref];
    }];
    
    return classrefs;
}

-  (BOOL)judgeChildrenOfClassWrapper:(ClassWrapper *)classWrapper inClassrefs:(NSSet<NSString *> *)classrefs {
    __block BOOL isContain = NO;
    [classWrapper.childClassWrappers enumerateObjectsUsingBlock:^(ClassWrapper * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([classrefs containsObject:obj.className]) {
            isContain = YES;
            *stop = YES;
            return;
        }
        
        if ([obj.childClassWrappers count] > 0) {
            isContain = [self judgeChildrenOfClassWrapper:obj inClassrefs:classrefs];
        }
    }];
    
    return isContain;
}

-  (NSArray<ClassWrapper *> *)getUnusedClassesWithClassrefs:(NSSet<NSString *> *)classrefs classInfoDataStruct:(ClassInfoDataStruct *)classInfoDataStruct {
    NSMutableArray<ClassWrapper *> *exceptClasses = @[].mutableCopy;
    [classInfoDataStruct.classNames enumerateObjectsUsingBlock:^(NSString * _Nonnull className, NSUInteger idx, BOOL * _Nonnull stop) {
        ClassWrapper *classWrapper = [classInfoDataStruct.classWrapperMap objectForKey:className];
        if ([classrefs containsObject:classWrapper.className] || [self judgeChildrenOfClassWrapper:classWrapper inClassrefs:classrefs]) {
            classWrapper.isUsed = YES;
            
            if (!classWrapper.isEmpty) {
                return;
            }
            
            return;
        }
        
        if (!self.filterBlock) {
            [exceptClasses addObject:classWrapper];
            return;
        }
        
        if (self.filterBlock(classWrapper.className)) {
            [exceptClasses addObject:classWrapper];
        }
    }];
    
    return exceptClasses;
}

- (NSSet<NSString *> *)getMethodRefs {
    NSString *methodRefsString = [NSString stringWithContentsOfFile:self.methodRefsPath encoding:NSUTF8StringEncoding error:nil];
    NSArray<NSString *> *lines = [methodRefsString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableSet<NSString *> *methodRefs = [[NSMutableSet alloc] init];
    NSString *methodDescripation = @"__RODATA:__objc_methname:";
    [lines enumerateObjectsUsingBlock:^(NSString * _Nonnull line, NSUInteger idx, BOOL * _Nonnull stop) {
        if (![line containsString:methodDescripation]) {
            return;
        }
        
        NSString *methodRef = [[[line componentsSeparatedByString:@"  "] lastObject] stringByReplacingOccurrencesOfString:methodDescripation withString:@""];
        [methodRefs addObject:methodRef];
    }];
    
    return methodRefs;
}

- (NSArray<MethodWrapper *> *)getAllMethodsWithDataSegmentString:(NSString *)dataSegmentString {
    NSMutableArray<MethodWrapper *> *methodWrappers = @[].mutableCopy;
    
    NSArray<NSString *> *lines = [dataSegmentString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSString *methodPre = @"imp";
    [lines enumerateObjectsUsingBlock:^(NSString * _Nonnull line, NSUInteger idx, BOOL * _Nonnull stop) {
        if (![line containsString:methodPre]) {
            return;
        }
        
        //过滤掉.cxx_destruct
        if ([line containsString:@".cxx_destruct"]) {
            return;
        }
        
        NSString *methodName = [[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@"imp " withString:@""];
        
        NSRange rangeOfSpace = [methodName rangeOfString:@" "];
        NSString *detailName = rangeOfSpace.location == NSNotFound ? nil :[methodName substringFromIndex:rangeOfSpace.location + 1];
        
        NSString *result = [detailName stringByReplacingOccurrencesOfString:@"+[" withString:@""];
        result = [result stringByReplacingOccurrencesOfString:@"-[" withString:@""];
        result = [result stringByReplacingOccurrencesOfString:@"]" withString:@""];
        NSArray<NSString *> *names = [result componentsSeparatedByString:@" "];
        
        MethodWrapper *methodWrapper = [[MethodWrapper alloc] init];
        methodWrapper.methodName = [names lastObject];
        methodWrapper.detailName = detailName;
        methodWrapper.className = [names firstObject];
        
        [methodWrappers addObject:methodWrapper];
    }];
    
    return methodWrappers;
}

@end
