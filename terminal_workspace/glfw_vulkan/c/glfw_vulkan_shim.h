#pragma once

#define GLFW_INCLUDE_VULKAN
#include <GLFW/glfw3.h>
#include <vulkan/vulkan.h>

VkResult glfw_vulkan_create_window_surface
  (VkInstance instance,
   GLFWwindow *window,
   VkSurfaceKHR *surface);
