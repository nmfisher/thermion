extension Foo on void Function() {
  void call() {
    print("AY");
  }
}

class Foobar {
  void call() {
    print("FOOBAR");
  }
}

void main(List<String> args) {
  // void Function() foo = () {
  //   print("NO");
  // };
  // foo();
  final foo = Foobar();
  foo();
}