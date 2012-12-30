#!/usr/bin/perl
#Grab.pl
# Perl Implementation of this:
#    http://linuxtv.org/downloads/v4l-dvb-apis/v4l2grab-example.html

use V4l2;
#Init
$ifmt = V4l2::v4l2_format::new();
$ireq = V4l2::v4l2_requestbuffers::new();
$ibuf = V4l2::v4l2_buffer::new();
$sfmt = V4l2::v4l2_format::new();
$cint = V4l2::intp::new();
$DELAY = 0;
$nPIC = 10;
$fd = -1;
@buffers;
$n_buffers;
$BUF_REQ = 2;
$IMG_WIDTH = 640;
$IMG_HEIGHT = 480;
$dev_name = "/dev/video0";

#Open Device
print "...Open: ";
$fd = V4l2::v4l2_open($dev_name, $V4l2::O_RDWR | $V4l2::O_NONBLOCK, 0);
if ($fd < 0) { print "Error!\n"; die; }else{ print "Success!\n"; }
#Set Video Format
print "...Set Video Format\n";
V4l2::CLEAR($ifmt);
$ifmt->{type} = $V4l2::V4L2_BUF_TYPE_VIDEO_CAPTURE;
$ifmt->{fmt}->{pix}->{width} = $IMG_WIDTH;
$ifmt->{fmt}->{pix}->{height} = $IMG_HEIGHT;
$ifmt->{fmt}->{pix}->{pixelformat} =  $V4l2::V4L2_PIX_FMT_RGB24;
$ifmt->{fmt}->{pix}->{field} = $V4l2::V4L2_FIELD_INTERLACED;
print $ifmt->{fmt}->{pix}->{pixelformat} . "\n";
V4l2::xioctl($fd, $V4l2::VIDIOC_S_FMT, $ifmt);
if ($ifmt->{fmt}->{pix}->{pixelformat} != $V4l2::V4L2_PIX_FMT_RGB24) {
    print "Libv4l didn't accept RGB24 format. Can't proceed.\n";
    die;
}
if (($ifmt->{fmt}->{pix}->{width} != $IMG_WIDTH)
 || ($ifmt->{fmt}->{pix}->{height} != $IMG_HEIGHT)){
    print "Warning: driver is sending image at ";
    print $ifmt->{fmt}->{pix}->{width}, $ifmt->{fmt}->{pix}->{height};
}

#Request Buffers
print "...Request Buffers\n";
V4l2::CLEAR($ireq); 
$ireq->{count} = $BUF_REQ;
$ireq->{type} = $V4l2::V4L2_BUF_TYPE_VIDEO_CAPTURE;
$ireq->{memory} = $V4l2::V4L2_MEMORY_MMAP;
V4l2::xioctl($fd, $V4l2::VIDIOC_REQBUFS, $ireq);

#Create Buffer
print "...Create Buffers\n";
for($i=0; $i<$BUF_REQ; $i++){
    push(@buffer, V4l2::v4l2_buffer::new());
}

#MMAP Buffers
print"...Query & MMAP Buffers\n";
for ($n_buffers = 0; $n_buffers < $BUF_REQ; $n_buffers++) {
    V4l2::CLEAR($ibuf);
    $ibuf->{type}        = $V4l2::V4L2_BUF_TYPE_VIDEO_CAPTURE;
    $ibuf->{memory}      = $V4l2::V4L2_MEMORY_MMAP;
    $ibuf->{index}       = $n_buffers;
    V4l2::xioctl($fd, $V4l2::VIDIOC_QUERYBUF, $ibuf);
    $buffers[$n_buffers]->{length} = $ibuf->{length};
    $buffers[$n_buffers]->{start} = V4l2::v4l2_mmap(undef, $ibuf->{length},
                                    $V4l2::PROT_READ | $V4l2::PROT_WRITE, 
                                    $V4l2::MAP_SHARED, $fd, $ibuf->{m}->{offset});
    if ($V4l2::MAP_FAILED == $buffers[$n_buffers]->{start}) {
        print "ERROR: MMAP (" . $n_buffers . ")\n";
        die;
    }
}

#Set Buffers
print "...Set Buffers\n";
for ($i = 0; $i < $n_buffers; $i++) {
    V4l2::CLEAR(buf);
    $ibuf->{type} = $V4l2::V4L2_BUF_TYPE_VIDEO_CAPTURE;
    $ibuf->{memory} = $V4l2::V4L2_MEMORY_MMAP;
    $ibuf->{index} = $i;
    V4l2::xioctl($fd, $V4l2::VIDIOC_QBUF, $ibuf);
}
#Stream On
print $fd . "...Video Stream ON\n";;
V4l2::intp::assign($cint, $V4l2::V4L2_BUF_TYPE_VIDEO_CAPTURE);
V4l2::xioctl($fd, $V4l2::VIDIOC_STREAMON, $cint);

#Capture Loop
print "...Enter Capture Loop\n";
for ($i = 0; $i < $nPIC; $i++) {
    #Time Delay
    sleep $DELAY;
    #File Out
    print "..." . $i . ": DeQueue Buffer";
    V4l2::CLEAR($ibuf);
    $ibuf->{type} = $V4l2::V4L2_BUF_TYPE_VIDEO_CAPTURE;
    $ibuf->{memory} = $V4l2::V4L2_MEMORY_MMAP;
    V4l2::xioctl($fd, $V4l2::VIDIOC_DQBUF, $ibuf);
    printf ", File Out";
    $s_name = "out/image_" . $i . ".ppm";
    $s_head = "P6\n" . $IMG_WIDTH . " " . $IMG_HEIGHT . " 255\n";
    V4l2::buf_to_file($s_name, "w", $s_head,
                      $buffers[$ibuf->{index}]->{start}, $ibuf->{bytesused});
    print ", Queue Buffer\n";
    V4l2::xioctl($fd, $V4l2::VIDIOC_QBUF, $ibuf);
}
print "...Exit Capture Loop\n";

#Video Stream Off
print "...Video Stream OFF\n";
V4l2::intp::assign($cint, $V4l2::V4L2_BUF_TYPE_VIDEO_CAPTURE);
V4l2::xioctl($fd, $V4l2::VIDIOC_STREAMOFF, $cint);

#Munmap Buffers
print "...MUNMAP Buffers\n";
for ($i = 0; $i < $n_buffers; $i++){
    V4l2::v4l2_munmap($buffers[$i]->{start}, $buffers[$i]->{length});
}

#Close
print "...CLOSE\n";
V4l2::v4l2_close($fd);
print "...Shutdown\n";
exit 0;
