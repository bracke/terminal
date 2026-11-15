# c_string_ownership

Neutral cancellation-safe ownership for temporary C strings shared by the
terminal and reusable GLFW/Vulkan libraries.

`C_String_Ownership` is the only consumer API. Its C allocation primitives,
header, and Ada implementation are private to the library.

Build and run its standalone contract smoke through the root crate's pinned
Alire toolchain:

```sh
alr exec -- gprbuild -p -P c_string_ownership/tests/c_string_ownership_tests.gpr
alr exec -- gprbuild -p -P c_string_ownership/tests/c_string_ownership_failure_tests.gpr
c_string_ownership/tests/bin/c_string_ownership_smoke
c_string_ownership/tests/bin/c_string_ownership_failure_smoke
```
