#import <Cordova/CDVPlugin.h>
#import "CFCallNumber.h"

@implementation CFCallNumber

+ (BOOL)available {
    // Fixed: Use consistent "tel:" scheme (not "tel://")
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel:"]];
}

- (void) callNumber:(CDVInvokedUrlCommand*)command {
    
    [self.commandDelegate runInBackground:^{
        
        NSString* number = [command.arguments objectAtIndex:0];
        
        // Validate input
        if (!number || [number length] == 0) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                              messageAsString:@"InvalidPhoneNumber"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            return;
        }
        
        // Use modern percent encoding for production reliability
        NSString* encodedNumber;
        if (@available(iOS 9.0, *)) {
            // Use URLFragmentAllowedCharacterSet for phone numbers - more restrictive and reliable
            NSCharacterSet *allowedChars = [NSCharacterSet characterSetWithCharactersInString:@"0123456789+*#"];
            encodedNumber = [number stringByAddingPercentEncodingWithAllowedCharacters:allowedChars];
        } else {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            encodedNumber = [number stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            #pragma clang diagnostic pop
        }
        
        if (!encodedNumber) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                              messageAsString:@"EncodingError"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            return;
        }
        
        if(![encodedNumber hasPrefix:@"tel:"]){
            encodedNumber = [NSString stringWithFormat:@"tel:%@", encodedNumber];
        }

        // CRITICAL: All UI operations and plugin results must be on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if(![CFCallNumber available]) {
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                                  messageAsString:@"NoFeatureCallSupported"];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                return;
            }
            
            NSURL* url = [NSURL URLWithString:encodedNumber];
            if (!url) {
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                                  messageAsString:@"InvalidURL"];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                return;
            }
            
            // Production-safe URL opening
            if (@available(iOS 10.0, *)) {
                [[UIApplication sharedApplication] openURL:url 
                                                   options:@{} 
                                         completionHandler:^(BOOL success) {
                    // Ensure plugin result is sent on main thread
                    dispatch_async(dispatch_get_main_queue(), ^{
                        CDVPluginResult* result;
                        if (success) {
                            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                        } else {
                            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                       messageAsString:@"CouldNotCallPhoneNumber"];
                        }
                        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                    });
                }];
            } else {
                // Fallback for iOS < 10.0
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Wdeprecated-declarations"
                BOOL success = [[UIApplication sharedApplication] openURL:url];
                #pragma clang diagnostic pop
                
                CDVPluginResult* pluginResult;
                if (success) {
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                } else {
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                     messageAsString:@"CouldNotCallPhoneNumber"];
                }
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }
        });
    }];
}

- (void) isCallSupported:(CDVInvokedUrlCommand*)command {
    [self.commandDelegate runInBackground: ^{
        CDVPluginResult* pluginResult = [CDVPluginResult
                                         resultWithStatus:CDVCommandStatus_OK
                                         messageAsBool:[CFCallNumber available]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

@end