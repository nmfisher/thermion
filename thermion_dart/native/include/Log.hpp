#pragma once 

#ifdef __EMSCRIPTEN__
#include <emscripten/console.h>
#endif 
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

#ifdef __EMSCRIPTEN__
#define Log(...) emscripten_console_logf(__VA_ARGS__);
#else
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

#if defined(_WIN32) || defined(_WIN64)
#define __FILENAME__ (strrchr(__FILE__, '\\') ? strrchr(__FILE__, '\\') + 1 : __FILE__)
#endif 

#ifdef __ANDROID__
    #define __FILENAME__ (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)
#elif defined __OBJC__
    #define __FILENAME__ (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)
#else
    #define __FILENAME__ (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)
#endif


#ifdef ENABLE_TRACING
    #ifdef __ANDROID__
        #define __FILENAME__ (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)
        #define TRACE(fmt, ...) Log("TRACE %s:%d " fmt, __FILENAME__, __LINE__, ##__VA_ARGS__)
    #elif defined __OBJC__
        #define __FILENAME__ (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)
        #define TRACE(fmt, ...) Log("TRACE %s:%d " fmt, __FILENAME__, __LINE__, ##__VA_ARGS__)
    #else
        #define __FILENAME__ (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)
        #define TRACE(fmt, ...) Log("TRACE %s:%d " fmt, __FILENAME__, __LINE__, ##__VA_ARGS__)
    #endif
#else
    #define TRACE(fmt, ...) ((void)0)
#endif

#define ERROR(fmt, ...) Log("Error: %s:%d " fmt, __FILENAME__, __LINE__, ##__VA_ARGS__)
