//
//  UploadcareKit+Deprecated.m
//  UploadcareKit
//
//  Created by Zoreslav Khimich on 10/18/12.
//  Copyright (c) 2012 Uploadcare. All rights reserved.
//

#import "UploadcareKit+Deprecated.h"

#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>

#import "AFJSONRequestOperation.h"
#import "AFHTTPRequestOperation.h"
#import "UIImageView+AFNetworking.h"

#import "JSONKit.h"

/* GHETTO */

#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s:%d " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif

#define ALog(fmt, ...) NSLog((@"%s:%d " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);

#define API_BASE @"https://api.staging0.uploadcare.com"
#define API_UPLOAD @"https://upload.staging0.uploadcare.com"
#define API_RESIZER @"https://services.staging0.uploadcare.com/resizer/"
#define REQUEST_TIMEOUT 20.0

#define DATE_RFC2822_FORMAT @"EEE, dd MMM yyyy HH:mm:ss Z"

/* -GHETTO */


@implementation UploadcareKit (Deprecated)

- (void)setPublicKey:(NSString *)public secretKey:(NSString *)secret {
    self.publicKey = public;
    self.secretKey = secret;
}

- (void)requestFile:(NSString *)file_id
        withSuccess:(void (^)(NSHTTPURLResponse *response, id JSON, UploadcareFile *file))success
         andFailure:(void (^)(id responseObject, NSError *error))failure {
    
    if (![self isPublicAndSecretValid]) {
        return;
    }
    
    AFJSONRequestOperation *operation =
    [AFJSONRequestOperation
     JSONRequestOperationWithRequest:[self buildRequestWithMethod:@"GET"
                                                          baseURL:API_BASE
                                                              URI:[NSString stringWithFormat:@"/files/%@/", file_id]]
     success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
         UploadcareFile *file = [[UploadcareFile alloc] init];
         [file setInfo:JSON];
         
         DLog(@"+success %@ : %@ : %@", response, [request URL], JSON);
         success(response, JSON, file);
     }
     failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
         DLog(@"!failure %@\%@\n%@\n%@", request, response, error, JSON);
         failure(response, error);
     }];
    [operation start];
}

- (void)requestFileListWithSuccess:(void (^)(NSHTTPURLResponse *response, id JSON, NSArray *files))success
                        andFailure:(void (^)(id responseObject, NSError *error))failure {
    
    if (![self isPublicAndSecretValid]) {
        return;
    }
    
    AFJSONRequestOperation *operation =
    [AFJSONRequestOperation
     JSONRequestOperationWithRequest:[self buildRequestWithMethod:@"GET"
                                                          baseURL:API_BASE
                                                              URI:@"/files/"]
     success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
         NSMutableArray *files = [[NSMutableArray alloc] init];
         UploadcareFile *file = nil;
         for (NSDictionary *dict in [JSON objectForKey:@"results"]) {
             file = [[UploadcareFile alloc] init];
             [file setInfo:dict];
             [files addObject:file];
         }
         if (success) {
             success(response, JSON, files);
         }
     }
     failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
         if (failure) {
             failure(response, error);
         }
         DLog(@"%@\%@\n%@\n%@", request, response, error, JSON);
     }];
    [operation start];
}

- (void)deleteFile:(UploadcareFile *)file
           success:(void (^)(NSHTTPURLResponse *response))success
        andFailure:(void (^)(NSHTTPURLResponse *response, NSError *error))failure {
    
    if (![self isPublicAndSecretValid]) {
        return;
    }
    
    AFJSONRequestOperation *operation =
    [AFJSONRequestOperation
     JSONRequestOperationWithRequest:[self buildRequestWithMethod:@"DELETE"
                                                          baseURL:API_BASE
                                                              URI:[file apiURI]
                                                          andData:nil]
     success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
         if (success) {
             success(response);
         }
     }
     failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
         DLog(@"!failure: %@\n%@ : %@ : %@", [request allHTTPHeaderFields], response, error, JSON);
         if (failure) {
             failure(response, error);
         }
     }];
    [operation start];
}

- (void)keep:(BOOL)status forFile:(UploadcareFile *)file {
    if (![self isPublicAndSecretValid]) {
        return;
    }
    
    [self keep:status forFile:file success:nil andFailure:nil];
}

- (void)keep:(BOOL)status
     forFile:(UploadcareFile *)file
     success:(void (^)(NSHTTPURLResponse *response, id JSON, UploadcareFile *file))success
  andFailure:(void (^)(NSHTTPURLResponse *response, NSError *error))failure {
    
    if (![self isPublicAndSecretValid]) {
        return;
    }
    
    AFJSONRequestOperation *operation =
    [AFJSONRequestOperation
     JSONRequestOperationWithRequest:[self buildRequestWithMethod:@"POST"
                                                          baseURL:API_BASE
                                                              URI:[file apiURI]
                                                          andData:[NSString stringWithFormat:@"{\"keep\" : \"%@\"}", status ? @"1" : @"0"]]
     success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
         [file setInfo:JSON];
         
         if (success) {
             success(response, JSON, file);
         }
     }
     failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
         DLog(@"!failure: %@\n%@ : %@ : %@", [request allHTTPHeaderFields], response, error, JSON);
         if (failure) {
             failure(response, error);
         }
     }];
    [operation start];
}

