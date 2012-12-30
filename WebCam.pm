#!/usr/bin/perl
package WebCam;
use Graphics::Magick; #package: libgraphics-magick-perl
use Image::Compare; #install from cpan
use V4l2;
use Gtk2;
use base 'Exporter';
our @EXPORT = qw(on nextImage compare save compress close);

$PFIX = "/tmp/WEBCAM_";

my $imgfile;
our $dev_name;
our $fd;
our @buffers;
our @n_buffers;
our @BUF_REQ;
our $ifmt;
our $ireq;
our $ibuf;
our $cint;
our $img;
our $imgbuf;
our $MEMORY;
sub new{
    $dev_name = $_[0];
    $fd = -1;
    @buffers;
    $n_buffers;
    $BUF_REQ = 2;
    $ifmt = V4l2::v4l2_format::new();
    $ireq = V4l2::v4l2_requestbuffers::new();
    $ibuf = V4l2::v4l2_buffer::new();
    $cint = V4l2::intp::new();
    $img = Gtk2::Image->new;
}

sub on{
    #Open Device
    print "...Open " . $dev_name . ": ";
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
    V4l2::xioctl($fd, $V4l2::VIDIOC_S_FMT, $ifmt);
    if ($ifmt->{fmt}->{pix}->{pixelformat} != $V4l2::V4L2_PIX_FMT_RGB24) {
        print "Libv4l didn't accept RGB24 format. Can't proceed.\n";
        die;
    }
    if (($ifmt->{fmt}->{pix}->{width} != 640)
     || ($ifmt->{fmt}->{pix}->{height} != 480)){
        print "Warning: driver is sending image at ";
        print $ifmt->{fmt}->{pix}->{width} . ", " . $ifmt->{fmt}->{pix}->{height} . "\n";
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
    print "...Video Stream ON\n";;
    V4l2::intp::assign($cint, $V4l2::V4L2_BUF_TYPE_VIDEO_CAPTURE);
    V4l2::xioctl($fd, $V4l2::VIDIOC_STREAMON, $cint);

}

sub save{
    $n = $_[1];
    print "Saving Image to: " . $n . ".jpeg\n";
    nextImage();
    my $image = new Graphics::Magick;
    $image->Read($PFIX . "buff.ppm");
    $image->Set(compression=>'JPEG');
    $image->Write($n . ".jpeg");
}

sub nextImage{
    V4l2::CLEAR($ibuf);
    $ibuf->{type} = $V4l2::V4L2_BUF_TYPE_VIDEO_CAPTURE;
    $ibuf->{memory} = $V4l2::V4L2_MEMORY_MMAP;
    V4l2::xioctl($fd, $V4l2::VIDIOC_DQBUF, $ibuf);
    $s_head = "P6\n" . $ifmt->{fmt}->{pix}->{width} . " " . $ifmt->{fmt}->{pix}->{height} . " 255\n";
    V4l2::buf_to_file($PFIX . "buff.ppm", "w", $s_head,
                      $buffers[$ibuf->{index}]->{start}, $ibuf->{bytesused});
    V4l2::xioctl($fd, $V4l2::VIDIOC_QBUF, $ibuf);
}

sub compare{
    my $cmp = Image::Compare->new();
    $cmp->set_method(
        method => &Image::Compare::THRESHOLD,
        args   => 50,
    );
    $cmp->set_image1(
        img  => $PFIX . 'current.jpeg',
        type => 'jpeg',
    );
    $cmp->set_image2(
        img  => $PFIX . 'previous.jpeg',
        type => 'jpeg',
    );
    if ($cmp->compare()){
        $r = 0;
    }else{
        $r = 1;
    }
    return $r;
}

sub compress{
    #Set previous image (for compare)
    my $imprv = new Graphics::Magick;
    $imprv->Read($PFIX . "buff.ppm");
    $imprv->Set(compression=>'JPEG');
    $imprv->Resize(width=>100, height=>100);
    $imprv->Write($PFIX . "previous.jpeg");
    #get next image
    nextImage();
    #set current image (for compare)
    my $imcur = new Graphics::Magick;
    $imcur->Read($PFIX . "buff.ppm");
    $imcur->Set(compression=>'JPEG');
    $imcur->Resize(width=>100, height=>100);
    $imcur->Write($PFIX . "current.jpeg");
    #Image
    my $image = new Graphics::Magick;
    $image->Read($PFIX . "buff.ppm");
    $image->Resize(width=>320, height=>240, blur=>0, filter=>Gaussian);
    $image->Write($PFIX . "buff.jpeg");
    close(FH);
}
    

sub close{
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
}

1;#End WebCam
