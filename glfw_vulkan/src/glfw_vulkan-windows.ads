with GLFW_Vulkan;
with GLFW_Vulkan.Raw;

package GLFW_Vulkan.Windows is
   type Window is limited private;

   type Create_Status is
     (Ok,
      Not_Initialized,
      Invalid_Size,
      Create_Failed);

   procedure Create
     (Ctx    : in out GLFW_Vulkan.Context;
      W      : out Window;
      Width  : Positive;
      Height : Positive;
      Title  : String;
      Status : out Create_Status);

   procedure Destroy (W : in out Window);
   function Is_Valid (W : Window) return Boolean;
   function Should_Close (W : Window) return Boolean;

   procedure Set_Should_Close
     (W     : in out Window;
      Close : Boolean);

   procedure Set_Title
     (W     : Window;
      Title : String);

   procedure Framebuffer_Size
     (W      : Window;
      Width  : out Natural;
      Height : out Natural);

private
   type Window is limited record
      Handle : Raw.GLFW_Window_Handle := Raw.Null_Window;
   end record;
end GLFW_Vulkan.Windows;
