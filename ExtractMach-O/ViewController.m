//
//  ViewController.m
//  extract extract extract ExtractMach-O
//
//  Created by Ansel on 2019/6/18.
//  Copyright © 2019年 Ansel. All rights reserved.
//

#import "ViewController.h"
#import "DataAnalyzer.h"

@interface ViewController ()

@property(nonatomic, strong) DataAnalyzer *dataAnalyzer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    self.dataAnalyzer = [[DataAnalyzer alloc] initWithDataSegmentPath:[[NSBundle mainBundle] pathForResource:@"dataSegment" ofType:@"txt"] methodRefsPath:[[NSBundle mainBundle] pathForResource:@"methodRefs" ofType:@"txt"]];
    [self.dataAnalyzer setMethodCategory:MethodCategoryExcludeSettrAndGetter];
    [self.dataAnalyzer setFilterBlock:^BOOL(NSString * _Nonnull className) {
        if ([className hasPrefix:@"WMSM"] || [className hasPrefix:@"WMMRN"] || [className hasPrefix:@"WMRN"]) {
            return NO;
        }
        
        if ([className hasPrefix:@"WM"] || [className hasPrefix:@"PA"] || [className hasPrefix:@"SAT"]) {
            return YES;
        }
        
        return NO;
    }];
    
    [self.dataAnalyzer getUnusedDataStructCallback:^(UnusedDataStruct * _Nonnull unusedDataStruct) {
        NSLog(@"-------unusedClasses start--------\n%@\n-------unusedClasses end----------\n", unusedDataStruct.unusedClasses);
        NSLog(@"-------unusedMethods start--------\n%@\n-------unusedMethods end----------\n", unusedDataStruct.unusedMethods);
    }];
}

@end
