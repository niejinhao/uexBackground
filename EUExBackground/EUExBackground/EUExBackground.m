/**
 *
 *	@file   	: EUExBackground.m  in EUExBackground Project .
 *
 *	@author 	: CeriNo.
 * 
 *	@date   	: Created on 16/3/7.
 *
 *	@copyright 	: 2016 The AppCan Open Source Project.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import "EUExBackground.h"
#import "JSON.h"
#import "uexBackgroundManager.h"


#define UEX_FALSE @(NO)
#define UEX_TRUE @(YES)

@interface EUExBackground()
@property (nonatomic,weak)uexBackgroundManager *manager;
@end

@implementation EUExBackground





#pragma mark - Life Cycle


- (instancetype)initWithWebViewEngine:(id<AppCanWebViewEngineObject>)engine{
    self = [super initWithWebViewEngine:engine];
    if (self) {
        _manager = [uexBackgroundManager sharedManager];
    }
    return self;
}


- (void)clean{
    
}



- (void)dealloc{
    [self clean];
    
}







#pragma mark - API



- (NSNumber *)start:(NSMutableArray *)inArguments{

    ACArgsUnpack(NSDictionary *info) = inArguments;
    NSString *jsPath = stringArg(info[@"jsPath"]);
    
    if (!jsPath) {
        return UEX_FALSE;
    }
    NSError *error = nil;
    NSString *js = [NSString stringWithContentsOfFile:[self absPath:jsPath] encoding:NSUTF8StringEncoding error:&error];
    if (!js || error) {
        return UEX_FALSE;
    }
    NSArray *resPaths = arrayArg(info[@"jsResourcePaths"]);
    if (resPaths) {
        [resPaths enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *aResPath = stringArg(obj);
            if (aResPath) {
                NSError *e = nil;
                NSString *jsRes = [NSString stringWithContentsOfFile:[self absPath:aResPath] encoding:NSUTF8StringEncoding error:&e];
                if (!e && jsRes) {
                    [self.manager.jsResources addObject:jsRes];
                }
            }
        }];
    }

    
    BOOL isSuccess = [_manager startWithJSScript:js];
    if (!isSuccess) {
        return UEX_FALSE;
    }
    return UEX_TRUE;
}

- (NSNumber *)stop:(NSMutableArray *)inArguments{
    BOOL isSuccess = [self.manager stop];
    if (!isSuccess) {
        return UEX_FALSE;
    }
     return UEX_TRUE;
}

- (NSNumber *)addTimer:(NSMutableArray *)inArguments{

    ACArgsUnpack(NSDictionary *info) = inArguments;
    NSString *identifier = stringArg(info[@"id"]);
    NSString *cbName = stringArg(info[@"callbackName"]);
    NSNumber *intervalNum = numberArg(info[@"timeInterval"]);
    NSNumber *timesNum = numberArg(info[@"repeatTimes"]);
    if (!identifier || !cbName || !intervalNum || !timesNum) {
         return UEX_FALSE;
    }
    
    BOOL isAdded = [self.manager addTimerWithIdentifier:identifier
                                           callbackName:cbName
                                           timeInterval:[intervalNum doubleValue]/1000
                                            repeatTimes:[timesNum integerValue]];
    if (!isAdded) {
        return UEX_FALSE;
    }
    return UEX_TRUE;
}

- (void)cancelTimer:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSArray *timerNames) = inArguments;
    if (!timerNames || timerNames.count == 0) {
        [self.manager cancelAllTimers];
        return;
    }
    [timerNames enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *identifier = stringArg(obj);
        if (identifier) {
            [self.manager cancelTimerWithIdentifier:identifier];
        }
    }];
}






@end
