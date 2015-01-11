#!/bin/bash

# where install Enigma2 tree
INSTALL_E2DIR="/usr/local/e2"

BACKUP_E2="etc/enigma2 etc/tuxbox/*.xml etc/tuxbox/nim_sockets share/enigma2/xine.conf"

# ----------------------------------------------------------------------

DO_BACKUP=0
DO_RESTORE=0
DO_XINE=1
DO_CONFIGURE=1
DO_PARALLEL=1
DO_MAKEINSTALL=1

function e2_backup {
        echo "-----------------------------"
        echo "BACKUP E2 CONFIG"
        echo "-----------------------------"

	tar -C $INSTALL_E2DIR -v -c -z -f e2backup.tgz $BACKUP_E2
}

function e2_restore {
        echo "-----------------------------"
        echo "RESTORE OLD E2 CONFIG"
        echo "-----------------------------"
        
	if [ -f e2backup.tgz ]; then
		sudo tar -C $INSTALL_E2DIR -v -x -z -f e2backup.tgz
	fi
}

function usage {
	echo "Usage:"
	echo " -b : backup E2 conf file before re-compile"
	echo " -r : restore E2 conf file after re-compile"
	echo " -x : don't compile xine-lib (compile only enigma2)"
	echo " -nc: don't start configure/autoconf"
	echo " -py: parallel compile (y threads) e.g. -p2"
	echo " -ni: only execute make and no make install"
	echo " -h : this help"
	echo ""
	echo "common usage:"
	echo "  $0 -b -r : make E2 backup, compile E2, restore E2 conf files"
	echo ""
}

while [ "$1" != "" ]; do
    case $1 in
        -b ) 	DO_BACKUP=1
              shift
              ;;
        -r ) 	DO_RESTORE=1
		          shift
              ;;
	      -x )	DO_XINE=0
		          shift
		          ;;
	      -nc )	DO_CONFIGURE=0
		          shift
		          ;;
        -ni )	DO_MAKEINSTALL=0
		          shift
		          ;;
        -p* ) if [ "`expr substr "$1" 3 3`" = "" ]
              then
                 echo "Number threads is missing"
                 usage
                 exit
              else
                 DO_PARALLEL=`expr substr "$1" 3 3`
              fi     
              shift
		          ;;
	      -h )  usage
	      	    exit
	      	    ;;
	      * )  	echo "Unknown parameter $1"
	      	    usage
	      	    exit
	      	    ;;
    esac
done

if [ "$DO_BACKUP" -eq "1" ]; then
	e2_backup
fi

# ----------------------------------------------------------------------

if [ "$DO_XINE" -eq "1" ]; then

	# Build and install xine-lib:
	PKG="xine-lib"

	cd $PKG
	
  if [ "$DO_CONFIGURE" -eq "1" ]; then	
	  echo "-----------------------------------------"
	  echo "configuring OpenPliPC $PKG"
	  echo "-----------------------------------------"

	  ./autogen.sh --disable-xinerama --disable-musepack --disable-vcd --disable-modplug --prefix=/usr
  fi	

  if [ "$DO_MAKEINSTALL" -eq "0" ]; then
	  echo "-----------------------------------------"
	  echo "build OpenPliPC $PKG, please wait..."
	  echo "-----------------------------------------"

	  make -j"$DO_PARALLEL"
    if [ ! $? -eq 0 ]
    then
      echo ""
      echo "An error occured while building xine-lib"
      exit
    fi
    
  else
	  echo "--------------------------------------"
	  echo "installing OpenPliPC $PKG"
	  echo "--------------------------------------"

	  sudo make -j"$DO_PARALLEL" install
    if [ ! $? -eq 0 ]
    then
      echo ""
      echo "An error occured while building xine-lib"
      exit
    fi
  fi
    
	cd ..

fi

# ----------------------------------------------------------------------

# Build and install enigma2:

PKG="enigma2"

cd $PKG

if [ "$DO_CONFIGURE" -eq "1" ]; then

  echo "--------------------------------------"
  echo "configuring OpenPliPC $PKG"
  echo "--------------------------------------"

  autoreconf -i
  ./configure --prefix=$INSTALL_E2DIR --with-xlib --with-debug PYTHON="/usr/bin/python2"
fi  
 
echo "--------------------------------------"
echo "build OpenPliPC $PKG, please wait..."
echo "--------------------------------------"

if [ "$DO_MAKEINSTALL" -eq "0" ]; then
  make -j"$DO_PARALLEL"
  if [ ! $? -eq 0 ]
  then
    echo ""
    echo "An error occured while building OpenPliPC"
    exit
  fi
  
else  
  echo "--------------------------------------"
  echo "installing OpenPliPC $PKG in $INSTALL_E2DIR"
  echo "--------------------------------------"

  sudo make -j"$DO_PARALLEL" install
  if [ ! $? -eq 0 ]
  then
    echo ""
    echo "An error occured while building OpenPliPC"
    exit
  fi
fi  
cd ..
 
echo "--------------------------------------"
echo "final step: installing E2 conf files"
echo "--------------------------------------"

# strip binary
sudo strip $INSTALL_E2DIR/bin/enigma2

# removing pre-compiled py files
sudo find $INSTALL_E2DIR/lib/enigma2/python/ -name "*.py[oc]" -exec rm {} \;

# copying needed files
sudo mkdir -p $INSTALL_E2DIR/etc/enigma2
sudo mkdir -p $INSTALL_E2DIR/etc/tuxbox
sudo cp share/fonts/* $INSTALL_E2DIR/share/fonts
sudo cp -rf etc/* $INSTALL_E2DIR/etc
sudo cp enigma2/data/black.mvi $INSTALL_E2DIR/etc/tuxbox/logo.mvi

ln -sf $INSTALL_E2DIR/bin/enigma2 ./e2bin

if [ "$DO_RESTORE" -eq "1" ]; then
	e2_restore
fi

echo ""
echo "**********************<END>**********************"
