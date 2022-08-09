#include <streambuf>
#include <functional>
#include <cassert>
#include <cstring>

namespace polyvox {

  class streambuf : public std::streambuf
  {
      public:
          streambuf(const char *begin, const char *end);
          ~streambuf() {
            
          }
          streamsize size();
          
      private:
          int_type uflow() override;
          int_type underflow() override;
          int_type pbackfail(int_type ch) override;
          streampos seekoff(streamoff off, ios_base::seekdir way, ios_base::openmode which) override;
          streampos seekpos(streampos sp, ios_base::openmode which) override;
          std::streamsize showmanyc() override;
          
  };

}