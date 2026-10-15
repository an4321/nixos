{ stdenv, odin, xorg }:

stdenv.mkDerivation {
	pname = "fogwm";
	version = "0.1.0";

	src = ./.;

	nativeBuildInputs = [ odin ];
	buildInputs = [ xorg.libX11 ];

	# The vendor:x11/xlib bindings need X11 headers at compile time
	# and -lX11 at link time.
	NIX_CFLAGS_COMPILE = [ "-I${xorg.libX11}/include" ];
	NIX_LDFLAGS = [ "-L${xorg.libX11}/lib" "-lX11" ];

	buildPhase = '' odin build main.odin -out:fogwm '';

	installPhase = ''
		mkdir -p $out/bin
		cp fogwm $out/bin/fogwm
	'';

	doCheck = false;
}
