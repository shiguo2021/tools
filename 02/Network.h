//
//  Network.h
//  链式编程
//
//  Created by 十国 on 2020/3/14.
//  Copyright © 2020 十国. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef void(^progress_t)(float fraction,int64_t completed,int64_t total);
typedef void(^file_t )(NSURL * __nullable localUrl);
typedef void(^response_t)(NSDictionary * __nullable result,id __nullable error);
typedef void(^error_t   )(id __nullable  error);

NS_ASSUME_NONNULL_BEGIN

@interface Network : NSObject
+(Network * (^) (NSString  *)) url;
-(Network * (^) (NSArray *)) headers;
-(Network * (^) (NSDictionary *)) params;
-(Network * (^) (void)) urlencoded;

-(Network * (^) (progress_t)) progress;
-(Network * (^) (file_t )) file;
-(void(^)(response_t)) get;
-(void(^)(response_t)) post;
-(void(^)(response_t)) upload;
-(void(^)(error_t)) download;
@end

NS_ASSUME_NONNULL_END
