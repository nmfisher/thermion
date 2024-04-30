#include <streambuf>
#include <functional>
#include <cassert>
#include <cstring>

namespace flutter_filament {

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

StreamBufferAdapter::StreamBufferAdapter(const char *begin, const char *end)
{
    setg((char*)begin, (char*)begin, (char*)end);
}

std::streamsize StreamBufferAdapter::size() {
  return egptr() - eback();
}

std::streambuf::int_type StreamBufferAdapter::underflow()
{
    if (gptr() == egptr()) {
        return traits_type::eof();
    }
    return *(gptr());
}

std::streambuf::int_type StreamBufferAdapter::uflow()
{
    if (gptr() == egptr()) {
        return traits_type::eof();
    }
    gbump(1);

    return *(gptr());
}

std::streambuf::int_type StreamBufferAdapter::pbackfail(int_type ch)
{
    if (gptr() ==  eback() || (ch != traits_type::eof() && ch != gptr()[-1]))
        return traits_type::eof();
    gbump(-ch);
    return *(gptr());
}

std::streamsize StreamBufferAdapter::showmanyc()
{
    return egptr() - gptr();
}

std::streampos StreamBufferAdapter::seekoff(std::streamoff off, std::ios_base::seekdir way, std::ios_base::openmode which = std::ios_base::in) {
  if(way == std::ios_base::beg) {
    setg(eback(), eback()+off, egptr());
  } else if(way == std::ios_base::cur) {
    gbump((int)off);
  } else {
    setg(eback(), egptr()-off, egptr());
  }
  return gptr() - eback();
}

std::streampos StreamBufferAdapter::seekpos(std::streampos sp, std::ios_base::openmode which = std::ios_base::in) {
    return seekoff(sp - pos_type(off_type(0)), std::ios_base::beg, which);
}
}