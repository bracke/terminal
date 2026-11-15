separate (GLFW_Vulkan.Input_Registry)
package body Dispatching is
   type Dispatch_Guard is
     new Ada.Finalization.Limited_Controlled with record
      Entered  : Boolean := False;
      Window   : Raw.GLFW_Window_Handle := Raw.Null_Window;
      Hold     : Dispatch_Hold;
   end record;
   overriding procedure Finalize (Guard : in out Dispatch_Guard);

   procedure Enter (Guard : in out Dispatch_Guard) is
   begin
      if Guard.Hold.Kind /= Active_Dispatch_Hold
        or else Guard.Hold.Token = null
      then
         raise Program_Error with "callback dispatch token is missing";
      end if;
      Dispatch_Context.Enter (Guard.Window);
      Guard.Entered := True;
   end Enter;
   overriding procedure Finalize (Guard : in out Dispatch_Guard) is
   begin
      if Guard.Entered then
         begin
            Dispatch_Context.Leave;
         exception
            when E : others =>
               Failure_Log.Note_Infrastructure
                 (Input.Registry_Infrastructure_Failure,
                  Ada.Exceptions.Exception_Name (E));
         end;
         Guard.Entered := False;
      end if;
      if Guard.Hold.Kind /= No_Dispatch_Hold then
         begin
            case Guard.Hold.Kind is
               when Waiting_Dispatch_Hold =>
                  Registry.End_Wait (Guard.Hold.Token);
               when Active_Dispatch_Hold =>
                  Registry.End_Dispatch (Guard.Hold.Token);
               when No_Dispatch_Hold =>
                  null;
            end case;
         exception
            when E : others =>
               Failure_Log.Note_Infrastructure
                 (Input.Registry_Infrastructure_Failure,
                  Ada.Exceptions.Exception_Name (E));
         end;
         Guard.Hold.Kind := No_Dispatch_Hold;
         Guard.Window := Raw.Null_Window;
         Guard.Hold.Token := null;
      end if;
   end Finalize;

   procedure Acquire_Blocking
     (Window : Raw.GLFW_Window_Handle;
      Kind   : Callback_Kind;
      Value  : out Input.Callback_Set;
      Guard  : in out Dispatch_Guard)
   is
      Was_Retired : Boolean;
   begin
      Guard.Window := Window;
      Registry.Acquire (Window, Kind, Value, Guard.Hold);
      while Guard.Hold.Kind = Waiting_Dispatch_Hold loop
         Was_Retired := False;
         Guard.Hold.Token.Mutation_Complete.Wait_Until_Open;
         Registry.Resume_Wait
           (Guard.Hold, Kind, Value, Was_Retired);
         if Was_Retired then
            --  The event belongs to the retired native-window generation.
            --  Never retry it against a newly allocated window at the same
            --  address.
            Value := (others => <>);
            return;
         end if;
      end loop;
      if Guard.Hold.Kind = No_Dispatch_Hold then
         Guard.Window := Raw.Null_Window;
      end if;
   end Acquire_Blocking;

   generic
      type Event_Type is private;
      Kind : Callback_Kind;
      with procedure Invoke (Value : Input.Callback_Set; Event : Event_Type);
   procedure Dispatch_Event
     (Window : Raw.GLFW_Window_Handle;
      Event  : Event_Type);

   procedure Dispatch_Event
     (Window : Raw.GLFW_Window_Handle;
      Event  : Event_Type)
   is
      Value : Input.Callback_Set;
      Guard : Dispatch_Guard;
   begin
      Acquire_Blocking (Window, Kind, Value, Guard);
      if Is_Set (Value, Kind) then
         Enter (Guard);
         begin
            Invoke (Value, Event);
         exception
            when E : others =>
               Failure_Log.Note_Callback
                 (Failure_Source_For (Kind),
                  Ada.Exceptions.Exception_Name (E));
         end;
      end if;
   exception
      when E : others =>
         Failure_Log.Note_Infrastructure
           (Failure_Source_For (Kind), Ada.Exceptions.Exception_Name (E));
   end Dispatch_Event;

   procedure Invoke_Key
     (Value : Input.Callback_Set; Event : Input.Key_Event) is
   begin
      Value.Key.all (Event);
   end Invoke_Key;

   procedure Invoke_Character
     (Value : Input.Callback_Set; Event : Input.Character_Event) is
   begin
      Value.Character.all (Event);
   end Invoke_Character;

   procedure Invoke_Mouse_Button
     (Value : Input.Callback_Set; Event : Input.Mouse_Button_Event) is
   begin
      Value.Mouse_Button.all (Event);
   end Invoke_Mouse_Button;

   procedure Invoke_Cursor_Position
     (Value : Input.Callback_Set; Event : Input.Cursor_Position_Event) is
   begin
      Value.Cursor_Position.all (Event);
   end Invoke_Cursor_Position;

   procedure Invoke_Scroll
     (Value : Input.Callback_Set; Event : Input.Scroll_Event) is
   begin
      Value.Scroll.all (Event);
   end Invoke_Scroll;

   procedure Invoke_Focus
     (Value : Input.Callback_Set; Event : Input.Focus_Event) is
   begin
      Value.Focus.all (Event);
   end Invoke_Focus;

   procedure Dispatch_Key_Impl is new Dispatch_Event
     (Input.Key_Event, Key_Kind, Invoke_Key);
   procedure Dispatch_Character_Impl is new Dispatch_Event
     (Input.Character_Event, Character_Kind, Invoke_Character);
   procedure Dispatch_Cursor_Position_Impl is new Dispatch_Event
     (Input.Cursor_Position_Event,
      Cursor_Position_Kind,
      Invoke_Cursor_Position);
   procedure Dispatch_Focus_Impl is new Dispatch_Event
     (Input.Focus_Event, Focus_Kind, Invoke_Focus);

   procedure Dispatch_Key
     (Window : Raw.GLFW_Window_Handle; Event : Input.Key_Event) is
   begin
      Dispatch_Key_Impl (Window, Event);
   end Dispatch_Key;

   procedure Dispatch_Character
     (Window : Raw.GLFW_Window_Handle; Event : Input.Character_Event) is
   begin
      Dispatch_Character_Impl (Window, Event);
   end Dispatch_Character;

   procedure Dispatch_Mouse_Button
     (Window : Raw.GLFW_Window_Handle;
      Event : Input.Mouse_Button_Event;
      Read_Cursor : not null access procedure (X, Y : out Float))
   is
      Value : Input.Callback_Set;
      Guard : Dispatch_Guard;
      Enriched : Input.Mouse_Button_Event := Event;
   begin
      Acquire_Blocking (Window, Mouse_Button_Kind, Value, Guard);
      if Is_Set (Value, Mouse_Button_Kind) then
         Enter (Guard);
         Read_Cursor (Enriched.X, Enriched.Y);
         begin
            Invoke_Mouse_Button (Value, Enriched);
         exception
            when E : others =>
               Failure_Log.Note_Callback
                 (Input.Mouse_Button_Callback_Failure,
                  Ada.Exceptions.Exception_Name (E));
         end;
      end if;
   exception
      when E : others =>
         Failure_Log.Note_Infrastructure
           (Input.Mouse_Button_Callback_Failure,
            Ada.Exceptions.Exception_Name (E));
   end Dispatch_Mouse_Button;

   procedure Dispatch_Cursor_Position
     (Window : Raw.GLFW_Window_Handle; Event : Input.Cursor_Position_Event) is
   begin
      Dispatch_Cursor_Position_Impl (Window, Event);
   end Dispatch_Cursor_Position;

   procedure Dispatch_Scroll
     (Window : Raw.GLFW_Window_Handle;
      Event : Input.Scroll_Event;
      Read_Cursor : not null access procedure (X, Y : out Float))
   is
      Value : Input.Callback_Set;
      Guard : Dispatch_Guard;
      Enriched : Input.Scroll_Event := Event;
   begin
      Acquire_Blocking (Window, Scroll_Kind, Value, Guard);
      if Is_Set (Value, Scroll_Kind) then
         Enter (Guard);
         Read_Cursor (Enriched.X, Enriched.Y);
         begin
            Invoke_Scroll (Value, Enriched);
         exception
            when E : others =>
               Failure_Log.Note_Callback
                 (Input.Scroll_Callback_Failure,
                  Ada.Exceptions.Exception_Name (E));
         end;
      end if;
   exception
      when E : others =>
         Failure_Log.Note_Infrastructure
           (Input.Scroll_Callback_Failure,
            Ada.Exceptions.Exception_Name (E));
   end Dispatch_Scroll;

   procedure Dispatch_Focus
     (Window : Raw.GLFW_Window_Handle; Event : Input.Focus_Event) is
   begin
      Dispatch_Focus_Impl (Window, Event);
   end Dispatch_Focus;

end Dispatching;
