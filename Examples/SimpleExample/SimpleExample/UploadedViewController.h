//
//  UploadedViewController.h
//  SimpleExample
//
//  Created by Artyom Loenko on 8/2/12.
//  Copyright (c) 2012 Uploadcare. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UploadedViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, readwrite) BOOL showLocal;

@end
