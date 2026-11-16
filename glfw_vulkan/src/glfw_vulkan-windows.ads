with Ada.Finalization;
with System;
with GLFW_Vulkan;
with GLFW_Vulkan.Raw;

package GLFW_Vulkan.Windows is
   type Window is new Ada.Finalization.Limited_Controlled with private;

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

   type Property_Status is (Ok, Window_Invalid, Invalid_Value);

   procedure Create
     (Ctx    : in out GLFW_Vulkan.Context;
      W      : in out Window;
      Width  : Natural;
      Height : Natural;
      Title  : String;
      Status : out Create_Status);

   procedure Destroy (W : in out Window);
   overriding procedure Finalize (W : in out Window);
   function Is_Valid (W : Window) return Boolean;
   function Should_Close (W : Window) return Boolean;
   --  Native window identity for platform integration seams such as UIA and
   --  NSAccessibility. The returned handle is borrowed and remains owned by W.
   function Native_Handle (W : Window) return System.Address;

   procedure Set_Should_Close
     (W     : in out Window;
      Close : Boolean);

   procedure Set_Title
     (W     : Window;
      Title : String);

   procedure Set_Opacity
     (W       : Window;
      Opacity : Float;
      Status  : out Property_Status);
   procedure Set_Floating
     (W       : Window;
      Enabled : Boolean;
      Status  : out Property_Status);
   procedure Set_Decorated
     (W       : Window;
      Enabled : Boolean;
      Status  : out Property_Status);
   procedure Show (W : Window; Status : out Property_Status);
   procedure Hide (W : Window; Status : out Property_Status);
   procedure Toggle_Visibility (W : Window; Status : out Property_Status);

   procedure Set_Standard_Cursor
     (W      : in out Window;
      Cursor : Standard_Cursor;
      Status : out Cursor_Status);

   procedure Framebuffer_Size
     (W      : Window;
      Width  : out Natural;
      Height : out Natural);

private
   function Window_Size_Valid
     (Width, Height : Natural) return Boolean;

   type Window is new Ada.Finalization.Limited_Controlled with record
      Handle : Raw.GLFW_Window_Handle := Raw.Null_Window;
      Cursor : Raw.GLFW_Cursor_Handle := Raw.Null_Cursor;
      Runtime : GLFW_Vulkan.Runtime_Lease;
   end record;
end GLFW_Vulkan.Windows;
