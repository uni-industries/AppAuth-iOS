/*! @file OIDRedirectHTTPHandler.m
    @brief AppAuth iOS SDK
    @copyright
        Copyright 2016 Google Inc. All Rights Reserved.
    @copydetails
        Licensed under the Apache License, Version 2.0 (the "License");
        you may not use this file except in compliance with the License.
        You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

        Unless required by applicable law or agreed to in writing, software
        distributed under the License is distributed on an "AS IS" BASIS,
        WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
        See the License for the specific language governing permissions and
        limitations under the License.
 */

#import <TargetConditionals.h>

#if TARGET_OS_OSX

#import "OIDRedirectHTTPHandler.h"

#import "OIDAuthorizationService.h"
#import "OIDErrorUtilities.h"
#import "OIDExternalUserAgentSession.h"
#import "OIDLoopbackHTTPServer.h"

/*! @brief Page that is returned following a completed authorization. Show your own page instead by
        supplying a URL in @c initWithSuccessURL that the user will be redirected to.
 */
static NSString *const kHTMLAuthorizationComplete =
    @"<style>#main{border:1px solid #a9a9a9;border-radius:10px;margin-left:auto;margin-right:auto;margin-top:200px;padding:20px 30px;width:500px;display:flex;gap:20px;font-family:\"SF Pro\",sans-serif}h1{color:#a9a9a9;font-size:16px;margin-bottom:5px}h2{margin-top:5px;font-size:14px}h2 a{color:#000;text-decoration:none}h2 a:hover{text-decoration:underline}</style><div id=main><svg fill=none height=64 viewBox=\"0 0 32 32\"width=64 xmlns=http://www.w3.org/2000/svg><path d=\"M23.8504 31.5546V16.0369C23.8504 11.3864 22.1073 7.57777 18.3941 5.09739C14.6803 2.61702 9.90483 2.29371 5.88322 4.25023C8.77795 1.85652 12.1608 0.445801 16.0336 0.445801C20.4051 0.445801 24.1588 1.97069 27.2956 5.02047C30.4319 8.0708 32.0003 11.7428 32.0003 16.0369V31.5546H23.8504Z\"fill=url(#paint0_linear_2923_143534) /><path d=\"M10.3335 21.5368C11.8491 23.0844 13.6956 23.8583 15.8696 23.8583H22.0989V31.5005H15.8887C11.5283 31.5005 7.79041 29.9889 4.6738 26.9658C1.55831 23.9433 0 20.2869 0 15.9966C0 6.37287 9.52567 0.928272 17.365 6.17178C17.4633 6.23733 17.5599 6.30399 17.656 6.37343L17.6621 6.37788L17.6863 6.3951L17.8076 6.48509L17.8121 6.48787C17.9054 6.55786 17.9981 6.62952 18.0891 6.7023L18.0924 6.70452L18.1194 6.72618L18.2295 6.81618L18.2317 6.81784L18.2402 6.82506L18.2992 6.87451L18.3581 6.9245L18.3683 6.93339L18.3862 6.9495L18.4991 7.04783L18.5031 7.05116L18.5329 7.07727L18.6244 7.15948L18.6357 7.17004L18.6474 7.18059L18.7042 7.23281L18.7604 7.28503L18.7665 7.29003L18.8165 7.33781L18.8722 7.39113L18.8957 7.41391L18.9272 7.44502L19.0176 7.53501L19.0362 7.55334L19.0895 7.60834L19.1867 7.70944L19.1963 7.71944L19.2491 7.775L19.2671 7.79444L19.3839 7.92332L19.3867 7.9261L19.4036 7.94554L19.4547 8.00276L19.5041 8.05886L19.5052 8.06053L19.6052 8.17608L19.6187 8.19274L19.6541 8.23496L19.703 8.29385L19.7513 8.35273L19.799 8.41217L19.8137 8.4305L19.8929 8.53216L19.9395 8.59216L19.985 8.65326L20.0305 8.71382L20.0541 8.74548L20.076 8.77548L20.1204 8.83714L20.1339 8.85547L20.208 8.96102L20.2518 9.02379L20.2945 9.08712L20.3372 9.1499L20.3777 9.21156L20.3793 9.21378L20.4203 9.27766L20.4215 9.27989L20.4709 9.3571L20.5316 9.45265L20.5422 9.47043L20.5456 9.47487L20.5821 9.53487L20.6209 9.59986L20.6361 9.6243L20.6597 9.6643L20.6973 9.72985C19.3362 8.61827 17.7262 8.06164 15.8696 8.06164C13.6714 8.06164 11.8176 8.84214 10.3149 10.402C8.80663 11.9619 8.055 13.8512 8.055 15.9966C8.055 18.142 8.81225 19.9886 10.3335 21.5368Z\"fill=url(#paint1_linear_2923_143534) /><defs><linearGradient gradientUnits=userSpaceOnUse id=paint0_linear_2923_143534 x1=17.3982 x2=-28.8902 y1=57.3167 y2=4.65372><stop stop-color=#2675FE /><stop stop-color=#FF67C0 offset=1 /></linearGradient><linearGradient gradientUnits=userSpaceOnUse id=paint1_linear_2923_143534 x1=17.3982 x2=-28.8902 y1=57.3167 y2=4.65372><stop stop-color=#2675FE /><stop stop-color=#FF67C0 offset=1 /></linearGradient></defs></svg><div><h1>Authorization Complete!</h1><h2><a href=ai.avy:// >Return to Avy</a></h2></div></div>";

