separate (GLFW_Vulkan.Input_Registry)
protected body Callback_Registry is
   function Find
     (Window : Raw.GLFW_Window_Handle) return Window_Callbacks_Access
   is
      Item : Window_Callbacks_Access := Heads (Bucket_For (Window));
   begin
      while Item /= null loop
         if Item.Window = Window then
            return Item;
         end if;
         Item := Item.Next;
      end loop;
      return null;
   end Find;

   function Find_Exact
     (Window : Raw.GLFW_Window_Handle;
      Generation : Interfaces.Unsigned_64) return Window_Callbacks_Access
   is
      Item : Window_Callbacks_Access := Find (Window);
   begin
      if Item /= null and then Item.Generation = Generation then
         return Item;
      end if;
      Item := Retired_Heads (Bucket_For (Window));
      while Item /= null loop
         if Item.Window = Window and then Item.Generation = Generation then
            return Item;
         end if;
         Item := Item.Next;
      end loop;
      return null;
   end Find_Exact;

   procedure Free_If_Unreferenced (Item : in out Window_Callbacks_Access) is
      Bucket : Callback_Bucket_Index;
      Previous : Window_Callbacks_Access := null;
      Current : Window_Callbacks_Access;
   begin
      if Item = null
        or else not Item.Retired
        or else Item.Active_Dispatches /= 0
        or else Item.Waiting_Dispatches /= 0
        or else Item.Retirement_Held
        or else Item.Updating
        or else Item.Removing
      then
         return;
      end if;
      Bucket := Bucket_For (Item.Window);
      Current := Retired_Heads (Bucket);
      while Current /= null and then Current /= Item loop
         Previous := Current;
         Current := Current.Next;
      end loop;
      if Current = null then
         raise Program_Error with "retired callback entry is not registered";
      elsif Previous = null then
         Retired_Heads (Bucket) := Current.Next;
      else
         Previous.Next := Current.Next;
      end if;
      Item.Next := null;
      Free_Window_Callbacks (Item);
   end Free_If_Unreferenced;

   procedure Ensure
     (Window : Raw.GLFW_Window_Handle; Item : out Window_Callbacks_Access) is
   begin
      if Window = Raw.Null_Window then
         raise Constraint_Error with "cannot register callbacks for a null window";
      end if;
      Item := Find (Window);
      if Item = null then
         Item := new Window_Callbacks'(Window => Window, others => <>);
         Item.Generation := Next_Generation;
         Next_Generation := Next_Generation + 1;
         if Next_Generation = 0 then
            Next_Generation := 1;
         end if;
         Item.Quiescent.Open;
         Item.Next := Heads (Bucket_For (Window));
         Heads (Bucket_For (Window)) := Item;
      end if;
   end Ensure;

   procedure Set
     (Window : Raw.GLFW_Window_Handle;
      Generation : Interfaces.Unsigned_64;
      Binding_Owner : Interfaces.Unsigned_64;
      Kind   : Callback_Kind;
      Value  : Input.Callback_Set)
   is
      Item : constant Window_Callbacks_Access := Find (Window);
   begin
      if Item = null
        or else Item.Generation /= Generation
        or else not Item.Updating
        or else Item.Binding_Owner /= Binding_Owner
      then
         raise Program_Error with
           "callback update requires an active mutation transaction";
      end if;
      case Kind is
         when Key_Kind             => Item.Values.Key := Value.Key;
         when Character_Kind       => Item.Values.Character := Value.Character;
         when Mouse_Button_Kind    => Item.Values.Mouse_Button := Value.Mouse_Button;
         when Cursor_Position_Kind =>
            Item.Values.Cursor_Position := Value.Cursor_Position;
         when Scroll_Kind          => Item.Values.Scroll := Value.Scroll;
         when Focus_Kind           => Item.Values.Focus := Value.Focus;
      end case;
   end Set;

   procedure Claim_Binding
     (Window     : Raw.GLFW_Window_Handle;
      Generation : Interfaces.Unsigned_64;
      Owner      : out Interfaces.Unsigned_64;
      Previous   : out Input.Callback_Set)
   is
      Item : constant Window_Callbacks_Access := Find (Window);
   begin
      Owner := 0;
      Previous := (others => <>);
      if Item = null
        or else Item.Generation /= Generation
        or else not Item.Updating
      then
         raise Program_Error with
           "callback binding claim requires an active update transaction";
      elsif Item.Binding_Owner /= 0 then
         raise Program_Error with "window callbacks already have an owner";
      end if;
      Owner := Next_Binding_Owner;
      Next_Binding_Owner := Next_Binding_Owner + 1;
      if Next_Binding_Owner = 0 then
         Next_Binding_Owner := 1;
      end if;
      Item.Binding_Owner := Owner;
      Previous := Item.Values;
   end Claim_Binding;

   procedure Authorize_Binding
     (Window     : Raw.GLFW_Window_Handle;
      Generation : Interfaces.Unsigned_64;
      Owner      : Interfaces.Unsigned_64)
   is
      Item : constant Window_Callbacks_Access := Find (Window);
   begin
      if Owner = 0
        or else Item = null
        or else Item.Generation /= Generation
        or else not Item.Updating
        or else Item.Binding_Owner /= Owner
      then
         raise Program_Error with "callback binding owner is stale";
      end if;
   end Authorize_Binding;

   procedure Release_Binding
     (Window     : Raw.GLFW_Window_Handle;
      Generation : Interfaces.Unsigned_64;
      Owner      : Interfaces.Unsigned_64)
   is
      Item : constant Window_Callbacks_Access := Find (Window);
   begin
      if Owner = 0
        or else Item = null
        or else Item.Generation /= Generation
        or else not Item.Updating
        or else Item.Binding_Owner /= Owner
      then
         raise Program_Error with "callback binding owner is stale";
      end if;
      Item.Binding_Owner := 0;
   end Release_Binding;

   procedure Acquire
     (Window : Raw.GLFW_Window_Handle;
      Kind   : Callback_Kind;
      Value  : out Input.Callback_Set;
      Hold   : in out Dispatch_Hold)
   is
      Item : constant Window_Callbacks_Access := Find (Window);
   begin
      Hold.Token := null;
      Hold.Kind := No_Dispatch_Hold;
      Value := (others => <>);
      if Item = null then
         return;
      elsif Item.Removing or else Item.Updating then
         if Item.Waiting_Dispatches = Natural'Last then
            raise Storage_Error with "callback waiter count overflow";
         end if;
         Item.Waiting_Dispatches := Item.Waiting_Dispatches + 1;
         Hold.Token := Item;
         Hold.Kind := Waiting_Dispatch_Hold;
         return;
      end if;
      case Kind is
         when Key_Kind             => Value.Key := Item.Values.Key;
         when Character_Kind       => Value.Character := Item.Values.Character;
         when Mouse_Button_Kind    => Value.Mouse_Button := Item.Values.Mouse_Button;
         when Cursor_Position_Kind =>
            Value.Cursor_Position := Item.Values.Cursor_Position;
         when Scroll_Kind          => Value.Scroll := Item.Values.Scroll;
         when Focus_Kind           => Value.Focus := Item.Values.Focus;
      end case;
      if Is_Set (Value, Kind) then
         if Item.Active_Dispatches = Natural'Last then
            raise Storage_Error with "callback dispatch count overflow";
         end if;
         Item.Active_Dispatches := Item.Active_Dispatches + 1;
         Hold.Token := Item;
         Hold.Kind := Active_Dispatch_Hold;
      end if;
   end Acquire;

   procedure End_Wait (Token : in out Window_Callbacks_Access) is
      Item : Window_Callbacks_Access := Token;
   begin
      Token := null;
      if Item = null then
         return;
      elsif Item.Waiting_Dispatches = 0 then
         raise Program_Error with "callback waiter count underflow";
      end if;
      Item.Waiting_Dispatches := Item.Waiting_Dispatches - 1;
      Free_If_Unreferenced (Item);
   end End_Wait;

   procedure Resume_Wait
     (Hold    : in out Dispatch_Hold;
      Kind    : Callback_Kind;
      Value   : out Input.Callback_Set;
      Retired : out Boolean)
   is
      Item : Window_Callbacks_Access := Hold.Token;
   begin
      Value := (others => <>);
      Retired := False;
      --  Preserve the caller's existing waiter ownership unless this
      --  operation explicitly consumes it below.  This also keeps cleanup
      --  correct if promotion raises before changing either counter.
      Hold.Kind := Waiting_Dispatch_Hold;
      if Item = null then
         Hold.Kind := No_Dispatch_Hold;
         return;
      elsif Item.Waiting_Dispatches = 0 then
         raise Program_Error with "callback waiter count underflow";
      elsif Item.Retired then
         Item.Waiting_Dispatches := Item.Waiting_Dispatches - 1;
         Hold.Token := null;
         Retired := True;
         Hold.Kind := No_Dispatch_Hold;
         Free_If_Unreferenced (Item);
         return;
      elsif Item.Removing or else Item.Updating then
         --  A second mutation began after the suspension object woke. Keep the
         --  same generation pinned and wait for that mutation as well.
         Hold.Kind := Waiting_Dispatch_Hold;
         return;
      end if;

      --  Convert the waiter hold directly into a dispatch hold while the
      --  registry is locked. Retirement and native-address reuse cannot occur
      --  between observing this generation and acquiring its callback.
      case Kind is
         when Key_Kind             => Value.Key := Item.Values.Key;
         when Character_Kind       => Value.Character := Item.Values.Character;
         when Mouse_Button_Kind    => Value.Mouse_Button := Item.Values.Mouse_Button;
         when Cursor_Position_Kind =>
            Value.Cursor_Position := Item.Values.Cursor_Position;
         when Scroll_Kind          => Value.Scroll := Item.Values.Scroll;
         when Focus_Kind           => Value.Focus := Item.Values.Focus;
      end case;
      if Is_Set (Value, Kind) then
         if Item.Active_Dispatches = Natural'Last then
            --  Leave the waiter hold intact so the caller's controlled guard
            --  can release it while propagating the exception.
            raise Storage_Error with "callback dispatch count overflow";
         end if;
         Item.Waiting_Dispatches := Item.Waiting_Dispatches - 1;
         Item.Active_Dispatches := Item.Active_Dispatches + 1;
         Hold.Kind := Active_Dispatch_Hold;
      else
         Item.Waiting_Dispatches := Item.Waiting_Dispatches - 1;
         Hold.Token := null;
         Hold.Kind := No_Dispatch_Hold;
      end if;
   end Resume_Wait;

   procedure End_Retirement (Token : in out Window_Callbacks_Access) is
      Item : Window_Callbacks_Access := Token;
   begin
      Token := null;
      if Item = null then
         return;
      elsif not Item.Retirement_Held then
         raise Program_Error with "callback retirement hold is not active";
      end if;
      Item.Retirement_Held := False;
      Free_If_Unreferenced (Item);
   end End_Retirement;

   procedure End_Dispatch (Token : in out Window_Callbacks_Access) is
      Item : Window_Callbacks_Access := Token;
   begin
      Token := null;
      if Item = null then
         return;
      elsif Item.Active_Dispatches = 0 then
         raise Program_Error with "callback dispatch count underflow";
      end if;
      Item.Active_Dispatches := Item.Active_Dispatches - 1;
      if (Item.Updating or else Item.Removing or else Item.Retired)
        and then Item.Active_Dispatches <= Item.Permitted_Dispatches
      then
         Item.Quiescent.Open;
      end if;
      Free_If_Unreferenced (Item);
   end End_Dispatch;

   procedure Try_Begin_Remove
     (Window : Raw.GLFW_Window_Handle; Permitted_Active : Natural;
      Started : out Boolean;
      Generation : out Interfaces.Unsigned_64)
   is
      Item : Window_Callbacks_Access;
   begin
      Generation := 0;
      Ensure (Window, Item);
      if Item.Updating
        or else Item.Removing
        or else Item.Binding_Owner /= 0
      then
         Started := False;
         return;
      end if;
      Item.Removing := True;
      Item.Permitted_Dispatches := Permitted_Active;
      Item.Quiescent.Close;
      Item.Mutation_Complete.Close;
      if Item.Active_Dispatches <= Permitted_Active then
         Item.Quiescent.Open;
      end if;
      Generation := Item.Generation;
      Started := True;
   end Try_Begin_Remove;

   procedure Try_Begin_Update
     (Window : Raw.GLFW_Window_Handle; Permitted_Active : Natural;
      Started : out Boolean;
      Generation : out Interfaces.Unsigned_64) is
      Item : Window_Callbacks_Access;
   begin
      Generation := 0;
      if Window = Raw.Null_Window then
         raise Constraint_Error with "cannot register callbacks for a null window";
      end if;
      Ensure (Window, Item);
      if Item.Updating or else Item.Removing then
         Started := False;
         return;
      end if;
      Item.Updating := True;
      Item.Permitted_Dispatches := Permitted_Active;
      Item.Quiescent.Close;
      Item.Mutation_Complete.Close;
      if Item.Active_Dispatches <= Permitted_Active then
         Item.Quiescent.Open;
      end if;
      Generation := Item.Generation;
      Started := True;
   end Try_Begin_Update;

   function Mutation_Item
     (Window : Raw.GLFW_Window_Handle;
      Generation : Interfaces.Unsigned_64) return Window_Callbacks_Access is
   begin
      return Find_Exact (Window, Generation);
   end Mutation_Item;

   procedure Finish_Mutation
     (Window : Raw.GLFW_Window_Handle; Generation : Interfaces.Unsigned_64)
   is
      Item : Window_Callbacks_Access := Find_Exact (Window, Generation);
   begin
      if Item /= null then
         Item.Updating := False;
         --  A remove transaction that unwinds before Remove is called must
         --  restore the entry.  Otherwise every later registration finds
         --  an entry that remains permanently undispatchable.
         Item.Removing := False;
         Item.Permitted_Dispatches := 0;
         Item.Quiescent.Open;
         Item.Mutation_Complete.Open;
         Free_If_Unreferenced (Item);
      end if;
   end Finish_Mutation;

   function Waiting_Dispatch_Count
     (Window : Raw.GLFW_Window_Handle) return Natural
   is
      Item : constant Window_Callbacks_Access := Find (Window);
   begin
      return (if Item = null then 0 else Item.Waiting_Dispatches);
   end Waiting_Dispatch_Count;

   function Retirement_In_Progress
     (Window : Raw.GLFW_Window_Handle) return Boolean
   is
      Item : Window_Callbacks_Access := Retired_Heads (Bucket_For (Window));
   begin
      while Item /= null loop
         if Item.Window = Window and then Item.Retirement_Held then
            return True;
         end if;
         Item := Item.Next;
      end loop;
      return False;
   end Retirement_In_Progress;
   procedure Remove
     (Window : Raw.GLFW_Window_Handle; Generation : Interfaces.Unsigned_64)
   is
      Previous : Window_Callbacks_Access := null;
      Bucket : constant Callback_Bucket_Index := Bucket_For (Window);
      Item : Window_Callbacks_Access := Heads (Bucket);
   begin
      while Item /= null loop
         if Item.Window = Window and then Item.Generation = Generation then
            if not Item.Removing then
               raise Program_Error with
                 "callback removal requires an active remove transaction";
            end if;
            if Previous = null then
               Heads (Bucket) := Item.Next;
            else
               Previous.Next := Item.Next;
            end if;
            Item.Retired := True;
            Item.Next := Retired_Heads (Bucket);
            Retired_Heads (Bucket) := Item;
            return;
         end if;
         Previous := Item;
         Item := Item.Next;
      end loop;
   end Remove;

   procedure Retire
     (Window           : Raw.GLFW_Window_Handle;
      Permitted_Active : Natural;
      Token            : out Window_Callbacks_Access)
   is
      Previous : Window_Callbacks_Access := null;
      Bucket : constant Callback_Bucket_Index := Bucket_For (Window);
      Item : Window_Callbacks_Access := Heads (Bucket);
   begin
      Token := null;
      while Item /= null and then Item.Window /= Window loop
         Previous := Item;
         Item := Item.Next;
      end loop;
      if Item = null then
         return;
      elsif Previous = null then
         Heads (Bucket) := Item.Next;
      else
         Previous.Next := Item.Next;
      end if;

      --  Existing dispatch tokens keep this retired entry alive.  Waiters are
      --  released and discard the event belonging to this retired generation.
      Item.Values.Key := null;
      Item.Values.Character := null;
      Item.Values.Mouse_Button := null;
      Item.Values.Cursor_Position := null;
      Item.Values.Scroll := null;
      Item.Values.Focus := null;
      Item.Permitted_Dispatches := Permitted_Active;
      Item.Retired := True;
      Item.Retirement_Held := True;
      Token := Item;
      Item.Quiescent.Close;
      if Item.Active_Dispatches <= Permitted_Active then
         Item.Quiescent.Open;
      end if;
      --  Do not release an active mutation here.  The retiring window must
      --  remain alive until its mutation guard reaches Finish_Mutation; that
      --  guard may still be about to call a native callback setter with this
      --  window handle.
      Item.Next := Retired_Heads (Bucket);
      Retired_Heads (Bucket) := Item;
   end Retire;
end Callback_Registry;
