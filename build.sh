#!/bin/bash

# Color UI
grn=$(tput setaf 2)             # green
yellow=$(tput setaf 3)          # yellow
bldgrn=${txtbld}$(tput setaf 2) # bold green
red=$(tput setaf 1)             # red
txtbld=$(tput bold)             # bold
bldblu=${txtbld}$(tput setaf 4) # bold blue
blu=$(tput setaf 4)             # blue
txtrst=$(tput sgr0)             # reset
blink=$(tput blink)             # blink

#
# Configure defualt value:
# CPU = use all cpu for build
# CHAT = chat telegram for push build. use id.
#
CPU=$(nproc --all)
KEY="none"
SUBNAME="none"
CHAT="-1001441002138"

#
# Add support cmd:
# --cpu= for cpu used to compile
# --key= for bot key used to push.
# --name= for custom subname of kernel
#
config() {

    arg1=${1}

    case ${1} in
        "--cpu="* )
            CPU="--cpu="
            CPU=${arg1#"$CPU"}
        ;;
        "--key="* )
            KEY="--key="
            KEY=${arg1#"$KEY"}
        ;;
        "--name="* )
            SUBNAME="--name="
            SUBNAME=${arg1#"$SUBNAME"}
        ;;
    esac
}

arg1=${1}
arg2=${2}
arg3=${3}

config ${1}
config ${2}
config ${3}

echo "Config for resource of environment done."
echo "CPU for build: $CPU"
echo "KEY for telegram push: $KEY"
echo "NAME of kernel: $SUBNAME"

if [ ! $KEY == "none" ]; then
    curl -s -X POST https://api.telegram.org/bot"$KEY"/sendMessage \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d chat_id="$CHAT" \
        -d text="<b>• Build For Lavender started •</b>"
fi

# Clean stuff
if [ -f "out/arch/arm64/boot/Image.gz-dtb" ]; then
    rm -rf "out/arch/arm64/boot/Image.gz-dtb"
fi

# start build date
DATE=$(date +"%Y%m%d-%H%M")

# Compiler type
TOOLCHAIN_DIRECTORY="../"

# Build defconfig
DEFCONFIG="lavender_defconfig"

# Check for compiler
if [ ! -d "$TOOLCHAIN_DIRECTORY" ]; then
    mkdir $TOOLCHAIN_DIRECTORY
fi


if [ -d "$TOOLCHAIN_DIRECTORY/custom-clang" ]; then
    echo -e "${bldgrn}"
    echo "clang is ready"
    echo -e "${txtrst}"
else
    echo -e "${red}"
    echo "Need to download clang"
    echo -e "${txtrst}"
    exit
fi

#
# Build start with clang
#
PATH="$(pwd)/$TOOLCHAIN_DIRECTORY/custom-clang/bin:${PATH}"
make O=out CC=clang ARCH=arm64 $DEFCONFIG
make -j$CPU O=out \
			ARCH=arm64 \
			CC=clang \
			AR=llvm-ar \
			NM=llvm-nm \
			OBJCOPY=llvm-objcopy \
			OBJDUMP=llvm-objdump \
			STRIP=llvm-strip \
			CROSS_COMPILE=aarch64-linux-gnu- \
			CROSS_COMPILE_ARM32=arm-linux-gnueabi-

if [ ! -f "out/arch/arm64/boot/Image.gz-dtb" ]; then
    echo -e "${red}"
    echo "Error"
    echo -e "${txtrst}"
    exit
fi

# Download anykernel for flash kernel
git clone --depth=1 https://github.com/Peppe289/AnyKernel3.git -b lavender anykernel

# If download of anykernel give some error abort zip operation
if [ ! -f "anykernel/anykernel.sh" ]; then
    echo -e "${red}"
    echo "AnyKernel error. Abort zip."
    echo -e "${txtrts}"
    echo "The path of the Image.gz-dtb is: $(pwd)/out/arch/arm64/boot/Image.gz-dtb"
    exit
fi

if [ $SUBNAME == "none" ]; then
    SUBNAME=$DATE
fi

cp out/arch/arm64/boot/Image.gz-dtb anykernel
cd anykernel
zip -r9 ../Rave-$SUBNAME.zip * -x .git README.md *placeholder
cd ..
rm -rf anykernel
echo "The path of the kernel.zip is: $(pwd)/Rave-$SUBNAME.zip"

if [ ! $KEY == "none" ]; then
    curl -F chat_id="$CHAT" \
        -F caption="-Keep Rave" \
        -F document=@"Rave-$SUBNAME.zip" \
        https://api.telegram.org/bot"$KEY"/sendDocument

    curl -s -X POST "https://api.telegram.org/bot"${1}"/sendMessage" \
	    -d chat_id="$CHAT" \
	    -d "disable_web_page_preview=true" \
	    -d "parse_mode=html" \
	    -d text="<b>Branch</b>: <code>$(git rev-parse --abbrev-ref HEAD)</code>%0A<b>Last Commit</b>: <code>$(git log --pretty=format:'%s' -1)</code>%0A<b>Kernel Version</b>: <code>$(make kernelversion)</code>"
fi
