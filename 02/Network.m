//
//  Network.m
//  链式编程
//
//  Created by 十国 on 2020/3/14.
//  Copyright © 2020 十国. All rights reserved.
//

#import "Network.h"
#define WeakObj(o) autoreleasepool{} __weak typeof(o) o##Weak = o;
#define StrongObj(o) autoreleasepool{} __strong typeof(o) o = o##Weak;
@interface NSDictionary (NetworkTool)
-(NSString*(^)(void))dict2url;
-(NSString*(^)(void))dict2json;
@end
@interface NSString (NetworkTool)
-(NSString*(^)(void))check;
@end
@interface Network()<NSURLSessionDataDelegate,NSURLSessionDownloadDelegate>;
@property (nonatomic,copy)   NSString * url_;
@property (nonatomic,strong) NSDictionary * params_;
@property (nonatomic,strong) NSArray * headers_;
@property (nonatomic,assign) BOOL urlencoded_;
@property (nonatomic,strong) NSMutableData * data;
@property (nonatomic,copy)   file_t file_;
@property (nonatomic,copy)   error_t error_;
@property (nonatomic,copy)   response_t response_;
@property (nonatomic,copy)   progress_t progress_;
@end
@implementation Network

+(Network * (^) (NSString *))url
{
    return ^(NSString * url){
        NSAssert([url hasPrefix:@"http"],@"错误原因：这不是一个http请求");
        Network * network = [[Network alloc] init];
        network.url_ = url;
        return network;
    };
}
-(Network * (^) (NSArray *))headers
{
    @WeakObj(self)
    return ^(NSArray * headers){
        @StrongObj(self)
        self.headers_ = headers ;
        return self;
    };
}
-(Network * (^) (NSDictionary *))params
{
    @WeakObj(self)
    return ^(NSDictionary * params){
        @StrongObj(self)
        self.params_ = params ;
        return self;
    };
}
-(Network * (^) (void))urlencoded
{
    @WeakObj(self)
    return ^(){
        @StrongObj(self)
        self.urlencoded_ = YES ;
        return self;
    };
}
-(Network *(^)(progress_t))progress{
    @WeakObj(self)
    return ^(progress_t progress){
        @StrongObj(self)
        self.progress_ = progress;
        return self;
    };
}
-(Network *(^)(file_t))file{
    @WeakObj(self)
    return ^(file_t file){
        @StrongObj(self)
        self.file_ = file;
        return self;
    };
}
-(void(^)(response_t))get
{
    @WeakObj(self)
    return ^(response_t response){
        @StrongObj(self)
        self.response_ = response;
        if (self.params_ == nil) self.params_ = @{};
        NSURL * URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@",self.url_,self.params_.dict2url()].check()];
        NSMutableURLRequest * mutableURLRequest = [NSMutableURLRequest requestWithURL:URL];
        [self sessionDataTask:mutableURLRequest];
    };
}
-(void(^)(response_t))post
{
    @WeakObj(self)
    return ^(response_t response){
        @StrongObj(self)
        self.response_ = response;
        if (self.params_ == nil) self.params_ = @{};
        NSMutableURLRequest * mutableURLRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.url_.check()]];
                      mutableURLRequest.HTTPMethod = @"POST";
                      NSString * body;
        if(self.urlencoded_){
          body = self.params_.dict2url();
          [mutableURLRequest addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        }else{
          // 默认提交JSON数据
          body = self.params_.dict2json();
          [mutableURLRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        }
        mutableURLRequest.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
        [self sessionDataTask:mutableURLRequest];
    };
}
-(void)sessionDataTask:(NSMutableURLRequest *) mutableURLRequest{
    mutableURLRequest.timeoutInterval = 30;
    //1.0 设置请求头
    if(self.headers_ && [self.headers_ isKindOfClass:[NSArray class]]){
        for (NSDictionary * header in self.headers_) {
            NSArray<NSString*>* keys = header.allKeys;
            NSArray<NSString*>* values = header.allValues;
            NSAssert(keys.count == 1 && values.count == 1,@"错误原因：headers设置错误");
            [mutableURLRequest addValue:values.firstObject forHTTPHeaderField:keys.firstObject];
        }
    }
    //2.0 发起会话
    NSURLSession * session = [NSURLSession sharedSession];
    NSURLSessionDataTask * dataTask = [session dataTaskWithRequest:mutableURLRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error == nil) {
            @try{
                NSDictionary * dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.response_) self.response_(dict,nil);
                });
            }
            @catch(NSException *e){
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.response_) self.response_(nil,@{@"错误原因":@"JSON反序列化错误",@"异常信息":e});
                });
            }
        }else{
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.response_) self.response_(nil,error);
            });
        }
    }];
    
    [dataTask resume];
}


