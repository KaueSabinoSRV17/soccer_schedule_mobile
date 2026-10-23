# Source this file from bash or zsh: source scripts/env.sh
if [ -n "${ZSH_VERSION:-}" ]; then
  SOCCER_PROJECT_ROOT="$(cd "$(dirname "${(%):-%x}")/.." && pwd)"
elif [ -n "${BASH_VERSION:-}" ]; then
  SOCCER_PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
else
  echo 'Use bash or zsh to source scripts/env.sh' >&2
  return 1
fi
export SOCCER_PROJECT_ROOT
export FLUTTER_ROOT="$SOCCER_PROJECT_ROOT/.tooling/flutter"
export ANDROID_HOME="$SOCCER_PROJECT_ROOT/.tooling/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export JAVA_HOME="$SOCCER_PROJECT_ROOT/.tooling/jdk"
export GRADLE_USER_HOME="$SOCCER_PROJECT_ROOT/.tooling/gradle"
export PUB_CACHE="$SOCCER_PROJECT_ROOT/.tooling/pub-cache"
# Override a previous Windows/remote ADB bridge for this Linux-first workflow.
unset ADB_SERVER_SOCKET ANDROID_ADB_SERVER_ADDRESS ANDROID_ADB_SERVER_PORT
export PATH="$FLUTTER_ROOT/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$JAVA_HOME/bin:$PATH"
if [ -z "${CHROME_EXECUTABLE:-}" ] && [ -x /opt/google/chrome/chrome ]; then
  export CHROME_EXECUTABLE=/opt/google/chrome/chrome
fi


if [ -x "$SOCCER_PROJECT_ROOT/.tooling/node/bin/node" ]; then
  export PATH="$SOCCER_PROJECT_ROOT/.tooling/node/bin:$PATH"
fi
