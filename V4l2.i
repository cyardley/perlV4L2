%module V4l2
%include "lib/swig/cpointer.i"
%include "lib/swig/carrays.i"

#C Variable wrappers
%pointer_class(int, intp);
%pointer_class(long int, lintp);
%pointer_class(char, charp);
%array_class(char, cstr);

#TypeMaps
%apply int { int*};
%apply char { __s8 };
%apply unsigned char { __u8 };
%apply char* { __u8* };
%apply short { __s16 };
%apply unsigned short { __u16 };
%apply int { __s32 };
%apply unsigned int { __u32 };
%apply long long int { int64_t };
%apply __u8* { int* };

%inline %{
    #include "lib/include/videodev2.h"
    #include "lib/include/libv4l2.h"
    #include "lib/include/libv4lconvert.h"
    #define CLEAR(x) memset(&(x), 0, sizeof(x))
    struct buffer {
        void   *start;
        size_t length;
    };
%}
%perlcode%{
    #perl helper functions
%}
#Perl library for SWIG
%include "lib/swig/perl5/perl5.swg"

#Header files
%include "lib/include/videodev2.h"
%include "lib/include/libv4l2.h"
%include "lib/include/libv4lconvert.h"
%include "lib/fcntl.h"


extern void xioctl(int fh, long int request, void* arg);
extern void buf_to_file(char* out_name, char* mode, char* header, void* start, size_t length);

