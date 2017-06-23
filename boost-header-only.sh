#!/bin/bash

# -------------------------------------
# Create minimalist boost directory
# -------------------------------------

if [ ! $# -eq 1 ]; then
    echo "usage: $( basename $0 ) <branch>"
    exit 1
fi

# You can override the toolset like this: `TOOLSET=clang ./boost.simd.dev.setup.sh`
TOOLSET=gcc
BRANCH=$1
BOOST_DIR=$BRANCH

# Get boost from git
# -------------------------------------
rm -rf $BOOST_DIR
git clone --depth=1 -b $BRANCH https://github.com/boostorg/boost.git $BOOST_DIR

# Move to destination directory
# -------------------------------------
cd $BOOST_DIR

# Get every submodules and get the latest update of the given branch
# -------------------------------------
git_clone() {
    git clone -b $BRANCH --depth=1 https://github.com/$1 $2
}

get_submodules() {
    cat .gitmodules | grep submodule | cut -d '"' -f 2
}

get_path_of_submodule() {
    cat .gitmodules | grep "submodule \"$1\"" -A 3 | grep path | cut -d '=' -f 2 | tr -d ' '
}

for m in $( get_submodules ); do
    # New libraries like `hana` have that extra `libs/` in their names, just get rid of it
    R=$( echo $m | sed 's#^libs/##g' )
    git_clone "boostorg/$R" "$( get_path_of_submodule $m )"
done

# Bootstraping boost
# -------------------------------------
./bootstrap.sh --with-toolset=$TOOLSET
./b2 headers

# Use hard copy instead of symlink (for Windows)
# -------------------------------------
_boost() {
    echo $1 | sed "s/^boost/_boost/g"
}

to_relative_path() {
    echo $1 | sed 's/\.\.\///g'
}

# Create directories
for d in $( find boost -type d ); do
    DST=$( _boost $d )
    mkdir -p $DST
done

# Create directories (that are symlinks)
for d in $( find boost -type l | grep -v '.hpp' ); do
    DST=$( _boost $d )
    SRC=$( to_relative_path $( readlink $d ) )
    cp -rf $SRC $DST
done

# Create files (that are symlinks)
for f in $( find boost -type l | grep '.hpp' ); do
    DST=$( _boost $f )
    SRC=$( to_relative_path $( readlink $f ) )
    cp -f $SRC $DST
done

# Remove extra stuff and finally update `boost` directory with hardcopied files
# -------------------------------------

find . -maxdepth 1\
    | grep -v '_boost'\
    | grep -v LICENSE_1_0.txt\
    | xargs rm -rfv

# Rename _boost
mv _boost boost