//上传
-(NSMutableData *)data{
    if(!_data){
        _data = [NSMutableData data];
    }
    return _data;
}
-(void (^)(response_t))upload{
    @WeakObj(self)
    return ^(response_t response_){
        @StrongObj(self)
        self.response_ = response_;
        //1.0 校验数据
        NSAssert(self.params_,@"错误原因：参数不能为空，至少还有fileWord");
        //2.0 要准备的数据
        __block NSArray <NSDictionary*> * files ;
        __block NSString * fileWord ;
        [self.params_ enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            if ([obj isKindOfClass:[NSArray class]] && ([key isEqualToString:@"Files"] || [key isEqualToString:@"files"])) {
                files = obj;
                fileWord = key;
            }
        }];
        NSMutableData * data= [NSMutableData data];
        NSMutableString *body=[[NSMutableString alloc] init];
        
        
        //3.0 要传入的参数
        NSArray *keys= [self.params_ allKeys];
        //遍历keys
        for (NSString * key in keys) {
            if (![key isEqualToString:fileWord]) {
                //添加分界线
                [body appendFormat:@"--AaB03x\r\n"];
                //添加字段名称，换2行
                [body appendFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n",key];
                //添加字段的值
                [body appendFormat:@"%@\r\n",self.params_[key]];
            }
        }

        
        //添加分界线
        [body appendFormat:@"--AaB03x\r\n"];
        [data appendData:[body dataUsingEncoding:NSUTF8StringEncoding]];
        
        //4.0 要上传的文件
        int i = 0;
        for (NSDictionary * file in files) {
            NSAssert([file[@"data"] isKindOfClass:[NSData class]],@"错误原因:data is not NSData class");
            //4.1 获取fileName
            NSDateFormatter *formatter=[[NSDateFormatter alloc]init];
            formatter.dateFormat=@"yyyyMMddHHmmssSSS";
            NSString *str=[formatter stringFromDate:[NSDate date]];
            NSString *fileName=[NSString stringWithFormat:@"%@.%@",str,file[@"type"]];
            
            //4.2 声明file字段
            NSMutableString *fileBody=[[NSMutableString alloc]init];
            [fileBody appendFormat:@"--AaB03x\r\n"];//添加分界线
            [fileBody appendFormat:@"%@", [NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@%d\"; filename=\"%@\"\r\n",fileWord,i,fileName]];
            //            [fileBody appendFormat:@"Content-Type: %@\r\n\r\n",file.mimeType];
            [fileBody appendFormat:@"Content-Type: application/octet-stream; charset=utf-8\r\n\r\n"];
            [data appendData:[fileBody dataUsingEncoding:NSUTF8StringEncoding]];
            
            //4.3 追加图片的二进制数据
            [data appendData:file[@"data"]];
            [data appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
            
            i++;
        }
        //5.0 结束符--AaB03x--
        [data appendData:[@"--AaB03x--\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        
        //6.0 发起请求
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.url_]
                                                               cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                           timeoutInterval:30];
        request.HTTPMethod = @"POST";
        [request setValue:@"multipart/form-data; boundary=AaB03x" forHTTPHeaderField:@"Content-Type"];
        [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[data length]] forHTTPHeaderField:@"Content-Length"];
        
        //7.0 设置请求头
        if(self.headers_ && [self.headers_ isKindOfClass:[NSArray class]]){
            for (NSDictionary * header in self.headers_) {
                NSArray<NSString*>* keys = header.allKeys;
                NSArray<NSString*>* values = header.allValues;
                NSAssert(keys.count == 1 && values.count == 1,@"错误原因：headers设置错误");
                [request addValue:values.firstObject forHTTPHeaderField:keys.firstObject];
            }
        }
        
        [request setHTTPBody:data];
        
        NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request];
        [task resume];
        
        //8.0
        if (self.progress_) self.progress_(0,0,0);
    };
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.progress_) {
            self.progress_((float)totalBytesSent/totalBytesExpectedToSend,totalBytesSent,totalBytesExpectedToSend);
        }
    });
}
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    /*
     NSURLSessionResponseCancel = 0,取消 默认
     NSURLSessionResponseAllow = 1, 接收
     NSURLSessionResponseBecomeDownload = 2, 变成下载任务
     NSURLSessionResponseBecomeStream        变成流
     这里的block是传给服务端的，如若不写则代表取消网络请求。
     */
    completionHandler(NSURLSessionResponseAllow);
}
/**
 *  接收到服务器返回的数据 调用多次
 */
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    //拼接数据
    [self.data appendData:data];
}
/**
 *  请求结束或者是失败的时候调用
 */
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (error == nil) {
        @try{
            
            NSMutableDictionary * dict = [NSJSONSerialization JSONObjectWithData:self.data options:kNilOptions error:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.response_) self.response_(dict,nil);
            });
        }
        @catch(NSException *e){
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.response_) self.response_(nil,@{@"错误原因":@"JSON反序列化错误",@"异常信息":e});
            });
        }
        
    }else{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.response_) self.response_(nil,error);
            if (self.error_) self.error_(error);
        });
      
    }
    [session finishTasksAndInvalidate];
}
// 下载
-(void (^)(error_t))download{
    @WeakObj(self)
    return ^(error_t error){
        @StrongObj(self)
        //1.0 校验数据
        if (self.params_ == nil) self.params_ = @{};
        self.error_ = error;
        //2.0
        NSURL * URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@",self.url_,self.params_.dict2url()].check()];
        NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:URL];
        
        //3.0 设置请求头
        if(self.headers_ && [self.headers_ isKindOfClass:[NSArray class]]){
            for (NSDictionary * header in self.headers_) {
                NSArray<NSString*>* keys = header.allKeys;
                NSArray<NSString*>* values = header.allValues;
                NSAssert(keys.count == 1 && values.count == 1,@"错误原因：headers设置错误");
                [request addValue:values.firstObject forHTTPHeaderField:keys.firstObject];
            }
        }
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
        NSURLSessionDownloadTask * downloadtask = [session downloadTaskWithRequest:request];
        [downloadtask resume];
        
        //4.0
        if (self.progress_) self.progress_(0,0,0);
    };
}
//1. downloadTask下载过程中会执行
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.progress_) {
            self.progress_((float)totalBytesWritten/totalBytesExpectedToWrite,totalBytesWritten,totalBytesExpectedToWrite);
        }
    });

}

//2.downloadTask下载完成的时候会执行
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location{
    //该方法内部已经完成了边接收数据边写沙盒的操作，解决了内存飙升的问题
    //对数据进行使用，或者保存（默认存储到临时文件夹 tmp 中，需要剪切文件到 cache）
    //NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:downloadTask.response.suggestedFilename];
    //[[NSFileManager defaultManager] moveItemAtURL:location toURL:[NSURL fileURLWithPath:self.destination] error:nil];
    //NSData * data = [NSData dataWithContentsOfURL:location.filePathURL];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.file_) {
            self.file_(location.filePathURL);
        }
    });

}
@end
@implementation NSDictionary (NetworkTool)
-(NSString*(^)(void))dict2url
{
    return ^{
        NSMutableString * path = [NSMutableString string];
        [self enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            [path appendFormat:@"%@=%@&",key,obj];
        }];
        return path;
    };
}
-(NSString*(^)(void))dict2json
{
    return ^{
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:self options:kNilOptions  error:&error];
        NSString * json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return json;
    };
}
@end
@implementation NSString (NetworkTool)

-(NSString*(^)(void))check
{
    return ^{
        return [self stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet characterSetWithCharactersInString:@"`#%^{}\"[]|\\<> "].invertedSet];
    };
}

@end
