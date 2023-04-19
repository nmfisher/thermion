#include "TimeIt.hpp"

#if __cplusplus <= 199711L

void Timer::reset()
{
  clock_gettime(CLOCK_REALTIME, &beg_);
}

double Timer::elapsed()
{
  clock_gettime(CLOCK_REALTIME, &end_);
  return end_.tv_sec - beg_.tv_sec +
      (end_.tv_nsec - beg_.tv_nsec) / 1000000000.;
}

#else

void Timer::reset()
{
  beg_ = clock_::now();
}

double Timer::elapsed()
{
  return std::chrono::duration_cast<second_>
      (clock_::now() - beg_).count();
}

#endif