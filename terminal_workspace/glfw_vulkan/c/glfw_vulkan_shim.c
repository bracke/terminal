#include "glfw_vulkan_shim.h"

VkResult glfw_vulkan_create_window_surface
  (VkInstance instance,
   GLFWwindow *window,
   VkSurfaceKHR *surface)
{
    return glfwCreateWindowSurface(instance, window, NULL, surface);
}

