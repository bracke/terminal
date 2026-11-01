with Interfaces.C;
with GLFW_Vulkan.Raw;
with GLFW_Vulkan.Windows.Internal;

package body GLFW_Vulkan.Input is
   use type Interfaces.C.int;
   use type Interfaces.C.unsigned;
   use type GLFW_Vulkan.Raw.GLFW_Window_Handle;

   Max_Callback_Windows : constant := 16;
   subtype Callback_Slot is Positive range 1 .. Max_Callback_Windows;
   type Window_Callbacks is record
      Window          : Raw.GLFW_Window_Handle := Raw.Null_Window;
      Key             : Key_Callback := null;
      Character       : Character_Callback := null;
      Mouse_Button    : Mouse_Button_Callback := null;
      Cursor_Position : Cursor_Position_Callback := null;
      Scroll          : Scroll_Callback := null;
      Focus           : Focus_Callback := null;
   end record;
   type Callback_Table is array (Callback_Slot) of Window_Callbacks;
   Callbacks : Callback_Table := (others => <>);

   function Find_Slot (Window : Raw.GLFW_Window_Handle) return Natural is
   begin
      if Window = Raw.Null_Window then
         return 0;
      end if;
      for I in Callbacks'Range loop
         if Callbacks (I).Window = Window then
            return I;
         end if;
      end loop;
      return 0;
   end Find_Slot;

   function Ensure_Slot (Window : Raw.GLFW_Window_Handle) return Callback_Slot is
      Existing : constant Natural := Find_Slot (Window);
   begin
      if Existing > 0 then
         return Callback_Slot (Existing);
      elsif Window = Raw.Null_Window then
         raise Constraint_Error with "cannot register callbacks for a null window";
      end if;
      for I in Callbacks'Range loop
         if Callbacks (I).Window = Raw.Null_Window then
            Callbacks (I).Window := Window;
            return I;
         end if;
      end loop;
      raise Storage_Error with "GLFW callback window capacity exceeded";
   end Ensure_Slot;

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
      Slot : constant Natural := Find_Slot (Window);
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
      if Slot > 0 and then Callbacks (Slot).Key /= null then
         Callbacks (Slot).Key.all (Event);
      end if;
   end Dispatch_Key;

   procedure Dispatch_Char
     (Window     : Raw.GLFW_Window_Handle;
      Code_Point : Interfaces.C.unsigned)
   is
      Slot : constant Natural := Find_Slot (Window);
   begin
      if Slot > 0
        and then Callbacks (Slot).Character /= null
        and then Natural (Code_Point) <= Wide_Wide_Character'Pos (Wide_Wide_Character'Last)
      then
         Callbacks (Slot).Character.all
           ((Code_Point => Wide_Wide_Character'Val (Natural (Code_Point))));
      end if;
   end Dispatch_Char;

   procedure Dispatch_Mouse_Button
     (Window : Raw.GLFW_Window_Handle;
      Button : Interfaces.C.int;
      Action : Interfaces.C.int;
      Mods   : Interfaces.C.int)
   is
      X_Pos : Interfaces.C.double := 0.0;
      Y_Pos : Interfaces.C.double := 0.0;
      Slot : constant Natural := Find_Slot (Window);
   begin
      if Slot > 0 and then Callbacks (Slot).Mouse_Button /= null then
         Raw.Get_Cursor_Pos (Window, X_Pos, Y_Pos);
         Callbacks (Slot).Mouse_Button.all
           ((Button     => To_Mouse_Button (Button),
             Raw_Button => Integer (Button),
             Action     => To_Action (Action),
             Modifiers  =>
               (Shift   => Has_Mod (Mods, Raw.GLFW_MOD_SHIFT),
                Control => Has_Mod (Mods, Raw.GLFW_MOD_CONTROL),
                Alt     => Has_Mod (Mods, Raw.GLFW_MOD_ALT),
                Super   => Has_Mod (Mods, Raw.GLFW_MOD_SUPER)),
             X          => Float (X_Pos),
             Y          => Float (Y_Pos)));
      end if;
   end Dispatch_Mouse_Button;

   procedure Dispatch_Cursor_Position
     (Window : Raw.GLFW_Window_Handle;
      X_Pos  : Interfaces.C.double;
      Y_Pos  : Interfaces.C.double)
   is
      Slot : constant Natural := Find_Slot (Window);
   begin
      if Slot > 0 and then Callbacks (Slot).Cursor_Position /= null then
         Callbacks (Slot).Cursor_Position.all
           ((X => Float (X_Pos), Y => Float (Y_Pos)));
      end if;
   end Dispatch_Cursor_Position;

   procedure Dispatch_Scroll
     (Window   : Raw.GLFW_Window_Handle;
      X_Offset : Interfaces.C.double;
      Y_Offset : Interfaces.C.double)
   is
      X_Pos : Interfaces.C.double := 0.0;
      Y_Pos : Interfaces.C.double := 0.0;
      Slot : constant Natural := Find_Slot (Window);
   begin
      if Slot > 0 and then Callbacks (Slot).Scroll /= null then
         Raw.Get_Cursor_Pos (Window, X_Pos, Y_Pos);
         Callbacks (Slot).Scroll.all
           ((X_Offset => Float (X_Offset),
             Y_Offset => Float (Y_Offset),
             X        => Float (X_Pos),
             Y        => Float (Y_Pos)));
      end if;
   end Dispatch_Scroll;

   procedure Dispatch_Focus
     (Window  : Raw.GLFW_Window_Handle;
      Focused : Interfaces.C.int)
   is
      Slot : constant Natural := Find_Slot (Window);
   begin
      if Slot > 0 and then Callbacks (Slot).Focus /= null then
         Callbacks (Slot).Focus.all ((Focused => Focused /= 0));
      end if;
   end Dispatch_Focus;

   procedure Set_Key_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Key_Callback)
   is
      Previous : Raw.Key_Callback_Access;
      Slot : constant Callback_Slot := Ensure_Slot
        (GLFW_Vulkan.Windows.Internal.Handle (W));
      pragma Unreferenced (Previous);
   begin
      Callbacks (Slot).Key := Callback;
      Previous := Raw.Set_Key_Callback
        (GLFW_Vulkan.Windows.Internal.Handle (W),
         Dispatch_Key'Access);
   end Set_Key_Callback;

   procedure Set_Character_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Character_Callback)
   is
      Previous : Raw.Char_Callback_Access;
      Slot : constant Callback_Slot := Ensure_Slot
        (GLFW_Vulkan.Windows.Internal.Handle (W));
      pragma Unreferenced (Previous);
   begin
      Callbacks (Slot).Character := Callback;
      Previous := Raw.Set_Char_Callback
        (GLFW_Vulkan.Windows.Internal.Handle (W),
         Dispatch_Char'Access);
   end Set_Character_Callback;

   procedure Set_Mouse_Button_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Mouse_Button_Callback)
   is
      Previous : Raw.Mouse_Button_Callback_Access;
      Slot : constant Callback_Slot := Ensure_Slot
        (GLFW_Vulkan.Windows.Internal.Handle (W));
      pragma Unreferenced (Previous);
   begin
      Callbacks (Slot).Mouse_Button := Callback;
      Previous := Raw.Set_Mouse_Button_Callback
        (GLFW_Vulkan.Windows.Internal.Handle (W),
         Dispatch_Mouse_Button'Access);
   end Set_Mouse_Button_Callback;

   procedure Set_Cursor_Position_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Cursor_Position_Callback)
   is
      Previous : Raw.Cursor_Pos_Callback_Access;
      Slot : constant Callback_Slot := Ensure_Slot
        (GLFW_Vulkan.Windows.Internal.Handle (W));
      pragma Unreferenced (Previous);
   begin
      Callbacks (Slot).Cursor_Position := Callback;
      Previous := Raw.Set_Cursor_Pos_Callback
        (GLFW_Vulkan.Windows.Internal.Handle (W),
         Dispatch_Cursor_Position'Access);
   end Set_Cursor_Position_Callback;

   procedure Set_Scroll_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Scroll_Callback)
   is
      Previous : Raw.Scroll_Callback_Access;
      Slot : constant Callback_Slot := Ensure_Slot
        (GLFW_Vulkan.Windows.Internal.Handle (W));
      pragma Unreferenced (Previous);
   begin
      Callbacks (Slot).Scroll := Callback;
      Previous := Raw.Set_Scroll_Callback
        (GLFW_Vulkan.Windows.Internal.Handle (W),
         Dispatch_Scroll'Access);
   end Set_Scroll_Callback;

   procedure Set_Focus_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Focus_Callback)
   is
      Previous : Raw.Window_Focus_Callback_Access;
      Slot : constant Callback_Slot := Ensure_Slot
        (GLFW_Vulkan.Windows.Internal.Handle (W));
      pragma Unreferenced (Previous);
   begin
      Callbacks (Slot).Focus := Callback;
      Previous := Raw.Set_Window_Focus_Callback
        (GLFW_Vulkan.Windows.Internal.Handle (W),
         Dispatch_Focus'Access);
   end Set_Focus_Callback;

   procedure Clear_Callbacks (W : in out GLFW_Vulkan.Windows.Window) is
      Window : constant Raw.GLFW_Window_Handle :=
        GLFW_Vulkan.Windows.Internal.Handle (W);
      Slot : constant Natural := Find_Slot (Window);
      Previous_Key : Raw.Key_Callback_Access;
      Previous_Char : Raw.Char_Callback_Access;
      Previous_Mouse : Raw.Mouse_Button_Callback_Access;
      Previous_Cursor : Raw.Cursor_Pos_Callback_Access;
      Previous_Scroll : Raw.Scroll_Callback_Access;
      Previous_Focus : Raw.Window_Focus_Callback_Access;
      pragma Unreferenced
        (Previous_Key, Previous_Char, Previous_Mouse, Previous_Cursor,
         Previous_Scroll, Previous_Focus);
   begin
      if Window = Raw.Null_Window then
         return;
      end if;
      Previous_Key := Raw.Set_Key_Callback (Window, null);
      Previous_Char := Raw.Set_Char_Callback (Window, null);
      Previous_Mouse := Raw.Set_Mouse_Button_Callback (Window, null);
      Previous_Cursor := Raw.Set_Cursor_Pos_Callback (Window, null);
      Previous_Scroll := Raw.Set_Scroll_Callback (Window, null);
      Previous_Focus := Raw.Set_Window_Focus_Callback (Window, null);
      if Slot > 0 then
         Callbacks (Slot) := (others => <>);
      end if;
   end Clear_Callbacks;
end GLFW_Vulkan.Input;
