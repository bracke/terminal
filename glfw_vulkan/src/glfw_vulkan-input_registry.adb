with Ada.Exceptions;
with Ada.Finalization;
with Ada.Unchecked_Deallocation;
with Interfaces;
with System.Storage_Elements;
with GLFW_Vulkan.Input_Dispatch_Context;
with GLFW_Vulkan.Input_Failures;

package body GLFW_Vulkan.Input_Registry is
   package Input renames GLFW_Vulkan.Input;
   package Dispatch_Context renames GLFW_Vulkan.Input_Dispatch_Context;
   package Failure_Log renames GLFW_Vulkan.Input_Failures;
   package Raw renames GLFW_Vulkan.Raw;
   use type Raw.GLFW_Window_Handle;
   use type Input.Key_Callback;
   use type Input.Character_Callback;
   use type Input.Mouse_Button_Callback;
   use type Input.Cursor_Position_Callback;
   use type Input.Scroll_Callback;
   use type Input.Focus_Callback;
   use type Interfaces.Unsigned_64;

   type Callback_Kind is
     (Key_Kind,
      Character_Kind,
      Mouse_Button_Kind,
      Cursor_Position_Kind,
      Scroll_Kind,
      Focus_Kind);

   function Failure_Source_For
     (Kind : Callback_Kind) return Input.Failure_Source is
     (case Kind is
         when Key_Kind             => Input.Key_Callback_Failure,
         when Character_Kind       => Input.Character_Callback_Failure,
         when Mouse_Button_Kind    => Input.Mouse_Button_Callback_Failure,
         when Cursor_Position_Kind => Input.Cursor_Position_Callback_Failure,
         when Scroll_Kind          => Input.Scroll_Callback_Failure,
         when Focus_Kind           => Input.Focus_Callback_Failure);

   function Is_Set
     (Value : Input.Callback_Set; Kind : Callback_Kind) return Boolean is
     (case Kind is
         when Key_Kind             => Value.Key /= null,
         when Character_Kind       => Value.Character /= null,
         when Mouse_Button_Kind    => Value.Mouse_Button /= null,
         when Cursor_Position_Kind => Value.Cursor_Position /= null,
         when Scroll_Kind          => Value.Scroll /= null,
         when Focus_Kind           => Value.Focus /= null);

   protected type Mutation_Barrier is
      procedure Close;
      procedure Open;
      entry Wait_Until_Open;
   private
      Is_Open : Boolean := True;
   end Mutation_Barrier;

   protected body Mutation_Barrier is
      procedure Close is
      begin
         Is_Open := False;
      end Close;

      procedure Open is
      begin
         Is_Open := True;
      end Open;

      entry Wait_Until_Open when Is_Open is
      begin
         null;
      end Wait_Until_Open;
   end Mutation_Barrier;

   type Window_Callbacks;
   type Window_Callbacks_Access is access Window_Callbacks;
   type Window_Callbacks is limited record
      Window          : Raw.GLFW_Window_Handle := Raw.Null_Window;
      Values          : Input.Callback_Set;
      Updating        : Boolean := False;
      Removing        : Boolean := False;
      Retired         : Boolean := False;
      Retirement_Held : Boolean := False;
      Active_Dispatches : Natural := 0;
      Waiting_Dispatches : Natural := 0;
      Permitted_Dispatches : Natural := 0;
      Generation      : Interfaces.Unsigned_64 := 0;
      Binding_Owner   : Interfaces.Unsigned_64 := 0;
      Quiescent : Mutation_Barrier;
      Mutation_Complete : Mutation_Barrier;
      Next            : Window_Callbacks_Access := null;
   end record;

   type Dispatch_Hold_Kind is
     (No_Dispatch_Hold,
      Waiting_Dispatch_Hold,
      Active_Dispatch_Hold);

   --  Limited makes the holder a by-reference parameter.  A protected
   --  acquisition therefore publishes its cleanup state before a deferred
   --  task abort can resume at the call boundary.
   type Dispatch_Hold is limited record
      Token : Window_Callbacks_Access := null;
      Kind  : Dispatch_Hold_Kind := No_Dispatch_Hold;
   end record;

   procedure Free_Window_Callbacks is new Ada.Unchecked_Deallocation
     (Window_Callbacks, Window_Callbacks_Access);

   subtype Callback_Bucket_Index is Natural range 0 .. 63;
   type Callback_Bucket_Array is
     array (Callback_Bucket_Index) of Window_Callbacks_Access;

   function Bucket_For
     (Window : Raw.GLFW_Window_Handle) return Callback_Bucket_Index
   is
      Address : constant Interfaces.Unsigned_64 :=
        Interfaces.Unsigned_64
          (System.Storage_Elements.To_Integer (System.Address (Window)));
      --  Window pointers are aligned, so their low bits contain no entropy.
      --  Fold higher bits before reducing to the fixed bucket count.
      Mixed : constant Interfaces.Unsigned_64 :=
        Address
        xor Interfaces.Shift_Right (Address, 4)
        xor Interfaces.Shift_Right (Address, 17)
        xor Interfaces.Shift_Right (Address, 33);
   begin
      return Callback_Bucket_Index
        (Mixed mod Interfaces.Unsigned_64 (Callback_Bucket_Index'Last + 1));
   end Bucket_For;

   protected type Callback_Registry is
      procedure Set
        (Window : Raw.GLFW_Window_Handle;
         Generation : Interfaces.Unsigned_64;
         Binding_Owner : Interfaces.Unsigned_64;
         Kind   : Callback_Kind;
         Value  : Input.Callback_Set);
      procedure Claim_Binding
        (Window     : Raw.GLFW_Window_Handle;
         Generation : Interfaces.Unsigned_64;
         Owner      : out Interfaces.Unsigned_64;
         Previous   : out Input.Callback_Set);
      procedure Authorize_Binding
        (Window     : Raw.GLFW_Window_Handle;
         Generation : Interfaces.Unsigned_64;
         Owner      : Interfaces.Unsigned_64);
      procedure Release_Binding
        (Window     : Raw.GLFW_Window_Handle;
         Generation : Interfaces.Unsigned_64;
         Owner      : Interfaces.Unsigned_64);
      procedure Acquire
        (Window : Raw.GLFW_Window_Handle;
         Kind   : Callback_Kind;
         Value  : out Input.Callback_Set;
         Hold   : in out Dispatch_Hold);
      procedure End_Wait (Token : in out Window_Callbacks_Access);
      procedure Resume_Wait
        (Hold    : in out Dispatch_Hold;
         Kind    : Callback_Kind;
         Value   : out Input.Callback_Set;
         Retired : out Boolean);
      procedure End_Retirement (Token : in out Window_Callbacks_Access);
      procedure End_Dispatch (Token : in out Window_Callbacks_Access);
      procedure Try_Begin_Update
        (Window : Raw.GLFW_Window_Handle; Permitted_Active : Natural;
         Started : out Boolean;
         Generation : out Interfaces.Unsigned_64);
      procedure Try_Begin_Remove
        (Window : Raw.GLFW_Window_Handle; Permitted_Active : Natural;
         Started : out Boolean;
         Generation : out Interfaces.Unsigned_64);
      function Mutation_Item
        (Window : Raw.GLFW_Window_Handle;
         Generation : Interfaces.Unsigned_64) return Window_Callbacks_Access;
      procedure Finish_Mutation
        (Window : Raw.GLFW_Window_Handle; Generation : Interfaces.Unsigned_64);
      procedure Remove
        (Window : Raw.GLFW_Window_Handle; Generation : Interfaces.Unsigned_64);
      procedure Retire
        (Window           : Raw.GLFW_Window_Handle;
         Permitted_Active : Natural;
         Token            : out Window_Callbacks_Access);
      function Waiting_Dispatch_Count
        (Window : Raw.GLFW_Window_Handle) return Natural;
      function Retirement_In_Progress
        (Window : Raw.GLFW_Window_Handle) return Boolean;
   private
      Heads : Callback_Bucket_Array := (others => null);
      Retired_Heads : Callback_Bucket_Array := (others => null);
      Next_Generation : Interfaces.Unsigned_64 := 1;
      Next_Binding_Owner : Interfaces.Unsigned_64 := 1;
   end Callback_Registry;

   protected body Callback_Registry is separate;

   Registry : Callback_Registry;

   type Retirement_Guard is
     new Ada.Finalization.Limited_Controlled with record
      Token : Window_Callbacks_Access := null;
   end record;
   overriding procedure Finalize (Guard : in out Retirement_Guard);

   overriding procedure Finalize (Guard : in out Retirement_Guard) is
   begin
      if Guard.Token /= null then
         Registry.End_Retirement (Guard.Token);
      end if;
   exception
      when E : others =>
         Failure_Log.Note_Infrastructure
           (Input.Registry_Infrastructure_Failure,
            Ada.Exceptions.Exception_Name (E));
         Guard.Token := null;
   end Finalize;

   package Dispatching is
      procedure Dispatch_Key
        (Window : Raw.GLFW_Window_Handle; Event : Input.Key_Event);
      procedure Dispatch_Character
        (Window : Raw.GLFW_Window_Handle; Event : Input.Character_Event);
      procedure Dispatch_Mouse_Button
        (Window : Raw.GLFW_Window_Handle;
         Event : Input.Mouse_Button_Event;
         Read_Cursor : not null access procedure (X, Y : out Float));
      procedure Dispatch_Cursor_Position
        (Window : Raw.GLFW_Window_Handle;
         Event : Input.Cursor_Position_Event);
      procedure Dispatch_Scroll
        (Window : Raw.GLFW_Window_Handle;
         Event : Input.Scroll_Event;
         Read_Cursor : not null access procedure (X, Y : out Float));
      procedure Dispatch_Focus
        (Window : Raw.GLFW_Window_Handle; Event : Input.Focus_Event);
   end Dispatching;
   package body Dispatching is separate;

   type Mutation_Kind is (Update_Mutation, Remove_Mutation);

   procedure Begin_Mutation
     (Guard  : in out Mutation_Guard;
      Window : Raw.GLFW_Window_Handle;
      Kind   : Mutation_Kind)
   is
      Depth : constant Natural := Dispatch_Context.Depth_For (Window);
      Started : Boolean := False;
      Item : Window_Callbacks_Access;
   begin
      if Guard.Active then
         raise Program_Error with "callback mutation guard is already active";
      end if;
      case Kind is
         when Update_Mutation =>
            Registry.Try_Begin_Update
              (Window,
               (if Dispatch_Context.Active then Depth else 0),
               Started,
               Guard.Generation);
         when Remove_Mutation =>
            Registry.Try_Begin_Remove
              (Window,
               (if Dispatch_Context.Active then Depth else 0),
               Started,
               Guard.Generation);
      end case;
      if not Started then
         raise Program_Error with
           "callback registry mutation already in progress for this window";
      end if;
      Guard.Active := True;
      Guard.Window := Window;
      Item := Registry.Mutation_Item (Window, Guard.Generation);
      if Item = null then
         begin
            Registry.Finish_Mutation (Guard.Window, Guard.Generation);
         exception
            when E : others =>
               Failure_Log.Note_Infrastructure
                 (Input.Registry_Infrastructure_Failure,
                  Ada.Exceptions.Exception_Name (E));
         end;
         Guard.Active := False;
         Guard.Window := Raw.Null_Window;
         Guard.Generation := 0;
         Guard.Binding_Owner := 0;
         raise Program_Error with
           "callback registry lost an active mutation item";
      end if;
      Item.Quiescent.Wait_Until_Open;
   end Begin_Mutation;

   procedure Begin_Update
     (Guard : in out Mutation_Guard; Window : Raw.GLFW_Window_Handle) is
   begin
      Begin_Mutation (Guard, Window, Update_Mutation);
   end Begin_Update;

   procedure Begin_Remove
     (Guard : in out Mutation_Guard; Window : Raw.GLFW_Window_Handle)
   is
   begin
      Begin_Mutation (Guard, Window, Remove_Mutation);
   end Begin_Remove;

   overriding procedure Finalize (Guard : in out Mutation_Guard) is
   begin
      if Guard.Active then
         begin
            Registry.Finish_Mutation (Guard.Window, Guard.Generation);
         exception
            when E : others =>
               Failure_Log.Note_Infrastructure
                 (Input.Registry_Infrastructure_Failure,
                  Ada.Exceptions.Exception_Name (E));
         end;
         Guard.Active := False;
         Guard.Window := Raw.Null_Window;
         Guard.Generation := 0;
         Guard.Binding_Owner := 0;
      end if;
   end Finalize;

   procedure Set_Value
     (Guard : in out Mutation_Guard;
      Kind  : Callback_Kind;
      Value : Input.Callback_Set) is
   begin
      if not Guard.Active then
         raise Program_Error with "callback mutation guard is not active";
      end if;
      Registry.Set
        (Guard.Window, Guard.Generation, Guard.Binding_Owner, Kind, Value);
   end Set_Value;

   procedure Set_Key
     (Guard  : in out Mutation_Guard;
      Value  : Input.Key_Callback)
   is
   begin
      Set_Value (Guard, Key_Kind, (Key => Value, others => <>));
   end Set_Key;

   procedure Set_Character
     (Guard  : in out Mutation_Guard;
      Value  : Input.Character_Callback)
   is
   begin
      Set_Value (Guard, Character_Kind, (Character => Value, others => <>));
   end Set_Character;

   procedure Set_Mouse_Button
     (Guard  : in out Mutation_Guard;
      Value  : Input.Mouse_Button_Callback)
   is
   begin
      Set_Value
        (Guard, Mouse_Button_Kind, (Mouse_Button => Value, others => <>));
   end Set_Mouse_Button;

   procedure Set_Cursor_Position
     (Guard  : in out Mutation_Guard;
      Value  : Input.Cursor_Position_Callback)
   is
   begin
      Set_Value
        (Guard, Cursor_Position_Kind,
         (Cursor_Position => Value, others => <>));
   end Set_Cursor_Position;

   procedure Set_Scroll
     (Guard  : in out Mutation_Guard;
      Value  : Input.Scroll_Callback)
   is
   begin
      Set_Value (Guard, Scroll_Kind, (Scroll => Value, others => <>));
   end Set_Scroll;

   procedure Set_Focus
     (Guard  : in out Mutation_Guard;
      Value  : Input.Focus_Callback)
   is
   begin
      Set_Value (Guard, Focus_Kind, (Focus => Value, others => <>));
   end Set_Focus;

   procedure Claim_Binding
     (Guard    : in out Mutation_Guard;
      Owner    : out Interfaces.Unsigned_64;
      Previous : out Input.Callback_Set) is
   begin
      if not Guard.Active then
         raise Program_Error with "callback mutation guard is not active";
      end if;
      Registry.Claim_Binding
        (Guard.Window, Guard.Generation, Owner, Previous);
      Guard.Binding_Owner := Owner;
   end Claim_Binding;

   procedure Authorize_Binding
     (Guard : in out Mutation_Guard;
      Owner : Interfaces.Unsigned_64) is
   begin
      if not Guard.Active then
         raise Program_Error with "callback mutation guard is not active";
      end if;
      Registry.Authorize_Binding (Guard.Window, Guard.Generation, Owner);
      Guard.Binding_Owner := Owner;
   end Authorize_Binding;

   procedure Release_Binding
     (Guard : in out Mutation_Guard;
      Owner : Interfaces.Unsigned_64) is
   begin
      if not Guard.Active then
         raise Program_Error with "callback mutation guard is not active";
      end if;
      Registry.Release_Binding (Guard.Window, Guard.Generation, Owner);
      Guard.Binding_Owner := 0;
   end Release_Binding;

   procedure Remove (Guard : in out Mutation_Guard) is
   begin
      if not Guard.Active then
         raise Program_Error with "callback removal guard is not active";
      end if;
      Registry.Remove (Guard.Window, Guard.Generation);
   end Remove;

   procedure Retire (Window : Raw.GLFW_Window_Handle) is
      Guard : Retirement_Guard;
      Depth : constant Natural := Dispatch_Context.Depth_For (Window);
   begin
      if Window /= Raw.Null_Window then
         Registry.Retire
           (Window,
            (if Dispatch_Context.Active then Depth else 0),
            Guard.Token);
         if Guard.Token /= null then
            Guard.Token.Quiescent.Wait_Until_Open;
            Guard.Token.Mutation_Complete.Wait_Until_Open;
            Registry.End_Retirement (Guard.Token);
         end if;
      end if;
   end Retire;

   function Waiting_Dispatch_Count
     (Window : Raw.GLFW_Window_Handle) return Natural is
     (Registry.Waiting_Dispatch_Count (Window));

   function Retirement_In_Progress
     (Window : Raw.GLFW_Window_Handle) return Boolean is
     (Registry.Retirement_In_Progress (Window));

   procedure Dispatch_Key
     (Window : Raw.GLFW_Window_Handle; Event : Input.Key_Event)
      renames Dispatching.Dispatch_Key;
   procedure Dispatch_Character
     (Window : Raw.GLFW_Window_Handle; Event : Input.Character_Event)
      renames Dispatching.Dispatch_Character;
   procedure Dispatch_Mouse_Button
     (Window : Raw.GLFW_Window_Handle;
      Event : Input.Mouse_Button_Event;
      Read_Cursor : not null access procedure (X, Y : out Float))
      renames Dispatching.Dispatch_Mouse_Button;
   procedure Dispatch_Cursor_Position
     (Window : Raw.GLFW_Window_Handle; Event : Input.Cursor_Position_Event)
      renames Dispatching.Dispatch_Cursor_Position;
   procedure Dispatch_Scroll
     (Window : Raw.GLFW_Window_Handle;
      Event : Input.Scroll_Event;
      Read_Cursor : not null access procedure (X, Y : out Float))
      renames Dispatching.Dispatch_Scroll;
   procedure Dispatch_Focus
     (Window : Raw.GLFW_Window_Handle; Event : Input.Focus_Event)
      renames Dispatching.Dispatch_Focus;

   procedure Note_Callback_Failure
     (Source         : Input.Failure_Source;
      Exception_Name : String) is
   begin
      Failure_Log.Note_Callback (Source, Exception_Name);
   end Note_Callback_Failure;

   procedure Note_Infrastructure_Failure
     (Source         : Input.Failure_Source;
      Exception_Name : String) is
   begin
      Failure_Log.Note_Infrastructure (Source, Exception_Name);
   end Note_Infrastructure_Failure;

   procedure Reset_Callback_Failures is
   begin
      Failure_Log.Reset_Callbacks;
   end Reset_Callback_Failures;

   procedure Reset_Infrastructure_Failures is
   begin
      Failure_Log.Reset_Infrastructure;
   end Reset_Infrastructure_Failures;

   function Failures return Input.Failure_Snapshot is (Failure_Log.Snapshot);
end GLFW_Vulkan.Input_Registry;
