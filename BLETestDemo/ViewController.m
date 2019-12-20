//
//  ViewController.m
//  BLETestDemo
//
//  Created by fankangpeng on 2019/12/16.
//  Copyright © 2019 fankangpeng. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>

@interface ViewController ()<CBCentralManagerDelegate, CBPeripheralDelegate>

//蓝牙管理者
@property (nonatomic, strong) CBCentralManager *centralManager;
//当前外设节点
@property (nonatomic,strong)CBCharacteristic *characteristic;

//处于连接状态的设备
@property (nonatomic, strong) CBPeripheral *activePeripheral;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"蓝牙SDK测试";
    // 1: 初始化 CentralManager，初始化成功会触发centralManagerDidUpdateState 代理
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:nil];
    // Do any additional setup after loading the view.
}
- (void)centralManagerDidUpdateState:(CBCentralManager *)centralManager {
    if (centralManager.state == CBCentralManagerStatePoweredOn) {
        //蓝牙打开 去搜索设备
       [self.centralManager scanForPeripheralsWithServices:nil options:nil];
    }
    
}
#pragma mark - 搜索到的设备
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    if ([peripheral.name containsString:@"M4"]) {
       //针对手环
           NSData *tempMac = [advertisementData objectForKey:@"kCBAdvDataManufacturerData"];
           uint8_t dataVal[100] = {0x0};
           [tempMac getBytes:&dataVal length:tempMac.length];
           NSString *mac;
           if (tempMac.length == 8) {
               mac = [[NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x",dataVal[2],dataVal[3],dataVal[4],dataVal[5],dataVal[6],dataVal[7]] lowercaseString];
               mac = [mac uppercaseString];
           }
        if ([mac isEqualToString:@"19:10:12:04:22:1A"]) {
            NSLog(@"__找到了 去连接");
            //需记录peripheral
            self.activePeripheral = peripheral;
            [self.centralManager connectPeripheral:peripheral options:nil];
            [central stopScan];
        }
    }
}
#pragma  mark - 成功连接设备
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    peripheral.delegate = self;
    //连接成功找服务
    [peripheral discoverServices:nil];
    self.activePeripheral = peripheral;
}
#pragma  mark - 接收到已连接设备的服务
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        NSLog(@"%s,%@",__func__, error);
    }
    for (CBService *service in peripheral.services) {
        if ([service.UUID.UUIDString.uppercaseString isEqualToString:@"6E400001-B5A3-F393-E0A9-E50E24DCCA9E"]) {
            NSLog(@"接收到已连接设备的服务");
            //找到服务找特征
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }
}
#pragma  mark - 获取服务特征
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        NSLog(@"%s,%@",__func__, error);
    }
    NSLog(@"获取到服务特征");
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID.UUIDString.lowercaseString isEqualToString:@"6e400002-b5a3-f393-e0a9-e50e24dcca9e"]) {
            self.characteristic = characteristic;
            //获取到特征 注册需要的通知等
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
        else if ([characteristic.UUID.UUIDString.lowercaseString isEqualToString:@""]) {
        }
       
    }
}
/*
 *标识订阅成功吧，获取蓝牙返回数据还是上边的那个方法
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{

    if (characteristic.isNotifying) {
        NSLog(@"通知打开成功");
        //读蓝牙数据
        [peripheral readValueForCharacteristic:characteristic];
        
    } else {
        NSLog(@"Notification stopped on %@.  Disconnecting", characteristic);
//        NSLog(@"%@", characteristic);
//        [self.myCentralManager cancelPeripheralConnection:peripheral];
    }
    //测试写个指令
    Byte byte[8] = {0};
    byte[0] = 0xab;
    byte[1] = 0;
    byte[2] = 5;
    byte[3] = 0xff;
    byte[4] = 0x72;
    byte[5] = 0x80;
    byte[6] = 1;
    byte[7] = YES;
    NSData *data = [NSData dataWithBytes:byte length:8];
    [self sendCommand:data];
}

#pragma mark - 读取返回来的数据
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    NSLog(@"蓝牙返回的数据：%@",characteristic.value);
    
}

- (void)sendCommand:(NSData *)data {
    if (self.activePeripheral == nil) {
        return;
    }
    [self writeCharacteristic:self.activePeripheral sUUID:@"6e400002-b5a3-f393-e0a9-e50e24dcca9e" cUUID:@"6e400002-b5a3-f393-e0a9-e50e24dcca9e" data:data response:NO];
}

- (void)writeCharacteristic:(CBPeripheral *)peripheral sUUID:(NSString *)sUUID cUUID:(NSString *)cUUID data:(NSData *)data response:(BOOL)response {
    for ( CBService *service in peripheral.services) {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:sUUID]]) {
            for ( CBCharacteristic *characteristic in service.characteristics ) {
                if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:cUUID]]) {
                    if (response) {
                        //写入数据 有代理回调
                        [peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
                    }
                    else {
                        
                        //写入数据 无代理回调
                        [peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
                    }
                }
            }
        }
    }
}
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error{
    if (error) {
        NSLog(@"写入失败%@",[error localizedDescription]);
    }else{
        NSLog(@"写入成功");
    }
}

@end
