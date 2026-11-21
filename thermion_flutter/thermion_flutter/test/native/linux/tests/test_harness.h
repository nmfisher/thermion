// Minimal test runner for the Linux plugin harness. No external dependencies
// so it builds anywhere GLib does.
#pragma once

#include <cstdio>
#include <sstream>
#include <string>
#include <vector>

namespace harness {

struct TestCase {
  const char* name;
  void (*fn)();
};

inline std::vector<TestCase>& Registry() {
  static std::vector<TestCase> tests;
  return tests;
}

struct AutoRegister {
  AutoRegister(const char* name, void (*fn)()) { Registry().push_back({name, fn}); }
};

inline int& Failures() {
  static int failures = 0;
  return failures;
}

inline void Fail(const std::string& message, const char* file, int line) {
  Failures()++;
  std::fprintf(stderr, "  FAILED %s:%d: %s\n", file, line, message.c_str());
}

template <typename A, typename B>
void CheckEq(const A& a, const B& b, const char* as, const char* bs, const char* file,
             int line) {
  if (!(a == b)) {
    std::ostringstream out;
    out << as << " == " << bs << " (got " << a << " vs " << b << ")";
    Fail(out.str(), file, line);
  }
}

}  // namespace harness

#define THERMION_TEST(name)                                           \
  static void name();                                                 \
  static harness::AutoRegister name##_registration(#name, &name);     \
  static void name()

#define EXPECT_TRUE(cond) \
  ((cond) ? (void)0 : harness::Fail("expected " #cond, __FILE__, __LINE__))
#define EXPECT_FALSE(cond) \
  (!(cond) ? (void)0 : harness::Fail("expected !(" #cond ")", __FILE__, __LINE__))
#define EXPECT_EQ(a, b) harness::CheckEq((a), (b), #a, #b, __FILE__, __LINE__)
