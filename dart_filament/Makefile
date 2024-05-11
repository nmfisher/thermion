web-bindings:
	dart --enable-experiment=native-assets run ffigen --config ffigen/swift.yaml
swift-bindings:
	dart --enable-experiment=native-assets run ffigen --config ffigen/swift.yaml
shared-bindings:
	dart --enable-experiment=native-assets run ffigen --config ffigen/shared.yaml
bindings: shared-bindings swift-bindings web-bindings
	