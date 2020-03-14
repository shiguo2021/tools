#import <Foundation/Foundation.h>

@class Request,Upload,Download;



NS_ASSUME_NONNULL_BEGIN
@interface Network : NSObject
+(Request  * (^) (void)) get;
+(Request  * (^) (void)) post;
+(Request  * (^) (NSString * )) url;
+(Upload   * (^) (void)) upload;
+(Download * (^) (void)) download;
@end
NS_ASSUME_NONNULL_END




typedef void(^progress_t)(float fraction,int64_t completed,int64_t total);
typedef void(^file_t )(NSURL * __nullable localUrl);
typedef void(^response_t)(NSDictionary * __nullable result,id __nullable error);
typedef void(^error_t   )(id __nullable  error);



NS_ASSUME_NONNULL_BEGIN
@interface Request:NSObject;
-(Request * (^) (NSString  *)) url;
-(Request * (^) (NSArray *)) headers;
-(Request * (^) (NSDictionary *)) params;
-(Request * (^) (void)) urlencoded; //bodyType设置成key-value形式
-(void(^)(response_t )) t;
@end
NS_ASSUME_NONNULL_END




NS_ASSUME_NONNULL_BEGIN
//基于formData
@interface Upload:NSObject;
-(Upload * (^) (NSString  * )) url;
-(Upload * (^) (NSArray *)) headers;
-(Upload * (^) (NSDictionary *)) params;
-(Upload * (^) (progress_t)) progress;
-(void(^)(response_t )) t;
@end
NS_ASSUME_NONNULL_END




NS_ASSUME_NONNULL_BEGIN
@interface Download:NSObject;
-(Download * (^) (NSString * __nonnull)) url;
-(Download * (^) (NSArray *)) headers;
-(Download * (^) (NSDictionary *)) params;
-(Download * (^) (progress_t)) progress;
-(Download * (^) (file_t )) file;
-(void(^)(error_t)) t;
@end
NS_ASSUME_NONNULL_END
