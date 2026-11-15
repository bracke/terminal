#include <GLFW/glfw3.h>

/* Publish newly created native handles through caller-owned storage before
   returning across the Ada cancellation boundary. */
void terminal_glfw_create_window
  (GLFWwindow **target,
   int width,
   int height,
   const char *title,
   void *monitor,
   void *share)
{
   *target = glfwCreateWindow
     (width,
      height,
      title,
      (GLFWmonitor *) monitor,
      (GLFWwindow *) share);
}

void terminal_glfw_create_standard_cursor(GLFWcursor **target, int shape)
{
   *target = glfwCreateStandardCursor(shape);
}

/* GLFW's setter returns no status. The marker records that the native window
   was changed before control can return to cancellable Ada code. */
void terminal_glfw_set_cursor
  (GLFWwindow *window, GLFWcursor *cursor, int *installed)
{
   *installed = 0;
   glfwSetCursor(window, cursor);
   *installed = 1;
}

/* Callback replacement is an ownership transaction. Publish both the
   predecessor and the completion marker before returning across Ada's task
   cancellation boundary. */
void terminal_glfw_set_key_callback_owned
  (GLFWwindow *window, GLFWkeyfun callback,
   GLFWkeyfun *previous, int *installed)
{
   *installed = 0;
   *previous = glfwSetKeyCallback(window, callback);
   *installed = 1;
}

void terminal_glfw_set_char_callback_owned
  (GLFWwindow *window, GLFWcharfun callback,
   GLFWcharfun *previous, int *installed)
{
   *installed = 0;
   *previous = glfwSetCharCallback(window, callback);
   *installed = 1;
}

void terminal_glfw_set_mouse_button_callback_owned
  (GLFWwindow *window, GLFWmousebuttonfun callback,
   GLFWmousebuttonfun *previous, int *installed)
{
   *installed = 0;
   *previous = glfwSetMouseButtonCallback(window, callback);
   *installed = 1;
}

void terminal_glfw_set_cursor_pos_callback_owned
  (GLFWwindow *window, GLFWcursorposfun callback,
   GLFWcursorposfun *previous, int *installed)
{
   *installed = 0;
   *previous = glfwSetCursorPosCallback(window, callback);
   *installed = 1;
}

void terminal_glfw_set_scroll_callback_owned
  (GLFWwindow *window, GLFWscrollfun callback,
   GLFWscrollfun *previous, int *installed)
{
   *installed = 0;
   *previous = glfwSetScrollCallback(window, callback);
   *installed = 1;
}

void terminal_glfw_set_window_focus_callback_owned
  (GLFWwindow *window, GLFWwindowfocusfun callback,
   GLFWwindowfocusfun *previous, int *installed)
{
   *installed = 0;
   *previous = glfwSetWindowFocusCallback(window, callback);
   *installed = 1;
}

/* Record completion before returning across the Ada cancellation boundary. */
void terminal_glfw_terminate(int *completed)
{
   *completed = 0;
   glfwTerminate();
   *completed = 1;
}
