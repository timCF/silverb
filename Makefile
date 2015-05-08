clean:
	rm -rf /Users/tim/MYprojects/silverb/_build/dev/lib/silverb/priv}/silverb
	mix clean
	mix deps.clean --all
	rm -rf ./_build
release:
	mix clean
	mix deps.get
	mix deps.compile exrm
	mix deps.compile silverb
	mix silverb.on
	mix deps.compile
	mix compile
	mix silverb.check
	mix silverb.off
	mix release.clean --implode
	mix release
