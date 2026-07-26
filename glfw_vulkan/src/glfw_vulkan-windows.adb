with Interfaces.C;
with Interfaces.C.Strings;
with System;
with GLFW_Vulkan.Raw;

package body GLFW_Vulkan.Windows is
   use type GLFW_Vulkan.Raw.GLFW_Window_Handle;
   use type GLFW_Vulkan.Raw.GLFW_Cursor_Handle;
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
         if W.Cursor /= Raw.Null_Cursor then
            Raw.Set_Cursor (W.Handle, Raw.Null_Cursor);
            Raw.Destroy_Cursor (W.Cursor);
            W.Cursor := Raw.Null_Cursor;
         end if;
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

   procedure Set_Title
     (W     : Window;
      Title : String)
   is
      C_Title : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String (Title);
   begin
      if W.Handle /= Raw.Null_Window then
         Raw.Set_Window_Title (W.Handle, C_Title);
      end if;
      Interfaces.C.Strings.Free (C_Title);
   end Set_Title;

   function Raw_Cursor_Shape
     (Cursor : Standard_Cursor) return Interfaces.C.int
   is
   begin
      case Cursor is
         when Default_Cursor => return Raw.GLFW_ARROW_CURSOR;
         when I_Beam_Cursor  => return Raw.GLFW_IBEAM_CURSOR;
         when Hand_Cursor    => return Raw.GLFW_HAND_CURSOR;
      end case;
   end Raw_Cursor_Shape;

   procedure Set_Standard_Cursor
     (W      : in out Window;
      Cursor : Standard_Cursor;
      Status : out Cursor_Status)
   is
      New_Cursor : Raw.GLFW_Cursor_Handle := Raw.Null_Cursor;
   begin
      if W.Handle = Raw.Null_Window then
         Status := Window_Invalid;
         return;
      end if;

      if Cursor /= Default_Cursor then
         New_Cursor := Raw.Create_Standard_Cursor (Raw_Cursor_Shape (Cursor));
         if New_Cursor = Raw.Null_Cursor then
            Status := Create_Failed;
            return;
         end if;
      end if;

      Raw.Set_Cursor (W.Handle, New_Cursor);
      if W.Cursor /= Raw.Null_Cursor then
         Raw.Destroy_Cursor (W.Cursor);
      end if;
      W.Cursor := New_Cursor;
      Status := Ok;
   end Set_Standard_Cursor;

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