#pragma mark - request builders

- (NSURLRequest *)buildRequestWithMethod:(NSString *)method baseURL:(NSString *)base_url URI:(NSString *)url {
    return [self buildRequestWithMethod:method baseURL:base_url URI:url andData:nil];
}

- (NSURLRequest *)buildRequestWithMethod:(NSString *)method baseURL:(NSString *)base_url URI:(NSString *)url andData:(NSString *)data {
    if (!data) {
        data = @"";
    }
    
    NSURL *destination = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", base_url, url]];
    
    NSString *content_type = @"application/json";
    NSString *content_hash = [UploadcareKit md5ForString:data];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = DATE_RFC2822_FORMAT;
    [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]]; // GMT
    [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    NSString *date = [dateFormatter stringFromDate:[NSDate date]];
    
    NSString *sign_string = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@",
                             method, content_hash, content_type, date, url];
    NSString *sign = [UploadcareKit hashedValueForString:sign_string WithKey:self.secretKey];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:destination];
    
    [request setHTTPMethod:method];
    [request setHTTPBody:[data dataUsingEncoding:NSASCIIStringEncoding]];
    
    [request addValue:[NSString stringWithFormat:@"UploadCare %@:%@", self.publicKey, sign] forHTTPHeaderField:@"Authentication"];
    [request addValue:date forHTTPHeaderField:@"Date"];
    [request addValue:content_type forHTTPHeaderField:@"Content-Type"];
    
    DLog(@"sign_string = %@, data = %@", sign_string, data);
    DLog(@"%@", [request allHTTPHeaderFields]);
    
    return request;
}

- (NSURLRequest *)buildRequestForUploadWithFilename:(NSString *)filename andData:(NSData *)data {
    NSURL *postURL = [NSURL URLWithString:@"https://upload.staging0.uploadcare.com/base/"]; // FIXME
    NSMutableURLRequest *postRequest = [NSMutableURLRequest requestWithURL:postURL
                                                               cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                           timeoutInterval:REQUEST_TIMEOUT];
    [postRequest setHTTPMethod:@"POST"];
    NSString *stringBoundary = @"----------------------------3410bed48fe0";
    NSString *headerBoundary = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",
                                stringBoundary];
    [postRequest addValue:headerBoundary forHTTPHeaderField:@"Content-Type"];
    
    NSMutableData *postBody = [NSMutableData data];
    
    // publickey part
    [postBody appendData:[[NSString stringWithFormat:@"--%@\r\n", stringBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [postBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"UPLOADCARE_PUB_KEY\"\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [postBody appendData:[[NSString stringWithString:self.publicKey] dataUsingEncoding:NSASCIIStringEncoding]];
    [postBody appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    
    // get the image data from main bundle directly into NSData object
    [postBody appendData:[[NSString stringWithFormat:@"--%@\r\n", stringBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [postBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"myfile\"; filename=\"%@\"\r\n", filename] dataUsingEncoding:NSUTF8StringEncoding]];
    [postBody appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [postBody appendData:data];
    
    // final boundary
    [postBody appendData:[[NSString stringWithFormat:@"--%@--\r\n", stringBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [postRequest setHTTPBody:postBody];
    
    DLog(@"%@", [postRequest allHTTPHeaderFields]);
    
    return postRequest;
}

#pragma mark - SHA1 and MD5 tools

+ (NSString *)md5ForString:(NSString *)input {
    unsigned char digest[16];
    CC_MD5([input UTF8String], strlen([input UTF8String]), digest);
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    
    return output;
}

+ (NSString *)hashedValueForString:(NSString *)input WithKey:(NSString *) key {
    unsigned char cHMAC[CC_SHA1_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA1,
           [key cStringUsingEncoding:NSUTF8StringEncoding], strlen([key cStringUsingEncoding:NSUTF8StringEncoding]),
           [input cStringUsingEncoding:NSUTF8StringEncoding], strlen([input cStringUsingEncoding:NSUTF8StringEncoding]),
           cHMAC);
    
    NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", cHMAC[i]];
    }
    
    return output;
}

#pragma mark - Tools

+ (NSString *)validateUUID:(NSString *)uuid {
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:@"[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}"
                                  options:NSRegularExpressionCaseInsensitive
                                  error:&error];
    NSRange rangeOfFirstMatch = [regex rangeOfFirstMatchInString:uuid options:0 range:NSMakeRange(0, [uuid length])];
    
	if (!NSEqualRanges(rangeOfFirstMatch, NSMakeRange(NSNotFound, 0))) {
        DLog(@"Extracted URL: %@", [uuid substringWithRange:rangeOfFirstMatch]);
        return [uuid substringWithRange:rangeOfFirstMatch];
	}
    return nil;
}

- (BOOL)isPublicAndSecretValid {
    if (self.publicKey == nil || self.secretKey == nil) {
        DLog(@"Warning! You must specify public key and secret key! All you need to know you can find in documentation.")
        return NO;
    }
    return YES;
}

#pragma mark - Services helpers

+ (void)downloadImageAtURL:(NSURL *)url withPlaceholder:(UIImage *)placeholder forImageView:(UIImageView *) imageView {
    [imageView setImageWithURL:url placeholderImage:placeholder];
}


@end
