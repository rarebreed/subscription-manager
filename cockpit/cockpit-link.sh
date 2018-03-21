# Links our web app to cockpit
# usage:
# ./cockpit-link.sh linked-dir name-of-link
#
# Example:  from quartermaster directory
# ./cockpit-link.sh build quartermaster     # will link the build directory for quartermaster 
# ./cockpit-link.sh spec quartermaster-test # will link the spec directory for quartermaster-test 
mkdir -p ~/.local/share/cockpit
pushd `dirname $0` > /dev/null
SCRIPTPATH=$PWD
popd
pushd "$SCRIPTPATH/$1"
ln -snf $PWD ~/.local/share/cockpit/$2
popd