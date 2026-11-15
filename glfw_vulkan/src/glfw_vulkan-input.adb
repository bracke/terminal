with Ada.Exceptions;
with Interfaces.C;
with GLFW_Vulkan.Input_Registry;
with GLFW_Vulkan.Raw;
with GLFW_Vulkan.Windows.Internal;

package body GLFW_Vulkan.Input is
   use type Interfaces.C.int;
   use type Interfaces.C.unsigned;
   use type GLFW_Vulkan.Raw.GLFW_Window_Handle;

   package Registry renames GLFW_Vulkan.Input_Registry;

   Native_Callbacks : Callback_Backend :=
     (Set_Key       => Raw.Set_Key_Callback_Owned'Access,
      Set_Character => Raw.Set_Char_Callback_Owned'Access,
      Set_Mouse     => Raw.Set_Mouse_Button_Callback_Owned'Access,
      Set_Cursor    => Raw.Set_Cursor_Pos_Callback_Owned'Access,
      Set_Scroll    => Raw.Set_Scroll_Callback_Owned'Access,
      Set_Focus     => Raw.Set_Window_Focus_Callback_Owned'Access);

   type Native_Change_Guard is
     new Ada.Finalization.Limited_Controlled with record
      Window : Raw.GLFW_Window_Handle := Raw.Null_Window;
      Previous : aliased Raw_Callback_Set;
      Installed : aliased Callback_Channel_Set := (others => 0);
      Committed : Boolean := False;
   end record;
   overriding procedure Finalize (Guard : in out Native_Change_Guard);

   procedure Configure_Callback_Backend (Value : Callback_Backend) is
   begin
      Native_Callbacks := Value;
   end Configure_Callback_Backend;

   procedure Reset_Callback_Backend is
   begin
      Native_Callbacks :=
        (Set_Key       => Raw.Set_Key_Callback_Owned'Access,
         Set_Character => Raw.Set_Char_Callback_Owned'Access,
         Set_Mouse     => Raw.Set_Mouse_Button_Callback_Owned'Access,
         Set_Cursor    => Raw.Set_Cursor_Pos_Callback_Owned'Access,
         Set_Scroll    => Raw.Set_Scroll_Callback_Owned'Access,
         Set_Focus     => Raw.Set_Window_Focus_Callback_Owned'Access);
   end Reset_Callback_Backend;

   function Has_Mod (Mods : Interfaces.C.int; Flag : Interfaces.C.int) return Boolean is
     (((Mods / Flag) mod 2) = 1);

   function To_Action (Action : Interfaces.C.int) return Key_Action is
   begin
      if Action = Raw.GLFW_PRESS then
         return Press;
      elsif Action = Raw.GLFW_REPEAT then
         return Repeat;
      else
         return Release;
      end if;
   end To_Action;

   function To_Key (Raw_Key : Interfaces.C.int) return Key is
   begin
      case Integer (Raw_Key) is
         when 257 => return Enter;
         when 258 => return Tab;
         when 259 => return Backspace;
         when 256 => return Escape;
         when 32  => return Space;
         when 39  => return Apostrophe;
         when 44  => return Comma;
         when 45  => return Minus;
         when 46  => return Period;
         when 47  => return Slash;
         when 59  => return Semicolon;
         when 61  => return Equal;
         when 91  => return Left_Bracket;
         when 92  => return Backslash;
         when 93  => return Right_Bracket;
         when 96  => return Grave_Accent;
         when 265 => return Up;
         when 264 => return Down;
         when 263 => return Left;
         when 262 => return Right;
         when 268 => return Home;
         when 269 => return End_Key;
         when 266 => return Page_Up;
         when 267 => return Page_Down;
         when 260 => return Insert;
         when 261 => return Delete;
         when 290 => return F1;
         when 291 => return F2;
         when 292 => return F3;
         when 293 => return F4;
         when 294 => return F5;
         when 295 => return F6;
         when 296 => return F7;
         when 297 => return F8;
         when 298 => return F9;
         when 299 => return F10;
         when 300 => return F11;
         when 301 => return F12;
         when 65  => return A;
         when 66  => return B;
         when 67  => return C;
         when 68  => return D;
         when 69  => return E;
         when 70  => return F;
         when 71  => return G;
         when 72  => return H;
         when 73  => return I;
         when 74  => return J;
         when 75  => return K;
         when 76  => return L;
         when 77  => return M;
         when 78  => return N;
         when 79  => return O;
         when 80  => return P;
         when 81  => return Q;
         when 82  => return R;
         when 83  => return S;
         when 84  => return T;
         when 85  => return U;
         when 86  => return V;
         when 87  => return W;
         when 88  => return X;
         when 89  => return Y;
         when 90  => return Z;
         when 48  => return Num_0;
         when 49  => return Num_1;
         when 50  => return Num_2;
         when 51  => return Num_3;
         when 52  => return Num_4;
         when 53  => return Num_5;
         when 54  => return Num_6;
         when 55  => return Num_7;
         when 56  => return Num_8;
         when 57  => return Num_9;
         when 320 => return Kp_0;
         when 321 => return Kp_1;
         when 322 => return Kp_2;
         when 323 => return Kp_3;
         when 324 => return Kp_4;
         when 325 => return Kp_5;
         when 326 => return Kp_6;
         when 327 => return Kp_7;
         when 328 => return Kp_8;
         when 329 => return Kp_9;
         when 330 => return Kp_Decimal;
         when 331 => return Kp_Divide;
         when 332 => return Kp_Multiply;
         when 333 => return Kp_Subtract;
         when 334 => return Kp_Add;
         when 335 => return Kp_Enter;
         when 336 => return Kp_Equal;
         when others => return Unknown;
      end case;
   end To_Key;

   function To_Mouse_Button (Button : Interfaces.C.int) return Mouse_Button is
   begin
      if Button = Raw.GLFW_MOUSE_BUTTON_LEFT then
         return Left;
      elsif Button = Raw.GLFW_MOUSE_BUTTON_RIGHT then
         return Right;
      elsif Button = Raw.GLFW_MOUSE_BUTTON_MIDDLE then
         return Middle;
      else
         return Other;
      end if;
   end To_Mouse_Button;

   procedure Dispatch_Key
     (Window   : Raw.GLFW_Window_Handle;
      Raw_Key  : Interfaces.C.int;
      Scancode : Interfaces.C.int;
      Action   : Interfaces.C.int;
      Mods     : Interfaces.C.int)
     with Convention => C;

   procedure Dispatch_Char
     (Window     : Raw.GLFW_Window_Handle;
      Code_Point : Interfaces.C.unsigned)
     with Convention => C;

   procedure Dispatch_Mouse_Button
     (Window : Raw.GLFW_Window_Handle;
      Button : Interfaces.C.int;
      Action : Interfaces.C.int;
      Mods   : Interfaces.C.int)
     with Convention => C;

   procedure Dispatch_Cursor_Position
     (Window : Raw.GLFW_Window_Handle;
      X_Pos  : Interfaces.C.double;
      Y_Pos  : Interfaces.C.double)
     with Convention => C;

   procedure Dispatch_Scroll
     (Window   : Raw.GLFW_Window_Handle;
      X_Offset : Interfaces.C.double;
      Y_Offset : Interfaces.C.double)
     with Convention => C;

   procedure Dispatch_Focus
     (Window  : Raw.GLFW_Window_Handle;
      Focused : Interfaces.C.int)
     with Convention => C;

   procedure Dispatch_Key
     (Window   : Raw.GLFW_Window_Handle;
      Raw_Key  : Interfaces.C.int;
      Scancode : Interfaces.C.int;
      Action   : Interfaces.C.int;
      Mods     : Interfaces.C.int)
   is
   begin
      declare
         Event : constant Key_Event :=
           (Key       => To_Key (Raw_Key),
            Raw_Key   => Integer (Raw_Key),
            Scancode  => Integer (Scancode),
            Action    => To_Action (Action),
            Modifiers =>
              (Shift   => Has_Mod (Mods, Raw.GLFW_MOD_SHIFT),
               Control => Has_Mod (Mods, Raw.GLFW_MOD_CONTROL),
               Alt     => Has_Mod (Mods, Raw.GLFW_MOD_ALT),
               Super   => Has_Mod (Mods, Raw.GLFW_MOD_SUPER)));
      begin
         Registry.Dispatch_Key (Window, Event);
      end;
   exception
      when E : others =>
         Registry.Note_Infrastructure_Failure
           (Key_Callback_Failure, Ada.Exceptions.Exception_Name (E));
   end Dispatch_Key;

   procedure Dispatch_Char
     (Window     : Raw.GLFW_Window_Handle;
      Code_Point : Interfaces.C.unsigned) is
   begin
      if Code_Point <=
        Interfaces.C.unsigned
          (Wide_Wide_Character'Pos (Wide_Wide_Character'Last))
      then
         Registry.Dispatch_Character
           (Window,
            (Code_Point =>
               Wide_Wide_Character'Val (Natural (Code_Point))));
      end if;
   exception
      when E : others =>
         Registry.Note_Infrastructure_Failure
           (Character_Callback_Failure, Ada.Exceptions.Exception_Name (E));
   end Dispatch_Char;

   procedure Dispatch_Mouse_Button
     (Window : Raw.GLFW_Window_Handle;
      Button : Interfaces.C.int;
      Action : Interfaces.C.int;
      Mods   : Interfaces.C.int)
   is
      procedure Read_Cursor (X, Y : out Float) is
         X_Pos : Interfaces.C.double := 0.0;
         Y_Pos : Interfaces.C.double := 0.0;
      begin
         Raw.Get_Cursor_Pos (Window, X_Pos, Y_Pos);
         X := Float (X_Pos);
         Y := Float (Y_Pos);
      end Read_Cursor;
   begin
      Registry.Dispatch_Mouse_Button
        (Window,
         (Button     => To_Mouse_Button (Button),
          Raw_Button => Integer (Button),
          Action     => To_Action (Action),
          Modifiers  =>
            (Shift   => Has_Mod (Mods, Raw.GLFW_MOD_SHIFT),
             Control => Has_Mod (Mods, Raw.GLFW_MOD_CONTROL),
             Alt     => Has_Mod (Mods, Raw.GLFW_MOD_ALT),
             Super   => Has_Mod (Mods, Raw.GLFW_MOD_SUPER)),
          X          => 0.0,
          Y          => 0.0),
         Read_Cursor'Access);
   exception
      when E : others =>
         Registry.Note_Infrastructure_Failure
           (Mouse_Button_Callback_Failure,
            Ada.Exceptions.Exception_Name (E));
   end Dispatch_Mouse_Button;

   procedure Dispatch_Cursor_Position
     (Window : Raw.GLFW_Window_Handle;
      X_Pos  : Interfaces.C.double;
      Y_Pos  : Interfaces.C.double) is
   begin
      Registry.Dispatch_Cursor_Position
        (Window, (X => Float (X_Pos), Y => Float (Y_Pos)));
   exception
      when E : others =>
         Registry.Note_Infrastructure_Failure
           (Cursor_Position_Callback_Failure,
            Ada.Exceptions.Exception_Name (E));
   end Dispatch_Cursor_Position;

   procedure Dispatch_Scroll
     (Window   : Raw.GLFW_Window_Handle;
      X_Offset : Interfaces.C.double;
      Y_Offset : Interfaces.C.double)
   is
      procedure Read_Cursor (X, Y : out Float) is
         X_Pos : Interfaces.C.double := 0.0;
         Y_Pos : Interfaces.C.double := 0.0;
      begin
         Raw.Get_Cursor_Pos (Window, X_Pos, Y_Pos);
         X := Float (X_Pos);
         Y := Float (Y_Pos);
      end Read_Cursor;
   begin
      Registry.Dispatch_Scroll
        (Window,
         (X_Offset => Float (X_Offset),
          Y_Offset => Float (Y_Offset),
          X        => 0.0,
          Y        => 0.0),
         Read_Cursor'Access);
   exception
      when E : others =>
         Registry.Note_Infrastructure_Failure
           (Scroll_Callback_Failure, Ada.Exceptions.Exception_Name (E));
   end Dispatch_Scroll;

   procedure Dispatch_Focus
     (Window  : Raw.GLFW_Window_Handle;
      Focused : Interfaces.C.int) is
   begin
      Registry.Dispatch_Focus (Window, (Focused => Focused /= 0));
   exception
      when E : others =>
         Registry.Note_Infrastructure_Failure
           (Focus_Callback_Failure, Ada.Exceptions.Exception_Name (E));
   end Dispatch_Focus;

   generic
      type Public_Callback is private;
      type Raw_Callback is private;
      with procedure Install
        (Window   : Raw.GLFW_Window_Handle;
         Callback : Raw_Callback;
         Guard    : in out Native_Change_Guard);
      Dispatcher : Raw_Callback;
      with procedure Store
        (Guard : in out Registry.Mutation_Guard;
         Value : Public_Callback);
   procedure Install_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Public_Callback);

   procedure Install_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Public_Callback)
   is
      Window : constant Raw.GLFW_Window_Handle :=
        GLFW_Vulkan.Windows.Internal.Handle (W);
      Guard : Registry.Mutation_Guard;
      Native_Change : Native_Change_Guard;
   begin
      Registry.Begin_Update (Guard, Window);
      Native_Change.Window := Window;
      Install (Window, Dispatcher, Native_Change);
      Store (Guard, Callback);
      Native_Change.Committed := True;
   end Install_Callback;

   procedure Install_Native_Key
     (Window   : Raw.GLFW_Window_Handle;
      Callback : Raw.Key_Callback_Access;
      Guard    : in out Native_Change_Guard) is
   begin
      Native_Callbacks.Set_Key.all
        (Window, Callback,
         Guard.Previous.Key'Access,
         Guard.Installed (Key_Channel)'Access);
   end Install_Native_Key;

   procedure Install_Native_Character
     (Window   : Raw.GLFW_Window_Handle;
      Callback : Raw.Char_Callback_Access;
      Guard    : in out Native_Change_Guard) is
   begin
      Native_Callbacks.Set_Character.all
        (Window, Callback,
         Guard.Previous.Character'Access,
         Guard.Installed (Character_Channel)'Access);
   end Install_Native_Character;

   procedure Install_Native_Mouse
     (Window   : Raw.GLFW_Window_Handle;
      Callback : Raw.Mouse_Button_Callback_Access;
      Guard    : in out Native_Change_Guard) is
   begin
      Native_Callbacks.Set_Mouse.all
        (Window, Callback,
         Guard.Previous.Mouse'Access,
         Guard.Installed (Mouse_Channel)'Access);
   end Install_Native_Mouse;

   procedure Install_Native_Cursor
     (Window   : Raw.GLFW_Window_Handle;
      Callback : Raw.Cursor_Pos_Callback_Access;
      Guard    : in out Native_Change_Guard) is
   begin
      Native_Callbacks.Set_Cursor.all
        (Window, Callback,
         Guard.Previous.Cursor'Access,
         Guard.Installed (Cursor_Channel)'Access);
   end Install_Native_Cursor;

   procedure Install_Native_Scroll
     (Window   : Raw.GLFW_Window_Handle;
      Callback : Raw.Scroll_Callback_Access;
      Guard    : in out Native_Change_Guard) is
   begin
      Native_Callbacks.Set_Scroll.all
        (Window, Callback,
         Guard.Previous.Scroll'Access,
         Guard.Installed (Scroll_Channel)'Access);
   end Install_Native_Scroll;

   procedure Install_Native_Focus
     (Window   : Raw.GLFW_Window_Handle;
      Callback : Raw.Window_Focus_Callback_Access;
      Guard    : in out Native_Change_Guard) is
   begin
      Native_Callbacks.Set_Focus.all
        (Window, Callback,
         Guard.Previous.Focus'Access,
         Guard.Installed (Focus_Channel)'Access);
   end Install_Native_Focus;

   procedure Install_Key_Callback is new Install_Callback
     (Public_Callback => Key_Callback,
      Raw_Callback    => Raw.Key_Callback_Access,
      Install         => Install_Native_Key,
      Dispatcher      => Dispatch_Key'Access,
      Store           => Registry.Set_Key);

   procedure Install_Character_Callback is new Install_Callback
     (Public_Callback => Character_Callback,
      Raw_Callback    => Raw.Char_Callback_Access,
      Install         => Install_Native_Character,
      Dispatcher      => Dispatch_Char'Access,
      Store           => Registry.Set_Character);

   procedure Install_Mouse_Button_Callback is new Install_Callback
     (Public_Callback => Mouse_Button_Callback,
      Raw_Callback    => Raw.Mouse_Button_Callback_Access,
      Install         => Install_Native_Mouse,
      Dispatcher      => Dispatch_Mouse_Button'Access,
      Store           => Registry.Set_Mouse_Button);

   procedure Install_Cursor_Position_Callback is new Install_Callback
     (Public_Callback => Cursor_Position_Callback,
      Raw_Callback    => Raw.Cursor_Pos_Callback_Access,
      Install         => Install_Native_Cursor,
      Dispatcher      => Dispatch_Cursor_Position'Access,
      Store           => Registry.Set_Cursor_Position);

   procedure Install_Scroll_Callback is new Install_Callback
     (Public_Callback => Scroll_Callback,
      Raw_Callback    => Raw.Scroll_Callback_Access,
      Install         => Install_Native_Scroll,
      Dispatcher      => Dispatch_Scroll'Access,
      Store           => Registry.Set_Scroll);

   procedure Install_Focus_Callback is new Install_Callback
     (Public_Callback => Focus_Callback,
      Raw_Callback    => Raw.Window_Focus_Callback_Access,
      Install         => Install_Native_Focus,
      Dispatcher      => Dispatch_Focus'Access,
      Store           => Registry.Set_Focus);

   procedure Set_Key_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Key_Callback)
   is
   begin
      Install_Key_Callback (W, Callback);
   end Set_Key_Callback;

   procedure Set_Character_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Character_Callback)
   is
   begin
      Install_Character_Callback (W, Callback);
   end Set_Character_Callback;

   procedure Set_Mouse_Button_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Mouse_Button_Callback)
   is
   begin
      Install_Mouse_Button_Callback (W, Callback);
   end Set_Mouse_Button_Callback;

   procedure Set_Cursor_Position_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Cursor_Position_Callback)
   is
   begin
      Install_Cursor_Position_Callback (W, Callback);
   end Set_Cursor_Position_Callback;

   procedure Set_Scroll_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Scroll_Callback)
   is
   begin
      Install_Scroll_Callback (W, Callback);
   end Set_Scroll_Callback;

   procedure Set_Focus_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Focus_Callback)
   is
   begin
      Install_Focus_Callback (W, Callback);
   end Set_Focus_Callback;

   procedure Store_Callback_Set
     (Guard : in out Registry.Mutation_Guard;
      Value : Callback_Set) is
   begin
      Registry.Set_Key (Guard, Value.Key);
      Registry.Set_Character (Guard, Value.Character);
      Registry.Set_Mouse_Button (Guard, Value.Mouse_Button);
      Registry.Set_Cursor_Position (Guard, Value.Cursor_Position);
      Registry.Set_Scroll (Guard, Value.Scroll);
      Registry.Set_Focus (Guard, Value.Focus);
   end Store_Callback_Set;

   procedure Restore_Native_Callbacks
     (Window        : Raw.GLFW_Window_Handle;
      Previous      : aliased in Raw_Callback_Set;
      Installed     : aliased in Callback_Channel_Set;
      Complete      : out Boolean;
      Reraise_Error : Boolean)
   is
      First_Error : Ada.Exceptions.Exception_Occurrence;
      Failed      : Boolean := False;

      procedure Note (Error : Ada.Exceptions.Exception_Occurrence) is
      begin
         if not Failed then
            Ada.Exceptions.Save_Occurrence (First_Error, Error);
            Failed := True;
         end if;
         begin
            Registry.Note_Infrastructure_Failure
              (Registry_Infrastructure_Failure,
               Ada.Exceptions.Exception_Name (Error));
         exception
            when others => null;
         end;
      end Note;

      Restored : aliased Interfaces.C.int;
      Discarded_Key : aliased Raw.Key_Callback_Access;
      Discarded_Character : aliased Raw.Char_Callback_Access;
      Discarded_Mouse : aliased Raw.Mouse_Button_Callback_Access;
      Discarded_Cursor : aliased Raw.Cursor_Pos_Callback_Access;
      Discarded_Scroll : aliased Raw.Scroll_Callback_Access;
      Discarded_Focus : aliased Raw.Window_Focus_Callback_Access;
   begin
      if Installed (Focus_Channel) /= 0 then
         begin
            Restored := 0;
            Native_Callbacks.Set_Focus.all
              (Window, Previous.Focus,
               Discarded_Focus'Access, Restored'Access);
            if Restored = 0 then
               raise Program_Error with "focus callback restoration failed";
            end if;
         exception
            when E : others => Note (E);
         end;
      end if;
      if Installed (Scroll_Channel) /= 0 then
         begin
            Restored := 0;
            Native_Callbacks.Set_Scroll.all
              (Window, Previous.Scroll,
               Discarded_Scroll'Access, Restored'Access);
            if Restored = 0 then
               raise Program_Error with "scroll callback restoration failed";
            end if;
         exception
            when E : others => Note (E);
         end;
      end if;
      if Installed (Cursor_Channel) /= 0 then
         begin
            Restored := 0;
            Native_Callbacks.Set_Cursor.all
              (Window, Previous.Cursor,
               Discarded_Cursor'Access, Restored'Access);
            if Restored = 0 then
               raise Program_Error with "cursor callback restoration failed";
            end if;
         exception
            when E : others => Note (E);
         end;
      end if;
      if Installed (Mouse_Channel) /= 0 then
         begin
            Restored := 0;
            Native_Callbacks.Set_Mouse.all
              (Window, Previous.Mouse,
               Discarded_Mouse'Access, Restored'Access);
            if Restored = 0 then
               raise Program_Error with "mouse callback restoration failed";
            end if;
         exception
            when E : others => Note (E);
         end;
      end if;
      if Installed (Character_Channel) /= 0 then
         begin
            Restored := 0;
            Native_Callbacks.Set_Character.all
              (Window, Previous.Character,
               Discarded_Character'Access, Restored'Access);
            if Restored = 0 then
               raise Program_Error with
                 "character callback restoration failed";
            end if;
         exception
            when E : others => Note (E);
         end;
      end if;
      if Installed (Key_Channel) /= 0 then
         begin
            Restored := 0;
            Native_Callbacks.Set_Key.all
              (Window, Previous.Key,
               Discarded_Key'Access, Restored'Access);
            if Restored = 0 then
               raise Program_Error with "key callback restoration failed";
            end if;
         exception
            when E : others => Note (E);
         end;
      end if;
      Complete := not Failed;
      if Failed and then Reraise_Error then
         Ada.Exceptions.Reraise_Occurrence (First_Error);
      end if;
   end Restore_Native_Callbacks;

   overriding procedure Finalize (Guard : in out Native_Change_Guard) is
      Complete : Boolean;
   begin
      if not Guard.Committed and then Guard.Window /= Raw.Null_Window then
         Restore_Native_Callbacks
           (Guard.Window,
            Guard.Previous,
            Guard.Installed,
            Complete,
            Reraise_Error => False);
      end if;
      Guard.Committed := True;
   exception
      when others => Guard.Committed := True;
   end Finalize;

   procedure Restore_Raw_Callbacks
     (Token : Callback_Binding_Token) is
      Complete : Boolean;
   begin
      Restore_Native_Callbacks
        (Token.Window,
         Token.Previous_Raw,
         Token.Installed,
         Complete,
         Reraise_Error => True);
   end Restore_Raw_Callbacks;

   procedure Attach_Callbacks
     (W         : in out GLFW_Vulkan.Windows.Window;
      Callbacks : Callback_Set;
      Token     : in out Callback_Binding_Token)
   is
      Window : constant Raw.GLFW_Window_Handle :=
        GLFW_Vulkan.Windows.Internal.Handle (W);
      Guard : Registry.Mutation_Guard;
   begin
      if Token.Active then
         raise Program_Error with "callback binding is already attached";
      elsif Window = Raw.Null_Window then
         raise Constraint_Error with "cannot bind callbacks to a null window";
      end if;
      Registry.Begin_Update (Guard, Window);
      Registry.Claim_Binding
        (Guard, Token.Owner, Token.Previous);
      Token.Window := Window;
      Token.Active := True;
      Native_Callbacks.Set_Key.all
        (Window, Dispatch_Key'Access,
         Token.Previous_Raw.Key'Access,
         Token.Installed (Key_Channel)'Access);
      Native_Callbacks.Set_Character.all
        (Window, Dispatch_Char'Access,
         Token.Previous_Raw.Character'Access,
         Token.Installed (Character_Channel)'Access);
      Native_Callbacks.Set_Mouse.all
        (Window, Dispatch_Mouse_Button'Access,
         Token.Previous_Raw.Mouse'Access,
         Token.Installed (Mouse_Channel)'Access);
      Native_Callbacks.Set_Cursor.all
        (Window, Dispatch_Cursor_Position'Access,
         Token.Previous_Raw.Cursor'Access,
         Token.Installed (Cursor_Channel)'Access);
      Native_Callbacks.Set_Scroll.all
        (Window, Dispatch_Scroll'Access,
         Token.Previous_Raw.Scroll'Access,
         Token.Installed (Scroll_Channel)'Access);
      Native_Callbacks.Set_Focus.all
        (Window, Dispatch_Focus'Access,
         Token.Previous_Raw.Focus'Access,
         Token.Installed (Focus_Channel)'Access);
      Store_Callback_Set (Guard, Callbacks);
   exception
      when Original : others =>
         if Token.Active then
            declare
               Saved : Ada.Exceptions.Exception_Occurrence;
               Restored : Boolean;
            begin
               Ada.Exceptions.Save_Occurrence (Saved, Original);
               begin
                  Restore_Native_Callbacks
                    (Token.Window,
                     Token.Previous_Raw,
                     Token.Installed,
                     Restored,
                     Reraise_Error => False);
                  if Restored then
                     Store_Callback_Set (Guard, Token.Previous);
                     Registry.Release_Binding (Guard, Token.Owner);
                     Token := (others => <>);
                  end if;
               exception
                  when Cleanup_Error : others =>
                     Registry.Note_Infrastructure_Failure
                       (Registry_Infrastructure_Failure,
                        Ada.Exceptions.Exception_Name (Cleanup_Error));
               end;
               Ada.Exceptions.Reraise_Occurrence (Saved);
            end;
         end if;
         raise;
   end Attach_Callbacks;

   procedure Detach_Callbacks
     (W     : in out GLFW_Vulkan.Windows.Window;
      Token : in out Callback_Binding_Token)
   is
      Window : constant Raw.GLFW_Window_Handle :=
        GLFW_Vulkan.Windows.Internal.Handle (W);
      Guard : Registry.Mutation_Guard;
   begin
      if not Token.Active then
         return;
      elsif Window /= Token.Window then
         raise Program_Error with "callback binding belongs to another window";
      end if;
      Registry.Begin_Update (Guard, Window);
      Registry.Authorize_Binding (Guard, Token.Owner);
      Restore_Raw_Callbacks (Token);
      Store_Callback_Set (Guard, Token.Previous);
      Registry.Release_Binding (Guard, Token.Owner);
      Token := (others => <>);
   end Detach_Callbacks;

   procedure Abandon_Callbacks (Token : in out Callback_Binding_Token) is
      Restored : Boolean;

      procedure Note (Error : Ada.Exceptions.Exception_Occurrence) is
      begin
         Registry.Note_Infrastructure_Failure
           (Registry_Infrastructure_Failure,
            Ada.Exceptions.Exception_Name (Error));
      end Note;
   begin
      if not Token.Active then
         return;
      end if;

      --  Remove the Ada callbacks before touching the native registrations.
      --  Any dispatcher left installed by a failing backend then finds no
      --  registry entry and cannot call a callback whose scope has ended.
      begin
         Registry.Retire (Token.Window);
      exception
         when E : others => Note (E);
      end;

      Restore_Native_Callbacks
        (Token.Window,
         Token.Previous_Raw,
         Token.Installed,
         Restored,
         Reraise_Error => False);
      Token := (others => <>);
   end Abandon_Callbacks;

   procedure Clear_Callbacks (W : in out GLFW_Vulkan.Windows.Window) is
      Window : constant Raw.GLFW_Window_Handle :=
        GLFW_Vulkan.Windows.Internal.Handle (W);
      Guard : Registry.Mutation_Guard;
      Native_Change : Native_Change_Guard;
   begin
      if Window = Raw.Null_Window then
         return;
      end if;
      --  Prevent new dispatches from acquiring a callback before detaching
      --  GLFW's C entry points, then wait for callbacks already in flight.
      Registry.Begin_Remove (Guard, Window);
      Native_Change.Window := Window;
      Install_Native_Key (Window, null, Native_Change);
      Install_Native_Character (Window, null, Native_Change);
      Install_Native_Mouse (Window, null, Native_Change);
      Install_Native_Cursor (Window, null, Native_Change);
      Install_Native_Scroll (Window, null, Native_Change);
      Install_Native_Focus (Window, null, Native_Change);
      Registry.Remove (Guard);
      Native_Change.Committed := True;
   end Clear_Callbacks;

   function Failure_Diagnostics return Failure_Snapshot is
     (Registry.Failures);
end GLFW_Vulkan.Input;
