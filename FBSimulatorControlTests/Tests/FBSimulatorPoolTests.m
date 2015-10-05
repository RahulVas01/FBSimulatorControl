/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import <FBSimulatorControl/FBSimulator.h>
#import <FBSimulatorControl/FBSimulatorApplication.h>
#import <FBSimulatorControl/FBSimulatorControlConfiguration.h>
#import <FBSimulatorControl/FBSimulatorPool+Private.h>
#import <FBSimulatorControl/FBSimulatorPool.h>

#import "CoreSimulatorDoubles.h"

@interface FBSimulatorPoolTests : XCTestCase

@property (nonatomic, strong) FBSimulatorPool *pool;

@end

@implementation FBSimulatorPoolTests

- (void)teardown
{
  self.pool = nil;
}

+ (NSDictionary *)keySimulatorsByName:(id<NSFastEnumeration>)simulators
{
  NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
  for (FBSimulator *simulator in simulators) {
    dictionary[simulator.name] = simulator;
  }
  return dictionary;
}

- (void)createPoolWithExistingDeviceSpecs:(NSArray *)deviceSpecs
{
  NSMutableArray *devices = [NSMutableArray array];
  for (NSDictionary *deviceSpec in deviceSpecs) {
    NSString *name = deviceSpec[@"name"];
    NSUUID *uuid = deviceSpec[@"uuid"] ?: [NSUUID UUID];
    FBSimulatorState state = [(deviceSpec[@"state"] ?: @(FBSimulatorStateShutdown)) integerValue];

    FBSimulatorControlTests_SimDevice_Double *device = [FBSimulatorControlTests_SimDevice_Double new];
    device.name = name;
    device.UDID = uuid;
    device.state = state;

    [devices addObject:device];
  }

  FBSimulatorControlTests_SimDeviceSet_Double *deviceSet = [FBSimulatorControlTests_SimDeviceSet_Double new];
  deviceSet.availableDevices = [devices copy];

  FBSimulatorControlConfiguration *poolConfig = [FBSimulatorControlConfiguration
    configurationWithSimulatorApplication:[FBSimulatorApplication simulatorApplicationWithError:nil]
    deviceSetPath:nil
    namePrefix:nil
    bucket:1
    options:0];
  self.pool = [FBSimulatorPool poolWithConfiguration:poolConfig deviceSet:(id)deviceSet];
}

- (void)mockAllocationOfNamedDevices:(NSArray *)deviceNames
{
  NSDictionary *lookup = [FBSimulatorPoolTests keySimulatorsByName:self.pool.allSimulatorsInPool];
  for (NSString *deviceName in deviceNames) {
    FBSimulator *simulator = lookup[deviceName];
    XCTAssertNotNil(simulator, @"Expected there is a existing device named %@", deviceName);
    [self.pool.allocatedUDIDs addObject:simulator.udid];
  }
}

- (void)testInflatesDevicesFromTheSamePool
{
  [self createPoolWithExistingDeviceSpecs:@[
    @{@"name" : @"E2E_1_0_iPad 2_9.0", @"state" : @(FBSimulatorStateBooted)},
    @{@"name" : @"E2E_1_0_iPhone 5_9.0", @"state" : @(FBSimulatorStateCreating)},
    @{@"name" : @"E2E_1_1_iPhone 5_9.0", @"state" : @(FBSimulatorStateShutdown)},
    @{@"name" : @"iPad 3"},
    @{@"name" : @"iPhone 6S"},
    @{@"name" : @"E2E_1_2_iPhone 5_9.0", @"state" : @(FBSimulatorStateBooted)},
    @{@"name" : @"E2E_2_0_iPhone 5_9.0", @"state" : @(FBSimulatorStateShutdown)},
    @{@"name" : @"E2E_2_0_iPad 1_9.0", @"state" : @(FBSimulatorStateBooted)}
  ]];

  NSOrderedSet *devices = self.pool.allSimulatorsInPool;
  XCTAssertEqual(devices.count, 4);

  XCTAssertEqualObjects([devices[0] name], @"E2E_1_0_iPad 2_9.0");
  XCTAssertEqual([devices[0] state], FBSimulatorStateBooted);
  XCTAssertEqual([devices[0] bucketID], 1);
  XCTAssertEqual([devices[0] offset], 0);
  XCTAssertEqual([devices[0] pool], self.pool);

  XCTAssertEqualObjects([devices[1] name], @"E2E_1_0_iPhone 5_9.0");
  XCTAssertEqual([devices[1] state], FBSimulatorStateCreating);
  XCTAssertEqual([devices[1] bucketID], 1);
  XCTAssertEqual([devices[1] offset], 0);
  XCTAssertEqual([devices[1] pool], self.pool);

  XCTAssertEqualObjects([devices[2] name], @"E2E_1_1_iPhone 5_9.0");
  XCTAssertEqual([devices[2] state], FBSimulatorStateShutdown);
  XCTAssertEqual([devices[2] bucketID], 1);
  XCTAssertEqual([devices[2] offset], 1);
  XCTAssertEqual([devices[2] pool], self.pool);

  XCTAssertEqualObjects([devices[3] name], @"E2E_1_2_iPhone 5_9.0");
  XCTAssertEqual([devices[3] state], FBSimulatorStateBooted);
  XCTAssertEqual([devices[3] bucketID], 1);
  XCTAssertEqual([devices[3] offset], 2);
  XCTAssertEqual([devices[3] pool], self.pool);
}

