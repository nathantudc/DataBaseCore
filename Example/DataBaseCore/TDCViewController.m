//
//  TDCViewController.m
//  DataBaseCore
//
//  Created by tudaican on 12/01/2020.
//  Copyright (c) 2020 tudaican. All rights reserved.
//

#import "TDCViewController.h"
#import <DataBaseCore/DataBaseCoreManager.h>

@interface TDCViewController ()

@property (nonatomic, strong) DataBaseCoreManager *dataBaseM;

@end

@implementation TDCViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - layzing

-(DataBaseCoreManager*)dataBaseM{
    if (!_dataBaseM) {
        _dataBaseM = [[DataBaseCoreManager alloc] init];
    }
    return _dataBaseM;
}

@end
