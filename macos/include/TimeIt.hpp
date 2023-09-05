#ifndef TIMEIT_H_
#define TIMEIT_H_

#pragma once

#if __cplusplus <= 199711L
 #include <ctime>
#else
 #include <chrono>
#endif

class Timer
{
 public:

  Timer() { reset(); }
  void reset();
  double elapsed();

 private:

#if __cplusplus <= 199711L
  timespec beg_, end_;
#else
  typedef std::chrono::high_resolution_clock clock_;
  typedef std::chrono::duration<double, std::ratio<1> > second_;
  std::chrono::time_point<clock_> beg_;
#endif

};

#endif  // TIMEIT_H_
