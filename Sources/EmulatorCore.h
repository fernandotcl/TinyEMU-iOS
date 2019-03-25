//
//  EmulatorCore.h
//  TinyEMU-iOS
//
//  Created by Fernando Lemos on 3/24/19.
//
//  Refer to the LICENSE file for licensing information.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@protocol EmulatorCoreDelegate;


@interface EmulatorCore: NSObject

- (instancetype)initWithConfigPath:(NSString *)path NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, weak) id <EmulatorCoreDelegate> delegate;

- (void)start;

- (void)writeData:(NSData *)data;

@end


@protocol EmulatorCoreDelegate <NSObject>

- (void)emulatorCore:(EmulatorCore *)core didReceiveOutput:(NSData *)data;

@end


NS_ASSUME_NONNULL_END
