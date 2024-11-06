#pragma once 

#ifndef FLUTTER_FILAMENT_LOG_H
#define FLUTTER_FILAMENT_LOG_H

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#elif defined __ANDROID__
#include <android/log.h>
#define LOGTAG "ThermionFlutter"
#else
#include <stdarg.h>
#include <stdio.h>
#include <iostream>
#endif

static void Log(const char *fmt, ...) {    
    va_list args;
    va_start(args, fmt);
    
#ifdef __ANDROID__
    __android_log_vprint(ANDROID_LOG_DEBUG, LOGTAG, fmt, args);
#elif defined __OBJC__
    NSString *format = [[NSString alloc] initWithUTF8String:fmt];
    NSLogv(format, args);
#else
    vprintf(fmt, args);
    std::cout << std::endl;
#endif
    
    va_end(args);
}

#endif