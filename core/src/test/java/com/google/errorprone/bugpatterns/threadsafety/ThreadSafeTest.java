/*
 * Copyright 2014 Google Inc. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.google.errorprone.bugpatterns.threadsafety;

import com.google.errorprone.CompilationTestHelper;

import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.ObjectOutputStream;

/** {@link ThreadSafe}Test */
@RunWith(JUnit4.class)
public class ThreadSafeTest {
  private CompilationTestHelper compilationHelper;

  @Before
  public void setUp() {
    compilationHelper = CompilationTestHelper.newInstance(ThreadSafe.class);
  }

  @Test
  public void testLocked() throws Exception {
    compilationHelper.assertCompileFailsWithMessages(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "import java.util.concurrent.locks.Lock;",
            "class Test {",
            "  final Lock lock = null;",
            "  @GuardedBy(\"lock\")",
            "  int x;",
            "  void m() {",
            "    lock.lock();",
            "    // BUG: Diagnostic contains:",
            "    // Expected this.lock",
            "    x++;",
            "    try {",
            "      x++;",
            "    } catch (Exception e) {",
            "      x--;",
            "    } finally {",
            "      lock.unlock();",
            "    }",
            "    // BUG: Diagnostic contains:",
            "    // Expected this.lock",
            "    x++;",
            "  }",
            "}"
        )
    );
  }

  /**
   * "static synchronized method() { ... }" == "synchronized (MyClass.class) { ... }"
   */
  @Test
  public void testStaticLocked() throws Exception {
    compilationHelper.assertCompileSucceeds(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "import java.util.concurrent.locks.Lock;",
            "class Test {",
            "  @GuardedBy(\"Test.class\")",
            "  static int x;",
            "  static synchronized void m() {",
            "    x++;",
            "  }",
            "}"
        )
    );
  }


  @Test
  public void testMonitor() throws Exception {
    compilationHelper.assertCompileFailsWithMessages(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "import com.google.common.util.concurrent.Monitor;",
            "class Test {",
            "  final Monitor monitor = null;",
            "  @GuardedBy(\"monitor\")",
            "  int x;",
            "  void m() {",
            "    monitor.enter();",
            "    // BUG: Diagnostic contains:",
            "    // Expected this.monitor",
            "    x++;",
            "    try {",
            "      x++;",
            "    } finally {",
            "      monitor.leave();",
            "    }",
            "    // BUG: Diagnostic contains:",
            "    // Expected this.monitor",
            "    x++;",
            "  }",
            "}"
        )
    );
  }

  @Test
  public void testWrongLock() throws Exception {
    compilationHelper.assertCompileFailsWithMessages(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "import java.util.concurrent.locks.Lock;",
            "class Test {",
            "  final Lock lock1 = null;",
            "  final Lock lock2 = null;",
            "  @GuardedBy(\"lock1\")",
            "  int x;",
            "  void m() {",
            "    lock2.lock();",
            "    try {",
            "    // BUG: Diagnostic contains:",
            "    // Expected this.lock1",
            "      x++;",
            "    } finally {",
            "      lock2.unlock();",
            "    }",
            "  }",
            "}"
        )
    );
  }

  @Test
  public void testGuardedStaticFieldAccess_1() throws Exception {
    compilationHelper.assertCompileSucceeds(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class Test {",
            "  public static final Object lock = new Object();",
            "  @GuardedBy(\"lock\")",
            "  public static int x;",
            "  void m() {",
            "    synchronized (Test.lock) {",
            "      Test.x++;",
            "    }",
            "  }",
            "}"
        )
    );
  }

  @Test
  public void testGuardedStaticFieldAccess_2() throws Exception {
    compilationHelper.assertCompileSucceeds(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class Test {",
            "  public static final Object lock = new Object();",
            "  @GuardedBy(\"lock\")",
            "  public static int x;",
            "  void m() {",
            "    synchronized (lock) {",
            "      Test.x++;",
            "    }",
            "  }",
            "}"
        )
    );
  }

  @Test
  public void testGuardedStaticFieldAccess_3() throws Exception {
    compilationHelper.assertCompileSucceeds(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class Test {",
            "  public static final Object lock = new Object();",
            "  @GuardedBy(\"lock\")",
            "  public static int x;",
            "  void m() {",
            "    synchronized (Test.lock) {",
            "      x++;",
            "    }",
            "  }",
            "}"
        )
    );
  }

  @Test
  public void testGuardedStaticFieldAccess_EnclosingClass() throws Exception {
    compilationHelper.assertCompileSucceeds(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class Test {",
            "  @GuardedBy(\"Test.class\")",
            "  public static int x;",
            "  synchronized static void n() {",
            "    Test.x++;",
            "  }",
            "}"
        )
    );
  }

  @Test
  public void testBadStaticFieldAccess() throws Exception {
    compilationHelper.assertCompileFailsWithMessages(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class Test {",
            "  public static final Object lock = new Object();",
            "  @GuardedBy(\"lock\")",
            "  public static int x;",
            "  void m() {",
            "    // BUG: Diagnostic contains:",
            "    // Expected Test.lock",
            "    Test.x++;",
            "  }",
            "}"
        )
    );
  }

  @Test
  public void testBadGuard() throws Exception {
    compilationHelper.assertCompileFailsWithMessages(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class Test {",
            "  // BUG: Diagnostic contains: Invalid @GuardedBy expression",
            "  @GuardedBy(\"foo\") int y;",
            "}"
        )
    );
  }

  @Test
  public void testUnheldInstanceGuard() throws Exception {
    compilationHelper.assertCompileFailsWithMessages(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class Test {",
            "  final Object mu = new Object();",
            "  @GuardedBy(\"mu\") int y;",
            "}",
            "class Main {",
            "  void m(Test t) {",
            "    // BUG: Diagnostic contains: Expected t.mu",
            "    t.y++;",
            "  }",
            "}"
        )
    );
  }

  @Test
  public void testCtor() throws Exception {
    compilationHelper.assertCompileSucceeds(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class Test {",
            "  @GuardedBy(\"this\") int x;",
            "  public Test() {",
            "    this.x = 42;",
            "  }",
            "}"
        )
    );
  }

  @Test
  public void testBadGuardMethodAccess() throws Exception {
    compilationHelper.assertCompileFailsWithMessages(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class Test {",
            "  @GuardedBy(\"this\") void x() {}",
            "  void m() {",
            "    // BUG: Diagnostic contains: this",
            "    x();",
            "  }",
            "}"
        )
    );
  }

  @Test
  public void testTransitiveGuardMethodAccess() throws Exception {
    compilationHelper.assertCompileSucceeds(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class Test {",
            "  @GuardedBy(\"this\") void x() {}",
            "  @GuardedBy(\"this\") void m() {",
            "    x();",
            "  }",
            "}"
        )
    );
  }

  @Test
  public void testReadWriteLock() throws Exception {
    compilationHelper.assertCompileSucceeds(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "import java.util.concurrent.locks.ReentrantReadWriteLock;",
            "class Test {",
            "  final ReentrantReadWriteLock lock = new ReentrantReadWriteLock();",
            "  @GuardedBy(\"lock\") boolean b = false;",
            "  void m() {",
            "    lock.readLock().lock();",
            "    try {",
            "      b = true;",
            "    } finally {",
            "      lock.readLock().unlock();",
            "    }",
            "  }",
            "  void n() {",
            "    lock.writeLock().lock();",
            "    try {",
            "      b = true;",
            "    } finally {",
            "      lock.writeLock().unlock();",
            "    }",
            "  }",
            "}"
        )
    );
  }

  @Test
  public void testInnerClass_enclosingClassLock() throws Exception {
    compilationHelper.assertCompileSucceeds(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "public class Test {",
            "  final Object mu = new Object();",
            "  @GuardedBy(\"mu\") boolean b = false;",
            "  private final class Baz {",
            "    public void m() {",
            "      synchronized (mu) {",
            "        n();",
            "      }",
            "    }",
            "    @GuardedBy(\"Test.this.mu\")",
            "    private void n() {",
            "      b = true;",
            "    }",
            "  }",
            "}"
        )
    );
  }

  // notice lexically enclosing owner, use NamedThis!
  @Test
  public void testInnerClass_thisLock() throws Exception {
    compilationHelper.assertCompileFailsWithMessages(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "public class Test {",
            "  @GuardedBy(\"this\") boolean b = false;",
            "  private final class Baz {",
            "    private synchronized void n() {",
            "      // BUG: Diagnostic contains: Expected Test.this",
            "      b = true;",
            "    }",
            "  }",
            "}"
        )
    );
  }

  @Test
  public void testAnonymousClass() throws Exception {
    compilationHelper.assertCompileFailsWithMessages(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "public class Test {",
            "  @GuardedBy(\"this\") boolean b = false;",
            "  private synchronized void n() {",
            "    b = true;",
            "    new Object() {",
            "      void m() {",
            "        // BUG: Diagnostic contains: Expected Test.this",
            "        b = true;",
            "      }",
            "    };",
            "  }",
            "}"
        )
    );
  }

  @Test
  public void testInheritedLock() throws Exception {
    compilationHelper.assertCompileSucceeds(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class A {",
            "  final Object lock = new Object();",
            "}",
            "class B extends A {",
            "  @GuardedBy(\"lock\") boolean b = false;",
            "  void m() {",
            "    synchronized (lock) {",
            "      b = true;",
            "    };",
            "  }",
            "}"
        )
    );
  }

  @Test
  public void testEnclosingSuperAccess() throws Exception {
    compilationHelper.assertCompileSucceeds(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class A {",
            "  final Object lock = new Object();",
            "  @GuardedBy(\"lock\") boolean flag = false;",
            "}",
            "class B extends A {",
            "  void m() {",
            "    new Object() {",
            "      @GuardedBy(\"lock\")",
            "      void n() {",
            "        flag = true;",
            "      }",
            "    };",
            "  }",
            "}"
        )
    );
  }

  @Test
  public void testSuperAccess_this() throws Exception {
    compilationHelper.assertCompileSucceeds(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class A {",
            "  final Object lock = new Object();",
            "  @GuardedBy(\"this\") boolean flag = false;",
            "}",
            "class B extends A {",
            "  synchronized void m() {",
            "    flag = true;",
            "  }",
            "}"
        )
    );
  }

  @Test
  public void testSuperAccess_lock() throws Exception {
    compilationHelper.assertCompileSucceeds(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class A {",
            "  final Object lock = new Object();",
            "  @GuardedBy(\"lock\") boolean flag = false;",
            "}",
            "class B extends A {",
            "  void m() {",
            "    synchronized (lock) {",
            "      flag = true;",
            "    }",
            "    synchronized (this.lock) {",
            "      flag = true;",
            "    }",
            "  }",
            "}"
        )
    );
  }

  @Test
  public void testSuperAccess_staticLock() throws Exception {
    compilationHelper.assertCompileSucceeds(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class A {",
            "  static final Object lock = new Object();",
            "  @GuardedBy(\"lock\") static boolean flag = false;",
            "}",
            "class B extends A {",
            "  void m() {",
            "    synchronized (A.lock) {",
            "      flag = true;",
            "    }",
            "    synchronized (B.lock) {",
            "      flag = true;",
            "    }",
            "  }",
            "}"
        )
    );
  }

  @Test
  public void testOtherClass_bad_staticLock() throws Exception {
    compilationHelper.assertCompileFailsWithMessages(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class A {",
            "  static final Object lock = new Object();",
            "  @GuardedBy(\"lock\") static boolean flag = false;",
            "}",
            "class B {",
            "  static final Object lock = new Object();",
            "  @GuardedBy(\"lock\") static boolean flag = false;",
            "  void m() {",
            "    synchronized (B.lock) {",
            "      // BUG: Diagnostic contains: Expected A.lock",
            "      A.flag = true;",
            "    }",
            "    synchronized (A.lock) {",
            "      // BUG: Diagnostic contains: Expected B.lock",
            "      B.flag = true;",
            "    }",
            "  }",
            "}"
        )
    );
  }

  @Test
  public void testOtherClass_bad_staticLock_alsoSub() throws Exception {
    compilationHelper.assertCompileFailsWithMessages(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class A {",
            "  static final Object lock = new Object();",
            "  @GuardedBy(\"lock\") static boolean flag = false;",
            "}",
            "class B extends A {",
            "  static final Object lock = new Object();",
            "  @GuardedBy(\"lock\") static boolean flag = false;",
            "  void m() {",
            "    synchronized (B.lock) {",
            "      // BUG: Diagnostic contains: Expected A.lock",
            "      A.flag = true;",
            "    }",
            "    synchronized (A.lock) {",
            "      // BUG: Diagnostic contains: Expected B.lock",
            "      B.flag = true;",
            "    }",
            "  }",
            "}"
        )
    );
  }

  @Test
  public void testOtherClass_staticLock() throws Exception {
    compilationHelper.assertCompileSucceeds(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class A {",
            "  static final Object lock = new Object();",
            "  @GuardedBy(\"lock\") static boolean flag = false;",
            "}",
            "class B {",
            "  void m() {",
            "    synchronized (A.lock) {",
            "      A.flag = true;",
            "    }",
            "  }",
            "}"
        )
    );
  }

  @Test
  public void instanceAccess_instanceGuard() throws Exception {
    compilationHelper.assertCompileFailsWithMessages(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class InstanceAccess_InstanceGuard {",
            "    class A {",
            "        final Object lock = new Object();",
            "        @GuardedBy(\"lock\")",
            "        int x;",
            "    }",
            "",
            "    class B extends A {",
            "        void m() {",
            "            synchronized (this.lock) {",
            "                this.x++;",
            "            }",
            "            // BUG: Diagnostic contains: Expected this.lock",
            "            this.x++;",
            "        }",
            "    }",
            "}"
        )
    );
  }

  @Test
  public void instanceAccess_lexicalGuard() throws Exception {
    compilationHelper.assertCompileFailsWithMessages(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class InstanceAccess_LexicalGuard {",
            "    class Outer {",
            "        final Object lock = new Object();",
            "        class Inner {",
            "            @GuardedBy(\"lock\")",
            "            int x;",
            "            void m() {",
            "                synchronized (Outer.this.lock) {",
            "                    this.x++;",
            "                }",
            "                // BUG: Diagnostic contains: Expected Outer.this.lock",
            "                this.x++;",
            "            }",
            "        }",
            "    }",
            "}"
        )
    );
  }

  @Test
  public void lexicalAccess_instanceGuard() throws Exception {
    compilationHelper.assertCompileFailsWithMessages(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class LexicalAccess_InstanceGuard {",
            "    class Outer {",
            "        final Object lock = new Object();",
            "        @GuardedBy(\"lock\")",
            "        int x;",
            "        class Inner {",
            "            void m() {",
            "                synchronized (Outer.this.lock) {",
            "                    Outer.this.x++;",
            "                }",
            "                // BUG: Diagnostic contains: Expected Outer.this.lock",
            "                Outer.this.x++;",
            "            }",
            "        }",
            "    }",
            "}"
        )
    );
  }

  @Test
  public void lexicalAccess_lexicalGuard() throws Exception {
    compilationHelper.assertCompileFailsWithMessages(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class LexicalAccess_LexicalGuard {",
            "    class Outer {",
            "        final Object lock = new Object();",
            "        class Inner {",
            "            @GuardedBy(\"lock\")",
            "            int x;",
            "            class InnerMost {",
            "                void m() {",
            "                    synchronized (Outer.this.lock) {",
            "                        Inner.this.x++;",
            "                    }",
            "                    // BUG: Diagnostic contains: Expected Outer.this.lock",
            "                    Inner.this.x++;",
            "                }",
            "            }",
            "        }",
            "    }",
            "}"
        )
    );
  }

  @Test
  public void instanceAccess_thisGuard() throws Exception {
    compilationHelper.assertCompileFailsWithMessages(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class InstanceAccess_ThisGuard {",
            "    class A {",
            "        @GuardedBy(\"this\")",
            "        int x;",
            "    }",
            "",
            "    class B extends A {",
            "        void m() {",
            "            synchronized (this) {",
            "                this.x++;",
            "            }",
            "            // BUG: Diagnostic contains: Expected this",
            "            this.x++;",
            "        }",
            "    }",
            "}"
        )
    );
  }

  @Test
  public void instanceAccess_namedThisGuard() throws Exception {
    compilationHelper.assertCompileFailsWithMessages(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class InstanceAccess_NamedThisGuard {",
            "    class Outer {",
            "        class Inner {",
            "            @GuardedBy(\"Outer.this\")",
            "            int x;",
            "            void m() {",
            "                synchronized (Outer.this) {",
            "                    x++;",
            "                }",
            "                // BUG: Diagnostic contains: Expected Outer.this",
            "                x++;",
            "            }",
            "        }",
            "    }",
            "}"
        )
    );
  }

  @Test
  public void lexicalAccess_thisGuard() throws Exception {
    compilationHelper.assertCompileFailsWithMessages(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class LexicalAccess_ThisGuard {",
            "    class Outer {",
            "        @GuardedBy(\"this\")",
            "        int x;",
            "        class Inner {",
            "            void m() {",
            "                synchronized (Outer.this) {",
            "                    Outer.this.x++;",
            "                }",
            "                // BUG: Diagnostic contains: Expected Outer.this",
            "                Outer.this.x++;",
            "            }",
            "        }",
            "    }",
            "}"
        )
    );
  }

  @Test
  public void lexicalAccess_namedThisGuard() throws Exception {
    compilationHelper.assertCompileFailsWithMessages(
        CompilationTestHelper.forSourceLines(
            "threadsafety.Test",
            "package threadsafety.Test;",
            "import javax.annotation.concurrent.GuardedBy;",
            "class LexicalAccess_NamedThisGuard {",
            "    class Outer {",
            "        class Inner {",
            "            @GuardedBy(\"Outer.this\")",
            "            int x;",
            "            class InnerMost {",
            "                void m() {",
            "                    synchronized (Outer.this) {",
            "                        Inner.this.x++;",
            "                    }",
            "                    // BUG: Diagnostic contains: Expected Outer.this",
            "                    Inner.this.x++;",
            "                }",
            "            }",
            "        }",
            "    }",
            "}"
        )
    );
  }

  @Test
  public void serializable() throws IOException {
    new ObjectOutputStream(new ByteArrayOutputStream()).writeObject(new ThreadSafe());
  }
}