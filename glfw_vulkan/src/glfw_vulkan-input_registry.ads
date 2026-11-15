with Ada.Finalization;
with Interfaces;
with GLFW_Vulkan.Input;
with GLFW_Vulkan.Raw;

private package GLFW_Vulkan.Input_Registry is
   type Mutation_Guard is
     new Ada.Finalization.Limited_Controlled with private;

   procedure Begin_Update
     (Guard  : in out Mutation_Guard;
      Window : GLFW_Vulkan.Raw.GLFW_Window_Handle);
   procedure Begin_Remove
     (Guard  : in out Mutation_Guard;
      Window : GLFW_Vulkan.Raw.GLFW_Window_Handle);

   procedure Set_Key
     (Guard  : in out Mutation_Guard;
      Value  : GLFW_Vulkan.Input.Key_Callback);
   procedure Set_Character
     (Guard  : in out Mutation_Guard;
      Value  : GLFW_Vulkan.Input.Character_Callback);
   procedure Set_Mouse_Button
     (Guard  : in out Mutation_Guard;
      Value  : GLFW_Vulkan.Input.Mouse_Button_Callback);
   procedure Set_Cursor_Position
     (Guard  : in out Mutation_Guard;
      Value  : GLFW_Vulkan.Input.Cursor_Position_Callback);
   procedure Set_Scroll
     (Guard  : in out Mutation_Guard;
      Value  : GLFW_Vulkan.Input.Scroll_Callback);
   procedure Set_Focus
     (Guard  : in out Mutation_Guard;
      Value  : GLFW_Vulkan.Input.Focus_Callback);
   procedure Claim_Binding
     (Guard    : in out Mutation_Guard;
      Owner    : out Interfaces.Unsigned_64;
      Previous : out GLFW_Vulkan.Input.Callback_Set);
   procedure Authorize_Binding
     (Guard : in out Mutation_Guard;
      Owner : Interfaces.Unsigned_64);
   procedure Release_Binding
     (Guard : in out Mutation_Guard;
      Owner : Interfaces.Unsigned_64);
   procedure Remove (Guard : in out Mutation_Guard);
   --  Finalizer fallback for a native window that will be destroyed even when
   --  its normal callback-removal transaction could not complete.
   procedure Retire (Window : GLFW_Vulkan.Raw.GLFW_Window_Handle);
   function Waiting_Dispatch_Count
     (Window : GLFW_Vulkan.Raw.GLFW_Window_Handle) return Natural;
   function Retirement_In_Progress
     (Window : GLFW_Vulkan.Raw.GLFW_Window_Handle) return Boolean;

   procedure Dispatch_Key
     (Window : GLFW_Vulkan.Raw.GLFW_Window_Handle;
      Event  : GLFW_Vulkan.Input.Key_Event);
   procedure Dispatch_Character
     (Window : GLFW_Vulkan.Raw.GLFW_Window_Handle;
      Event  : GLFW_Vulkan.Input.Character_Event);
   procedure Dispatch_Mouse_Button
     (Window : GLFW_Vulkan.Raw.GLFW_Window_Handle;
      Event  : GLFW_Vulkan.Input.Mouse_Button_Event;
      Read_Cursor : not null access procedure (X, Y : out Float));
   procedure Dispatch_Cursor_Position
     (Window : GLFW_Vulkan.Raw.GLFW_Window_Handle;
      Event  : GLFW_Vulkan.Input.Cursor_Position_Event);
   procedure Dispatch_Scroll
     (Window : GLFW_Vulkan.Raw.GLFW_Window_Handle;
      Event  : GLFW_Vulkan.Input.Scroll_Event;
      Read_Cursor : not null access procedure (X, Y : out Float));
   procedure Dispatch_Focus
     (Window : GLFW_Vulkan.Raw.GLFW_Window_Handle;
      Event  : GLFW_Vulkan.Input.Focus_Event);

   procedure Note_Callback_Failure
     (Source         : GLFW_Vulkan.Input.Failure_Source;
      Exception_Name : String);
   procedure Note_Infrastructure_Failure
     (Source         : GLFW_Vulkan.Input.Failure_Source;
      Exception_Name : String);
   procedure Reset_Callback_Failures;
   procedure Reset_Infrastructure_Failures;
   function Failures return GLFW_Vulkan.Input.Failure_Snapshot;

private
   type Mutation_Guard is
     new Ada.Finalization.Limited_Controlled with record
      Active : Boolean := False;
      Window : GLFW_Vulkan.Raw.GLFW_Window_Handle :=
        GLFW_Vulkan.Raw.Null_Window;
      Generation : Interfaces.Unsigned_64 := 0;
      Binding_Owner : Interfaces.Unsigned_64 := 0;
   end record;
   overriding procedure Finalize (Guard : in out Mutation_Guard);
end GLFW_Vulkan.Input_Registry;
