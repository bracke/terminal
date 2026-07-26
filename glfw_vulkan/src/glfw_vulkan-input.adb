with Interfaces.C;
with GLFW_Vulkan.Raw;
with GLFW_Vulkan.Windows.Internal;

package body GLFW_Vulkan.Input is
   use type Interfaces.C.int;
   use type Interfaces.C.unsigned;
   use type GLFW_Vulkan.Raw.GLFW_Window_Handle;

   Global_Key_Callback  : Key_Callback := null;
   Global_Char_Callback : Character_Callback := null;
   Global_Mouse_Button_Callback : Mouse_Button_Callback := null;
   Global_Cursor_Position_Callback : Cursor_Position_Callback := null;
   Global_Scroll_Callback : Scroll_Callback := null;
   Global_Focus_Callback : Focus_Callback := null;

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
      pragma Unreferenced (Window);
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
      if Global_Key_Callback /= null then
         Global_Key_Callback.all (Event);
      end if;
   end Dispatch_Key;

   procedure Dispatch_Char
     (Window     : Raw.GLFW_Window_Handle;
      Code_Point : Interfaces.C.unsigned)
   is
      pragma Unreferenced (Window);
   begin
      if Global_Char_Callback /= null
        and then Natural (Code_Point) <= Wide_Wide_Character'Pos (Wide_Wide_Character'Last)
      then
         Global_Char_Callback.all
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
   begin
      if Global_Mouse_Button_Callback /= null then
         Raw.Get_Cursor_Pos (Window, X_Pos, Y_Pos);
         Global_Mouse_Button_Callback.all
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
      pragma Unreferenced (Window);
   begin
      if Global_Cursor_Position_Callback /= null then
         Global_Cursor_Position_Callback.all
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
   begin
      if Global_Scroll_Callback /= null then
         Raw.Get_Cursor_Pos (Window, X_Pos, Y_Pos);
         Global_Scroll_Callback.all
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
      pragma Unreferenced (Window);
   begin
      if Global_Focus_Callback /= null then
         Global_Focus_Callback.all ((Focused => Focused /= 0));
      end if;
   end Dispatch_Focus;

   procedure Set_Key_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Key_Callback)
   is
      Previous : Raw.Key_Callback_Access;
      pragma Unreferenced (Previous);
   begin
      Global_Key_Callback := Callback;
      Previous := Raw.Set_Key_Callback
        (GLFW_Vulkan.Windows.Internal.Handle (W),
         Dispatch_Key'Access);
   end Set_Key_Callback;

   procedure Set_Character_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Character_Callback)
   is
      Previous : Raw.Char_Callback_Access;
      pragma Unreferenced (Previous);
   begin
      Global_Char_Callback := Callback;
      Previous := Raw.Set_Char_Callback
        (GLFW_Vulkan.Windows.Internal.Handle (W),
         Dispatch_Char'Access);
   end Set_Character_Callback;

   procedure Set_Mouse_Button_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Mouse_Button_Callback)
   is
      Previous : Raw.Mouse_Button_Callback_Access;
      pragma Unreferenced (Previous);
   begin
      Global_Mouse_Button_Callback := Callback;
      Previous := Raw.Set_Mouse_Button_Callback
        (GLFW_Vulkan.Windows.Internal.Handle (W),
         Dispatch_Mouse_Button'Access);
   end Set_Mouse_Button_Callback;

   procedure Set_Cursor_Position_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Cursor_Position_Callback)
   is
      Previous : Raw.Cursor_Pos_Callback_Access;
      pragma Unreferenced (Previous);
   begin
      Global_Cursor_Position_Callback := Callback;
      Previous := Raw.Set_Cursor_Pos_Callback
        (GLFW_Vulkan.Windows.Internal.Handle (W),
         Dispatch_Cursor_Position'Access);
   end Set_Cursor_Position_Callback;

   procedure Set_Scroll_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Scroll_Callback)
   is
      Previous : Raw.Scroll_Callback_Access;
      pragma Unreferenced (Previous);
   begin
      Global_Scroll_Callback := Callback;
      Previous := Raw.Set_Scroll_Callback
        (GLFW_Vulkan.Windows.Internal.Handle (W),
         Dispatch_Scroll'Access);
   end Set_Scroll_Callback;

   procedure Set_Focus_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Focus_Callback)
   is
      Previous : Raw.Window_Focus_Callback_Access;
      pragma Unreferenced (Previous);
   begin
      Global_Focus_Callback := Callback;
      Previous := Raw.Set_Window_Focus_Callback
        (GLFW_Vulkan.Windows.Internal.Handle (W),
         Dispatch_Focus'Access);
   end Set_Focus_Callback;
end GLFW_Vulkan.Input;
