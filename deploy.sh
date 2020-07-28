#!/bin/bash

# ----------------------
# KUDU Deployment Script
# Version: 1.0.17
# ----------------------

# Helpers
# -------

exitWithMessageOnError () {
  if [ ! $? -eq 0 ]; then
    echo "An error has occurred during web site deployment."
    echo $1
    exit 1
  fi
}

# Prerequisites
# -------------

# Verify node.js installed
hash node 2>/dev/null
exitWithMessageOnError "Missing node.js executable, please install node.js, if already installed make sure it can be reached from current environment."

# Setup
# -----

SCRIPT_DIR="${BASH_SOURCE[0]%\\*}"
SCRIPT_DIR="${SCRIPT_DIR%/*}"
ARTifACTS=$SCRIPT_DIR/../artifacts
KUDU_SYNC_CMD=${KUDU_SYNC_CMD//\"}

if [[ ! -n "$DEPLOYMENT_SOURCE" ]]; then
  DEPLOYMENT_SOURCE=$SCRIPT_DIR
fi

if [[ ! -n "$NEXT_MANifEST_PATH" ]]; then
  NEXT_MANifEST_PATH=$ARTifACTS/manifest

  if [[ ! -n "$PREVIOUS_MANifEST_PATH" ]]; then
    PREVIOUS_MANifEST_PATH=$NEXT_MANifEST_PATH
  fi
fi

if [[ ! -n "$DEPLOYMENT_TARGET" ]]; then
  DEPLOYMENT_TARGET=$ARTifACTS/wwwroot
else
  KUDU_SERVICE=true
fi

if [[ ! -n "$KUDU_SYNC_CMD" ]]; then
  # Install kudu sync
  echo Installing Kudu Sync
  npm install kudusync -g --silent
  exitWithMessageOnError "npm failed"

  if [[ ! -n "$KUDU_SERVICE" ]]; then
    # In case we are running locally this is the correct location of kuduSync
    KUDU_SYNC_CMD=kuduSync
  else
    # In case we are running on kudu service this is the correct location of kuduSync
    KUDU_SYNC_CMD=$APPDATA/npm/node_modules/kuduSync/bin/kuduSync
  fi
fi

# Node Helpers
# ------------

selectNodeVersion () {
  if [[ -n "$KUDU_SELECT_NODE_VERSION_CMD" ]]; then
    SELECT_NODE_VERSION="$KUDU_SELECT_NODE_VERSION_CMD \"$DEPLOYMENT_SOURCE\" \"$DEPLOYMENT_TARGET\" \"$DEPLOYMENT_TEMP\""
    eval $SELECT_NODE_VERSION
    exitWithMessageOnError "select node version failed"

    if [[ -e "$DEPLOYMENT_TEMP/__nodeVersion.tmp" ]]; then
      NODE_EXE=`cat "$DEPLOYMENT_TEMP/__nodeVersion.tmp"`
      exitWithMessageOnError "getting node version failed"
    fi
    
    if [[ -e "$DEPLOYMENT_TEMP/__npmVersion.tmp" ]]; then
      NPM_JS_PATH=`cat "$DEPLOYMENT_TEMP/__npmVersion.tmp"`
      exitWithMessageOnError "getting npm version failed"
    fi

    if [[ ! -n "$NODE_EXE" ]]; then
      NODE_EXE=node
    fi

    NPM_CMD="\"$NODE_EXE\" \"$NPM_JS_PATH\""
  else
    NPM_CMD=npm
    NODE_EXE=node
  fi
}

##################################################################################################################################
# Deployment
# ----------
:Deployment
echo Handling node.js deployment.
 
:: 1. Select node version
call :SelectNodeVersion
 
:: 2. Install npm packages
if EXIST "%DEPLOYMENT_SOURCE%\package.json" (
  pushd "%DEPLOYMENT_SOURCE%"
  call :ExecuteCmd !NPM_CMD! install
  if !ERRORLEVEL! NEQ 0 goto error
  popd
)
 
:: 3. Angular Prod Build
if EXIST "%DEPLOYMENT_SOURCE%/.angular-cli.json" (
echo Building App in %DEPLOYMENT_SOURCE%…
pushd "%DEPLOYMENT_SOURCE%"
call :ExecuteCmd !NPM_CMD! run build
if !ERRORLEVEL! NEQ 0 goto error
popd
)
 
:: 4. Copy Web.config
if EXIST "%DEPLOYMENT_SOURCE%\web.config" (
  pushd "%DEPLOYMENT_SOURCE%"
 :: the next line is optional to fix 404 error see section #8
  call :ExecuteCmd cp web.config dist\
  if !ERRORLEVEL! NEQ 0 goto error
  popd
)
 
:: 5. KuduSync
if /I "%IN_PLACE_DEPLOYMENT%" NEQ "1" (
  call :ExecuteCmd "%KUDU_SYNC_CMD%" -v 50 -f "%DEPLOYMENT_SOURCE%/dist" -t "%DEPLOYMENT_TARGET%" -n "%NEXT_MANifEST_PATH%" -p "%PREVIOUS_MANifEST_PATH%" -i ".git;.hg;.deployment;deploy.cmd"
  if !ERRORLEVEL! NEQ 0 goto error
)
# echo Handling node.js deployment.

# # 1. KuduSync
# if [[ "$IN_PLACE_DEPLOYMENT" -ne "1" ]]; then
#   "$KUDU_SYNC_CMD" -v 50 -f "$DEPLOYMENT_SOURCE" -t "$DEPLOYMENT_TARGET" -n "$NEXT_MANifEST_PATH" -p "$PREVIOUS_MANifEST_PATH" -i ".git;.hg;.deployment;deploy.sh"
#   exitWithMessageOnError "Kudu Sync failed"
# fi

# # 2. Select node version
# selectNodeVersion

# # 3. Install npm packages
# if [ -e "$DEPLOYMENT_TARGET/package.json" ]; then
#   cd "$DEPLOYMENT_TARGET"
#   echo "Running $NPM_CMD install --production"
#   eval $NPM_CMD install --production
#   exitWithMessageOnError "npm failed"
#   cd - > /dev/null
# fi

##################################################################################################################################
echo "Finished successfully."