- (void)testInflatesDevicesAcrossPools
{
  [self createPoolWithExistingDeviceSpecs:@[
    @{@"name" : @"E2E_1_0_iPad 2_9.0", @"state" : @(FBSimulatorStateBooted)},
    @{@"name" : @"E2E_1_0_iPhone 5_9.0", @"state" : @(FBSimulatorStateCreating)},
    @{@"name" : @"E2E_1_1_iPhone 5_9.0", @"state" : @(FBSimulatorStateShutdown)},
    @{@"name" : @"iPad 3"},
    @{@"name" : @"iPhone 6S"},
    @{@"name" : @"E2E_1_2_iPhone 5_9.0", @"state" : @(FBSimulatorStateBooted)},
    @{@"name" : @"E2E_2_0_iPhone 5_9.0", @"state" : @(FBSimulatorStateShutdown)},
    @{@"name" : @"E2E_2_0_iPad 1_9.0", @"state" : @(FBSimulatorStateBooted)}
  ]];

  NSOrderedSet *devices = self.pool.allPooledSimulators;
  XCTAssertEqual(devices.count, 6);

  XCTAssertEqualObjects([devices[0] name], @"E2E_1_0_iPad 2_9.0");
  XCTAssertEqual([devices[0] state], FBSimulatorStateBooted);
  XCTAssertEqual([devices[0] bucketID], 1);
  XCTAssertEqual([devices[0] offset], 0);
  XCTAssertEqual([devices[0] pool], self.pool);

  XCTAssertEqualObjects([devices[1] name], @"E2E_1_0_iPhone 5_9.0");
  XCTAssertEqual([devices[1] state], FBSimulatorStateCreating);
  XCTAssertEqual([devices[1] bucketID], 1);
  XCTAssertEqual([devices[1] offset], 0);
  XCTAssertEqual([devices[1] pool], self.pool);

  XCTAssertEqualObjects([devices[2] name], @"E2E_1_1_iPhone 5_9.0");
  XCTAssertEqual([devices[2] state], FBSimulatorStateShutdown);
  XCTAssertEqual([devices[2] bucketID], 1);
  XCTAssertEqual([devices[2] offset], 1);
  XCTAssertEqual([devices[2] pool], self.pool);

  XCTAssertEqualObjects([devices[3] name], @"E2E_1_2_iPhone 5_9.0");
  XCTAssertEqual([devices[3] state], FBSimulatorStateBooted);
  XCTAssertEqual([devices[3] bucketID], 1);
  XCTAssertEqual([devices[3] offset], 2);
  XCTAssertEqual([devices[3] pool], self.pool);

  XCTAssertEqualObjects([devices[4] name], @"E2E_2_0_iPad 1_9.0");
  XCTAssertEqual([devices[4] state], FBSimulatorStateBooted);
  XCTAssertEqual([devices[4] bucketID], 2);
  XCTAssertEqual([devices[4] offset], 0);
  XCTAssertNil([devices[4] pool]);

  XCTAssertEqualObjects([devices[5] name], @"E2E_2_0_iPhone 5_9.0");
  XCTAssertEqual([devices[5] state], FBSimulatorStateShutdown);
  XCTAssertEqual([devices[5] bucketID], 2);
  XCTAssertEqual([devices[5] offset], 0);
  XCTAssertNil([devices[5] pool]);
}

