with Interfaces.C;
with Interfaces.C.Strings;
with System;
with GLFW_Vulkan.Raw;

package body GLFW_Vulkan.Windows is
   use type GLFW_Vulkan.Raw.GLFW_Window_Handle;
   use type Interfaces.C.int;

   procedure Create
     (Ctx    : in out GLFW_Vulkan.Context;
      W      : out Window;
      Width  : Positive;
      Height : Positive;
      Title  : String;
      Status : out Create_Status)
   is
      C_Title : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Title);
   begin
      W.Handle := Raw.Null_Window;
      if not GLFW_Vulkan.Is_Initialized (Ctx) then
         Status := Not_Initialized;
         Interfaces.C.Strings.Free (C_Title);
         return;
      end if;

      Raw.Window_Hint (Raw.GLFW_CLIENT_API, Raw.GLFW_NO_API);
      W.Handle := Raw.Create_Window
        (Interfaces.C.int (Width),
         Interfaces.C.int (Height),
         C_Title,
         System.Null_Address,
         System.Null_Address);
      Interfaces.C.Strings.Free (C_Title);

      Status := (if W.Handle = Raw.Null_Window then Create_Failed else Ok);
   end Create;

   procedure Destroy (W : in out Window) is
   begin
      if W.Handle /= Raw.Null_Window then
         Raw.Destroy_Window (W.Handle);
         W.Handle := Raw.Null_Window;
      end if;
   end Destroy;

   function Is_Valid (W : Window) return Boolean is
     (W.Handle /= Raw.Null_Window);

   function Should_Close (W : Window) return Boolean is
     (W.Handle = Raw.Null_Window or else Raw.Window_Should_Close (W.Handle) /= 0);

   procedure Set_Should_Close
     (W     : in out Window;
      Close : Boolean)
   is
   begin
      if W.Handle /= Raw.Null_Window then
         Raw.Set_Window_Should_Close (W.Handle, (if Close then 1 else 0));
      end if;
   end Set_Should_Close;

   procedure Framebuffer_Size
     (W      : Window;
      Width  : out Natural;
      Height : out Natural)
   is
      CW : Interfaces.C.int := 0;
      CH : Interfaces.C.int := 0;
   begin
      if W.Handle = Raw.Null_Window then
         Width := 0;
         Height := 0;
      else
         Raw.Get_Framebuffer_Size (W.Handle, CW, CH);
         Width := Natural'Max (0, Natural (CW));
         Height := Natural'Max (0, Natural (CH));
      end if;
   end Framebuffer_Size;
end GLFW_Vulkan.Windows;
