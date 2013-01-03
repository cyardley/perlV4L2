//Perl wrapper for Video 4 Linux 2
//Casey Yardley
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/mman.h>
#include <linux/videodev2.h>
#include <libv4l2.h>
#include <libv4lconvert.h>
#include <libv4l1.h>
#include <gtk/gtk.h>

#define CLEAR(x) memset(&(x), 0, sizeof(x))
struct buffer {
        void   *start;
        size_t length;
};
void xioctl(int fh, long int request, void* arg){
    int r=-1;
    do {
        r = v4l2_ioctl(fh, request, arg);
    } while (r == -1 && ((errno == EINTR) || (errno == EAGAIN)));
    if (r == -1) {
        fprintf(stderr, "error %d, %s\n", errno, strerror(errno));
        exit(EXIT_FAILURE);
    }
}
void buf_to_file(char* out_name, char* mode, char* header, void* start, size_t length){
    FILE *fout = fopen(out_name, mode);
    if (!fout) {
        perror("Cannot open image");
        exit(EXIT_FAILURE);
    }
    fprintf(fout, "%s", header);
    fwrite(start, length, 1, fout);
    fclose(fout);
}

//INFO
void printVIDCAP(int fh){
    struct v4l2_capability capability;
    xioctl(fh, VIDIOC_QUERYCAP, &capability);
    printf("Video Device: \"%i\"=======\n", fh);
    printf("Driver: %s\nCard: %s \n", capability.driver, capability.card);
    printf("Bus Info: %s\nVersion: %i \n", capability.bus_info, capability.version);
    printf("Capabilites: (%i)\n", capability.capabilities);
    printf("Video In: ");
    if(capability.capabilities & V4L2_CAP_VIDEO_CAPTURE) printf("YES\n"); else printf("NO\n");
    printf("Audio In: ");
    if(capability.capabilities & V4L2_CAP_AUDIO) printf("YES\n"); else printf("NO\n");
    printf("==========================================\n");
    return;
}

