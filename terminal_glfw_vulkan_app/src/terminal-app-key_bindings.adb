with Ada.Characters.Handling;
with Ada.Strings;
with Ada.Strings.Fixed;

package body Terminal.App.Key_Bindings is
   use type GLFW_Vulkan.Input.Key_Action;
   use type GLFW_Vulkan.Input.Key;

   function Same
     (Left, Right : GLFW_Vulkan.Input.Modifier_Set) return Boolean is
     (Left.Shift = Right.Shift
      and then Left.Control = Right.Control
      and then Left.Alt = Right.Alt
      and then Left.Super = Right.Super);

   function Defaults return Binding_Set is
     ([Paste            => (GLFW_Vulkan.Input.V, (True, True, False, False), True),
       Copy             => (GLFW_Vulkan.Input.C, (True, True, False, False), True),
       Search           => (GLFW_Vulkan.Input.F, (True, True, False, False), True),
       Copy_Mode        => (GLFW_Vulkan.Input.Space, (True, True, False, False), True),
       Open_Links       => (GLFW_Vulkan.Input.O, (True, True, False, False), True),
       Command_Palette  => (GLFW_Vulkan.Input.P, (True, True, False, False), True),
       New_Window       => (GLFW_Vulkan.Input.N, (True, True, False, False), True),
       Detach_Tab       => (GLFW_Vulkan.Input.D, (True, True, False, False), True),
       Reload_Config    => (GLFW_Vulkan.Input.Comma, (True, True, False, False), True),
       Settings         => (GLFW_Vulkan.Input.Comma, (False, True, False, False), True),
       Toggle_Pane_Zoom => (GLFW_Vulkan.Input.Z, (True, True, False, False), True),
       Move_Pane        => (GLFW_Vulkan.Input.M, (True, True, False, False), True),
       Broadcast_Input  => (GLFW_Vulkan.Input.I, (True, True, False, False), True),
       Toggle_Recording => (GLFW_Vulkan.Input.G, (True, True, False, False), True),
       Replay_Recording => (GLFW_Vulkan.Input.J, (True, True, False, False), True),
       Export_Transcript => (GLFW_Vulkan.Input.S, (True, True, False, False), True),
       Previous_Mark    => (GLFW_Vulkan.Input.Up, (True, True, False, False), True),
       Next_Mark        => (GLFW_Vulkan.Input.Down, (True, True, False, False), True),
       Select_Command_Block => (GLFW_Vulkan.Input.B, (True, True, False, False), True),
       Copy_Command_Block   => (GLFW_Vulkan.Input.Y, (True, True, False, False), True),
       Rerun_Command_Block  => (GLFW_Vulkan.Input.R, (True, True, False, False), True),
       Font_Increase    => (GLFW_Vulkan.Input.Equal, (True, True, False, False), True),
       Font_Decrease    => (GLFW_Vulkan.Input.Minus, (True, True, False, False), True),
       Font_Reset       => (GLFW_Vulkan.Input.Num_0, (True, True, False, False), True),
       New_Tab          => (GLFW_Vulkan.Input.T, (True, True, False, False), True),
       Close_Tab        => (GLFW_Vulkan.Input.W, (True, True, False, False), True),
       Next_Tab         => (GLFW_Vulkan.Input.Page_Down, (False, True, False, False), True),
       Previous_Tab     => (GLFW_Vulkan.Input.Page_Up, (False, True, False, False), True),
       Split_Horizontal => (GLFW_Vulkan.Input.H, (True, True, False, False), True),
       Split_Vertical   => (GLFW_Vulkan.Input.E, (True, True, False, False), True),
       Close_Pane       => (GLFW_Vulkan.Input.X, (True, True, False, False), True),
       Next_Pane        => (GLFW_Vulkan.Input.L, (True, True, False, False), True)]);

   function Key_From_Name
     (Name : String;
      Key  : out GLFW_Vulkan.Input.Key) return Boolean
   is
      Lower : constant String := Ada.Characters.Handling.To_Lower (Name);
   begin
      Key := GLFW_Vulkan.Input.Unknown;
      if Lower'Length = 1 and then Lower (Lower'First) in 'a' .. 'z' then
         Key := GLFW_Vulkan.Input.Key'Value
           (String'(1 => Ada.Characters.Handling.To_Upper (Lower (Lower'First))));
      elsif Lower'Length = 1 and then Lower (Lower'First) in '0' .. '9' then
         Key := GLFW_Vulkan.Input.Key'Value ("NUM_" & Lower);
      elsif Lower = "space" then Key := GLFW_Vulkan.Input.Space;
      elsif Lower = "enter" or else Lower = "return" then Key := GLFW_Vulkan.Input.Enter;
      elsif Lower = "tab" then Key := GLFW_Vulkan.Input.Tab;
      elsif Lower = "escape" or else Lower = "esc" then Key := GLFW_Vulkan.Input.Escape;
      elsif Lower = "backspace" then Key := GLFW_Vulkan.Input.Backspace;
      elsif Lower = "insert" then Key := GLFW_Vulkan.Input.Insert;
      elsif Lower = "delete" then Key := GLFW_Vulkan.Input.Delete;
      elsif Lower = "home" then Key := GLFW_Vulkan.Input.Home;
      elsif Lower = "end" then Key := GLFW_Vulkan.Input.End_Key;
      elsif Lower = "pageup" or else Lower = "page_up" then Key := GLFW_Vulkan.Input.Page_Up;
      elsif Lower = "pagedown" or else Lower = "page_down" then Key := GLFW_Vulkan.Input.Page_Down;
      elsif Lower = "up" then Key := GLFW_Vulkan.Input.Up;
      elsif Lower = "down" then Key := GLFW_Vulkan.Input.Down;
      elsif Lower = "left" then Key := GLFW_Vulkan.Input.Left;
      elsif Lower = "right" then Key := GLFW_Vulkan.Input.Right;
      elsif Lower = "minus" or else Lower = "-" then Key := GLFW_Vulkan.Input.Minus;
      elsif Lower = "comma" or else Lower = "," then Key := GLFW_Vulkan.Input.Comma;
      elsif Lower = "equal" or else Lower = "=" or else Lower = "+" then Key := GLFW_Vulkan.Input.Equal;
      elsif Lower'Length in 2 .. 3 and then Lower (Lower'First) = 'f' then
         Key := GLFW_Vulkan.Input.Key'Value (Ada.Characters.Handling.To_Upper (Lower));
      else
         return False;
      end if;
      return True;
   exception
      when Constraint_Error =>
         Key := GLFW_Vulkan.Input.Unknown;
         return False;
   end Key_From_Name;

   function Parse (Text : String; Result : out Binding) return Boolean is
      Clean : constant String := Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both);
      Start : Natural := Clean'First;
      Finish : Natural;
      Saw_Key : Boolean := False;
   begin
      Result := (others => <>);
      if Clean = "" or else Ada.Characters.Handling.To_Lower (Clean) = "none" then
         return Clean /= "";
      elsif Clean (Clean'Last) = '+' then
         return False;
      end if;
      while Start <= Clean'Last loop
         Finish := Start;
         while Finish <= Clean'Last and then Clean (Finish) /= '+' loop
            Finish := Finish + 1;
         end loop;
         declare
            Token : constant String := Ada.Characters.Handling.To_Lower
              (Ada.Strings.Fixed.Trim
                 (Clean (Start .. Finish - 1), Ada.Strings.Both));
         begin
            if Token = "ctrl" or else Token = "control" then
               Result.Modifiers.Control := True;
            elsif Token = "shift" then
               Result.Modifiers.Shift := True;
            elsif Token = "alt" or else Token = "option" then
               Result.Modifiers.Alt := True;
            elsif Token = "super" or else Token = "cmd" or else Token = "command" then
               Result.Modifiers.Super := True;
            elsif Saw_Key or else not Key_From_Name (Token, Result.Key) then
               return False;
            else
               Saw_Key := True;
            end if;
         end;
         Start := Finish + 1;
      end loop;
      Result.Enabled := Saw_Key;
      return Saw_Key;
   end Parse;

   function Image (Value : Binding) return String is
      function Key_Name return String is
      begin
         case Value.Key is
            when GLFW_Vulkan.Input.A .. GLFW_Vulkan.Input.Z =>
               return Ada.Characters.Handling.To_Lower
                 (GLFW_Vulkan.Input.Key'Image (Value.Key));
            when GLFW_Vulkan.Input.Num_0 .. GLFW_Vulkan.Input.Num_9 =>
               declare
                  Full : constant String :=
                    GLFW_Vulkan.Input.Key'Image (Value.Key);
               begin
                  return Full (Full'Last .. Full'Last);
               end;
            when GLFW_Vulkan.Input.Space => return "space";
            when GLFW_Vulkan.Input.Enter => return "enter";
            when GLFW_Vulkan.Input.Tab => return "tab";
            when GLFW_Vulkan.Input.Escape => return "escape";
            when GLFW_Vulkan.Input.Backspace => return "backspace";
            when GLFW_Vulkan.Input.Insert => return "insert";
            when GLFW_Vulkan.Input.Delete => return "delete";
            when GLFW_Vulkan.Input.Home => return "home";
            when GLFW_Vulkan.Input.End_Key => return "end";
            when GLFW_Vulkan.Input.Page_Up => return "pageup";
            when GLFW_Vulkan.Input.Page_Down => return "pagedown";
            when GLFW_Vulkan.Input.Up => return "up";
            when GLFW_Vulkan.Input.Down => return "down";
            when GLFW_Vulkan.Input.Left => return "left";
            when GLFW_Vulkan.Input.Right => return "right";
            when GLFW_Vulkan.Input.Minus => return "minus";
            when GLFW_Vulkan.Input.Comma => return "comma";
            when GLFW_Vulkan.Input.Equal => return "equal";
            when GLFW_Vulkan.Input.F1 .. GLFW_Vulkan.Input.F12 =>
               return Ada.Characters.Handling.To_Lower
                 (GLFW_Vulkan.Input.Key'Image (Value.Key));
            when others => return "none";
         end case;
      end Key_Name;
   begin
      if not Value.Enabled then
         return "none";
      end if;
      return
        (if Value.Modifiers.Control then "ctrl+" else "")
        & (if Value.Modifiers.Shift then "shift+" else "")
        & (if Value.Modifiers.Alt then "alt+" else "")
        & (if Value.Modifiers.Super then "super+" else "")
        & Key_Name;
   end Image;

   function Action_For
     (Bindings : Binding_Set;
      Event    : GLFW_Vulkan.Input.Key_Event) return Action is
      Default_Bindings : constant Binding_Set := Defaults;
   begin
      if Event.Action = GLFW_Vulkan.Input.Release then
         return No_Action;
      end if;
      for Candidate in Configurable_Action loop
         if Bindings (Candidate).Enabled
           and then Bindings (Candidate).Key = Event.Key
           and then Same (Bindings (Candidate).Modifiers, Event.Modifiers)
         then
            return Candidate;
         end if;
      end loop;
      --  Preserve the platform-style copy/paste aliases while the primary
      --  binding retains its default.  Customizing or disabling that action
      --  replaces the whole default shortcut family.
      if Bindings (Paste) = Default_Bindings (Paste)
        and then
          ((Event.Key = GLFW_Vulkan.Input.V
            and then Same
              (Event.Modifiers,
               (Shift => False, Control => False,
                Alt => False, Super => True)))
           or else
             (Event.Key = GLFW_Vulkan.Input.Insert
              and then Same
                (Event.Modifiers,
                 (Shift => True, Control => False,
                  Alt => False, Super => False))))
      then
         return Paste;
      elsif Bindings (Copy) = Default_Bindings (Copy)
        and then
          ((Event.Key = GLFW_Vulkan.Input.C
            and then Same
              (Event.Modifiers,
               (Shift => False, Control => False,
                Alt => False, Super => True)))
           or else
             (Event.Key = GLFW_Vulkan.Input.Insert
              and then Same
                (Event.Modifiers,
                 (Shift => False, Control => True,
                  Alt => False, Super => False))))
      then
         return Copy;
      end if;
      return No_Action;
   end Action_For;

   function Action_Name (Value : Configurable_Action) return String is
   begin
      case Value is
         when Paste => return "paste";
         when Copy => return "copy";
         when Search => return "search";
         when Copy_Mode => return "copy-mode";
         when Open_Links => return "open-links";
         when Command_Palette => return "command-palette";
         when New_Window => return "new-window";
         when Detach_Tab => return "detach-tab";
         when Reload_Config => return "reload-config";
         when Settings => return "settings";
         when Toggle_Pane_Zoom => return "toggle-pane-zoom";
         when Move_Pane => return "move-pane";
         when Broadcast_Input => return "broadcast-input";
         when Toggle_Recording => return "toggle-recording";
         when Replay_Recording => return "replay-recording";
         when Export_Transcript => return "export-transcript";
         when Previous_Mark => return "previous-mark";
         when Next_Mark => return "next-mark";
         when Select_Command_Block => return "select-command-block";
         when Copy_Command_Block => return "copy-command-block";
         when Rerun_Command_Block => return "rerun-command-block";
         when Font_Increase => return "font-increase";
         when Font_Decrease => return "font-decrease";
         when Font_Reset => return "font-reset";
         when New_Tab => return "new-tab";
         when Close_Tab => return "close-tab";
         when Next_Tab => return "next-tab";
         when Previous_Tab => return "previous-tab";
         when Split_Horizontal => return "split-horizontal";
         when Split_Vertical => return "split-vertical";
         when Close_Pane => return "close-pane";
         when Next_Pane => return "next-pane";
      end case;
   end Action_Name;

   function Parse_Action_Name
     (Name   : String;
      Result : out Configurable_Action) return Boolean
   is
      Lower : constant String := Ada.Characters.Handling.To_Lower (Name);
   begin
      for Candidate in Configurable_Action loop
         if Lower = Action_Name (Candidate) then
            Result := Candidate;
            return True;
         end if;
      end loop;
      Result := Paste;
      return False;
   end Parse_Action_Name;
end Terminal.App.Key_Bindings;
