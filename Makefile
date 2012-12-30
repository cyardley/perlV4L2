V4L_LIB = /usr/lib/x86_64-linux-gnu
V4L_LBLOCK = -L$(V4L_LIB)libv4l1 -L$(V4L_LIB)/libv4l2 -L$(V4L_LIB)/libv4lconvert 
V4L_SOBLOCK = $(V4L_LIB)/libv4l2.so -L$(V4L_LIB)/libv4l2 -L$(V4L_LIB)/libv4lconvert.so
V4L_FLAGS = -lv4l2 -lv4lconvert -lv4l1
GTK_CFG = `pkg-config gtk+-2.0 --cflags --libs)`

all: V4l2.so

examples: grab svv

#svv
svv: svv.c
	gcc $(V4L_LBLOCK) -Wall -O2 svv.c -o svv $(GTK_CFG) $(V4L_SOBLOCK) $(V4L_FLAGS)

#grab - takes pictures
grab: grab.c
	gcc $(V4L_LBLOCK) -o grab grab.c $(V4L_SOBLOCK) $(V4L_FLAGS) 

#Perl Wrapper
#####swig: http://www.swig.org/tutorial.html
V4l2.so: V4l2.o
	gcc $(V4L_LBLOCK) $(shell perl -MConfig -e 'print @Config{lddlflags}') V4l2.o V4l2_wrap.o -o V4l2.so $(V4L_SOBLOCK) $(V4L_FLAGS) 

V4l2.o: V4l2_wrap.c
	gcc  $(GTK_CFG) -c $(shell perl -MConfig -e 'print join(" ", @Config{qw(ccflags optimize cccdlflags)}, "-I @Config{archlib}/CORE")') V4l2.c V4l2_wrap.c

V4l2_wrap.c: V4l2.i V4l2.c
	swig -perl5 V4l2.i

#Clean
clean:
	rm -f V4l2.pm V4l2_wrap.c V4l2.so *.o svv grab
	rm -f out/*

#Clear
clear:
	rm -f out/*
