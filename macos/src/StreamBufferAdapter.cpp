#include <streambuf>
#include <functional>
#include <cassert>
#include <cstring>

using namespace std;

namespace polyvox {

class StreamBufferAdapter : public std::streambuf
{
    public:
        StreamBufferAdapter(const char *begin, const char *end);
        ~StreamBufferAdapter() {
          
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

StreamBufferAdapter::StreamBufferAdapter(const char *begin, const char *end)
{
    setg((char*)begin, (char*)begin, (char*)end);
}

streamsize StreamBufferAdapter::size() {
  return egptr() - eback();
}

streambuf::int_type StreamBufferAdapter::underflow()
{
    if (gptr() == egptr()) {
        return traits_type::eof();
    }
    return *(gptr());
}

streambuf::int_type StreamBufferAdapter::uflow()
{
    if (gptr() == egptr()) {
        return traits_type::eof();
    }
    gbump(1);

    return *(gptr());
}

streambuf::int_type StreamBufferAdapter::pbackfail(int_type ch)
{
    if (gptr() ==  eback() || (ch != traits_type::eof() && ch != gptr()[-1]))
        return traits_type::eof();
    gbump(-ch);
    return *(gptr());
}

streamsize StreamBufferAdapter::showmanyc()
{
    return egptr() - gptr();
}

streampos StreamBufferAdapter::seekoff(streamoff off, ios_base::seekdir way, ios_base::openmode which = ios_base::in) {
  if(way == ios_base::beg) {
    setg(eback(), eback()+off, egptr());
  } else if(way == ios_base::cur) {
    gbump(off);
  } else {
    setg(eback(), egptr()-off, egptr());
  }
  return gptr() - eback();
}

streampos StreamBufferAdapter::seekpos(streampos sp, ios_base::openmode which = ios_base::in) {
    return seekoff(sp - pos_type(off_type(0)), std::ios_base::beg, which);
}
}