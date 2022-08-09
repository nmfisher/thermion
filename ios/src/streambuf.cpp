#include <streambuf>
#include <functional>
#include <cassert>
#include <cstring>

using namespace std;

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

streambuf::streambuf(const char *begin, const char *end)
{
    setg((char*)begin, (char*)begin, (char*)end);
}

streamsize streambuf::size() {
  return egptr() - eback();
}

streambuf::int_type streambuf::underflow()
{
    if (gptr() == egptr()) {
        return traits_type::eof();
    }
    return *(gptr());
}

streambuf::int_type streambuf::uflow()
{
    if (gptr() == egptr()) {
        return traits_type::eof();
    }
    gbump(1);

    return *(gptr());
}

streambuf::int_type streambuf::pbackfail(int_type ch)
{
    if (gptr() ==  eback() || (ch != traits_type::eof() && ch != gptr()[-1]))
        return traits_type::eof();
    gbump(-ch);
    return *(gptr());
}

streamsize streambuf::showmanyc()
{
    return egptr() - gptr();
}

streampos streambuf::seekoff(streamoff off, ios_base::seekdir way, ios_base::openmode which = ios_base::in) {
  if(way == ios_base::beg) {
    setg(eback(), eback()+off, egptr());
  } else if(way == ios_base::cur) {
    gbump(off);
  } else {
    setg(eback(), egptr()-off, egptr());
  }
  return gptr() - eback();
}

streampos streambuf::seekpos(streampos sp, ios_base::openmode which = ios_base::in) {
    return seekoff(sp - pos_type(off_type(0)), std::ios_base::beg, which);
}
}