- (void)testExposesUnmanagedSimulators
{
  [self createPoolWithExistingDeviceSpecs:@[
    @{@"name" : @"E2E_1_0_iPad 2_9.0", @"state" : @(FBSimulatorStateBooted)},
    @{@"name" : @"E2E_1_0_iPhone 5_9.0", @"state" : @(FBSimulatorStateCreating)},
    @{@"name" : @"E2E_1_1_iPhone 5_9.0", @"state" : @(FBSimulatorStateShutdown)},
    @{@"name" : @"iPad 3"},
    @{@"name" : @"iPhone 6S"},
    @{@"name" : @"E2E_1_2_iPhone 5_9.0", @"state" : @(FBSimulatorStateBooted)},
    @{@"name" : @"E2E_2_0_iPhone 5_9.0"},
    @{@"name" : @"E2E_2_0_iPad 1_9.0"}
  ]];

  NSOrderedSet *devices = self.pool.unmanagedSimulators;
  XCTAssertEqual(devices.count, 2);
  XCTAssertEqualObjects([devices[0] name], @"iPad 3");
  XCTAssertEqualObjects([devices[1] name], @"iPhone 6S");
}

- (void)testDividesAllocatedAndUnAllocated
{
  [self createPoolWithExistingDeviceSpecs:@[
    @{@"name" : @"E2E_1_0_iPad 2_9.0", @"state" : @(FBSimulatorStateBooted)},
    @{@"name" : @"E2E_1_0_iPhone 5_9.0", @"state" : @(FBSimulatorStateCreating)},
    @{@"name" : @"E2E_1_1_iPhone 5_9.0", @"state" : @(FBSimulatorStateShutdown)},
    @{@"name" : @"iPad 3"},
    @{@"name" : @"iPhone 6S"},
    @{@"name" : @"E2E_1_2_iPhone 5_9.0", @"state" : @(FBSimulatorStateBooted)},
    @{@"name" : @"E2E_2_0_iPhone 5_9.0"},
    @{@"name" : @"E2E_2_0_iPad 1_9.0"}
  ]];

  [self mockAllocationOfNamedDevices:@[
    @"E2E_1_0_iPad 2_9.0",
    @"E2E_1_1_iPhone 5_9.0"
  ]];

  NSOrderedSet *devices = self.pool.allocatedSimulators;
  XCTAssertEqual(devices.count, 2);

  XCTAssertEqualObjects([devices[0] name], @"E2E_1_1_iPhone 5_9.0");
  XCTAssertEqual([devices[0] state], FBSimulatorStateShutdown);
  XCTAssertEqual([devices[0] bucketID], 1);
  XCTAssertEqual([devices[0] offset], 1);

  XCTAssertEqualObjects([devices[1] name], @"E2E_1_0_iPad 2_9.0");
  XCTAssertEqual([devices[1] state], FBSimulatorStateBooted);
  XCTAssertEqual([devices[1] bucketID], 1);
  XCTAssertEqual([devices[1] offset], 0);

  devices = self.pool.unallocatedSimulators;
  XCTAssertEqual(devices.count, 2);

  XCTAssertEqualObjects([devices[0] name], @"E2E_1_0_iPhone 5_9.0");
  XCTAssertEqual([devices[0] state], FBSimulatorStateCreating);
  XCTAssertEqual([devices[0] bucketID], 1);
  XCTAssertEqual([devices[0] offset], 0);

  XCTAssertEqualObjects([devices[1] name], @"E2E_1_2_iPhone 5_9.0");
  XCTAssertEqual([devices[1] state], FBSimulatorStateBooted);
  XCTAssertEqual([devices[1] bucketID], 1);
  XCTAssertEqual([devices[1] offset], 2);
}

@end
