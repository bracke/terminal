with GLFW_Vulkan;
with GLFW_Vulkan.Raw;

package GLFW_Vulkan.Windows is
   type Window is limited private;

   type Create_Status is
     (Ok,
      Not_Initialized,
      Invalid_Size,
      Create_Failed);

   type Standard_Cursor is
     (Default_Cursor,
      I_Beam_Cursor,
      Hand_Cursor);

   type Cursor_Status is
     (Ok,
      Window_Invalid,
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

   procedure Set_Standard_Cursor
     (W      : in out Window;
      Cursor : Standard_Cursor;
      Status : out Cursor_Status);

   procedure Framebuffer_Size
     (W      : Window;
      Width  : out Natural;
      Height : out Natural);

private
   type Window is limited record
      Handle : Raw.GLFW_Window_Handle := Raw.Null_Window;
      Cursor : Raw.GLFW_Cursor_Handle := Raw.Null_Cursor;
   end record;
end GLFW_Vulkan.Windows;
