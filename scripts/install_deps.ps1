# Utilities

function ExecuteInPath {
	param(
		[Parameter(Mandatory=$true)]
		[string] $Path,

		[Parameter(Mandatory=$true)]
		[scriptblock] $ScriptBlock
	)

	Push-Location

	try {
		Set-Location -Path $Path -ErrorAction Stop

		& $ScriptBlock
	}
	finally {
		Pop-Location
	}
}

function GetEnv {
  param(
    [Parameter(Mandatory=$true)]
    [string] $Name
  )
  return [Environment]::GetEnvironmentVariable($Name, [EnvironmentVariableTarget]::Machine)
}

function SetEnv {
  param(
    [Parameter(Mandatory=$true)]
    [string] $Name,

    [Parameter(Mandatory=$true)]
    [string] $Value
  )
  [Environment]::SetEnvironmentVariable(
    $Name,
    $Value,
    [EnvironmentVariableTarget]::Machine
  )
  Set-Item "env:$Name" $Value
}

function AddToPath {
  param(
    [Parameter(Mandatory=$true)]
    [string] $Path
  )
  $CurrentPath = GetEnv "Path"
  If ($CurrentPath.Contains($Path) -eq "True") {
    return
  }

  SetEnv "Path" ($CurrentPath + ";" + $Path)
}

# Prepare dependencies folder

$DEPS_PATH = "dependencies"
If(!(Test-Path -PathType container $DEPS_PATH))
{
      New-Item -ItemType Directory -Path $DEPS_PATH
}
$DEPS_PATH = (Resolve-Path "dependencies").Path

# Install dependencies

Write-Host "Installing dependency: tree-sitter-cli" -ForegroundColor Green
npm install -g tree-sitter-cli

Write-Host "Installing dependency: mingw64" -ForegroundColor Green
$MINGW64_PATH = "$DEPS_PATH/mingw64"
If (!(Test-Path -PathType container $MINGW64_PATH)) {
  wget https://github.com/brechtsanders/winlibs_mingw/releases/download/15.2.0posix-13.0.0-ucrt-r6/winlibs-x86_64-posix-seh-gcc-15.2.0-mingw-w64ucrt-13.0.0-r6.zip -O $DEPS_PATH/winlibs-x86_64-posix-seh-gcc-15.2.0-mingw-w64ucrt-13.0.0-r6.zip
  $MINGW64_ZIP = "$DEPS_PATH/winlibs-x86_64-posix-seh-gcc-15.2.0-mingw-w64ucrt-13.0.0-r6.zip"
  Expand-Archive -Force $MINGW64_ZIP $DEPS_PATH
}
AddToPath "$MINGW64_PATH/bin"
SetEnv "CC" "gcc"

Write-Host "Installing dependency: lua" -ForegroundColor Green
$LUA_PATH = "$DEPS_PATH/lua-5.4.0"
If (!(Test-Path -PathType container $LUA_PATH)) {
  ExecuteInPath $DEPS_PATH {
    tar -xzvf ./lua-5.4.0.tar.gz
  }
}
ExecuteInPath $LUA_PATH {
  make clean
  make mingw
  $BUILD_PATH = "$LUA_PATH/build" -replace "\\", "/"
  make install INSTALL_TOP=$BUILD_PATH TO_BIN="lua.exe luac.exe lua54.dll"
}
AddToPath "$LUA_PATH/build/bin"

Write-Host "Installing dependency: luarocks" -ForegroundColor Green
$LUAROCKS_PATH = "$DEPS_PATH/luarocks-3.13.0-windows-32"
If (!(Test-Path -PathType container $LUAROCKS_PATH)) {
  $LUAROCKS_ZIP = "$DEPS_PATH/luarocks-3.13.0-windows-32.zip"
  Expand-Archive -Force $LUAROCKS_ZIP $DEPS_PATH
}
AddToPath $LUAROCKS_PATH
luarocks config lua_version 5.4
$LUAROCKS_ENV = luarocks path
$LUAROCKS_ENV -Split("\n") | ForEach-Object {
  $parts = $_.Substring(4).Trim('"').Split("=")
  if ($parts.Length -eq 2) {
    SetEnv $parts[0].Trim() $parts[1].Trim()
  }
}