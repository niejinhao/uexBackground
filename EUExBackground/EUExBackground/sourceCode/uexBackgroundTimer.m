/**
 *
 *	@file   	: uexBackgroundTimer.m  in EUExBackground Project .
 *
 *	@author 	: CeriNo.
 * 
 *	@date   	: Created on 16/3/8.
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

#import "uexBackgroundTimer.h"
#import "uexBackgroundManager.h"
@interface uexBackgroundTimer()




@end

@implementation uexBackgroundTimer
- (instancetype)initWithIdentifier:(NSString *)identifier
                      callbackName:(NSString *)callbackName
                      timeInterval:(NSTimeInterval)timeInterval
                       repeatTimes:(NSInteger)repeatTimes{
    NSParameterAssert(identifier && identifier.length > 0);
    NSParameterAssert(callbackName && callbackName.length > 0);
    NSParameterAssert(timeInterval > 0);
    self = [super init];
    if (self) {
        _identifier = identifier;
        _callbackName = callbackName;
        _timeInterval = timeInterval;
        _repeatTimes = repeatTimes?:0;
    }
    return self;
}

- (RACSignal *)timerSignal{
    RACSignal *signal = [[RACSignal return:nil] concat:[RACSignal interval:self.timeInterval onScheduler:[RACScheduler schedulerWithPriority:RACSchedulerPriorityBackground]]];
    if (self.repeatTimes > 0) {
        signal = [signal take:self.repeatTimes];
    }
    
    return signal;
}


- (void)dealloc{
    //NSLog(@"timer %@ dealloc",_identifier);
}

@end
