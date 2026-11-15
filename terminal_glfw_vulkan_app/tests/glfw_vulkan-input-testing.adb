with GLFW_Vulkan.Input_Registry;
with GLFW_Vulkan.Raw;
with Interfaces.C;

package body GLFW_Vulkan.Input.Testing is
   package Registry renames GLFW_Vulkan.Input_Registry;
   package Raw renames GLFW_Vulkan.Raw;
   use type Raw.Key_Callback_Access;
   use type Raw.Char_Callback_Access;
   use type Raw.Mouse_Button_Callback_Access;
   use type Raw.Cursor_Pos_Callback_Access;
   use type Raw.Scroll_Callback_Access;
   use type Raw.Window_Focus_Callback_Access;
   Cursor_Reads : Natural := 0;
   Fake_Call_Count : Natural := 0;
   Fake_Failure_Call : Natural := 0;
   Fake_Second_Failure_Call : Natural := 0;

   procedure Dummy_Key
     (Window : Raw.GLFW_Window_Handle;
      Key, Scancode, Action, Mods : Interfaces.C.int) is null
     with Convention => C;
   procedure Dummy_Character
     (Window : Raw.GLFW_Window_Handle;
      Code_Point : Interfaces.C.unsigned) is null
     with Convention => C;
   procedure Dummy_Mouse
     (Window : Raw.GLFW_Window_Handle;
      Button, Action, Mods : Interfaces.C.int) is null
     with Convention => C;
   procedure Dummy_Cursor
     (Window : Raw.GLFW_Window_Handle;
      X_Pos, Y_Pos : Interfaces.C.double) is null
     with Convention => C;
   procedure Dummy_Scroll
     (Window : Raw.GLFW_Window_Handle;
      X_Offset, Y_Offset : Interfaces.C.double) is null
     with Convention => C;
   procedure Dummy_Focus
     (Window : Raw.GLFW_Window_Handle;
      Focused : Interfaces.C.int) is null
     with Convention => C;
   Current_Key : Raw.Key_Callback_Access := Dummy_Key'Access;
   Current_Character : Raw.Char_Callback_Access := Dummy_Character'Access;
   Current_Mouse : Raw.Mouse_Button_Callback_Access := Dummy_Mouse'Access;
   Current_Cursor : Raw.Cursor_Pos_Callback_Access := Dummy_Cursor'Access;
   Current_Scroll : Raw.Scroll_Callback_Access := Dummy_Scroll'Access;
   Current_Focus : Raw.Window_Focus_Callback_Access := Dummy_Focus'Access;

   procedure Note_Fake_Call is
   begin
      Fake_Call_Count := Fake_Call_Count + 1;
      if (Fake_Failure_Call /= 0 and then Fake_Call_Count = Fake_Failure_Call)
        or else
          (Fake_Second_Failure_Call /= 0
           and then Fake_Call_Count = Fake_Second_Failure_Call)
      then
         raise Constraint_Error with "injected native callback failure";
      end if;
   end Note_Fake_Call;

   procedure Fake_Set_Key
     (Window : Raw.GLFW_Window_Handle;
      Callback : Raw.Key_Callback_Access;
      Previous : access Raw.Key_Callback_Access;
      Installed : access Interfaces.C.int)
     with Convention => C;
   procedure Fake_Set_Key
     (Window : Raw.GLFW_Window_Handle;
      Callback : Raw.Key_Callback_Access;
      Previous : access Raw.Key_Callback_Access;
      Installed : access Interfaces.C.int)
   is
      pragma Unreferenced (Window);
   begin
      Installed.all := 0;
      Note_Fake_Call;
      Previous.all := Current_Key;
      Current_Key := Callback;
      Installed.all := 1;
   end Fake_Set_Key;

   procedure Fake_Set_Character
     (Window : Raw.GLFW_Window_Handle;
      Callback : Raw.Char_Callback_Access;
      Previous : access Raw.Char_Callback_Access;
      Installed : access Interfaces.C.int)
     with Convention => C;
   procedure Fake_Set_Character
     (Window : Raw.GLFW_Window_Handle;
      Callback : Raw.Char_Callback_Access;
      Previous : access Raw.Char_Callback_Access;
      Installed : access Interfaces.C.int) is
      pragma Unreferenced (Window);
   begin
      Installed.all := 0;
      Note_Fake_Call;
      Previous.all := Current_Character;
      Current_Character := Callback;
      Installed.all := 1;
   end Fake_Set_Character;

   procedure Fake_Set_Mouse
     (Window : Raw.GLFW_Window_Handle;
      Callback : Raw.Mouse_Button_Callback_Access;
      Previous : access Raw.Mouse_Button_Callback_Access;
      Installed : access Interfaces.C.int)
     with Convention => C;
   procedure Fake_Set_Mouse
     (Window : Raw.GLFW_Window_Handle;
      Callback : Raw.Mouse_Button_Callback_Access;
      Previous : access Raw.Mouse_Button_Callback_Access;
      Installed : access Interfaces.C.int) is
      pragma Unreferenced (Window);
   begin
      Installed.all := 0;
      Note_Fake_Call;
      Previous.all := Current_Mouse;
      Current_Mouse := Callback;
      Installed.all := 1;
   end Fake_Set_Mouse;

   procedure Fake_Set_Cursor
     (Window : Raw.GLFW_Window_Handle;
      Callback : Raw.Cursor_Pos_Callback_Access;
      Previous : access Raw.Cursor_Pos_Callback_Access;
      Installed : access Interfaces.C.int)
     with Convention => C;
   procedure Fake_Set_Cursor
     (Window : Raw.GLFW_Window_Handle;
      Callback : Raw.Cursor_Pos_Callback_Access;
      Previous : access Raw.Cursor_Pos_Callback_Access;
      Installed : access Interfaces.C.int) is
      pragma Unreferenced (Window);
   begin
      Installed.all := 0;
      Note_Fake_Call;
      Previous.all := Current_Cursor;
      Current_Cursor := Callback;
      Installed.all := 1;
   end Fake_Set_Cursor;

   procedure Fake_Set_Scroll
     (Window : Raw.GLFW_Window_Handle;
      Callback : Raw.Scroll_Callback_Access;
      Previous : access Raw.Scroll_Callback_Access;
      Installed : access Interfaces.C.int)
     with Convention => C;
   procedure Fake_Set_Scroll
     (Window : Raw.GLFW_Window_Handle;
      Callback : Raw.Scroll_Callback_Access;
      Previous : access Raw.Scroll_Callback_Access;
      Installed : access Interfaces.C.int) is
      pragma Unreferenced (Window);
   begin
      Installed.all := 0;
      Note_Fake_Call;
      Previous.all := Current_Scroll;
      Current_Scroll := Callback;
      Installed.all := 1;
   end Fake_Set_Scroll;

   procedure Fake_Set_Focus
     (Window : Raw.GLFW_Window_Handle;
      Callback : Raw.Window_Focus_Callback_Access;
      Previous : access Raw.Window_Focus_Callback_Access;
      Installed : access Interfaces.C.int)
     with Convention => C;
   procedure Fake_Set_Focus
     (Window : Raw.GLFW_Window_Handle;
      Callback : Raw.Window_Focus_Callback_Access;
      Previous : access Raw.Window_Focus_Callback_Access;
      Installed : access Interfaces.C.int) is
      pragma Unreferenced (Window);
   begin
      Installed.all := 0;
      Note_Fake_Call;
      Previous.all := Current_Focus;
      Current_Focus := Callback;
      Installed.all := 1;
   end Fake_Set_Focus;

   procedure Reset_Fake_Callback_Backend is
   begin
      Fake_Call_Count := 0;
      Fake_Failure_Call := 0;
      Fake_Second_Failure_Call := 0;
      Current_Key := Dummy_Key'Access;
      Current_Character := Dummy_Character'Access;
      Current_Mouse := Dummy_Mouse'Access;
      Current_Cursor := Dummy_Cursor'Access;
      Current_Scroll := Dummy_Scroll'Access;
      Current_Focus := Dummy_Focus'Access;
   end Reset_Fake_Callback_Backend;

   procedure Use_Fake_Callback_Backend is
   begin
      Configure_Callback_Backend
        ((Set_Key       => Fake_Set_Key'Access,
          Set_Character => Fake_Set_Character'Access,
          Set_Mouse     => Fake_Set_Mouse'Access,
          Set_Cursor    => Fake_Set_Cursor'Access,
          Set_Scroll    => Fake_Set_Scroll'Access,
          Set_Focus     => Fake_Set_Focus'Access));
   end Use_Fake_Callback_Backend;

   procedure Restore_Native_Callback_Backend is
   begin
      Reset_Callback_Backend;
   end Restore_Native_Callback_Backend;

   procedure Fail_Fake_Callback_Install_At (Call : Natural) is
   begin
      Fake_Failure_Call := Call;
   end Fail_Fake_Callback_Install_At;

   procedure Fail_Fake_Callback_Installs_At
     (First_Call, Second_Call : Natural) is
   begin
      Fake_Failure_Call := First_Call;
      Fake_Second_Failure_Call := Second_Call;
   end Fail_Fake_Callback_Installs_At;

   function Fake_Callback_Call_Count return Natural is (Fake_Call_Count);

   function Fake_Callbacks_Are_Restored return Boolean is
   begin
      return Current_Key = Dummy_Key'Access
        and then Current_Character = Dummy_Character'Access
        and then Current_Mouse = Dummy_Mouse'Access
        and then Current_Cursor = Dummy_Cursor'Access
        and then Current_Scroll = Dummy_Scroll'Access
        and then Current_Focus = Dummy_Focus'Access;
   end Fake_Callbacks_Are_Restored;

   function Fake_Callbacks_Are_Cleared return Boolean is
   begin
      return Current_Key = null
        and then Current_Character = null
        and then Current_Mouse = null
        and then Current_Cursor = null
        and then Current_Scroll = null
        and then Current_Focus = null;
   end Fake_Callbacks_Are_Cleared;

   protected Mutation_Pause is
      procedure Mark_Paused;
      entry Wait_Until_Paused;
      entry Wait_Until_Released;
      procedure Release;
   private
      Paused   : Boolean := False;
      Released : Boolean := False;
   end Mutation_Pause;

   protected body Mutation_Pause is
      procedure Mark_Paused is
      begin
         Released := False;
         Paused := True;
      end Mark_Paused;
      entry Wait_Until_Paused when Paused is
      begin
         null;
      end Wait_Until_Paused;
      entry Wait_Until_Released when Released is
      begin
         null;
      end Wait_Until_Released;
      procedure Release is
      begin
         Released := True;
         Paused := False;
      end Release;
   end Mutation_Pause;

   function Window_Of (Handle : System.Address) return Raw.GLFW_Window_Handle is
     (Raw.GLFW_Window_Handle (Handle));

   procedure Zero_Cursor (X, Y : out Float) is
   begin
      Cursor_Reads := Cursor_Reads + 1;
      X := 0.0;
      Y := 0.0;
   end Zero_Cursor;

   procedure Reset_Cursor_Read_Count is
   begin
      Cursor_Reads := 0;
   end Reset_Cursor_Read_Count;

   function Cursor_Read_Count return Natural is (Cursor_Reads);

   procedure Claim_Binding
     (Handle       : System.Address;
      Owner        : out Binding_Owner;
      Previous_Key : out Key_Callback)
   is
      Window : constant Raw.GLFW_Window_Handle := Window_Of (Handle);
      Guard : Registry.Mutation_Guard;
      Previous : Callback_Set;
   begin
      Registry.Begin_Update (Guard, Window);
      Registry.Claim_Binding (Guard, Owner, Previous);
      Previous_Key := Previous.Key;
   end Claim_Binding;

   procedure Set_Bound_Key
     (Handle   : System.Address;
      Owner    : Binding_Owner;
      Callback : Key_Callback)
   is
      Window : constant Raw.GLFW_Window_Handle := Window_Of (Handle);
      Guard : Registry.Mutation_Guard;
   begin
      Registry.Begin_Update (Guard, Window);
      Registry.Authorize_Binding (Guard, Owner);
      Registry.Set_Key (Guard, Callback);
   end Set_Bound_Key;

   procedure Restore_Binding
     (Handle       : System.Address;
      Owner        : Binding_Owner;
      Previous_Key : Key_Callback)
   is
      Window : constant Raw.GLFW_Window_Handle := Window_Of (Handle);
      Guard : Registry.Mutation_Guard;
   begin
      Registry.Begin_Update (Guard, Window);
      Registry.Authorize_Binding (Guard, Owner);
      Registry.Set_Key (Guard, Previous_Key);
      Registry.Release_Binding (Guard, Owner);
   end Restore_Binding;

   procedure Set_Key_Callback
     (Handle : System.Address; Callback : Key_Callback)
   is
      Window : constant Raw.GLFW_Window_Handle := Window_Of (Handle);
      Guard : Registry.Mutation_Guard;
   begin
      Registry.Begin_Update (Guard, Window);
      Registry.Set_Key (Guard, Callback);
   end Set_Key_Callback;

   procedure Set_Key_Callback_Paused
     (Handle : System.Address; Callback : Key_Callback)
   is
      Window : constant Raw.GLFW_Window_Handle := Window_Of (Handle);
      Guard : Registry.Mutation_Guard;
   begin
      Registry.Begin_Update (Guard, Window);
      Mutation_Pause.Mark_Paused;
      Mutation_Pause.Wait_Until_Released;
      Registry.Set_Key (Guard, Callback);
   end Set_Key_Callback_Paused;

   procedure Wait_Until_Mutation_Paused is
   begin
      Mutation_Pause.Wait_Until_Paused;
   end Wait_Until_Mutation_Paused;

   procedure Release_Paused_Mutation is
   begin
      Mutation_Pause.Release;
   end Release_Paused_Mutation;

   function Waiting_Dispatch_Count (Handle : System.Address) return Natural is
     (Registry.Waiting_Dispatch_Count (Window_Of (Handle)));

   function Retirement_In_Progress (Handle : System.Address) return Boolean is
     (Registry.Retirement_In_Progress (Window_Of (Handle)));

   procedure Set_Character_Callback
     (Handle : System.Address; Callback : Character_Callback)
   is
      Window : constant Raw.GLFW_Window_Handle := Window_Of (Handle);
      Guard : Registry.Mutation_Guard;
   begin
      Registry.Begin_Update (Guard, Window);
      Registry.Set_Character (Guard, Callback);
   end Set_Character_Callback;

   procedure Set_Mouse_Button_Callback
     (Handle : System.Address; Callback : Mouse_Button_Callback)
   is
      Window : constant Raw.GLFW_Window_Handle := Window_Of (Handle);
      Guard : Registry.Mutation_Guard;
   begin
      Registry.Begin_Update (Guard, Window);
      Registry.Set_Mouse_Button (Guard, Callback);
   end Set_Mouse_Button_Callback;

   procedure Set_Cursor_Position_Callback
     (Handle : System.Address; Callback : Cursor_Position_Callback)
   is
      Window : constant Raw.GLFW_Window_Handle := Window_Of (Handle);
      Guard : Registry.Mutation_Guard;
   begin
      Registry.Begin_Update (Guard, Window);
      Registry.Set_Cursor_Position (Guard, Callback);
   end Set_Cursor_Position_Callback;

   procedure Set_Scroll_Callback
     (Handle : System.Address; Callback : Scroll_Callback)
   is
      Window : constant Raw.GLFW_Window_Handle := Window_Of (Handle);
      Guard : Registry.Mutation_Guard;
   begin
      Registry.Begin_Update (Guard, Window);
      Registry.Set_Scroll (Guard, Callback);
   end Set_Scroll_Callback;

   procedure Set_Focus_Callback
     (Handle : System.Address; Callback : Focus_Callback)
   is
      Window : constant Raw.GLFW_Window_Handle := Window_Of (Handle);
      Guard : Registry.Mutation_Guard;
   begin
      Registry.Begin_Update (Guard, Window);
      Registry.Set_Focus (Guard, Callback);
   end Set_Focus_Callback;

   procedure Clear_Callbacks (Handle : System.Address) is
      Window : constant Raw.GLFW_Window_Handle := Window_Of (Handle);
      Guard : Registry.Mutation_Guard;
   begin
      Registry.Begin_Remove (Guard, Window);
      Registry.Remove (Guard);
   end Clear_Callbacks;

   procedure Abandon_Clear (Handle : System.Address) is
      Window : constant Raw.GLFW_Window_Handle := Window_Of (Handle);
      Guard : Registry.Mutation_Guard;
   begin
      Registry.Begin_Remove (Guard, Window);
      --  Let the guard roll the uncommitted removal back.
   end Abandon_Clear;

   procedure Retire (Handle : System.Address) is
   begin
      Registry.Retire (Window_Of (Handle));
   end Retire;

   procedure Dispatch_Key
     (Handle : System.Address; Raw_Key : Integer := 65) is
   begin
      Registry.Dispatch_Key
        (Window_Of (Handle),
         (Key => A, Raw_Key => Raw_Key, Action => Press, others => <>));
   end Dispatch_Key;

   procedure Dispatch_Character (Handle : System.Address) is
   begin
      Registry.Dispatch_Character
        (Window_Of (Handle), (Code_Point => 'A'));
   end Dispatch_Character;

   procedure Dispatch_Mouse_Button (Handle : System.Address) is
   begin
      Registry.Dispatch_Mouse_Button
        (Window_Of (Handle), (others => <>), Zero_Cursor'Access);
   end Dispatch_Mouse_Button;

   procedure Dispatch_Cursor_Position (Handle : System.Address) is
   begin
      Registry.Dispatch_Cursor_Position (Window_Of (Handle), (others => <>));
   end Dispatch_Cursor_Position;

   procedure Dispatch_Scroll (Handle : System.Address) is
   begin
      Registry.Dispatch_Scroll
        (Window_Of (Handle), (others => <>), Zero_Cursor'Access);
   end Dispatch_Scroll;

   procedure Dispatch_Focus (Handle : System.Address) is
   begin
      Registry.Dispatch_Focus (Window_Of (Handle), (others => <>));
   end Dispatch_Focus;

   procedure Reset_Callback_Failures is
   begin
      Registry.Reset_Callback_Failures;
   end Reset_Callback_Failures;

   procedure Reset_Infrastructure_Failures is
   begin
      Registry.Reset_Infrastructure_Failures;
   end Reset_Infrastructure_Failures;
end GLFW_Vulkan.Input.Testing;
