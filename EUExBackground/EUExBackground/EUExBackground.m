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


#define kUexBackgroundResultFalse @(NO)
#define kUexBackgroundResultTrue @(YES)

@interface EUExBackground()
@property (nonatomic,weak)uexBackgroundManager *manager;
@end

@implementation EUExBackground





#pragma mark - Life Cycle

- (instancetype)initWithBrwView:(EBrowserView *)eInBrwView{
    self=[super initWithBrwView:eInBrwView];
    if(self){
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
    if([inArguments count] < 1){
        return kUexBackgroundResultFalse;
    }
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSDictionary class]]){
        return kUexBackgroundResultFalse;
    }
    if (!info[@"jsPath"] || ![info[@"jsPath"] isKindOfClass:[NSString class]]) {
        return kUexBackgroundResultFalse;
    }
    NSError *error = nil;
    NSString *js = [NSString stringWithContentsOfFile:[self absPath:info[@"jsPath"]] encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        return kUexBackgroundResultFalse;
    }
    if (info[@"jsResourcePaths"] && [info[@"jsResourcePaths"] isKindOfClass:[NSArray class]]) {
        [[[info[@"jsResourcePaths"]
          rac_sequence]filter:^BOOL(id value) {
            return [value isKindOfClass:[NSString class]];
        }]all:^BOOL(NSString *path) {
            NSError *e = nil;
            NSString *jsRes = [NSString stringWithContentsOfFile:[self absPath:path] encoding:NSUTF8StringEncoding error:&e];
            if (!e && jsRes) {
                [self.manager.jsResources addObject:jsRes];
            }
            return YES;
        }];
    }

    
    BOOL isSuccess = [_manager startWithJSScript:js];
    if (!isSuccess) {
        return kUexBackgroundResultFalse;
    }
    return kUexBackgroundResultTrue;
}

- (NSNumber *)stop:(NSMutableArray *)inArguments{
    BOOL isSuccess = [self.manager stop];
    if (!isSuccess) {
        return kUexBackgroundResultFalse;
    }
     return kUexBackgroundResultTrue;
}

- (NSNumber *)addTimer:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        return kUexBackgroundResultFalse;
    }
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSDictionary class]]){
        return kUexBackgroundResultFalse;
    }
    BOOL paramsTestPassed = [@[@"id",@"callbackName",@"repeatTimes",@"timeInterval"].rac_sequence all:^BOOL(id key) {
        return [info objectForKey:key];
    }];
    if (!paramsTestPassed) {
        return kUexBackgroundResultFalse;
    }
    BOOL isAdded = [self.manager addTimerWithIdentifier:info[@"id"]
                                           callbackName:info[@"callbackName"]
                                           timeInterval:[info[@"timeInterval"] doubleValue]/1000
                                            repeatTimes:[info[@"repeatTimes"] integerValue]];
    if (!isAdded) {
        return kUexBackgroundResultFalse;
    }
    return kUexBackgroundResultTrue;
}

- (void)cancelTimer:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        [self.manager cancelAllTimers];
        return;
    }
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSArray class]]){
        [self.manager cancelAllTimers];
        return;
    }
    [[[info rac_sequence]
      filter:^BOOL(id value) {
        return [value isKindOfClass:[NSString class]];
    }]
     all:^BOOL(NSString *identifier) {
        [self.manager cancelTimerWithIdentifier:identifier];
        return YES;
    }];
}



#pragma mark - JSON Callback

- (void)callbackJSONWithFunction:(NSString *)functionName object:(id)object{
    [EUtility uexPlugin:@"uexBackground"
         callbackByName:functionName
             withObject:object
                andType:uexPluginCallbackWithJsonString
               inTarget:self.meBrwView];
    
}


@end
