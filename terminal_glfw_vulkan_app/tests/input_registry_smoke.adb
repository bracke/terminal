with AUnit.Assertions;
with GLFW_Vulkan.Input;
with GLFW_Vulkan.Input.Scoped_Binding;
with GLFW_Vulkan.Input.Testing;
with GLFW_Vulkan.Windows;
with GLFW_Vulkan.Windows.Testing;
with System;
with System.Storage_Elements;

procedure Input_Registry_Smoke is
   use AUnit.Assertions;
   use type GLFW_Vulkan.Input.Failure_Source;
   use type GLFW_Vulkan.Windows.Create_Status;
   package Input renames GLFW_Vulkan.Input;
   package Testing renames GLFW_Vulkan.Input.Testing;

   First_Handle : constant System.Address :=
     System.Storage_Elements.To_Address (1);
   Second_Handle : constant System.Address :=
     System.Storage_Elements.To_Address (64);
   Third_Handle : constant System.Address :=
     System.Storage_Elements.To_Address (4);
   Fourth_Handle : constant System.Address :=
     System.Storage_Elements.To_Address (5);
   First_Count : Natural := 0;
   Second_Count : Natural := 0;
   Replacement_Count : Natural := 0;
   Reused_Count : Natural := 0;
   Cancelled_Retirement_Count : Natural := 0;
   Waiting_Count : Natural := 0;
   Character_Count : Natural := 0;
   Mouse_Count : Natural := 0;
   Cursor_Count : Natural := 0;
   Scroll_Count : Natural := 0;
   Focus_Count : Natural := 0;
   Nesting_Count : Natural := 0;
   Scoped_Count : Natural := 0;

   procedure Ignore_Key (Event : Input.Key_Event) is
      pragma Unreferenced (Event);
   begin
      Scoped_Count := Scoped_Count + 1;
   end Ignore_Key;
   procedure Ignore_Character (Event : Input.Character_Event) is null;
   procedure Ignore_Mouse (Event : Input.Mouse_Button_Event) is null;
   procedure Ignore_Cursor (Event : Input.Cursor_Position_Event) is null;
   procedure Ignore_Scroll (Event : Input.Scroll_Event) is null;
   procedure Ignore_Focus (Event : Input.Focus_Event) is null;

   package Scoped_Test is new GLFW_Vulkan.Input.Scoped_Binding
     (On_Key             => Ignore_Key,
      On_Character       => Ignore_Character,
      On_Mouse_Button    => Ignore_Mouse,
      On_Cursor_Position => Ignore_Cursor,
      On_Scroll          => Ignore_Scroll,
      On_Focus           => Ignore_Focus);
   function Callback_Failure_Count return Natural is
      Snapshot : constant Input.Failure_Snapshot := Input.Failure_Diagnostics;
   begin
      return Snapshot.Callback_Count;
   end Callback_Failure_Count;

   function Infrastructure_Failure_Count return Natural is
      Snapshot : constant Input.Failure_Snapshot := Input.Failure_Diagnostics;
   begin
      return Snapshot.Infrastructure_Count;
   end Infrastructure_Failure_Count;

   function Last_Callback_Failure return Input.Failure_Detail is
      Snapshot : constant Input.Failure_Snapshot := Input.Failure_Diagnostics;
   begin
      return Snapshot.Callback_Detail;
   end Last_Callback_Failure;

   function Last_Infrastructure_Failure return Input.Failure_Detail is
      Snapshot : constant Input.Failure_Snapshot := Input.Failure_Diagnostics;
   begin
      return Snapshot.Infrastructure_Detail;
   end Last_Infrastructure_Failure;

   protected Dispatch_Synchronization is
      procedure Mark_Entered;
      entry Wait_Until_Entered;
      entry Wait_Until_Released;
      procedure Release;
      procedure Reset;
   private
      Entered  : Boolean := False;
      Released : Boolean := False;
   end Dispatch_Synchronization;

   protected Mutation_Completion is
      procedure Mark_Completed;
      entry Wait_Until_Completed;
      procedure Reset;
      function Is_Completed return Boolean;
   private
      Completed : Boolean := False;
   end Mutation_Completion;

   protected Dispatch_Completion is
      procedure Mark_Completed;
      entry Wait_Until_Completed;
   private
      Completed : Boolean := False;
   end Dispatch_Completion;

   protected Unrelated_Dispatch_Completion is
      procedure Mark_Completed;
      entry Wait_Until_Completed;
   private
      Completed : Boolean := False;
   end Unrelated_Dispatch_Completion;

   protected Waiting_Dispatch_Completion is
      procedure Mark_Completed;
      entry Wait_Until_Completed;
   private
      Completed : Boolean := False;
   end Waiting_Dispatch_Completion;

   protected Retired_Dispatch_Completion is
      procedure Mark_Completed;
      entry Wait_Until_Completed;
   private
      Completed : Boolean := False;
   end Retired_Dispatch_Completion;

   protected body Retired_Dispatch_Completion is
      procedure Mark_Completed is
      begin
         Completed := True;
      end Mark_Completed;
      entry Wait_Until_Completed when Completed is
      begin
         null;
      end Wait_Until_Completed;
   end Retired_Dispatch_Completion;

   protected body Waiting_Dispatch_Completion is
      procedure Mark_Completed is
      begin
         Completed := True;
      end Mark_Completed;
      entry Wait_Until_Completed when Completed is
      begin
         null;
      end Wait_Until_Completed;
   end Waiting_Dispatch_Completion;

   protected body Mutation_Completion is
      procedure Mark_Completed is
      begin
         Completed := True;
      end Mark_Completed;

      entry Wait_Until_Completed when Completed is
      begin
         null;
      end Wait_Until_Completed;

      procedure Reset is
      begin
         Completed := False;
      end Reset;

      function Is_Completed return Boolean is (Completed);
   end Mutation_Completion;

   protected body Dispatch_Completion is
      procedure Mark_Completed is
      begin
         Completed := True;
      end Mark_Completed;

      entry Wait_Until_Completed when Completed is
      begin
         null;
      end Wait_Until_Completed;
   end Dispatch_Completion;

   protected body Unrelated_Dispatch_Completion is
      procedure Mark_Completed is
      begin
         Completed := True;
      end Mark_Completed;

      entry Wait_Until_Completed when Completed is
      begin
         null;
      end Wait_Until_Completed;
   end Unrelated_Dispatch_Completion;

   protected body Dispatch_Synchronization is
      procedure Mark_Entered is
      begin
         Entered := True;
      end Mark_Entered;

      entry Wait_Until_Entered when Entered is
      begin
         null;
      end Wait_Until_Entered;

      entry Wait_Until_Released when Released is
      begin
         null;
      end Wait_Until_Released;

      procedure Release is
      begin
         Released := True;
      end Release;

      procedure Reset is
      begin
         Entered := False;
         Released := False;
      end Reset;
   end Dispatch_Synchronization;

   procedure Count_First (Event : Input.Key_Event) is
      pragma Unreferenced (Event);
   begin
      First_Count := First_Count + 1;
   end Count_First;

   procedure Count_Second (Event : Input.Key_Event) is
      pragma Unreferenced (Event);
   begin
      Second_Count := Second_Count + 1;
   end Count_Second;

   procedure Count_Replacement (Event : Input.Key_Event) is
      pragma Unreferenced (Event);
   begin
      Replacement_Count := Replacement_Count + 1;
   end Count_Replacement;

   procedure Count_Reused (Event : Input.Key_Event) is
      pragma Unreferenced (Event);
   begin
      Reused_Count := Reused_Count + 1;
   end Count_Reused;

   procedure Count_Cancelled_Retirement (Event : Input.Key_Event) is
      pragma Unreferenced (Event);
   begin
      Cancelled_Retirement_Count := Cancelled_Retirement_Count + 1;
   end Count_Cancelled_Retirement;

   procedure Count_Waiting (Event : Input.Key_Event) is
      pragma Unreferenced (Event);
   begin
      Waiting_Count := Waiting_Count + 1;
   end Count_Waiting;

   procedure Replace_Self (Event : Input.Key_Event) is
      pragma Unreferenced (Event);
   begin
      First_Count := First_Count + 1;
      Testing.Set_Key_Callback
        (First_Handle, Count_Replacement'Unrestricted_Access);
   end Replace_Self;

   procedure Dispatch_Other_Window (Event : Input.Key_Event) is
      pragma Unreferenced (Event);
   begin
      First_Count := First_Count + 1;
      Testing.Dispatch_Key (Second_Handle);
   end Dispatch_Other_Window;

   procedure Clear_Self (Event : Input.Key_Event) is
      pragma Unreferenced (Event);
   begin
      First_Count := First_Count + 1;
      Testing.Clear_Callbacks (First_Handle);
   end Clear_Self;

   procedure Recreate_Self (Event : Input.Key_Event) is
      pragma Unreferenced (Event);
   begin
      First_Count := First_Count + 1;
      Testing.Clear_Callbacks (First_Handle);
      Testing.Set_Key_Callback
        (First_Handle, Count_Replacement'Unrestricted_Access);
   end Recreate_Self;

   procedure Raise_From_Callback (Event : Input.Key_Event) is
      pragma Unreferenced (Event);
   begin
      raise Constraint_Error with "intentional callback failure";
   end Raise_From_Callback;

   procedure Dispatch_Recursively (Event : Input.Key_Event) is
      pragma Unreferenced (Event);
   begin
      Nesting_Count := Nesting_Count + 1;
      Testing.Dispatch_Key (First_Handle);
   end Dispatch_Recursively;

   procedure Block_Third_Window (Event : Input.Key_Event) is
      pragma Unreferenced (Event);
   begin
      Dispatch_Synchronization.Mark_Entered;
      Dispatch_Synchronization.Wait_Until_Released;
   end Block_Third_Window;

   procedure Count_Character (Event : Input.Character_Event) is
      pragma Unreferenced (Event);
   begin
      Character_Count := Character_Count + 1;
   end Count_Character;

   procedure Count_Mouse (Event : Input.Mouse_Button_Event) is
      pragma Unreferenced (Event);
   begin
      Mouse_Count := Mouse_Count + 1;
   end Count_Mouse;

   procedure Count_Cursor (Event : Input.Cursor_Position_Event) is
      pragma Unreferenced (Event);
   begin
      Cursor_Count := Cursor_Count + 1;
   end Count_Cursor;

   procedure Count_Scroll (Event : Input.Scroll_Event) is
      pragma Unreferenced (Event);
   begin
      Scroll_Count := Scroll_Count + 1;
   end Count_Scroll;

   procedure Count_Focus (Event : Input.Focus_Event) is
      pragma Unreferenced (Event);
   begin
      Focus_Count := Focus_Count + 1;
   end Count_Focus;

   procedure Raise_Character (Event : Input.Character_Event) is
      pragma Unreferenced (Event);
   begin
      raise Constraint_Error with "intentional character callback failure";
   end Raise_Character;

   procedure Raise_Mouse (Event : Input.Mouse_Button_Event) is
      pragma Unreferenced (Event);
   begin
      raise Constraint_Error with "intentional mouse callback failure";
   end Raise_Mouse;

   procedure Raise_Cursor (Event : Input.Cursor_Position_Event) is
      pragma Unreferenced (Event);
   begin
      raise Constraint_Error with "intentional cursor callback failure";
   end Raise_Cursor;

   procedure Raise_Scroll (Event : Input.Scroll_Event) is
      pragma Unreferenced (Event);
   begin
      raise Constraint_Error with "intentional scroll callback failure";
   end Raise_Scroll;

   procedure Raise_Focus (Event : Input.Focus_Event) is
      pragma Unreferenced (Event);
   begin
      raise Constraint_Error with "intentional focus callback failure";
   end Raise_Focus;

   procedure Run_Concurrency_Cases is separate;
begin
   Testing.Reset_Callback_Failures;
   Testing.Reset_Infrastructure_Failures;
   declare
      Ctx : GLFW_Vulkan.Context;
      Window : GLFW_Vulkan.Windows.Window;
      Status : GLFW_Vulkan.Windows.Create_Status;
   begin
      GLFW_Vulkan.Windows.Testing.Set_Fake_Handle (Window, Fourth_Handle);
      GLFW_Vulkan.Windows.Create (Ctx, Window, 0, 1, "invalid", Status);
      Assert
        (Status = GLFW_Vulkan.Windows.Invalid_Size,
         "zero native window dimensions report invalid size");
      Assert
        (GLFW_Vulkan.Windows.Is_Valid (Window),
         "an invalid replacement size preserves the existing window");
      GLFW_Vulkan.Windows.Testing.Clear_Fake_Handle (Window);
   end;
   declare
      Window : aliased GLFW_Vulkan.Windows.Window;
      Install_Failure_Observed : Boolean := False;
   begin
      GLFW_Vulkan.Windows.Testing.Set_Fake_Handle (Window, Fourth_Handle);
      Testing.Reset_Fake_Callback_Backend;
      Testing.Use_Fake_Callback_Backend;
      declare
         Binding : Scoped_Test.Binding (Window'Access);
      begin
         Scoped_Test.Attach (Binding);
         Assert
           (Testing.Fake_Callback_Call_Count = 6,
            "production scoped binding installs its callback bundle");
         Scoped_Test.Detach (Binding);
         Assert
           (Testing.Fake_Callback_Call_Count = 12
            and then Testing.Fake_Callbacks_Are_Restored,
            "production scoped binding restores native predecessors");

         Testing.Reset_Fake_Callback_Backend;
         Testing.Fail_Fake_Callback_Install_At (3);
         begin
            Scoped_Test.Attach (Binding);
         exception
            when Constraint_Error => Install_Failure_Observed := True;
         end;
         Assert
           (Install_Failure_Observed
            and then Testing.Fake_Callback_Call_Count = 5
            and then Testing.Fake_Callbacks_Are_Restored,
            "production scoped binding rolls back a partial native install");
      end;

      Testing.Reset_Fake_Callback_Backend;
      declare
         Binding : Scoped_Test.Binding (Window'Access);
      begin
         Scoped_Test.Attach (Binding);
      end;
      Assert
        (Testing.Fake_Callback_Call_Count = 12
         and then Testing.Fake_Callbacks_Are_Restored,
         "production scoped binding finalizer restores native predecessors");

      Testing.Reset_Fake_Callback_Backend;
      Testing.Fail_Fake_Callback_Install_At (7);
      declare
         Binding : Scoped_Test.Binding (Window'Access);
      begin
         Scoped_Test.Attach (Binding);
      end;
      declare
         Before : constant Natural := Scoped_Count;
      begin
         Testing.Dispatch_Key (Fourth_Handle);
         Assert
           (Scoped_Count = Before
            and then Infrastructure_Failure_Count >= 1
            and then Testing.Fake_Callbacks_Are_Restored,
            "failed finalizer detach quarantines scoped Ada callbacks");
      end;

      --  Window teardown uses the same replaceable native backend as callback
      --  installation. Rollback remains best-effort when both the detach and
      --  one restoration operation fail.
      Testing.Reset_Fake_Callback_Backend;
      Input.Set_Key_Callback (Window, Count_First'Unrestricted_Access);
      Testing.Fail_Fake_Callback_Installs_At (4, 5);
      declare
         Clear_Failure_Observed : Boolean := False;
         Before : constant Natural := First_Count;
      begin
         begin
            Input.Clear_Callbacks (Window);
         exception
            when Constraint_Error => Clear_Failure_Observed := True;
         end;
         Testing.Dispatch_Key (Fourth_Handle);
         Assert
           (Clear_Failure_Observed
            and then Testing.Fake_Callback_Call_Count = 6
            and then First_Count = Before + 1
            and then Infrastructure_Failure_Count >= 1,
            "callback teardown continues rollback after a restoration failure");
         First_Count := Before;
      end;
      Testing.Fail_Fake_Callback_Installs_At (0, 0);
      Input.Clear_Callbacks (Window);
      Assert
        (Testing.Fake_Callback_Call_Count = 12
         and then Testing.Fake_Callbacks_Are_Cleared,
         "callback teardown is routed through the native backend abstraction");
      Testing.Restore_Native_Callback_Backend;
      GLFW_Vulkan.Windows.Testing.Clear_Fake_Handle (Window);
   exception
      when others =>
         Testing.Restore_Native_Callback_Backend;
         GLFW_Vulkan.Windows.Testing.Clear_Fake_Handle (Window);
         raise;
   end;
   Testing.Reset_Infrastructure_Failures;
   declare
      Owner : Testing.Binding_Owner;
      Previous : Input.Key_Callback;
      Second_Claim_Rejected : Boolean := False;
      Unowned_Update_Rejected : Boolean := False;
   begin
      Testing.Set_Key_Callback
        (Fourth_Handle, Count_First'Unrestricted_Access);
      Testing.Claim_Binding (Fourth_Handle, Owner, Previous);
      begin
         declare
            Other_Owner : Testing.Binding_Owner;
            Other_Previous : Input.Key_Callback;
         begin
            Testing.Claim_Binding
              (Fourth_Handle, Other_Owner, Other_Previous);
         end;
      exception
         when Program_Error => Second_Claim_Rejected := True;
      end;
      begin
         Testing.Set_Key_Callback
           (Fourth_Handle, Count_First'Unrestricted_Access);
      exception
         when Program_Error => Unowned_Update_Rejected := True;
      end;
      Testing.Set_Bound_Key
        (Fourth_Handle, Owner, Count_Second'Unrestricted_Access);
      Testing.Dispatch_Key (Fourth_Handle);
      Testing.Restore_Binding (Fourth_Handle, Owner, Previous);
      Testing.Dispatch_Key (Fourth_Handle);
      Assert
        (Second_Claim_Rejected
         and then Unowned_Update_Rejected
         and then First_Count = 1
         and then Second_Count = 1,
         "scoped callback ownership is exclusive and restores its predecessor");
      Testing.Clear_Callbacks (Fourth_Handle);
      First_Count := 0;
      Second_Count := 0;
   end;
   Testing.Set_Key_Callback (First_Handle, Count_First'Unrestricted_Access);
   Testing.Set_Key_Callback (Second_Handle, Count_Second'Unrestricted_Access);
   Testing.Dispatch_Key (First_Handle);
   Testing.Dispatch_Key (Second_Handle);
   Assert
     (First_Count = 1 and then Second_Count = 1,
      "callbacks remain isolated by window");
   Testing.Abandon_Clear (First_Handle);
   Testing.Dispatch_Key (First_Handle);
   Assert
     (First_Count = 2,
      "an interrupted clear restores the registered callbacks");
   Testing.Set_Key_Callback
     (Fourth_Handle, Count_First'Unrestricted_Access);
   Testing.Retire (Fourth_Handle);
   Testing.Dispatch_Key (Fourth_Handle);
   Assert
     (First_Count = 2,
      "retiring a native window removes its callback identity");
   Testing.Set_Key_Callback
     (Fourth_Handle, Count_Reused'Unrestricted_Access);
   Testing.Dispatch_Key (Fourth_Handle);
   Assert
     (Reused_Count = 1,
      "a reused native window address receives only new callbacks");
   Testing.Clear_Callbacks (Fourth_Handle);

   Testing.Set_Key_Callback
     (Third_Handle, Block_Third_Window'Unrestricted_Access);
   declare
      task Dispatch_Third_Window;
      task Replace_Third_Window;
      task Dispatch_Second_Window;
      task body Dispatch_Third_Window is
      begin
         Testing.Dispatch_Key (Third_Handle);
         Dispatch_Completion.Mark_Completed;
      end Dispatch_Third_Window;
      task body Replace_Third_Window is
      begin
         Dispatch_Synchronization.Wait_Until_Entered;
         Testing.Set_Key_Callback
           (Third_Handle, Block_Third_Window'Unrestricted_Access);
         Mutation_Completion.Mark_Completed;
      end Replace_Third_Window;
      task body Dispatch_Second_Window is
      begin
         Dispatch_Synchronization.Wait_Until_Entered;
         Testing.Dispatch_Key (Second_Handle);
         Unrelated_Dispatch_Completion.Mark_Completed;
      end Dispatch_Second_Window;
      Unrelated_Dispatch_Completed : Boolean := False;
   begin
      Dispatch_Synchronization.Wait_Until_Entered;
      select
         Unrelated_Dispatch_Completion.Wait_Until_Completed;
         Unrelated_Dispatch_Completed := True;
      or
         delay 5.0;
      end select;
      Dispatch_Synchronization.Release;
      Assert
        (Unrelated_Dispatch_Completed,
         "mutation must not block a colliding window dispatch");
      select
         Mutation_Completion.Wait_Until_Completed;
      or
         delay 5.0;
         abort Replace_Third_Window;
      end select;
      select
         Dispatch_Completion.Wait_Until_Completed;
      or
         delay 5.0;
         abort Dispatch_Third_Window;
      end select;
   end;
   Testing.Clear_Callbacks (Third_Handle);

   Run_Concurrency_Cases;

   Testing.Set_Character_Callback
     (Fourth_Handle, Count_Character'Unrestricted_Access);
   Testing.Set_Mouse_Button_Callback
     (Fourth_Handle, Count_Mouse'Unrestricted_Access);
   Testing.Set_Cursor_Position_Callback
     (Fourth_Handle, Count_Cursor'Unrestricted_Access);
   Testing.Set_Scroll_Callback
     (Fourth_Handle, Count_Scroll'Unrestricted_Access);
   Testing.Set_Focus_Callback
     (Fourth_Handle, Count_Focus'Unrestricted_Access);
   Testing.Dispatch_Character (Fourth_Handle);
   Testing.Dispatch_Mouse_Button (Fourth_Handle);
   Testing.Dispatch_Cursor_Position (Fourth_Handle);
   Testing.Dispatch_Scroll (Fourth_Handle);
   Testing.Dispatch_Focus (Fourth_Handle);
   Assert
     (Character_Count = 1
      and then Mouse_Count = 1
      and then Cursor_Count = 1
      and then Scroll_Count = 1
      and then Focus_Count = 1,
      "every callback kind uses the per-window registry");
   Testing.Clear_Callbacks (Fourth_Handle);
   Testing.Reset_Cursor_Read_Count;
   Testing.Dispatch_Character (Fourth_Handle);
   Testing.Dispatch_Mouse_Button (Fourth_Handle);
   Testing.Dispatch_Cursor_Position (Fourth_Handle);
   Testing.Dispatch_Scroll (Fourth_Handle);
   Testing.Dispatch_Focus (Fourth_Handle);
   Assert
     (Character_Count = 1
      and then Mouse_Count = 1
      and then Cursor_Count = 1
      and then Scroll_Count = 1
      and then Focus_Count = 1,
      "clearing a window removes every callback kind");
   Assert
     (Testing.Cursor_Read_Count = 0,
      "unregistered mouse and scroll events do not query cursor position");

   Testing.Set_Key_Callback (First_Handle, Replace_Self'Unrestricted_Access);
   Testing.Dispatch_Key (First_Handle);
   Testing.Dispatch_Key (First_Handle);
   Assert
     (First_Count = 3 and then Replacement_Count = 1,
      "a callback can replace itself without deadlock");

   Testing.Set_Key_Callback
     (First_Handle, Dispatch_Other_Window'Unrestricted_Access);
   Testing.Dispatch_Key (First_Handle);
   Assert
     (First_Count = 4 and then Second_Count = 3,
      "nested dispatch to another window is preserved");

   Testing.Set_Key_Callback (First_Handle, Clear_Self'Unrestricted_Access);
   Testing.Dispatch_Key (First_Handle);
   Testing.Dispatch_Key (First_Handle);
   Assert (First_Count = 5, "reentrant clear removes the callback safely");

   Testing.Set_Key_Callback (First_Handle, Recreate_Self'Unrestricted_Access);
   Testing.Dispatch_Key (First_Handle);
   Testing.Dispatch_Key (First_Handle);
   Assert
     (First_Count = 6
      and then Replacement_Count = 2
      and then Callback_Failure_Count = 0,
      "retired dispatch tokens cannot alter a replacement registration");

   Testing.Reset_Callback_Failures;
   Testing.Set_Key_Callback
     (First_Handle, Dispatch_Recursively'Unrestricted_Access);
   Testing.Dispatch_Key (First_Handle);
   Assert
     (Nesting_Count = 64
      and then Callback_Failure_Count = 0
      and then Infrastructure_Failure_Count = 1,
      "recursive dispatch is stopped and reported at the nesting limit");
   Assert
     (Last_Infrastructure_Failure.Source =
        Input.Key_Callback_Failure
      and then Last_Infrastructure_Failure.Name_Length > 0,
      "infrastructure failures retain callback kind and exception identity");
   Testing.Clear_Callbacks (First_Handle);

   Testing.Reset_Callback_Failures;
   Testing.Reset_Infrastructure_Failures;
   Testing.Set_Key_Callback
     (Second_Handle, Raise_From_Callback'Unrestricted_Access);
   Testing.Dispatch_Key (Second_Handle);
   Assert
     (Callback_Failure_Count = 1
      and then Infrastructure_Failure_Count = 0,
      "callback exceptions are observable");
   Assert
     (Last_Callback_Failure.Source = Input.Key_Callback_Failure
      and then Last_Callback_Failure.Name_Length > 0,
      "callback failures retain callback kind and exception identity");
   declare
      Failures : constant Input.Failure_Snapshot :=
        Input.Failure_Diagnostics;
   begin
      Assert
        (Failures.Callback_Count = 1
         and then Failures.Callback_Detail.Source =
           Input.Key_Callback_Failure
         and then Failures.Infrastructure_Count = 0,
         "failure diagnostics expose one coherent registry snapshot");
   end;
   Testing.Clear_Callbacks (Second_Handle);

   Testing.Reset_Callback_Failures;
   Testing.Set_Character_Callback
     (Fourth_Handle, Raise_Character'Unrestricted_Access);
   Testing.Set_Mouse_Button_Callback
     (Fourth_Handle, Raise_Mouse'Unrestricted_Access);
   Testing.Set_Cursor_Position_Callback
     (Fourth_Handle, Raise_Cursor'Unrestricted_Access);
   Testing.Set_Scroll_Callback
     (Fourth_Handle, Raise_Scroll'Unrestricted_Access);
   Testing.Set_Focus_Callback
     (Fourth_Handle, Raise_Focus'Unrestricted_Access);
   Testing.Dispatch_Character (Fourth_Handle);
   Assert
     (Callback_Failure_Count = 1
      and then Last_Callback_Failure.Source =
        Input.Character_Callback_Failure,
      "character callback failures retain their source");
   Testing.Dispatch_Mouse_Button (Fourth_Handle);
   Assert
     (Callback_Failure_Count = 2
      and then Last_Callback_Failure.Source =
        Input.Mouse_Button_Callback_Failure,
      "mouse callback failures retain their source");
   Testing.Dispatch_Cursor_Position (Fourth_Handle);
   Assert
     (Callback_Failure_Count = 3
      and then Last_Callback_Failure.Source =
        Input.Cursor_Position_Callback_Failure,
      "cursor callback failures retain their source");
   Testing.Dispatch_Scroll (Fourth_Handle);
   Assert
     (Callback_Failure_Count = 4
      and then Last_Callback_Failure.Source =
        Input.Scroll_Callback_Failure,
      "scroll callback failures retain their source");
   Testing.Dispatch_Focus (Fourth_Handle);
   Assert
     (Callback_Failure_Count = 5
      and then Last_Callback_Failure.Source =
        Input.Focus_Callback_Failure,
      "focus callback failures retain their source");
   Testing.Clear_Callbacks (Fourth_Handle);
end Input_Registry_Smoke;