/*! @brief Error warning that the @c currentAuthorizationFlow is not set on this object (likely a
        developer error, unless the user stumbled upon the loopback server before the authorization
        had started completely).
    @description An object conforming to @c OIDExternalUserAgentSession is returned when the
        authorization is presented with
        @c OIDAuthorizationService::presentAuthorizationRequest:callback:. It should be set to
        @c currentAuthorization when using a loopback redirect.
 */
static NSString *const kHTMLErrorMissingCurrentAuthorizationFlow =
    @"<html><body>AppAuth Error: No <code>currentAuthorizationFlow</code> is set on the "
     "<code>OIDRedirectHTTPHandler</code>. Cannot process redirect.</body></html>";

/*! @brief Error warning that the URL does not represent a valid redirect. This should be rare, may
        happen if the user stumbles upon the loopback server randomly.
 */
static NSString *const kHTMLErrorRedirectNotValid =
    @"<html><body>AppAuth Error: Not a valid redirect.</body></html>";

@implementation OIDRedirectHTTPHandler {
  HTTPServer *_httpServ;
  NSURL *_successURL;
}

- (instancetype)init {
  return [self initWithSuccessURL:nil];
}

- (instancetype)initWithSuccessURL:(nullable NSURL *)successURL {
  self = [super init];
  if (self) {
    _successURL = [successURL copy];
  }
  return self;
}

- (NSURL *)startHTTPListener:(NSError **)returnError withPort:(uint16_t)port {
  // Cancels any pending requests.
  [self cancelHTTPListener];

  // Starts a HTTP server on the loopback interface.
  // By not specifying a port, a random available one will be assigned.
  _httpServ = [[HTTPServer alloc] init];
  [_httpServ setPort:port];
  [_httpServ setDelegate:self];
  NSError *error = nil;
  if (![_httpServ start:&error]) {
    if (returnError) {
      *returnError = error;
    }
    return nil;
  } else if ([_httpServ hasIPv4Socket]) {
    // Prefer the IPv4 loopback address
    NSString *serverURL = [NSString stringWithFormat:@"http://127.0.0.1:%d/", [_httpServ port]];
    return [NSURL URLWithString:serverURL];
  } else if ([_httpServ hasIPv6Socket]) {
    // Use the IPv6 loopback address if IPv4 isn't available
    NSString *serverURL = [NSString stringWithFormat:@"http://[::1]:%d/", [_httpServ port]];
    return [NSURL URLWithString:serverURL];
  }

  return nil;
}

- (NSURL *)startHTTPListener:(NSError **)returnError {
  // A port of 0 requests a random available port
  return [self startHTTPListener:returnError withPort:0];
}

- (void)cancelHTTPListener {
  [self stopHTTPListener];

  // Cancels the pending authorization flow (if any) with error.
  NSError *cancelledError =
      [OIDErrorUtilities errorWithCode:OIDErrorCodeProgramCanceledAuthorizationFlow
                       underlyingError:nil
                           description:@"The HTTP listener was cancelled programmatically."];
  [_currentAuthorizationFlow failExternalUserAgentFlowWithError:cancelledError];
  _currentAuthorizationFlow = nil;
}

/*! @brief Stops listening on the loopback interface without modifying the state of the
        @c currentAuthorizationFlow. Should be called when the authorization flow completes or is
        cancelled.
 */
- (void)stopHTTPListener {
  _httpServ.delegate = nil;
  [_httpServ stop];
  _httpServ = nil;
}

- (void)HTTPConnection:(HTTPConnection *)conn didReceiveRequest:(HTTPServerRequest *)mess {
  // Sends URL to AppAuth.
  CFURLRef url = CFHTTPMessageCopyRequestURL(mess.request);
  BOOL handled = [_currentAuthorizationFlow resumeExternalUserAgentFlowWithURL:(__bridge NSURL *)url];

  // Stops listening to further requests after the first valid authorization response.
  if (handled) {
    _currentAuthorizationFlow = nil;
    [self stopHTTPListener];
  }

  // Responds to browser request.
  NSString *bodyText = kHTMLAuthorizationComplete;
  NSInteger httpResponseCode = (_successURL) ? 302 : 200;
  // Returns an error page if a URL other than the expected redirect is requested.
  if (!handled) {
    if (_currentAuthorizationFlow) {
      bodyText = kHTMLErrorRedirectNotValid;
      httpResponseCode = 404;
    } else {
      bodyText = kHTMLErrorMissingCurrentAuthorizationFlow;
      httpResponseCode = 400;
    }
  }
  NSData *data = [bodyText dataUsingEncoding:NSUTF8StringEncoding];

  CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault,
                                                          httpResponseCode,
                                                          NULL,
                                                          kCFHTTPVersion1_1);
  if (httpResponseCode == 302) {
    CFHTTPMessageSetHeaderFieldValue(response,
                                     (__bridge CFStringRef)@"Location",
                                     (__bridge CFStringRef)_successURL.absoluteString);
  }
  CFHTTPMessageSetHeaderFieldValue(response,
                                   (__bridge CFStringRef)@"Content-Length",
                                   (__bridge CFStringRef)[NSString stringWithFormat:@"%lu",
                                       (unsigned long)data.length]);
  CFHTTPMessageSetBody(response, (__bridge CFDataRef)data);

  [mess setResponse:response];
  CFRelease(response);
}

- (void)dealloc {
  [self cancelHTTPListener];
}

@end

#endif // TARGET_OS_OSX
