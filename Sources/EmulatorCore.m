//
//  EmulatorCore.m
//  TinyEMU-iOS
//
//  Created by Fernando Lemos on 3/24/19.
//
//  Refer to the LICENSE file for licensing information.
//

#import "EmulatorCore.h"


int temu_main(int argc, const char **argv);


@interface EmulatorCore ()

@property (nonatomic, copy) NSString *configPath;

@end


@implementation EmulatorCore

- (instancetype)initWithConfigPath:(NSString *)path
{
    self = [super init];
    if (self != nil) {
        self.configPath = path;
    }
    return self;
}

- (void)run
{
    const char *argv[2];
    argv[0] = "temu";
    argv[1] = self.configPath.UTF8String;
    temu_main(2, &argv[0]);
}

@end
