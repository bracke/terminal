with Ada.Exceptions;
with Ada.Finalization;
with C_String_Ownership;
with Interfaces.C;
with System;
with GLFW_Vulkan.Input;
with GLFW_Vulkan.Input_Registry;
with GLFW_Vulkan.Raw;

package body GLFW_Vulkan.Windows is
   use type GLFW_Vulkan.Raw.GLFW_Window_Handle;
   use type GLFW_Vulkan.Raw.GLFW_Cursor_Handle;
   use type Interfaces.C.int;

   type Window_Acquisition is
     new Ada.Finalization.Limited_Controlled with record
      Handle : aliased Raw.GLFW_Window_Handle := Raw.Null_Window;
   end record;
   overriding procedure Finalize (Item : in out Window_Acquisition);

   type Cursor_Acquisition is
     new Ada.Finalization.Limited_Controlled with record
      Window         : Raw.GLFW_Window_Handle := Raw.Null_Window;
      Handle         : aliased Raw.GLFW_Cursor_Handle := Raw.Null_Cursor;
      Previous       : Raw.GLFW_Cursor_Handle := Raw.Null_Cursor;
      Installed      : aliased Interfaces.C.int := 0;
      Previous_Owned : Boolean := False;
   end record;
   overriding procedure Finalize (Item : in out Cursor_Acquisition);

   protected Ownership_Publication is
      procedure Publish_Window
        (W      : in out Window;
         Source : in out Window_Acquisition);
      procedure Publish_Cursor
        (W      : in out Window;
         Source : in out Cursor_Acquisition);
   end Ownership_Publication;

   protected body Ownership_Publication is
      procedure Publish_Window
        (W      : in out Window;
         Source : in out Window_Acquisition) is
      begin
         W.Handle := Source.Handle;
         Source.Handle := Raw.Null_Window;
      end Publish_Window;

      procedure Publish_Cursor
        (W      : in out Window;
         Source : in out Cursor_Acquisition) is
      begin
         W.Cursor := Source.Handle;
         Source.Handle := Raw.Null_Cursor;
         Source.Installed := 0;
         Source.Previous_Owned := Source.Previous /= Raw.Null_Cursor;
      end Publish_Cursor;
   end Ownership_Publication;

   overriding procedure Finalize (Item : in out Window_Acquisition) is
      Owned : constant Raw.GLFW_Window_Handle := Item.Handle;
   begin
      Item.Handle := Raw.Null_Window;
      if Owned /= Raw.Null_Window then
         Raw.Destroy_Window (Owned);
      end if;
   end Finalize;

   overriding procedure Finalize (Item : in out Cursor_Acquisition) is
      Owned_New      : constant Raw.GLFW_Cursor_Handle := Item.Handle;
      Owned_Previous : constant Raw.GLFW_Cursor_Handle := Item.Previous;
   begin
      Item.Handle := Raw.Null_Cursor;
      Item.Previous := Raw.Null_Cursor;
      if Item.Installed /= 0 and then Item.Window /= Raw.Null_Window then
         Item.Installed := 0;
         Raw.Set_Cursor (Item.Window, Owned_Previous);
      end if;
      if Owned_New /= Raw.Null_Cursor then
         Raw.Destroy_Cursor (Owned_New);
      end if;
      if Item.Previous_Owned and then Owned_Previous /= Raw.Null_Cursor then
         Item.Previous_Owned := False;
         Raw.Destroy_Cursor (Owned_Previous);
      end if;
   end Finalize;

   function Window_Size_Valid
     (Width, Height : Natural) return Boolean is
     (Width > 0
      and then Height > 0
      and then Width <= Natural (Interfaces.C.int'Last)
      and then Height <= Natural (Interfaces.C.int'Last));

   procedure Create
     (Ctx    : in out GLFW_Vulkan.Context;
      W      : in out Window;
      Width  : Natural;
      Height : Natural;
      Title  : String;
      Status : out Create_Status)
   is
      C_Width : Interfaces.C.int;
      C_Height : Interfaces.C.int;
      C_Title : C_String_Ownership.Owner;
      Acquired : Window_Acquisition;
   begin
      if not Window_Size_Valid (Width, Height) then
         Status := Invalid_Size;
         return;
      end if;

      --  Reinitialization is supported and explicitly releases the old native
      --  handles before attempting to acquire replacements.
      Destroy (W);
      if not GLFW_Vulkan.Is_Initialized (Ctx) then
         Status := Not_Initialized;
         return;
      end if;

      C_Width := Interfaces.C.int (Width);
      C_Height := Interfaces.C.int (Height);
      C_String_Ownership.Set (C_Title, Title);

      Raw.Window_Hint (Raw.GLFW_CLIENT_API, Raw.GLFW_NO_API);
      Raw.Create_Window_Owned
        (Acquired.Handle'Access,
         C_Width,
         C_Height,
         C_String_Ownership.Unsafe_Pointer (C_Title),
         System.Null_Address,
         System.Null_Address);
      if Acquired.Handle /= Raw.Null_Window then
         GLFW_Vulkan.Retain_Runtime (W.Runtime);
         Ownership_Publication.Publish_Window (W, Acquired);
      end if;

      Status := (if W.Handle = Raw.Null_Window then Create_Failed else Ok);
   exception
      when others =>
         begin
            Destroy (W);
         exception
            when others => null;
         end;
         raise;
   end Create;

   procedure Destroy (W : in out Window) is
   begin
      if W.Cursor /= Raw.Null_Cursor then
         declare
            Owned_Cursor : constant Raw.GLFW_Cursor_Handle := W.Cursor;
         begin
            if W.Handle /= Raw.Null_Window then
               Raw.Set_Cursor (W.Handle, Raw.Null_Cursor);
            end if;
            W.Cursor := Raw.Null_Cursor;
            Raw.Destroy_Cursor (Owned_Cursor);
         end;
      end if;
      if W.Handle /= Raw.Null_Window then
         GLFW_Vulkan.Input.Clear_Callbacks (W);
         declare
            Owned_Window : constant Raw.GLFW_Window_Handle := W.Handle;
         begin
            W.Handle := Raw.Null_Window;
            Raw.Destroy_Window (Owned_Window);
         end;
      end if;
      GLFW_Vulkan.Release_Runtime (W.Runtime);
   end Destroy;

   overriding procedure Finalize (W : in out Window) is
   begin
      Destroy (W);
   exception
      when E : others =>
         --  A controlled finalizer must not replace the active exception with
         --  Program_Error.  Callback-registry teardown can fail during a
         --  concurrent mutation, so quarantine the Ada callbacks and complete
         --  native teardown best-effort with ownership markers cleared first.
         begin
            GLFW_Vulkan.Input_Registry.Note_Infrastructure_Failure
              (GLFW_Vulkan.Input.Registry_Infrastructure_Failure,
               Ada.Exceptions.Exception_Name (E));
         exception
            when others => null;
         end;
         declare
            Owned_Cursor : constant Raw.GLFW_Cursor_Handle := W.Cursor;
            Owned_Window : constant Raw.GLFW_Window_Handle := W.Handle;
         begin
            W.Cursor := Raw.Null_Cursor;
            W.Handle := Raw.Null_Window;
            begin
               GLFW_Vulkan.Input_Registry.Retire (Owned_Window);
            exception
               when Retire_Error : others =>
                  begin
                     GLFW_Vulkan.Input_Registry.Note_Infrastructure_Failure
                       (GLFW_Vulkan.Input.Registry_Infrastructure_Failure,
                        Ada.Exceptions.Exception_Name (Retire_Error));
                  exception
                     when others => null;
                  end;
            end;
            begin
               if Owned_Cursor /= Raw.Null_Cursor then
                  Raw.Destroy_Cursor (Owned_Cursor);
               end if;
            exception
               when others => null;
            end;
            begin
               if Owned_Window /= Raw.Null_Window then
                  Raw.Destroy_Window (Owned_Window);
               end if;
            exception
               when others => null;
            end;
         end;
      begin
         GLFW_Vulkan.Release_Runtime (W.Runtime);
      exception
         when others => null;
      end;
   end Finalize;

   function Is_Valid (W : Window) return Boolean is
     (W.Handle /= Raw.Null_Window);

   function Should_Close (W : Window) return Boolean is
     (W.Handle = Raw.Null_Window or else Raw.Window_Should_Close (W.Handle) /= 0);

   function Native_Handle (W : Window) return System.Address is
     (System.Address (W.Handle));

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
   begin
      if W.Handle /= Raw.Null_Window then
         declare
            C_Title : C_String_Ownership.Owner;
         begin
            C_String_Ownership.Set (C_Title, Title);
            Raw.Set_Window_Title
              (W.Handle, C_String_Ownership.Unsafe_Pointer (C_Title));
         end;
      end if;
   end Set_Title;

   procedure Set_Opacity
     (W       : Window;
      Opacity : Float;
      Status  : out Property_Status) is
   begin
      if W.Handle = Raw.Null_Window then
         Status := Window_Invalid;
      elsif Opacity < 0.0 or else Opacity > 1.0 then
         Status := Invalid_Value;
      else
         Raw.Set_Window_Opacity (W.Handle, Interfaces.C.C_float (Opacity));
         Status := Ok;
      end if;
   end Set_Opacity;

   procedure Set_Floating
     (W       : Window;
      Enabled : Boolean;
      Status  : out Property_Status) is
   begin
      if W.Handle = Raw.Null_Window then
         Status := Window_Invalid;
      else
         Raw.Set_Window_Attrib
           (W.Handle, Raw.GLFW_FLOATING, (if Enabled then 1 else 0));
         Status := Ok;
      end if;
   end Set_Floating;

   procedure Set_Decorated
     (W       : Window;
      Enabled : Boolean;
      Status  : out Property_Status) is
   begin
      if W.Handle = Raw.Null_Window then
         Status := Window_Invalid;
      else
         Raw.Set_Window_Attrib
           (W.Handle, Raw.GLFW_DECORATED, (if Enabled then 1 else 0));
         Status := Ok;
      end if;
   end Set_Decorated;

   procedure Show (W : Window; Status : out Property_Status) is
   begin
      if W.Handle = Raw.Null_Window then
         Status := Window_Invalid;
      else
         Raw.Show_Window (W.Handle);
         Raw.Focus_Window (W.Handle);
         Status := Ok;
      end if;
   end Show;

   procedure Hide (W : Window; Status : out Property_Status) is
   begin
      if W.Handle = Raw.Null_Window then
         Status := Window_Invalid;
      else
         Raw.Hide_Window (W.Handle);
         Status := Ok;
      end if;
   end Hide;

   procedure Toggle_Visibility (W : Window; Status : out Property_Status) is
   begin
      if W.Handle = Raw.Null_Window then
         Status := Window_Invalid;
      elsif Raw.Get_Window_Attrib (W.Handle, Raw.GLFW_VISIBLE) = 0 then
         Show (W, Status);
      else
         Hide (W, Status);
      end if;
   end Toggle_Visibility;

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
      Acquired : Cursor_Acquisition;
   begin
      if W.Handle = Raw.Null_Window then
         Status := Window_Invalid;
         return;
      end if;

      Acquired.Window := W.Handle;
      Acquired.Previous := W.Cursor;
      if Cursor /= Default_Cursor then
         Raw.Create_Standard_Cursor_Owned
           (Acquired.Handle'Access, Raw_Cursor_Shape (Cursor));
         if Acquired.Handle = Raw.Null_Cursor then
            Status := Create_Failed;
            return;
         end if;
      end if;

      Raw.Set_Cursor_Tracked
        (W.Handle, Acquired.Handle, Acquired.Installed'Access);
      Ownership_Publication.Publish_Cursor (W, Acquired);
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
         Width := (if CW <= 0 then 0 else Natural (CW));
         Height := (if CH <= 0 then 0 else Natural (CH));
      end if;
   end Framebuffer_Size;
end GLFW_Vulkan.Windows;
