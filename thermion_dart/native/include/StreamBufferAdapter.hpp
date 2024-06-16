#pragma once

#include <streambuf>
#include <functional>
#include <cassert>
#include <cstring>

namespace thermion_filament {


  // 
  // A generic adapter to expose any contiguous section of memory as a std::streambuf.
  // Mostly for Android/iOS assets which may not be able to be directly loaded as streams.
  //
  class StreamBufferAdapter : public std::streambuf
  {
      public:
          StreamBufferAdapter(const char *begin, const char *end);
          ~StreamBufferAdapter() {
            
          }
          std::streamsize size();
          
      private:
          int_type uflow() override;
          int_type underflow() override;
          int_type pbackfail(int_type ch) override;
          std::streampos seekoff(std::streamoff off, std::ios_base::seekdir way, std::ios_base::openmode which) override;
          std::streampos seekpos(std::streampos sp, std::ios_base::openmode which) override;
          std::streamsize showmanyc() override;
          
  };

}