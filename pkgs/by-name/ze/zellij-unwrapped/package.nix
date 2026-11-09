{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
  pkg-config,
  curl,
  libssh2,
  openssl,
  sqlite,
  writableTmpDirAsHomeHook,
  versionCheckHook,
  nix-update-script,
  withWebServer ? true,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "zellij-unwrapped";
  # Unreleased main: 0.45.1 never shows the folder picker (Ctrl f) on the welcome screen, because a
  # floating pane finds no room in a tab without terminal panes (zellij-org/zellij#5650).
  version = "0.46.0-unstable-2026-11-09";
  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "zellij-org";
    repo = "zellij";
    rev = "19dafe34b728bb1c2c3a77911e072132efc874b6";
    hash = "sha256-n1/2Vi4ABfng0oCs7F2Mp0EseZA/bPVOZPvBdviNfzM=";
  };

  # Remove the `vendored_curl` feature in order to link against the libcurl from nixpkgs instead of
  # the vendored one. Also remove `terminal`, main's new Zellij terminal window, which isn't needed
  postPatch = ''
    substituteInPlace Cargo.toml \
      --replace-fail ', "vendored_curl"' ""
    substituteInPlace Cargo.toml --replace-fail ', "terminal"]' ']'
  ''
  + lib.optionalString (!withWebServer) ''
    substituteInPlace Cargo.toml \
      --replace-fail ', "web_server_capability"' ""
  '';

  cargoHash = "sha256-i3Vh7w9YeGUkGIsbqA2UIiLtMqsSC+/ehdSDIfTckM8=";

  env.LIBSSH2_SYS_USE_PKG_CONFIG = 1;
  env.OPENSSL_NO_VENDOR = 1;

  nativeBuildInputs = [
    installShellFiles
    pkg-config
    (lib.getDev curl)
  ];

  buildInputs = [
    curl
    libssh2
    openssl
    sqlite
  ];

  nativeCheckInputs = [
    writableTmpDirAsHomeHook
  ];

  # main's test suite isn't vetted for this snapshot
  doCheck = false;

  nativeInstallCheckInputs = [
    versionCheckHook
  ];
  # The binary reports 0.46.0, so versionCheckHook would reject the unstable version string
  doInstallCheck = false;

  # Ensure that we don't vendor curl, but instead link against the libcurl from nixpkgs
  installCheckPhase = lib.optionalString (stdenv.hostPlatform.libc == "glibc") ''
    runHook preInstallCheck

    ldd "$out/bin/zellij" | grep libcurl.so

    runHook postInstallCheck
  '';

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd zellij \
      --bash <($out/bin/zellij setup --generate-completion bash) \
      --fish <($out/bin/zellij setup --generate-completion fish) \
      --zsh <($out/bin/zellij setup --generate-completion zsh)
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Terminal workspace with batteries included";
    homepage = "https://zellij.dev/";
    changelog = "https://github.com/zellij-org/zellij/blob/${finalAttrs.src.rev}/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [
      therealansh
      _0x4A6F
      abbe
      matthiasbeyer
      ryan4yin
    ];
    mainProgram = "zellij";
  };
})