/*
//__X__ C TEST DRIVER CODE
//NOT PART OF THE V4L2 INTERFACE

struct v4l2_format              fmt;
struct v4l2_format 		dst_fmt;
struct v4l2_buffer              buf;
struct v4l2_requestbuffers      req;
struct buffer			*buffers;

struct v4lconvert_data *v4lconvert_data;
unsigned char *dst_buf;

enum v4l2_buf_type              type;

int v4l2_X_open(char* dev_name){
    printf("...Open\n");
    int fd = v4l2_open(dev_name, O_RDWR | O_NONBLOCK, 0);
    if (fd < 0) {
        perror("Cannot open device");
        exit(EXIT_FAILURE);
    }
    return fd;
}
void v4l2_X_sfmt(int fd){
    printf("...Set Video Format\n");
    CLEAR(fmt);
    fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    fmt.fmt.pix.width       = 640;
    fmt.fmt.pix.height      = 480;
    fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_RGB24;
    fmt.fmt.pix.field       = V4L2_FIELD_INTERLACED;
    CLEAR(dst_fmt);
    dst_fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    dst_fmt.fmt.pix.width       = 640;
    dst_fmt.fmt.pix.height      = 480;
    dst_fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_JPEG;
    dst_fmt.fmt.pix.field       = V4L2_FIELD_INTERLACED;
    //xioctl(fd, VIDIOC_S_FMT, &dst_fmt);
    //Init Convert
    printf("...Init Convert\n");
    v4lconvert_data = v4lconvert_create(fd);
    if (v4lconvert_data == NULL){ printf("***ERROR: v4lconvert_create\n"); exit(1); }
    int x=0;
    printf("dst: %i, src: %i\n", dst_fmt.fmt.pix.pixelformat, fmt.fmt.pix.pixelformat);
    if (x = v4lconvert_try_format(v4lconvert_data, &fmt, &dst_fmt) != 0){
        printf("x: %i, dst: %i, src: %i\n", x, dst_fmt.fmt.pix.pixelformat, fmt.fmt.pix.pixelformat);
        printf("***ERROR: Try Format: Conversion Impossible\n");
        exit(1);
    }
    xioctl(fd, VIDIOC_S_FMT, &fmt);
    dst_buf = (unsigned char*)malloc(fmt.fmt.pix.sizeimage);
    printf("x: %i, dst_size: %i, dst: %i, src: %i\n", x, fmt.fmt.pix.sizeimage, dst_fmt.fmt.pix.pixelformat, fmt.fmt.pix.pixelformat);
    return;
}
void v4l2_X_rbuf(int fd){
    printf("...Request Buffers\n");
    CLEAR(req);
    req.count = 2;
    req.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    req.memory = V4L2_MEMORY_MMAP;
    xioctl(fd, VIDIOC_REQBUFS, &req);
    return;
}
void v4l2_X_createBufs(int n){
    buffers = calloc(n, sizeof(*buffers));
}
int v4l2_X_qmmap(int fd){
    printf("...Query & MMAP Buffers\n");
    int n_buffers; for (n_buffers = 0; n_buffers < 2; ++n_buffers) {
        CLEAR(buf);
        buf.type        = V4L2_BUF_TYPE_VIDEO_CAPTURE;
        buf.memory      = V4L2_MEMORY_MMAP;
        buf.index       = n_buffers;
        xioctl(fd, VIDIOC_QUERYBUF, &buf);
        buffers[n_buffers].length = buf.length;
        buffers[n_buffers].start = v4l2_mmap(NULL, buf.length,
                                             PROT_READ | PROT_WRITE, MAP_SHARED,
                                             fd, buf.m.offset);
        if (MAP_FAILED == buffers[n_buffers].start) {
            perror("mmap");
            exit(EXIT_FAILURE);
        }
    }
    return n_buffers;
}
void v4l2_X_setbufs(int fd, int n_buffers){
    printf("...Set Buffers\n");
    int i; for (i = 0; i < n_buffers; ++i) {
        CLEAR(buf);
        buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
        buf.memory = V4L2_MEMORY_MMAP;
        buf.index = i;
        xioctl(fd, VIDIOC_QBUF, &buf);
    }
}
void v4l2_X_streamOn(int fd){
    printf("...Video Stream ON\n");
    type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    xioctl(fd, VIDIOC_STREAMON, &type);
}
void v4l2_X_outBuf(int fd, int i, int w, int h){
    printf("...%i: DeQueue Buffer", i);
    CLEAR(buf);
    buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    buf.memory = V4L2_MEMORY_MMAP;
    xioctl(fd, VIDIOC_DQBUF, &buf);
    //Convert
printf("before convert\n");
    if (v4lconvert_convert(v4lconvert_data, &fmt, &dst_fmt,
	                   buffers[buf.index].start, buf.bytesused,
		           dst_buf, dst_fmt.fmt.pix.sizeimage) < 0) {
        printf("***Error converting image***\n");
    }
    //File out
    char out_name[256];
    FILE *fout;
    printf(", File Out");
    sprintf(out_name, "out/image_%03d.jpeg", i);	//sprintf(out_name, "out%03d.ppm", i);
    fout = fopen(out_name, "w");
    if (!fout) {
        perror("Cannot open image");
        exit(EXIT_FAILURE);
    }
    //fprintf(fout, "P6\n%d %d 255\n", w, h);
    fwrite(dst_buf, dst_fmt.fmt.pix.sizeimage, 1, fout);
    fclose(fout);
    printf(", Queue Buffer\n");
    xioctl(fd, VIDIOC_QBUF, &buf);
    return;
}
void v4l2_X_streamOff(int fd){
    printf("...Video Stream OFF\n");
    type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    xioctl(fd, VIDIOC_STREAMOFF, &type);
    return;
}
void v4l2_X_munmapBuf(int fd, int n_buffers){
    printf("...MUNMAP Buffers\n");
    int i; for (i = 0; i < n_buffers; ++i)
        v4l2_munmap(buffers[i].start, buffers[i].length);
    return;
}
void v4l2_X_close(int fd){
    printf("...CLOSE\n");
    v4l2_close(fd);
}

//Test Driver
int testDriver(char* dev_name){
    int fd = v4l2_X_open(dev_name);
    v4l2_X_sfmt(fd);
    v4l2_X_rbuf(fd);
    v4l2_X_createBufs(2);
    int n_buffers = v4l2_X_qmmap(fd);        
    v4l2_X_setbufs(fd, n_buffers);
    v4l2_X_streamOn(fd);
    printf("...Enter Capture Loop\n");
    int i; for (i = 0; i < 20; i++) {
        //put delay here
        v4l2_X_outBuf(fd, i, 640, 480);
    }
    printf("...Exit Capture Loop\n");
    printf("...Shutdown\n");
    v4l2_X_streamOff(fd);
    v4l2_X_munmapBuf(fd, n_buffers);
    v4l2_X_close(fd);
    return 0;
}

int main(int argv, char* argc[]){
    return testDriver("/dev/video0");
}

*/
