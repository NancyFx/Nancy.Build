#!/bin/bash
echo "Preparing to run build script..."

TARGET="default"
VERBOSITY="verbose"
DRYRUN=
SHOW_VERSION=false

SCRIPT_NAME="build.cake"
TOOLS_DIR="tools"
NUGET_EXE="$TOOLS_DIR/nuget.exe"
NUGET_URL="http://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
CAKE_VERSION="0.16.0"
CAKE_PATH="$TOOLS_DIR/Cake.$CAKE_VERSION/Cake.exe"

SCRIPT_ARGUMENTS=()

# Parse arguments.
for i in "$@"; do
    case $1 in
        --target ) TARGET="$2"; shift ;;
        -s|--script) SCRIPT_NAME="$2"; shift ;;
        -v|--verbosity) VERBOSITY="$2"; shift ;;
        -d|--dryrun) DRYRUN="-dryrun" ;;
        --version) SHOW_VERSION=true ;;
        --) shift; SCRIPT_ARGUMENTS+=("$@"); break ;;
        *) SCRIPT_ARGUMENTS+=("$1") ;;
    esac
    shift
done

function installnuget() {
    echo "Checking for nuget"
    if ! [ -x "$(command -v nuget)" ] ; then
        echo "Installing nuget to $TOOLS_DIR"
        wget -O $TOOLS_DIR $NUGET_URL
        export PATH=$TOOLS_DIR:$PATH
    fi
}

function installcake() {
  echo "Checking for Cake at "$CAKE_PATH
  if [ ! -f $CAKE_PATH ]; then
    echo "Installing Cake"
    nuget install Cake -Version $CAKE_VERSION -OutputDirectory $TOOLS_DIR
  fi
}

function runbuildscript() {
  if $SHOW_VERSION; then
      mono $CAKE_PATH -version
  else
      echo "Executing "mono $CAKE_PATH $SCRIPT_NAME -target=$TARGET -verbosity=$VERBOSITY $DRYRUN "${SCRIPT_ARGUMENTS[@]}"
      mono $CAKE_PATH $SCRIPT_NAME -target=$TARGET -verbosity=$VERBOSITY $DRYRUN "${SCRIPT_ARGUMENTS[@]}"
  fi
}

installnuget
installcake
runbuildscript